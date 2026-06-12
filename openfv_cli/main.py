# SPDX-License-Identifier: Apache-2.0
# openfv CLI entry point — skeleton for P0.7.
#
# Implements: docs/specs/cli.md v0.1
#   openfv run <filelist.f | file.sv ...> --top <module> [options]
#
# Exit codes (docs/specs/cli.md §Exit codes):
#   0  — completed cleanly
#   10 — usage error
#   11 — parse/elaboration error
#   12 — unsupported construct (not yet applicable in skeleton)
#   13 — internal error (missing binary, etc.)

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .errors import EXIT_INTERNAL, InternalError, ParseError, UsageError
from .filelist import parse_filelist
from .frontend import run_parse_only

# Flags that require stages not yet built (M1+) — accepted and validated but
# produce a clean "not implemented until M1" error (exit 13, NOT exit 10).
_M1_FLAGS = ("--emit-only", "--sva", "--depth", "--timeout", "--engines")


class _Parser(argparse.ArgumentParser):
    """ArgumentParser subclass that exits with code 10 (not 2) on usage errors.

    Per docs/specs/cli.md: "10 — usage error (bad flags, missing files)."
    argparse's default exit code for usage errors is 2; we override it.
    """

    def error(self, message: str) -> None:  # type: ignore[override]
        self.print_usage(sys.stderr)
        self.exit(10, f"{self.prog}: error: {message}\n")


def _build_parser() -> _Parser:
    parser = _Parser(
        prog="openfv",
        description="Open-source SVA formal verification — CLI skeleton (P0.7 / M0).",
        add_help=True,
    )
    sub = parser.add_subparsers(dest="command", parser_class=_Parser)

    run = sub.add_parser(
        "run",
        help="Parse, elaborate, and (eventually) verify a design.",
        description=(
            "Parse and elaborate a SystemVerilog design.  "
            "Full verification is available from M1 onwards."
        ),
    )

    run.add_argument(
        "inputs",
        nargs="+",
        metavar="file",
        help=".f filelist(s) or .sv source file(s)",
    )
    run.add_argument(
        "--top",
        required=True,
        metavar="MODULE",
        help="Top-level module to elaborate (required).",
    )
    run.add_argument(
        "--out",
        default="./openfv.out",
        metavar="DIR",
        help="Output directory (default: ./openfv.out).",
    )
    run.add_argument(
        "--parse-only",
        action="store_true",
        help="Stop after parse + elaboration (M0 milestone mode).",
    )
    run.add_argument(
        "--emit-only",
        action="store_true",
        help="Stop after .btor2 + .locmap emission; run no engine.  [not implemented until M1]",
    )
    run.add_argument(
        "--sva",
        action="append",
        default=[],
        metavar="FILE",
        help="Additional SVA/bind file (repeatable).  [not implemented until M1]",
    )
    run.add_argument(
        "--depth",
        type=int,
        default=20,
        metavar="N",
        help="BMC bound (default: 20).  [not implemented until M1]",
    )
    run.add_argument(
        "--timeout",
        type=int,
        default=600,
        metavar="SEC",
        help="Per-property wall-clock limit in seconds (default: 600).  [not implemented until M1]",
    )
    run.add_argument(
        "--engines",
        default=None,
        metavar="CSV",
        help="Engine/method portfolio selection (comma-separated).  [not implemented until M1]",
    )
    run.add_argument(
        "-v",
        dest="verbose",
        action="count",
        default=0,
        help="Increase verbosity (-v or -vv).",
    )

    return parser


def _collect_sv_files(inputs: list[str]) -> list[str]:
    """Expand any .f filelists; return a flat ordered list of .sv paths."""
    sv_files: list[str] = []
    for inp in inputs:
        p = Path(inp)
        if not p.exists():
            raise UsageError(f"input file not found: {inp}")
        suffix = p.suffix.lower()
        if suffix == ".f":
            expanded, _opts = parse_filelist(p)
            for sf in expanded:
                if not Path(sf).exists():
                    raise UsageError(
                        f"file listed in {inp} not found: {sf}"
                    )
            sv_files.extend(expanded)
        elif suffix in (".sv", ".v", ".svh", ".vh"):
            sv_files.append(str(p.resolve()))
        else:
            raise UsageError(
                f"unrecognised input file type '{suffix}': {inp}\n"
                "  Expected: .f (filelist) or .sv/.v source file."
            )
    if not sv_files:
        raise UsageError(
            "no source files after expanding filelist(s); nothing to elaborate."
        )
    return sv_files


def _validate_depth(depth: int) -> None:
    if depth < 1:
        raise UsageError(f"--depth must be a positive integer, got {depth}.")


def _validate_timeout(timeout: int) -> None:
    if timeout < 1:
        raise UsageError(f"--timeout must be a positive integer, got {timeout}.")


def _not_implemented(flag: str) -> None:
    """Exit 13 for flags that require the not-yet-built pipeline (M1+)."""
    raise InternalError(
        f"{flag} requires pipeline stages not yet built (available from M1).\n"
        "Use --parse-only to exercise the M0 skeleton."
    )


def cmd_run(args: argparse.Namespace) -> int:
    """Implement `openfv run`."""
    # Validate flags that require M1+ pipeline — these are usage-correct but
    # not-yet-implemented, so exit 13 (internal / not-implemented), NOT exit 10.
    if args.emit_only:
        _not_implemented("--emit-only")
    if args.sva:
        _not_implemented("--sva")
    if args.engines is not None:
        _not_implemented("--engines")

    # Validate numeric bounds (wrong values = usage error, exit 10).
    _validate_depth(args.depth)
    _validate_timeout(args.timeout)

    # --depth and --timeout without --parse-only / --emit-only only make sense
    # for the engine pipeline.  Accept them silently for now; they are no-ops
    # in --parse-only mode (see cli.md: "accept and validate").

    if not args.parse_only:
        # Full verification path — not implemented until M1.
        _not_implemented("full verification (no --parse-only flag)")

    # --- --parse-only path ---
    sv_files = _collect_sv_files(args.inputs)

    if args.verbose >= 1:
        print(f"[rtl-lower] inputs ({len(sv_files)} file(s)):", flush=True)
        for sf in sv_files:
            print(f"[rtl-lower]   {sf}", flush=True)

    run_parse_only(sv_files, top=args.top, verbose=args.verbose)
    # run_parse_only raises ParseError (exit 11) or InternalError (exit 13)
    # on failure; on success it returns normally.
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)

    if args.command is None:
        parser.print_help(sys.stderr)
        raise SystemExit(10)

    if args.command == "run":
        return cmd_run(args)

    # Unreachable with current subparser set, but be safe.
    raise UsageError(f"unknown command: {args.command}")


def entry() -> None:
    """Console-script entry point."""
    try:
        code = main()
    except SystemExit as exc:
        sys.exit(exc.code)
    except Exception as exc:  # noqa: BLE001
        # Uncaught exception — do NOT print a traceback to the user;
        # report as internal error (exit 13).
        print(
            f"openfv: unexpected internal error: {exc}\n"
            "(If you see this, please file an issue with the --vv output.)",
            file=sys.stderr,
        )
        sys.exit(EXIT_INTERNAL)
    sys.exit(code)
