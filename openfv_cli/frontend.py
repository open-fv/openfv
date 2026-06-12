# SPDX-License-Identifier: Apache-2.0
# circt-verilog frontend invocation — written clean-room from the cli.md spec
# and from direct inspection of `circt-verilog --help`.
#
# Binary location: $OPENFV_DEPS_PREFIX/bin/circt-verilog
# Documented fallback default: /home/achat/git/openfv/.openfv-deps/install
#
# circt-verilog flags used:
#   --parse-only          parse + elaborate only, no CIRCT IR lowering
#   --top=<name>          designate top module (can be repeated; we pass once)
#
# Diagnostics emitted by slang/circt-verilog already carry file:line:col
# prefixes when errors are present.  We forward stderr unchanged.

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

from .errors import InternalError, ParseError

# Documented fallback default for the installed deps tree.
_DEFAULT_DEPS_PREFIX = "/home/achat/git/openfv/.openfv-deps/install"


def _find_binary() -> str:
    """Return the path to circt-verilog, or raise InternalError."""
    prefix = os.environ.get("OPENFV_DEPS_PREFIX", _DEFAULT_DEPS_PREFIX)
    candidate = Path(prefix) / "bin" / "circt-verilog"
    if candidate.is_file() and os.access(candidate, os.X_OK):
        return str(candidate)
    raise InternalError(
        f"circt-verilog not found at {candidate}.\n"
        "Set OPENFV_DEPS_PREFIX to the install root (the directory that contains bin/).\n"
        "See docs/BUILDING.md for build instructions."
    )


def run_parse_only(
    sv_files: list[str],
    top: str,
    verbose: int = 0,
) -> None:
    """Invoke circt-verilog --parse-only on sv_files with --top=<top>.

    On success: prints a [rtl-lower] stage line and returns normally.
    On parse/elaboration error: prints diagnostics on stderr (forwarded from
    the tool, which already carries file:line:col) and raises ParseError(exit 11).
    On binary not found: raises InternalError(exit 13).
    """
    binary = _find_binary()

    cmd = [binary, "--parse-only", f"--top={top}"] + sv_files

    if verbose >= 2:
        print(f"[rtl-lower] running: {' '.join(cmd)}", flush=True)

    result = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    # Forward any stdout from the tool (informational messages).
    if result.stdout and verbose >= 1:
        for line in result.stdout.splitlines():
            print(f"[rtl-lower] {line}", flush=True)

    if result.returncode != 0:
        # circt-verilog / slang write diagnostics to stderr with file:line:col.
        # Forward them directly — do NOT add a Python traceback.
        if result.stderr:
            print(result.stderr, end="", file=sys.stderr)
        elif result.stdout:
            # Some versions write errors to stdout; forward to stderr.
            print(result.stdout, end="", file=sys.stderr)
        else:
            print(
                f"circt-verilog exited with code {result.returncode} (no diagnostic output)",
                file=sys.stderr,
            )
        raise ParseError("")  # message already printed above

    # Success.
    print(f"[rtl-lower] parse + elaboration OK  (top: {top})", flush=True)
    if verbose >= 2 and result.stderr:
        for line in result.stderr.splitlines():
            print(f"[rtl-lower] {line}", flush=True)
