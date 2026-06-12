# `.locmap` — BTOR2 ↔ RTL location map, v0.1

**Producer:** `btor2-emit`, written alongside every `.btor2` it emits (same basename: `foo.btor2` + `foo.locmap.json`).
**Consumers:** `witness-remap` (to name witness signals), `openfv` (to report properties by source location).
**Schema:** [`locmap-0.1.schema.json`](locmap-0.1.schema.json) · **Example:** [`examples/fifo.locmap.json`](examples/fifo.locmap.json)

## Purpose

A BTOR2 file identifies everything by numeric node id. The `.locmap` is the sidecar that lets later stages translate node ids back to the names the engineer wrote: hierarchical RTL paths, source file/line, widths, and which nodes are verification properties. It is the *only* channel for this information — nothing downstream may parse names out of the `.btor2` itself.

## Top-level fields

| Field | Meaning |
|---|---|
| `locmap_version` | `"0.1"`. Consumers reject unknown versions. |
| `generator` | Tool name + version that produced the file (for bug reports). |
| `design` | `top` module name, the `btor2_file` this sidecar describes, optional `source_files` list. |
| `step` | What one BTOR2 transition step means in RTL time. v0.1 supports only `{"kind": "single-clock", "clock_path": ..., "edge": ...}`: one step = one sampling event at that clock edge (sampling per IEEE 1800-2017 §16.5.1; see P1.8 semantics doc). Multiclock designs are **refused** in v0.1; a future version adds a `multi-clock` kind. |
| `signals` | Mapped BTOR2 nodes (see below). |
| `properties` | Verification nodes (see below). |
| `unmapped` | BTOR2 state/input nodes with **no** RTL identity (see below). |

## `signals[]` entries

| Field | Meaning |
|---|---|
| `btor2_id` | The node id (the leading integer of the node's line) in the `.btor2` file. |
| `kind` | `input` \| `state` \| `memory` (array-sorted state) \| `node` (a named combinational node, e.g. a wire that survived lowering). |
| `path` | Full hierarchical RTL name, `.`-separated, rooted at the top module name (e.g. `fifo.u_ctrl.wr_ptr`). |
| `width` | Bit width. For `memory`, MUST equal `memory.element_width`. |
| `signed` | Optional, default `false`. |
| `memory` | Required iff `kind == "memory"`: `{depth, element_width}`. |
| `source` | Optional `{file, line, col?}` of the declaration. Omitted only when genuinely unknown. |
| `origin` | `user` (declared in source RTL) \| `monitor` (introduced by sva-frontend's monitor automata) \| `lowering` (introduced by a lowering pass, e.g. a synthesized register). |

**Monitor signals** use the reserved hierarchy scope `_openfv` under the instance whose property they implement (e.g. `fifo._openfv.p_no_overflow.armed`) so waveform viewers group them away from user signals. The `_openfv` scope name is reserved: btor2-emit MUST reject user RTL that declares an identifier named `_openfv`.

## `properties[]` entries

| Field | Meaning |
|---|---|
| `btor2_id` | Node id of the `bad`/`justice`/`constraint`/`fair` node. |
| `role` | `bad` (safety violation marker, from `assert`) \| `constraint` (from `assume`) \| `justice` / `fairness` (reserved for liveness, Phase 2 R12 — emitted by no v0.1 producer). |
| `name` | Stable property name (see naming, below). Unique within the file. |
| `source` | `{file, line, col?}` of the assertion/assumption. |
| `text` | Optional verbatim source text, for display. |

**Property naming:** labeled assertions get `<instance path>.<label>` (e.g. `fifo.p_no_overflow`). Unlabeled assertions get `<instance path>.assert__<file-basename>__<line>`. Names are sanitized to `[A-Za-z0-9_.]`; anything else becomes `_`. These names are the join key used by `result.json` and `.wit` file naming — they must be stable across runs of the same input.

**Bad-index correspondence:** BTOR2 witnesses reference properties by *ordinal* (`b0`, `b1`, …), counting `bad` nodes in file order of the `.btor2`. Consumers derive the ordinal by sorting this file's `role == "bad"` entries by `btor2_id` ascending; the i-th is `b<i>`. (Same rule for `justice`/`j<i>`.) btor2-emit MUST emit `bad` nodes in increasing-id order so this rule holds trivially.

## `unmapped[]` entries

**Completeness invariant (the P1.3 contract):** every `state` and `input` node in the `.btor2` MUST appear in either `signals` or `unmapped`. Dropping a node silently is a bug — this is what makes "≥90% traceable, the rest *listed*" checkable.

| Field | Meaning |
|---|---|
| `btor2_id` | The node id. |
| `reason` | `optimized-away` (RTL signal existed but was folded by lowering) \| `no-location` (no source info survived; bug-tracked) \| `internal` (legitimately tool-internal, no RTL counterpart expected). |
| `note` | Optional free text (e.g. what it was folded into). |

## Invariants not expressible in JSON Schema (checked by consumers / tests)

1. Completeness invariant above.
2. `btor2_id` values are unique across `signals` + `properties` + `unmapped`.
3. Every `path` is rooted at `design.top`.
4. Property `name`s are unique.
5. `width == memory.element_width` for `kind == "memory"`.
