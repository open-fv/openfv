# Open-Source SVA Formal Verification Suite — Project Plan

**Goal:** An end-to-end, freely-redistributable formal verification flow that an academic can point at industrial SystemVerilog RTL + SVA testbenches and get: correct compilation, unbounded proofs, and source-level counterexample waves — without Jasper or VC Formal.

**Strategic framing (read this first):** The BTOR2 conversion is the *easy 10%*. The hard, mostly-unsolved-in-open-source parts are (a) a **complete, correct SVA temporal compiler** and (b) a **witness-to-RTL debug layer**. Everything below the SVA layer (parsing, word-level IR, BTOR2 emission, solving) already exists in the CIRCT/Slang/Pono ecosystem in usable form. So this project is *not* a from-scratch tool — it is a thin orchestration shell plus two genuinely new components, riding on mature upstreams. Architect accordingly: maximize reuse, contribute upstream, own only what doesn't exist.

**Companion document:** [TASKS.md](TASKS.md) is the executable work breakdown — every task as a self-contained card with a difficulty tier, dependencies, and acceptance criteria. This file is the *why and what*; TASKS.md is the *who does which piece next*.

---

## 1. Legal & clean-room policy

This project must be legally unimpeachable. "Clean-room" here has a precise meaning — it is **not** "write everything from scratch" (depending on permissively-licensed open source is legally safe and is the whole strategy). It means the following rules, which every contributor — human or AI — follows without exception:

### 1.1 Where semantics come from (the only allowed sources)

- **IEEE 1800-2017** (the SystemVerilog LRM), Clause 16 and Annex F, is the *sole normative source* for SVA semantics. Every semantic decision in `sva-frontend` cites a clause number.
- **Published academic literature** (papers on PSL/SVA-to-automata construction, IC3, liveness-to-safety, etc.). Algorithms and ideas from papers are not copyrightable; cite them in code comments and docs.
- **Public file-format specifications**: BTOR2 (the published paper + btor2tools docs), VCD (defined in IEEE 1800 itself), MLIR/CIRCT public docs.

### 1.2 What is forbidden

- **Never consult proprietary tools** (Jasper, VC Formal, Questa Formal, etc.): no reverse-engineering, no reading their docs/AppNotes for implementation guidance, no deriving our behavior from their outputs. If a semantic question arises, the answer comes from the LRM — if the LRM is ambiguous, we document the ambiguity and our reading, we do not check "what Jasper does."
- **Never copy-paste code** from any external source into our repos — not from upstreams, not from StackOverflow, not from blog posts, regardless of license. External code is consumed only as a *dependency* (linked library, subprocess, or submodule) with its license intact. This keeps provenance trivially auditable.
- **Never link GPL/strong-copyleft code** into our binaries. GPL tools may be invoked as separate processes only (see license table).

### 1.3 License rules

- All Tier-1 (our) repos are **Apache-2.0** with a DCO sign-off requirement on every commit.
- Dependency allowlist: **Apache-2.0 (incl. LLVM exception), MIT, BSD-2/3, ISC, zlib.** Anything else (GPL, LGPL, EUPL, unclear/no license) requires an explicit review recorded in `LICENSES.md` before first use, and may only be used across a process boundary, never linked.
- Every repo carries a `LICENSES.md` listing each dependency, its license, and how it is consumed (linked / subprocess / dev-only). CI fails if a dependency appears that isn't listed.

### 1.4 AI-contribution provenance

Every PR (AI- or human-authored) states in its description: which spec/LRM clauses it implements, and an affirmation that no external code was copied. Semantic decisions made by AI below the Fable tier are invalid — they must be escalated (see §5).

---

## 2. The repositories

Organize as a single GitHub **Org** (`openfv`). The flagship repo pulls the others in as submodules. Keep each repo small, single-purpose, and independently testable.

### Tier 0 — Upstream dependencies (do NOT fork unless forced)

These are consumed as libraries/submodules. Contribute patches upstream rather than maintaining forks — forking forks the maintenance burden too.

| Upstream | License | Role | How consumed |
|---|---|---|---|
| **slang** (MikePopoloski/slang) | MIT | SV-2017 parse + elaboration | Linked library. Untouched core. |
| **CIRCT** (llvm/circt) | Apache-2.0 w/ LLVM exception | Moore/HW/Comb/Seq/`ltl`/`verif` dialects, `MooreToCore`, BTOR2 emission | Linked; our passes live in our repos but target CIRCT dialects. Upstream the generic ones. |
| **Pono** (stanford-centaur/pono) | BSD-3 | IC3IA, k-induction, BMC | Subprocess (preferred) or linked. Not modified. |
| **btormc** (ships with Boolector) | MIT | BTOR2 BMC + k-induction engine | Subprocess. |
| **AVR** (aman-goel/avr) | GPLv3 — **dropped** by the P0.2 audit + `[FABLE]` review | ~~Alternative IC3/word-level engine~~ | **Not used.** Redundant with Pono+btormc; re-entry conditions in `LICENSES.md`. |
| **Bitwuzla** | MIT | SMT backend behind the engines | Linked by the engines, not by us. |
| **btor2tools** | MIT | BTOR2 parse/print/witness format | Linked in `witness-remap`. |
| **Verilator / Icarus** | LGPL/GPL components | Conformance reference simulators | **Subprocess only**, dev/CI-time only, never shipped linked. |
| **GTKWave (libfst)** | GPLv2 | FST format | **Never linked.** FST produced via external `vcd2fst` subprocess, or we ship VCD only. |
| **Surfer** | EUPL-1.2 | Waveform viewer | External program the user launches. Plugin work (Phase 5) needs a license review first. |

### Tier 1 — Repos we create (the actual project)

**Repo 1: `sva-frontend`** *(the core — this is the project)*
- **Does:** Consumes Slang's elaborated AST + CIRCT's Moore/HW dialects. Compiles the full SVA layer — sequences, properties, `|->`/`|=>`, `##[m:n]`/`##[1:$]`, `throughout`, `within`, `intersect`, `first_match`, local variables, multiclock, `disable iff`, full sampled-value semantics (`$past`, `$rose`, `$fell`, `$stable`, preponed-region timing) — into **monitor automata** expressed as a CIRCT dialect (extend CIRCT's `ltl`/`verif` dialects, or a small `sva` dialect if they prove insufficient — decision is task P2.2).
- **Why separate:** This is where every prior open-source attempt dies. It deserves its own repo, its own exhaustive conformance test suite, and its own versioning.
- **Soundness note:** The risk is *silent miscompilation*, not crashes. Every construct needs conformance vectors derived from the LRM and cross-checked against a reference simulator. Unsupported constructs are **refused loudly** — never half-handled.

**Repo 2: `rtl-lowering`** *(extend, don't invent)*
- **Does:** Hardens the SV→word-level path: multi-dimensional arrays, `generate` corner cases, `$`-system functions, X/Z handling, parameterization edge cases. Produces a clean word-level transition system in CIRCT's HW/Comb/Seq + the monitor dialect.
- **Reuse:** Mostly upstream CIRCT `MooreToCore` work. This repo is the *staging area* for passes before they're upstreamed; long-term, much of it should disappear into CIRCT.

**Repo 3: `btor2-emit`**
- **Does:** Lowers the combined (RTL + monitor) transition system to BTOR2. Expands operator coverage beyond CIRCT's current BTOR2 emission. Carries source-location metadata through to BTOR2 as a sidecar `.locmap` for later witness remapping.
- **Reuse:** Start from CIRCT's existing BTOR2 export. The metadata preservation is the new part and the one that makes Repo 5 possible.

**Repo 4: `fv-engine`** *(orchestration, not engine authorship)*
- **Does:** Runs Pono/btormc on the BTOR2; manages BMC depth, k-induction, IC3 invocation, engine portfolio + parallel racing, result aggregation (PROVEN / CEX@k / UNKNOWN / TIMEOUT). Emits a normalized `result.json` + raw witness.
- **Reuse:** Engines as subprocesses. **We do not write a model checker.** Our value is selection, racing, and a clean result contract.

**Repo 5: `witness-remap`** *(the second genuinely-new component)*
- **Does:** Takes a BTOR2 witness + the `.locmap` from Repo 3 and produces a **source-RTL-named** VCD/FST — signals named as the engineer wrote them, monitors annotated, assertion-failure cycle marked. Signals optimized away during lowering are marked as missing/reconstructed — never silently guessed.
- **Reuse:** `btor2tools` for witness parsing. VCD writer is written clean-room from the IEEE 1800 VCD spec (it's small). The *remapping* through all the lowering is the unbuilt part.

**Repo 6: `fv-debug`** *(optional, highest ambition — the "Visualize window")*
- **Does:** Cone-of-influence navigation, driver tracing, why-is-this-X, schematic view of the failing logic. Defer until 1–5 work; research-grade UI effort, license review of Surfer plugin boundary required first.

**Repo 7: `openfv`** *(this repo — the flagship)*
- **Does:** Single CLI entry point: `openfv run design.f --top dut --sva tb.sva`. Submodules all of the above. Owns integration tests, the regression suite of real designs, and the documentation site. Keep it thin.

**Repo 8: `fv-benchmarks`** *(credibility infrastructure)*
- **Does:** Curated open RTL + SVA test designs (own clean-room designs first; then OpenTitan blocks, picorv32, HWMCC BTOR2 sets — each license-checked on import). Golden results. This is how we prove correctness to skeptics and catch regressions.

### Dependency graph

```
openfv (flagship)
 ├── sva-frontend ── (slang, CIRCT)
 ├── rtl-lowering ── (CIRCT)
 ├── btor2-emit ───── (CIRCT btor2)
 ├── fv-engine ────── (Pono, btormc, Bitwuzla)
 ├── witness-remap ── (btor2tools)
 ├── fv-debug ─────── (Surfer)   [optional/late]
 └── fv-benchmarks    [test data, no code deps]
```

Build order = repo number: 1→2→3→4→5→(7 stitches as you go)→6.

---

## 3. How the repos stitch together

**Submodule + flagship pattern.** `openfv` pins each Tier-1 repo as a git submodule at a known-good SHA. CI in `openfv` bumps pins only when the integration suite passes. Each Tier-1 repo runs *its* unit tests in its own CI; `openfv` CI runs the *cross-repo* integration tests.

**The contract between repos is a file format, not an API call.** This keeps them decoupled and independently testable:

| Stage | Input | Output |
|---|---|---|
| `sva-frontend` + `rtl-lowering` | `.sv` / `.f` | CIRCT IR (textual `.mlir`) |
| `btor2-emit` | `.mlir` | `.btor2` + sidecar `.locmap` (JSON) |
| `fv-engine` | `.btor2` | `result.json` + raw `.wit` witness |
| `witness-remap` | `.wit` + `.locmap` | `.vcd` / `.fst` |
| `fv-debug` / Surfer | `.fst` | interactive view |

Because every boundary is a file, each repo is testable with golden files alone — no need to stand up the whole pipeline to test one stage. This is also how we catch silent miscompilation: golden `.btor2` and golden witnesses, diffed in CI.

The `.locmap` and `result.json` schemas are **versioned contracts**, specified in `openfv/docs/specs/` before anything implements them (task P0.6). Schema changes bump a version field and require a flagship-repo PR.

**CI/CD per repo:**
- Lint + build (the LLVM/CIRCT build is heavy — cache aggressively, pin the LLVM/CIRCT SHA in one place: a `versions.txt` in the flagship, mirrored to each repo).
- Unit tests against golden files.
- For `sva-frontend`: a *conformance* job that runs each SVA construct's vectors against a reference simulator (Verilator/Icarus for the subset they support) and diffs behavior. Vectors the simulator can't run are reported `SIM-UNSUPPORTED`, never silently skipped.

**CI/CD in `openfv`:**
- Nightly: full `fv-benchmarks` regression. Track PROVEN/CEX/UNKNOWN counts and solve times over time — regressions in *correctness* are release-blocking, regressions in *speed* are warnings.

---

## 4. Roadmap

Phases overlap deliberately; each has a falsifiable milestone. The full task-level breakdown lives in [TASKS.md](TASKS.md).

| Phase | When | What | Milestone (falsifiable) |
|---|---|---|---|
| **0 — Skeleton** | weeks 1–4 | Org, CI templates, build pinning, clean-room benchmark designs, interface-contract specs, CLI skeleton | `openfv` parses + elaborates a trivial design end-to-end and exits cleanly |
| **1 — Straight-line proof** | months 2–4 | Lowering + BTOR2 emission for simple sequential RTL; BMC orchestration; immediate assertions + `a \|-> b` | Prove/disprove a safety property on a real FIFO, with a (BTOR2-named) counterexample |
| **2 — SVA frontend** | months 4–10 | The long pole. Construct-by-construct ladder (12 rungs, see TASKS.md), each gated by LRM-derived conformance vectors | Each rung: conformance pass + correct verdict on a known-good/known-bad design pair |
| **3 — Unbounded proofs** | months 8–14 (overlaps 2) | k-induction + IC3IA portfolio racing (Pono, btormc); result normalization; soundness audit | Unbounded PROOF (not just BMC) on a non-trivial design |
| **4 — Source-level debug** | months 12–18 | Witness remap → RTL-named wave, failure cycle marked | Engineer opens a failing wave with *their* signal names in Surfer/GTKWave |
| **5 — Visualize-class debugger** | months 18+, optional | Surfer-hosted cone-of-influence / driver tracing | Click an X, see why |

### Definition of done (the academic-user test)

A grad student clones `openfv`, points it at an OpenTitan block with its SVA, runs one command, and gets either a trustworthy PROVEN or a source-named counterexample wave — no commercial license touched.

---

## 5. Execution model — who (which AI) does what

Work is executed by a mix of AI tiers. The breakdown in TASKS.md labels every task. The tiers and the rules that make delegation safe:

### The tiers

The tier names denote the *kind of judgment* a card needs, independent of which model is available to do it:

- **[FABLE]** — semantic and architectural decisions: SVA semantics interpretation from the LRM, automaton constructions, dialect/schema design, soundness audits, anything where a *plausible-but-wrong* answer would silently corrupt results. Also reviews every merge into the semantic core.
- **[OPUS]** — substantial implementation against a written spec: MLIR passes, C++ integration, conformance harness, engine orchestration, tricky CI. May make *engineering* choices (data structures, code layout) but no *semantic* choices.
- **[SONNET]** — mechanical, well-specified, locally verifiable work: test vectors from a spec table, golden files, schema-conformant writers, benchmark curation, CLI plumbing, docs, dashboards.

### Model mapping (current — Fable 5 unavailable)

Fable 5 was withdrawn from availability (2026-06-13). Until it returns, cards are staffed as:

| Tier | Model + reasoning effort |
|---|---|
| **[FABLE]** | **Opus at extra-high (`xhigh`) reasoning effort** |
| **[OPUS]** | Opus at high reasoning effort |
| **[SONNET]** | Sonnet (unchanged) |

This preserves the *intent* of the tiering — maximum rigor on semantic cards — by raising reasoning effort rather than the model. The protocol below still holds: a `[FABLE]` card done at `xhigh` must still write the spec + LRM citations + acceptance tests *first* and treat genuine ambiguity as a stop-and-escalate to the human, not a license to guess. The one rule that changes: "semantic decisions made by AI below the Fable tier are invalid" (§1.4) is read, for now, as "semantic decisions must be made at `[FABLE]` staffing (Opus xhigh) with the spec-first discipline, and surfaced to the human in the PR." If Fable 5 returns, revert to Fable for these cards.

### The protocol (non-negotiable)

1. **Spec before implementation.** For anything semantic, Fable writes the spec (with LRM clause citations) and the acceptance tests *first*. Opus/Sonnet implement to the spec.
2. **Stop-and-escalate.** If an implementing model finds the spec ambiguous, incomplete, or contradicted by a test, it **stops and flags** — it never picks an interpretation. A task card's "Escalate if" section lists known tripwires.
3. **Tests cross tiers.** Where possible, the tests are written by a different model than the implementation (typically Sonnet writes vectors from Fable's spec tables; Opus implements). This catches spec misreadings.
4. **Fable reviews the semantic core.** Every PR touching `sva-frontend` lowering, BTOR2 emission semantics, or witness remap correctness gets a Fable review before merge. CI plumbing, docs, and benchmarks don't need it.
5. **Self-contained task cards.** Every card in TASKS.md carries: repo, dependencies, inputs (which spec/files), deliverable, acceptance criteria, escalation triggers. A model should be able to pick one up with no conversation context.

---

## 6. Hard truths to keep on the wall

1. **Soundness > coverage > speed.** A tool that silently miscompiles one SVA construct is worse than one that refuses it. Refuse loudly until proven correct.
2. **You are not writing a model checker or a parser.** If you find yourself doing either, you've drifted. Orchestrate Pono; consume Slang.
3. **The engine gap to Jasper is real and multi-year.** Be honest in the README: this gives genuine open proofs, not Jasper-parity capacity.
4. **Upstream relentlessly.** Every pass that isn't SVA-monitor-specific belongs in CIRCT. Carrying a fork is how these projects die.
5. **The LRM is the only oracle.** When semantics are unclear, document the ambiguity and our reading — never peek at what a commercial tool does.
6. **An escalation is a success, not a failure.** A smaller model that stops on ambiguity has done its job; a smaller model that guesses has poisoned the well.
