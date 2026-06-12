# `openfv` CLI contract, v0.1

**Implements:** TASKS P0.7 (skeleton), extended through M1–M4. The CLI surface and exit codes below are the stable interface; **stdout text is for humans and is NOT stable** — scripts consume `result.json`.

## Invocation

```
openfv run <filelist.f | file.sv ...> --top <module> [options]
```

| Option | Default | Meaning |
|---|---|---|
| `--top <name>` | (required) | Top module to elaborate. |
| `--sva <file>` | — | Additional SVA/bind file; repeatable. |
| `--out <dir>` | `./openfv.out` | Output directory (created; existing contents of a previous run overwritten). |
| `--depth <N>` | `20` | BMC bound. |
| `--timeout <sec>` | `600` | Per-property wall-clock limit. |
| `--engines <csv>` | all available | Engine/method portfolio selection (names per `result.json` `engine` values). |
| `--parse-only` | — | Stop after parse + elaboration (M0 milestone mode). |
| `--emit-only` | — | Stop after `.btor2` + `.locmap` emission; run no engine. |
| `-v` / `-vv` | — | Verbosity (human output only). |

Inputs: a `.f` filelist (one path/`+define+`-style option per line, `#` comments) and/or direct `.sv` files. Relative paths in a `.f` resolve against the `.f` file's directory.

## Output directory layout

```
<out>/
  <top>.btor2            # btor2-emit output
  <top>.locmap.json      # sidecar, per locmap.md
  result.json            # per result.md
  <property>.wit         # one per CEX property, per witness.md
  <property>.vcd|.fst    # Phase 4+, per witness-remap
  <top>.mlir             # only with -vv (debug artifact, not a stable interface)
```

## Exit codes

| Code | Meaning | `result.json` produced? |
|---|---|---|
| `0` | Every property `PROVEN` (with `--parse-only`/`--emit-only`: stage completed clean). | yes (unless `--parse-only`) |
| `1` | At least one `CEX`. | yes |
| `2` | No CEX, but ≥1 property inconclusive (`BOUNDED_CLEAN`, `UNKNOWN`, `TIMEOUT`, or property-level `ERROR`). | yes |
| `10` | Usage error (bad flags, missing files). | no |
| `11` | Parse/elaboration error (with source file:line diagnostics). | no |
| `12` | **Unsupported SVA construct** — the refuse-loudly gate (plan §2 soundness note, TASKS P2.5). Message names the construct, its source location, and the tracking issue. | no |
| `13` | Internal tool error (incl. the engine-conflict soundness abort, result.md). | no |

Precedence for 0/1/2: any CEX ⇒ `1` (even if other properties are inconclusive); else any inconclusive ⇒ `2`; else `0`. Codes ≥ 10 mean the run aborted: no `result.json` is written (a partial one from a previous run is deleted first, so a stale file can never be mistaken for this run's result).

## Human output convention

Stage-prefixed lines on stdout (`[rtl-lower]`, `[sva-front]`, `[btor2-emit]`, `[fv-engine]`, `[result]`, `[debug]`), errors on stderr with `file:line:col:` prefixes where known. Pretty, not parseable — by design.
