# SPDX-License-Identifier: Apache-2.0
# Exit-code constants and clean-exit helpers — per docs/specs/cli.md.
#
# Exit codes:
#   0   — all properties PROVEN (or --parse-only/--emit-only completed cleanly)
#   1   — at least one CEX
#   2   — no CEX but ≥1 property inconclusive
#   10  — usage error (bad flags, missing files)
#   11  — parse/elaboration error (source file:line diagnostics on stderr)
#   12  — unsupported SVA construct (refuse-loudly gate)
#   13  — internal tool error (missing binary, engine conflict, etc.)

import sys

EXIT_OK = 0
EXIT_CEX = 1
EXIT_INCONCLUSIVE = 2
EXIT_USAGE = 10
EXIT_PARSE = 11
EXIT_UNSUPPORTED = 12
EXIT_INTERNAL = 13


class UsageError(SystemExit):
    """Raised for bad flags / missing required arguments (exit 10)."""

    def __init__(self, message: str) -> None:
        print(f"openfv: error: {message}", file=sys.stderr)
        super().__init__(EXIT_USAGE)


class ParseError(SystemExit):
    """Raised when parse/elaboration fails (exit 11)."""

    def __init__(self, message: str) -> None:
        # Message already contains file:line where known; just print it.
        print(message, file=sys.stderr)
        super().__init__(EXIT_PARSE)


class InternalError(SystemExit):
    """Raised for internal tool errors — missing binary, engine abort (exit 13)."""

    def __init__(self, message: str) -> None:
        print(f"openfv: internal error: {message}", file=sys.stderr)
        super().__init__(EXIT_INTERNAL)
