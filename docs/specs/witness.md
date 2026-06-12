# `.wit` — witness handling convention, v0.1

**Producer:** `fv-engine` · **Consumer:** `witness-remap`.

Unlike `.locmap`/`result.json`, the `.wit` format is not ours: it is the **standard BTOR2 witness text format** as publicly specified by the BTOR2 paper and the btor2tools documentation. This document specifies only our *conventions around* it. (Clean-room note: implementing from that published specification is in-policy, plan §1.1.)

## The normalization rule

`fv-engine` MUST write every counterexample as a standard BTOR2 witness, regardless of which engine produced it:

- `btormc` and Pono emit the format natively — passthrough after sanity-checking it parses (btor2tools parser).
- Any future engine with its own witness dialect (e.g. AVR) gets a converter **inside fv-engine**; engine-specific formats never cross the `.wit` boundary.
- A "CEX" whose witness cannot be parsed or normalized is reported as status `ERROR`, not `CEX` — an unverifiable counterexample is not a counterexample.

## File naming and placement

One witness per CEX property: `<out>/<property_name>.wit`, where `<property_name>` is the `.locmap`/`result.json` property `name` verbatim (it is already sanitized to `[A-Za-z0-9_.]` by the locmap naming rule). `result.json`'s `witness_file` field points to it.

## Interpretation conventions (for witness-remap)

- **Property reference:** the witness header's `b<i>`/`j<i>` ordinal resolves to a property via the bad-index correspondence rule in [locmap.md](locmap.md) (i-th `bad` node in ascending `btor2_id` order).
- **Step numbering:** frames are 0-based; frame `#0` is the initial state. One frame = one `.locmap` `step` (v0.1: one posedge of the single clock). `result.json` `depth` for a CEX equals the index of the last frame.
- **Values:** state/input assignments are binary strings per node id; array (memory) assignments carry an index. Node ids resolve through `.locmap` `signals`; ids absent from `signals` are looked up in `unmapped` and rendered under a reserved `_unmapped` scope rather than dropped.
- **Unassigned inputs:** an input not assigned in a frame is unconstrained at that step; witness-remap renders it as `x` in the wave (it must not invent a value).
