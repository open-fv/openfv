# openfv

End-to-end, freely-redistributable formal verification for SystemVerilog + SVA — no Jasper, no VC Formal.

A grad student points this at an OpenTitan block, runs one command, and gets either a trustworthy **PROVEN** or a source-named **counterexample waveform**.

## The goal

```
openfv run design.f --top dut --sva tb.sva
```

```
[rtl-lower]   Elaborating 42 modules...
[sva-front]   Compiling 7 properties...
[btor2-emit]  Emitting counter.btor2 (312 nodes)
[fv-engine]   Running IC3IA + BMC portfolio...
[result]      PROPERTY VIOLATION at cycle 47
[debug]       Writing wave: counter_cex.fst
              Open in Surfer: surfer counter_cex.fst
```

## Architecture

The BTOR2 conversion is the easy 10%. The hard parts are (a) a complete, correct SVA temporal compiler and (b) a witness-to-RTL debug layer. Everything below the SVA layer (parsing, word-level IR, BTOR2 emission, solving) already exists in the CIRCT/Slang/Pono ecosystem. This project is a thin orchestration shell plus two new components, riding on mature upstreams.

### Repository map

```
openfv (this repo — flagship)
 ├── sva-frontend ── slang, CIRCT ltl/verif dialects
 ├── rtl-lowering ── CIRCT MooreToCore
 ├── btor2-emit ───── CIRCT convert-hw-to-btor2
 ├── fv-engine ────── Pono, btormc, Bitwuzla       [planned]
 ├── witness-remap ── btor2tools, libfst            [planned]
 ├── fv-debug ─────── Surfer extension              [optional/late]
 └── fv-benchmarks    HWMCC, OpenTitan test data    [planned]
```

**Contract between repos is a file format, not an API call:**

| Stage | Input | Output |
|---|---|---|
| rtl-lowering + sva-frontend | `.sv` / `.f` | `.mlir` |
| btor2-emit | `.mlir` | `.btor2` + `.locmap` |
| fv-engine | `.btor2` | `result.json` + `.wit` |
| witness-remap | `.wit` + `.locmap` | `.fst` / `.vcd` |
| fv-debug / Surfer | `.fst` | interactive view |

Because every boundary is a file, each repo is independently testable with golden files alone.

### Tier 0 — Upstream dependencies (do NOT fork)

| Upstream | Role |
|---|---|
| [slang](https://github.com/MikePopoloski/slang) | SV-2017 parse + elaboration |
| [CIRCT](https://github.com/llvm/circt) | IR substrate; Moore/HW/Comb/Seq/ltl/verif dialects |
| [Pono](https://github.com/stanford-centaur/pono) | IC3IA, k-induction, BMC |
| [btormc](https://github.com/Boolector/boolector) | BTOR2 BMC + k-induction engine |
| [Bitwuzla](https://github.com/bitwuzla/bitwuzla) | SMT backend |
| [btor2tools](https://github.com/Boolector/btor2tools) | BTOR2 parse + witness format |
| [Surfer](https://gitlab.com/surfer-project/surfer) | Waveform viewer (Rust, extensible) |

Forking is a last resort — it forks the maintenance burden too. Upstream relentlessly.

## Roadmap

### Phase 0 — Skeleton (weeks 1–4)
Stand up CI, `fv-benchmarks` with trivial designs, `slang` + CIRCT building. **Milestone:** parse and elaborate a trivial design end-to-end.

### Phase 1 — Straight-line proof (months 2–4)
`rtl-lowering` + `btor2-emit` for combinational + simple sequential RTL. `fv-engine` orchestrating btormc/Pono for BMC. Simple concurrent assertions. **Milestone:** prove/disprove a safety property on a real FIFO with a counterexample.

### Phase 2 — SVA frontend, incrementally (months 4–10)
`sva-frontend` construct-by-construct, each gated by a conformance test against a simulator. `|->` / `|=>` / `##n` / `##[m:n]` first; repetition, `throughout`, `within` next; then unbounded operators and local variables.

### Phase 3 — Unbounded proofs (months 8–14)
`fv-engine` portfolio: k-induction + IC3IA (Pono) + btormc racing. **Milestone:** unbounded PROOF on a non-trivial design.

### Phase 4 — Source-level debug (months 12–18)
`witness-remap` → RTL-named FST. **Milestone:** engineer sees failing wave with their signal names.

### Phase 5 — Visualize-class debugger (months 18+, optional)
`fv-debug` as a Surfer extension: cone-of-influence, driver tracing.

## Hard truths

1. **Soundness > coverage > speed.** A tool that silently miscompiles one SVA construct is worse than one that refuses it.
2. **You are not writing a model checker or a parser.** Orchestrate Pono; consume Slang.
3. **The engine gap to Jasper is real and multi-year.** Be honest: this gives genuine open proofs, not Jasper-parity capacity.
4. **Upstream relentlessly.** Every pass that isn't SVA-monitor-specific belongs in CIRCT. Carrying a fork is how these projects die.

## Status

Phase 0 (skeleton) in progress — see [TASKS.md](TASKS.md) for live per-task status. All repos live under the [open-fv](https://github.com/open-fv) org and are wired here as submodules:

- [btor2-emit](https://github.com/open-fv/btor2-emit) — MLIR → BTOR2 + locmap, working prototype
- [sva-frontend](https://github.com/open-fv/sva-frontend), [rtl-lowering](https://github.com/open-fv/rtl-lowering) — scaffolded with pinned-CIRCT builds (P0.3)
- [fv-engine](https://github.com/open-fv/fv-engine), [witness-remap](https://github.com/open-fv/witness-remap), [fv-benchmarks](https://github.com/open-fv/fv-benchmarks) — scaffolded, work starts per TASKS.md
- [fv-debug](https://github.com/open-fv/fv-debug) — deferred until M4

Interface contracts (`.locmap`, `result.json`, CLI, `.wit`) are specified in [docs/specs/](docs/specs/). Build recipe: [docs/BUILDING.md](docs/BUILDING.md).

## Contributing

See the full architecture doc: [PROJECT_PLAN.md](PROJECT_PLAN.md), and the task-level work breakdown with per-task difficulty tiers and acceptance criteria: [TASKS.md](TASKS.md). Read the plan's legal/clean-room policy (§1) and execution model (§5) before picking up a task.

Each repo has its own CI. This flagship repo's CI runs cross-repo integration tests against `fv-benchmarks` (nightly once benchmarks exist). Correctness regressions are release-blocking; speed regressions are warnings.
