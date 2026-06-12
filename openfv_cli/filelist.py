# SPDX-License-Identifier: Apache-2.0
# .f filelist parser — written clean-room from the cli.md spec.
#
# Spec reference: docs/specs/cli.md
#   "Inputs: a .f filelist (one path/+define+-style option per line, # comments)
#    and/or direct .sv files. Relative paths in a .f resolve against the .f
#    file's directory."

from __future__ import annotations

import os
from pathlib import Path
from typing import Sequence


def parse_filelist(fpath: str | Path) -> tuple[list[str], list[str]]:
    """Parse a .f filelist file.

    Returns (sv_files, options) where:
      sv_files — absolute paths to every source file referenced
      options  — verbatim option lines (lines starting with +, -, etc.)

    Lines starting with '#' (after stripping) are comments and are ignored.
    Blank lines are ignored.
    All other lines are treated as paths or option tokens.

    Relative paths are resolved against the directory containing the .f file.
    """
    fpath = Path(fpath).resolve()
    base_dir = fpath.parent

    sv_files: list[str] = []
    options: list[str] = []

    with open(fpath, "r", encoding="utf-8") as fh:
        for raw_line in fh:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            # Option-style tokens (+define+, -I, etc.) are collected separately.
            if line.startswith("+") or line.startswith("-"):
                options.append(line)
            else:
                # Treat as a path; resolve relative to the .f file's directory.
                p = Path(line)
                if not p.is_absolute():
                    p = base_dir / p
                sv_files.append(str(p.resolve()))

    return sv_files, options
