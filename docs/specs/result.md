# `result.json` — normalized verification result, v0.1

**Producer:** `fv-engine` (finalized by `openfv`, which owns `exit_code`).
**Consumers:** `openfv` CLI, CI regression tracking, users' scripts. This file is the *only* stable machine interface to results — stdout is for humans and may change freely.
**Schema:** [`result-0.1.schema.json`](result-0.1.schema.json) · **Example:** [`examples/fifo.result.json`](examples/fifo.result.json)

## Status enum (per property)

| Status | Meaning | Honesty rule |
|---|---|---|
| `PROVEN` | Unbounded proof (k-induction closed, IC3 invariant found). | Only an *unbounded* method may report this. |
| `CEX` | Concrete counterexample found. `witness_file` + `depth` required. | |
| `BOUNDED_CLEAN` | No violation within the explored bound (`depth`). | **Never** collapse into `PROVEN`. A clean BMC run is not a proof (TASKS P1.6). |
| `UNKNOWN` | Engine terminated without a verdict (e.g. induction failed to close). | Soundness audits (P3.5) may *downgrade* results to UNKNOWN; never upgrade. |
| `TIMEOUT` | Resource limit hit before a verdict. | |
| `ERROR` | Engine crashed or emitted unparseable output for this property. | Never mapped to any verdict. |

**Conflict rule (P3.3):** if two engines return contradictory definitive answers (`PROVEN` vs `CEX`) for the same property, fv-engine MUST abort the whole run with a tool error (exit ≥ 10, no `result.json`) reporting a soundness bug — it must not pick a winner.

## Fields

Top level: `result_version` (`"0.1"`), `tool` `{name, version}`, `design` `{top, btor2_file?, locmap_file?}`, `run` `{started_utc, wall_seconds, engines?[]}`, `properties[]`, `summary`, `exit_code`.

Per property:

| Field | Meaning |
|---|---|
| `name` | Join key — MUST match the `.locmap` property `name`. |
| `btor2_id` | The `bad` node id, when known (matches `.locmap`). |
| `status` | See enum above. |
| `engine` | Which engine produced the verdict (`btormc`, `pono`, `avr`, …); `null` if none did. |
| `method` | `bmc` \| `k-induction` \| `ic3ia` \| `other`; `null` if no verdict. Required for `PROVEN`. |
| `depth` | `CEX`: 0-based index of the failing step (= last frame of the witness). `BOUNDED_CLEAN`: the bound checked. `PROVEN` by k-induction: the closing k. Otherwise `null`/omitted. |
| `witness_file` | Path (relative to `result.json`'s directory) of the `.wit`. Present iff `CEX`. |
| `time_seconds` | Wall time spent on this property (winning engine's time under portfolio). |
| `detail` | Free text for humans (limits hit, engine notes). Not a stable interface. |

`summary` carries the count of properties per status (all six keys required, zeros included). `exit_code` records what the `openfv` process exited with, per the [CLI contract](cli.md): `0` all proven, `1` ≥1 CEX, `2` inconclusive — it can only be 0/1/2 here, because tool-level errors (≥10) abort without producing a `result.json`.

## Invariants not in the schema (checked by tests)

1. `summary` counts equal the actual tally of `properties[].status`.
2. `exit_code` is derived from statuses per the CLI precedence rule (CEX > inconclusive > proven).
3. Every `name` is unique and, when a `.locmap` is referenced, exists in it.
4. `witness_file` exists on disk next to `result.json` whenever status is `CEX`.
