#!/usr/bin/env python3
"""Validate the spec examples against their JSON Schemas (draft 2020-12).

Run from anywhere:  python3 docs/specs/check_specs.py
Exit 0 iff every example validates. CI runs this on every flagship PR.
"""

import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

SPECS = Path(__file__).resolve().parent

# (schema file, example file) pairs. Extend when a contract version bumps.
PAIRS = [
    ("locmap-0.1.schema.json", "examples/fifo.locmap.json"),
    ("result-0.1.schema.json", "examples/fifo.result.json"),
]


def check(schema_rel: str, example_rel: str) -> bool:
    schema = json.loads((SPECS / schema_rel).read_text())
    Draft202012Validator.check_schema(schema)
    example = json.loads((SPECS / example_rel).read_text())
    errors = sorted(
        Draft202012Validator(schema).iter_errors(example),
        key=lambda e: list(e.absolute_path),
    )
    if errors:
        print(f"FAIL  {example_rel} vs {schema_rel}")
        for e in errors:
            loc = "/".join(str(p) for p in e.absolute_path) or "<root>"
            print(f"      at {loc}: {e.message}")
        return False
    print(f"PASS  {example_rel} vs {schema_rel}")
    return True


def main() -> int:
    ok = all([check(s, e) for s, e in PAIRS])
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
