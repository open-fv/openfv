# openfv interface contracts

These specs are the **versioned contracts** between pipeline stages (PROJECT_PLAN.md §3). Every boundary is a file; each file format is specified here *before* anything implements it. Downstream tasks (P0.7, P1.4, P1.6, P4.x) implement from these documents alone.

| Contract | Producer | Consumer | Spec | Schema |
|---|---|---|---|---|
| `.locmap` sidecar | btor2-emit | witness-remap, openfv | [locmap.md](locmap.md) | [locmap-0.1.schema.json](locmap-0.1.schema.json) |
| `result.json` | fv-engine | openfv, CI, users | [result.md](result.md) | [result-0.1.schema.json](result-0.1.schema.json) |
| `.wit` witness | fv-engine | witness-remap | [witness.md](witness.md) | (text format, externally specified) |
| CLI + exit codes | openfv | users, CI | [cli.md](cli.md) | — |

## Versioning policy

- Every JSON contract instance carries its version in a top-level field (`locmap_version`, `result_version`).
- Pre-1.0, any breaking change bumps the minor version (`0.1` → `0.2`), gets a new schema file (old one stays for reference), and requires a flagship-repo PR that updates the spec doc, the schema, the examples, and passes `check_specs.py`.
- Producers MUST emit exactly one version; consumers MUST reject versions they don't know (fail loudly, never best-effort parse).
- Schemas use `additionalProperties: false` deliberately: unknown fields are a contract violation, not an extension mechanism. Extensions go through a version bump.

## Validation

```
python3 docs/specs/check_specs.py
```

validates every example in `examples/` against its schema (JSON Schema draft 2020-12). CI runs this on every flagship PR. Adding a field to a schema without updating the examples — or vice versa — turns CI red.

## Clean-room note

The BTOR2 and BTOR2-witness formats are publicly specified (the BTOR2 paper and the btor2tools documentation); VCD is specified in IEEE 1800. Implementing readers/writers from those public specifications is in-policy (plan §1.1). The `.locmap` and `result.json` formats are our own.
