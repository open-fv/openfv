# Open-Source SVA Formal Verification Suite — Project Plan

**Goal:** An end-to-end, freely-redistributable formal verification flow that an academic can point at industrial SystemVerilog RTL + SVA testbenches and get: correct compilation, unbounded proofs, and source-level counterexample waves — without Jasper or VC Formal.

**Strategic framing (read this first):** The BTOR2 conversion is the *easy 10%*. The hard, mostly-unsolved-in-open-source parts are (a) a **complete, correct SVA temporal compiler** and (b) a **witness-to-RTL debug layer**. Everything below the SVA layer (parsing, word-level IR, BTOR2 emission, solving) already exists in the CIRCT/Slang/Pono ecosystem in usable form. So this project is *not* a from-scratch tool — it is a thin orchestration shell plus two genuinely new components, riding on mature upstreams. Architect accordingly: maximize reuse, contribute upstream, own only what doesn't exist.

---

## 1. The repositories

Organize as a single GitHub **Org** (suggested: `openfv` or similar). The flagship repo pulls the others in as submodules. Keep each repo small, single-purpose, and independently testable. Names below are suggestions — pick your own house style, but keep the *boundaries*.

### Tier 0 — Upstream dependencies (do NOT fork unless forced)

These are consumed as libraries/submodules. You contribute patches upstream rather than maintaining forks. Forking is a last resort because it forks the maintenance burden too.

| Upstream | Role | How you use it |
|---|---|---|
| **slang** (MikePopoloski/slang) | SV-2017 parse + elaboration | Linked as a library. Best-in-class frontend. Untouched core. |
| **CIRCT** (llvm/circt) | Moore/HW/Comb/Seq dialects, `MooreToCore`, `btor2` emission | The IR substrate. Your new passes live *in your own repos* but target CIRCT dialects. Upstream the generically-useful ones. |
| **Pono** (stanford-centaur/pono) | IC3IA, k-induction, BMC over BTOR2 | The proof engine. Orchestrated, not modified (mostly). |
| **AVR** (aman-goel/avr) | Alternative IC3/word-level engine | Secondary engine for portfolio. |
| **Boolector/Bitwuzla** | BTOR2 reference + SMT backend | Bitwuzla is the actively-maintained successor; use it as the SMT solver behind the engines. |
| **btor2tools** | BTOR2 parse/print/witness format | Witness parsing in your debug layer. |
| **Surfer** / **GTKWave** | Waveform viewers | Output target. Surfer (Rust, extensible) is the strategic bet; GTKWave for compatibility. |

### Tier 1 — Repos you create (the actual project)

**Repo 1: `sva-frontend`** *(the core — this is the project)*
- **Does:** Consumes Slang's elaborated AST + CIRCT's Moore/HW dialects. Compiles the full SVA layer — sequences, properties, `|->`/`|=>`, `##[m:n]`/`##[1:$]`, `throughout`, `within`, `intersect`, `first_match`, local variables, multiclock, `disable iff`, full sampled-value semantics (`$past`, `$rose`, `$fell`, `$stable`, preponed-region timing) — into **monitor automata** expressed as a CIRCT dialect (a small `sva`/`ltl` dialect, or extend CIRCT's existing `ltl`/`verif` dialects).
- **Why separate:** This is where every prior open-source attempt dies. It deserves its own repo, its own exhaustive conformance test suite, and its own versioning.
- **Reuse:** CIRCT already has nascent `ltl` and `verif` dialects — extend those upstream rather than inventing. The PSL/SVA→automata constructions are in the literature (see the knowledge doc).
- **Soundness note:** The risk is *silent miscompilation*, not crashes. Every construct needs a golden reference test against a simulator's interpretation.

**Repo 2: `rtl-lowering`** *(extend, don't invent)*
- **Does:** Hardens the SV→word-level path: multi-dimensional arrays, `generate` corner cases, `$`-system functions, X/Z handling, parameterization edge cases. Produces a clean word-level transition system in CIRCT's HW/Comb/Seq + your monitor dialect.
- **Reuse:** This is mostly upstream CIRCT `MooreToCore` work. Keep this repo as your *staging area* for passes before they're upstreamed. Long-term, much of it should disappear into CIRCT.

**Repo 3: `btor2-emit`** *(this is your old `sva2btor2`, scoped down)*
- **Does:** Lowers the combined (RTL + monitor) transition system to BTOR2. Expands operator coverage beyond what CIRCT's `btor2` emission handles today. Carries source-location metadata through to BTOR2 for later witness remapping.
- **Reuse:** Start from CIRCT's existing `ExportBTOR2` / `btor2` dialect. The metadata-preservation requirement is the new part and the one that makes Repo 5 possible.

**Repo 4: `fv-engine`** *(orchestration, not engine authorship)*
- **Does:** Runs Pono/AVR/btormc on the BTOR2, manages BMC depth, k-induction, IC3 invocation, engine portfolio + parallel racing, result aggregation (PROVEN / CEX@k / UNKNOWN / timeout). Emits a normalized result + raw witness.
- **Reuse:** Pono and AVR as subprocesses or linked. **You do not write a model checker.** Your value is selection, racing, and a clean result contract.

**Repo 5: `witness-remap`** *(the second genuinely-new component)*
- **Does:** Takes a BTOR2 witness + the location metadata from Repo 3 and produces a **source-RTL-named** VCD/FST — signals named as the engineer wrote them, monitors annotated, assertion-failure cycle marked.
- **Reuse:** `btor2tools` for witness parsing; FST/VCD writers exist (GTKWave's `libfst`). The *remapping* through all the lowering is the unbuilt part.

**Repo 6: `fv-debug`** *(optional, highest ambition — the "Visualize window")*
- **Does:** Cone-of-influence navigation, driver tracing, why-is-this-X, schematic view of the failing logic. The thing GTKWave/Surfer don't do.
- **Reuse:** Build as a **Surfer extension/plugin** rather than a new viewer. Surfer is Rust + extensible and is the right host. Defer until 1–5 work; this is a research-grade UI effort on its own.

**Repo 7: `openfv`** *(the flagship / meta-repo)*
- **Does:** The single command-line entry point. Submodules all of the above. Provides the user-facing flow: `openfv run design.f --top dut --sva tb.sva`. Owns the integration tests, the regression suite of real designs, and the documentation site.
- **Reuse:** Nothing to reuse — this is the glue. Keep it thin.

**Repo 8: `fv-benchmarks`** *(credibility infrastructure)*
- **Does:** Curated open RTL + SVA test designs (OpenTitan blocks, picorv32, FIFOs, arbiters, the HWMCC benchmark set in BTOR2). Golden results. This is how you prove correctness to skeptics and catch regressions.
- **Reuse:** HWMCC benchmarks, OpenTitan, lowRISC IP, various open SVA assertion libraries.

### Dependency graph

```
openfv (flagship)
 ├── sva-frontend ── (slang, CIRCT)
 ├── rtl-lowering ── (CIRCT)
 ├── btor2-emit ───── (CIRCT btor2)
 ├── fv-engine ────── (Pono, AVR, btormc, Bitwuzla)
 ├── witness-remap ── (btor2tools, libfst)
 ├── fv-debug ─────── (Surfer)   [optional/late]
 └── fv-benchmarks    [test data, no code deps]
```

Build order is the same as repo number: 1→2→3→4→5→(7 stitches as you go)→6.

---

## 2. How to stitch them together

**Submodule + flagship pattern.** `openfv` holds each Tier-1 repo as a git submodule pinned to a known-good SHA. CI in `openfv` bumps submodule pins only when the integration suite passes. Each Tier-1 repo has its own CI that runs *its* unit tests in isolation; `openfv` CI runs the *cross-repo* integration tests.

**The contract between repos is a file format, not an API call.** This keeps them decoupled and independently testable:
- `sva-frontend` + `rtl-lowering` → emit CIRCT IR (MLIR textual `.mlir`).
- `btor2-emit` → consumes `.mlir`, emits `.btor2` + a sidecar `.locmap` (signal/location metadata).
- `fv-engine` → consumes `.btor2`, emits a normalized `result.json` + raw `.wit` witness.
- `witness-remap` → consumes `.wit` + `.locmap` → emits `.fst`/`.vcd`.
- `fv-debug` / Surfer → consumes `.fst`.

Because every boundary is a file, each repo is testable with golden files alone — no need to stand up the whole pipeline to test one stage. This is also how you catch the silent-miscompilation risk: golden `.btor2` and golden witnesses, diffed in CI.

**CI/CD per repo:**
- Lint + build (the LLVM/CIRCT build is heavy — cache aggressively, pin LLVM SHA).
- Unit tests against golden files.
- For `sva-frontend`: a *conformance* job that runs each SVA construct against an open simulator (Verilator/Icarus for the cover/sim-checkable subset) and diffs behavior.

**CI/CD in `openfv`:**
- Nightly: full `fv-benchmarks` regression. Track PROVEN/CEX/UNKNOWN counts and solve times over time — regressions in *correctness* are release-blocking, regressions in *speed* are warnings.

---

## 3. Roadmap (from the flowchart's "now" to the goal)

The flowchart's color coding maps directly to phases: green is done, amber is hardening, red is invention.

### Phase 0 — Skeleton (weeks 1–4)
Stand up the Org, `openfv` flagship, CI templates, `fv-benchmarks` with a handful of trivial designs (a FIFO, a one-hot arbiter) and their hand-verified expected results. Get `slang` parsing + CIRCT building in CI. **Milestone:** `openfv` can parse and elaborate a trivial design end-to-end and exit cleanly (no verification yet).

### Phase 1 — Straight-line proof on the easy subset (months 2–4)
`rtl-lowering` + `btor2-emit` for combinational + simple sequential RTL. `fv-engine` orchestrating btormc/Pono for BMC. Support **immediate assertions** and the *simplest* concurrent assertions (`assert property (@(posedge clk) a |-> b);`). **Milestone:** prove/disprove a safety property on a real FIFO, with a (possibly ugly, BTOR2-named) counterexample.

### Phase 2 — The SVA frontend, incrementally (months 4–10)
This is the long pole. Build `sva-frontend` construct-by-construct, each gated by a conformance test:
1. Overlapping/non-overlapping implication, `##n`, bounded `##[m:n]`.
2. Repetition (`[*]`, `[->]`, `[=]`), `throughout`, `within`.
3. Unbounded `##[1:$]`, `first_match`, `intersect`.
4. Local variables in sequences, `disable iff`, full sampled-value functions.
5. Multiclock.
**Milestone after each:** the construct passes conformance against a simulator and proves correctly on a known-good/known-bad design pair.

### Phase 3 — Unbounded proofs + usability (months 8–14, overlaps Phase 2)
`fv-engine` portfolio: k-induction + IC3IA (Pono) + AVR racing. Result normalization. **Milestone:** unbounded PROOF (not just bounded BMC) on a non-trivial design — the thing that lets you say "formally bug-free," with the honest caveat that proof depth/capacity won't match Jasper on hard designs.

### Phase 4 — Source-level debug (months 12–18)
`witness-remap` → RTL-named FST openable in Surfer/GTKWave. **Milestone:** an engineer sees a failing wave with *their* signal names and the failing cycle marked.

### Phase 5 — Visualize-class debugger (months 18+, optional/research)
`fv-debug` as a Surfer extension: cone-of-influence, driver tracing. **Milestone:** click an X, see why.

### Definition of done (the academic-user test)
A grad student clones `openfv`, points it at an OpenTitan block with its SVA, runs one command, and gets either a trustworthy PROVEN or a source-named counterexample wave — no commercial license touched.

---

## 4. Hard truths to keep on the wall

1. **Soundness > coverage > speed.** A tool that silently miscompiles one SVA construct is worse than one that refuses it. Refuse loudly until proven correct.
2. **You are not writing a model checker or a parser.** If you find yourself doing either, you've drifted. Orchestrate Pono; consume Slang.
3. **The engine gap to Jasper is real and multi-year.** Be honest in the README: this gives genuine open proofs, not Jasper-parity capacity.
4. **Upstream relentlessly.** Every pass that isn't SVA-monitor-specific belongs in CIRCT. Carrying a fork is how these projects die.
