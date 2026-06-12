# TASKS — Executable Work Breakdown

Companion to [PROJECT_PLAN.md](PROJECT_PLAN.md). Read §1 (legal/clean-room) and §5 (execution model) of the plan before picking up any task.

## How to use this file

Every task is a **self-contained card**. An AI (or human) picking up a card needs only: this file, the plan, and the files the card lists under *Inputs*. Cards carry a tier label:

- `[FABLE]` — semantic/architectural; do not reassign downward.
- `[OPUS]` — implementation against a written spec; engineering choices OK, semantic choices forbidden.
- `[SONNET]` — mechanical, well-specified, locally verifiable.

**Universal rules for every task, regardless of tier:**

1. **Clean-room:** no code copied from anywhere; no consulting proprietary tools or their docs; SVA semantics only from IEEE 1800-2017 (cite clauses) or cited academic papers.
2. **Escalate, don't guess:** if the spec is ambiguous, incomplete, or a test contradicts it — stop, write up the ambiguity, tag `[FABLE]`. Each card lists known tripwires under *Escalate if*, but the rule applies generally.
3. **Definition of done** for every card: acceptance criteria met, tests green in that repo's CI, `LICENSES.md` updated if a dependency was added, PR description cites the spec/LRM clauses implemented and affirms no copied code.
4. Tasks within a phase may run in parallel unless *Depends* says otherwise.
5. **Status tracking:** a card with no *Status* line is not started. Sessions picking up a card add `**Status:** 🔄 <branch/PR>`; on completion change it to `**Status:** ✅ <where the deliverable lives>` **and append a marker to the card's heading** so tasks are scannable: **🟡 = done from the implementer's side, PR open, awaiting review/merge** (name the PR in the heading); **✅ = merged and fully done.** The merging PR flips 🟡 → ✅.

**ID scheme:** `P<phase>.<n>`; ladder rungs are `R<n>` with step suffixes (see Phase 2).

---

## Phase 0 — Skeleton (weeks 1–4)

**Milestone M0:** `openfv run benchmarks/fifo/fifo.f --top fifo --parse-only` parses + elaborates and exits 0; CI green in all repos.

### P0.1 — Repo + org scaffolding `[SONNET]` ✅
**Repo:** all Tier-1 · **Depends:** —
**Deliverable:** GitHub org `openfv`; the 8 repos created; each with Apache-2.0 `LICENSE`, `README.md` (one-paragraph role statement copied in spirit from the plan, written fresh), `CONTRIBUTING.md` (DCO sign-off required, clean-room rules summarized, link to plan §1), `.gitignore`, empty `LICENSES.md` with the table header, PR template containing the provenance affirmation checklist.
**Accept:** All repos exist; flagship has the others as submodules; PR template renders the checklist.
**Status:** ✅ Org is **`open-fv`** (`openfv` was taken by an unrelated 2017 org). 8 public repos; `openfv` + `btor2-emit` transferred from `abhigyan2001` (GitHub redirects the old URLs); scaffolding pushed to all; submodules wired in the flagship; P0.3 build templates copied verbatim into the three CIRCT repos. Note: two arXiv PDFs were removed from `btor2-emit` HEAD (no redistribution rights, repo now public) — they remain in git *history*; scrubbing history is an optional follow-up.

### P0.2 — License & provenance audit `[SONNET]` ✅
**Repo:** openfv · **Depends:** —
**Deliverable:** `LICENSES.md` in the flagship covering every Tier-0 upstream: exact license (read the upstream's LICENSE file, do not trust memory), how we consume it (linked / subprocess / dev-only), allowlist verdict per plan §1.3. Explicitly resolve: **AVR** (license unclear in the plan — find it; if non-permissive or absent, mark "subprocess-only pending review" or "do not use"), **Surfer** (EUPL — external program only; note that Phase 5 plugin work needs a fresh review), **GTKWave/libfst** (GPLv2 — never link; record the `vcd2fst`-as-subprocess decision), **Verilator/Icarus** (dev/CI subprocess only).
**Accept:** Every upstream in the plan §2 table has a row with a verdict; ambiguous cases carry an explicit `[FABLE]`-review flag rather than a guess.
**Escalate if:** any license is not plainly one of the allowlisted ones — flag, don't interpret.
**Status:** ✅ `LICENSES.md` in flagship covers all Tier-0 upstreams (the 10 from the plan §2 table **plus btormc/Boolector, MIT** — used by P1.6 but missing from the table; row added). Licenses verified from upstream LICENSE/COPYING files directly. Key findings: slang/CIRCT/Pono/Bitwuzla/btor2tools/btormc all on allowlist (MIT/Apache-2/BSD-3); **AVR is GPLv3** — `[FABLE]` review (2026-06-12) **dropped it from the plan**: redundant with Pono+btormc for all milestones, GPL stack underneath (Yices 2), permanent compliance surface; P3.2 closed blocked-by-license with re-entry conditions in `LICENSES.md`; Verilator (LGPLv3) and Icarus (GPLv2) approved as process-boundary dev/CI-only; GTKWave/libfst (GPLv2) approved as never-linked with vcd2fst subprocess decision recorded; Surfer (EUPL-1.2) approved for current file-based use, Phase 5 plugin work flagged for `[FABLE]` review.

### P0.3 — Pinned, reproducible builds `[OPUS]` 🟡 (infra merged in openfv#1; acceptance verification awaiting merge in openfv#4)
**Repo:** rtl-lowering, sva-frontend, btor2-emit (CIRCT-dependent repos) · **Depends:** P0.1
**Deliverable:** A `versions.txt` in the flagship pinning the LLVM/CIRCT and slang SHAs; per-repo CMake builds that fetch/build against exactly those pins; ccache wiring; a `docs/BUILDING.md` with a from-scratch Ubuntu LTS recipe that a fresh machine can follow verbatim.
**Accept:** Clean checkout → documented commands → all three repos build and run a hello-world `*-opt` tool. Same SHAs everywhere.
**Escalate if:** the pinned CIRCT requires local patches to build — do not carry patches silently; flag for an upstream-first decision.
**Status:** ✅ flagship: `versions.txt` (CIRCT/LLVM/slang pins, provenance-documented), `scripts/bootstrap-circt.sh` (build CIRCT once + ccache + pin-stamp), `cmake/OpenfvVersions.cmake` + `cmake/OpenfvCIRCT.cmake` (single-sourced pins, ccache wiring, pin-match verification), `docs/BUILDING.md` (from-scratch Ubuntu LTS recipe). Per-repo CMake + hello-world `*-opt` copied into rtl-lowering/sva-frontend/btor2-emit when P0.1 landed (`build-templates/` staging removed from the flagship). Full build/acceptance run still deferred to CI (P0.4) / a dev box: cmake+CIRCT toolchain not present in the authoring env — **P0.4 should flip this card to fully verified when its CIRCT cache build goes green.**

### P0.4 — CI templates `[OPUS]`
**Repo:** all Tier-1 · **Depends:** P0.3
**Deliverable:** GitHub Actions workflows: per-repo lint + build + unit-test on PR, with the CIRCT build cached as a restorable artifact keyed on `versions.txt` (a cold cache must not make every PR a 2-hour build); flagship workflow that additionally runs cross-repo integration tests and a (initially empty) nightly job skeleton; a DCO check.
**Accept:** A trivial PR in each repo goes red on a deliberately broken test and green when fixed; warm-cache PR build < 15 min.

### P0.5 — fv-benchmarks v0: clean-room trivial designs `[SONNET]` 🟡 (awaiting merge: fv-benchmarks#1 + flagship pin bump openfv#3)
**Repo:** fv-benchmarks · **Depends:** P0.1
**Deliverable:** Written-from-scratch SystemVerilog: (a) parameterizable synchronous FIFO, (b) free-running counter with wrap, (c) one-hot round-robin arbiter. Each with 2–3 SVA properties — at least one that genuinely holds and one that is deliberately violated (e.g., FIFO `full && push` overflow with the guard removed) — and an `EXPECTED.md` stating, with a hand-walked argument, PROVEN/CEX and the earliest violation cycle for each property.
**Accept:** Designs lint clean under Verilator (`--lint-only`); `EXPECTED.md` arguments are checkable by a reader in minutes; no code sourced from existing designs online.
**Escalate if:** unsure whether a property truly holds — say so in the PR instead of asserting it.

### P0.6 — Interface contracts v0 `[FABLE]` ✅
**Repo:** openfv (`docs/specs/`) · **Depends:** —
**Deliverable:** Versioned specs for: **`.locmap`** (JSON schema: BTOR2 node/state id → hierarchical RTL name, type/width, source file:line, plus entries for monitor-internal signals and a marker for signals with no RTL counterpart), **`result.json`** (status PROVEN/CEX/UNKNOWN/TIMEOUT/ERROR per property, engine attribution, depth `k`, timings, witness file pointer, schema version), **CLI contract** for `openfv run` (flags, exit codes: 0 = all proven, 1 = CEX found, 2 = unknown/timeout, ≥10 = tool error), and the `.wit` handling convention (raw BTOR2 witness format passthrough, per btor2tools).
**Accept:** JSON Schema files validate the included examples; downstream cards (P1.5, P1.6, P0.7) can implement from the spec alone without questions.
**Status:** ✅ `docs/specs/` (specs + schemas + examples + `check_specs.py`; wire the checker into CI via P0.4)

### P0.7 — openfv CLI skeleton `[SONNET]`
**Repo:** openfv · **Depends:** P0.3, P0.6
**Deliverable:** `openfv` CLI (suggest Python or thin C++ — implementer's choice) supporting `run <file.f> --top <name> --parse-only`: reads the `.f` filelist, invokes the CIRCT/slang frontend (`circt-verilog` or equivalent per P0.3 builds) to parse + elaborate, reports errors with file/line, uses the P0.6 exit codes. No verification yet.
**Accept:** Succeeds on all P0.5 benchmarks; clean, non-stack-trace error on a syntax-broken input; exit codes per spec.

---

## Phase 1 — Straight-line proof on the easy subset (months 2–4)

**Milestone M1:** `openfv run fifo.f --top fifo` proves the good property and produces `result.json` + a raw witness for the violated one, end-to-end in CI.

### P1.1 — Lowering gap survey `[OPUS]`
**Repo:** rtl-lowering · **Depends:** P0.3, P0.5
**Deliverable:** Run every P0.5 benchmark through ImportVerilog → Moore → `MooreToCore` → HW/Comb/Seq. `GAPS.md`: every failure or wrong-looking lowering as an entry with a *minimal* SV repro (≤20 lines), the error/wrong output, and a first-guess classification (missing op, unsupported construct, bug).
**Accept:** Every benchmark either lowers clean or has a GAPS.md entry with a repro that fails standalone.

### P1.2 — Lowering gap fixes `[OPUS]` *(one sub-card per GAPS.md entry)*
**Repo:** rtl-lowering · **Depends:** P1.1
**Deliverable:** Per gap: a pass/patch in rtl-lowering (staging) fixing it, an MLIR FileCheck test from the repro, and a note whether it should be upstreamed to CIRCT (default yes for anything not monitor-specific).
**Accept:** Repro lowers correctly; no regressions; upstream-candidate flag set.
**Escalate if:** the fix requires deciding simulation semantics (X/Z behavior, race semantics) — that's a `[FABLE]` semantic call.

### P1.3 — Location-metadata threading design `[FABLE]`
**Repo:** btor2-emit · **Depends:** P0.6
**Deliverable:** Design doc + skeleton implementation for how source names/locations survive ImportVerilog → MooreToCore → BTOR2 emission (MLIR location attributes + naming discipline), and the producer that emits the `.locmap` per spec. Identifies which lowering passes destroy information and what discipline (e.g., `sv.namehint`-style attrs, pass options) preserves it.
**Accept:** For the FIFO benchmark, ≥90% of user-declared signals in the BTOR2 output are traceable to a correct hierarchical name + file:line; the untraceable ones are *listed*, not dropped.

### P1.4 — .locmap writer + validation `[SONNET]`
**Repo:** btor2-emit · **Depends:** P1.3
**Deliverable:** Productionize the P1.3 skeleton: emit `.locmap` alongside every `.btor2`; JSON-Schema validation test; golden `.locmap` files for the benchmarks.
**Accept:** Schema-valid output for all benchmarks; golden-diff test in CI.

### P1.5 — btor2-emit operator coverage `[OPUS]`
**Repo:** btor2-emit · **Depends:** P1.1
**Deliverable:** Enumerate HW/Comb/Seq ops appearing in the lowered benchmarks (and the obvious near-term set: arithmetic, comparisons, mux, extract/concat/extension, shifts, registers with/without reset/enable, memories if cheap) vs. what the existing CIRCT BTOR2 export handles. Implement the missing ones. One golden `.btor2` FileCheck test per op.
**Accept:** All benchmarks emit valid BTOR2 (validated by `btor2tools`' parser); per-op golden tests green.
**Escalate if:** an op's BTOR2 mapping is semantically non-obvious (X-propagation, division-by-zero semantics) — write up options, tag `[FABLE]`.

### P1.6 — fv-engine v0: BMC runner `[OPUS]`
**Repo:** fv-engine · **Depends:** P0.6
**Deliverable:** Subprocess orchestration of `btormc` and Pono in BMC mode: launch with depth/time limits, parse engine output (sat/unsat/unknown + witness), emit `result.json` per spec + the raw `.wit`. Robust to engine crash/timeout (reported as ERROR/TIMEOUT, never as PROVEN). Unit-tested against hand-written BTOR2 files with known answers.
**Accept:** Known-SAT file → CEX@k with witness; known-UNSAT-to-depth file → correct bounded report (a bounded clean BMC run is **not** PROVEN — status must reflect that); kill -9 mid-run → ERROR.

### P1.7 — Immediate assertions end-to-end `[SONNET]`
**Repo:** rtl-lowering + btor2-emit · **Depends:** P1.2, P1.5
**Deliverable:** `assert (expr);` (immediate, in always blocks) lowered through `verif.assert` to a BTOR2 `bad` property; tests with one passing and one failing immediate assertion.
**Accept:** Failing assertion found by P1.6 BMC at the hand-computed cycle; passing one survives the bound.

### P1.8 — Clocking + sampling semantic foundation `[FABLE]`
**Repo:** sva-frontend · **Depends:** P1.2
**Deliverable:** The semantics doc that everything in Phase 2 builds on: how `@(posedge clk)` sampling maps onto the BTOR2 transition relation (preponed-region sampling, IEEE 1800-2017 §16.5.1/§4.4), reset/`disable iff` interaction deferred but slotted, and the reference lowering for the first concurrent assertion: `assert property (@(posedge clk) a |-> b);` with boolean `a`,`b` — including the acceptance tests.
**Accept:** Doc cites clauses for every decision; the reference lowering proves/falsifies correctly on a known-good/known-bad pair added to fv-benchmarks.

### P1.9 — End-to-end integration test `[SONNET]`
**Repo:** openfv · **Depends:** P1.4, P1.6, P1.7, P1.8
**Deliverable:** Wire the full pipeline into `openfv run`; flagship CI integration test on the FIFO: violated property → status CEX with witness file present; holding property → bounded-clean at the configured depth. Golden `result.json` (timing fields masked).
**Accept:** Milestone M1 demonstrably green in CI.

---

## Phase 2 — The SVA frontend (months 4–10) — the long pole

**Milestone M2:** every ladder rung below passes conformance and proves correctly on a known-good/known-bad design pair.

### Foundations

### P2.1 — SVA semantics master doc `[FABLE]`
**Repo:** sva-frontend (`docs/semantics/`) · **Depends:** P1.8
**Deliverable:** The project's law book, from IEEE 1800-2017 Clause 16 + Annex F *only*: tight/neutral satisfaction, weak vs strong sequences, empty-match rules, sequence vs property contexts, vacuity, sampled-value function semantics, and a per-construct table of edge cases (these tables become Sonnet's conformance-vector source). Documents every LRM ambiguity found, with our chosen reading and rationale.
**Accept:** Every Phase-2 construct has a section with clause citations and an edge-case table.

### P2.2 — Dialect decision RFC `[FABLE]`
**Repo:** sva-frontend · **Depends:** P1.8
**Deliverable:** Evaluate CIRCT's existing `ltl`/`verif` dialects against the R1–R12 ladder. Decision: extend upstream (preferred; draft the upstream RFC) vs. a thin local `sva` dialect for what doesn't fit. Defines the op set and lowering strategy (direct automata vs. ltl-then-automata) used by all rungs.
**Accept:** RFC merged in-repo; R1 implementation can start from it without further architecture questions.

### P2.3 — Conformance harness `[OPUS]`
**Repo:** sva-frontend · **Depends:** P1.9
**Deliverable:** Harness that takes a conformance vector (small SV module + property + stimulus + expected verdict per P2.4 format), runs it (a) through our pipeline as a BMC problem on the closed (stimulus-driven) design and (b) through Verilator — and Icarus where it supports the construct — and compares verdicts three ways: ours vs. expected, sim vs. expected, ours vs. sim. Constructs a simulator can't handle are reported `SIM-UNSUPPORTED` (counted, visible in CI output), never silently skipped. **A sim/expected mismatch is a finding to escalate, not auto-resolve** — the LRM (via the vector's expectation) outranks the simulator.
**Accept:** Harness runs the R1 vector set; all three comparisons reported per vector; CI job wired.

### P2.4 — Conformance vector format + library `[SONNET]` *(recurring, per rung)*
**Repo:** sva-frontend (`test/conformance/`) · **Depends:** P2.1, P2.3
**Deliverable:** Vector file format (one self-contained SV module + property + deterministic stimulus + expected verdict + LRM-table reference), then per rung: 10–30 vectors mechanically derived from the P2.1 edge-case tables, including empty-match, boundary `m=n`, zero-repetition, and overlap cases the table names.
**Accept:** Per rung: every row of the P2.1 edge-case table has ≥1 vector; `[FABLE]` reviews and signs off the vector set before the rung's implementation merges.

### The construct ladder

Each rung follows the same four steps — these are the actual assignable tasks (e.g. `R4.a`, `R4.b` …):

- **(a) `[FABLE]` Spec + construction note** — exact semantics (citing P2.1), the monitor-automaton construction, soundness argument, and the edge-case table if P2.1's needs extending.
- **(b) `[OPUS]` Implementation** — the lowering in the P2.2 dialect, per the (a) note. FileCheck unit tests.
- **(c) `[SONNET]` Conformance vectors** — per P2.4, from the (a)/P2.1 tables.
- **(d) `[FABLE]` Review + sign-off** — semantic review of (b) against (a); rung is "done" only after (d).

Rungs, in order (later rungs may start once their dependency rung passes (d)):

| Rung | Constructs | Notes / deviations from the pattern |
|---|---|---|
| **R1** | `##n`, `##[m:n]`, `\|->`, `\|=>` | First real automata; (a) sets the pattern all later notes follow. |
| **R2** | `[*n]`, `[*m:n]` | Consecutive repetition. |
| **R3** | `[->n]`, `[=n]` | Goto / nonconsecutive repetition. |
| **R4** | `throughout`, `within` | |
| **R5** | `##[m:$]`, `[*]`, `[+]` | Unbounded — (a) must address how unboundedness stays finite-state in the monitor. |
| **R6** | sequence `and`, `or`, `intersect` | `intersect` (length-matching) is the hard one. |
| **R7** | `first_match` | Interacts with everything before it; extra vectors on R5/R6 interplay. |
| **R8** | `disable iff` | Async abort semantics; interacts with P1.8 reset slot. |
| **R9** | `$past`, `$rose`, `$fell`, `$stable`, `$sampled` | Sampled-value functions incl. gating-clock-arg cases; mostly mechanical once P1.8/P2.1 nail sampling. |
| **R10** | **local variables** in sequences | **(b) is `[FABLE]`-led too** — automata-with-data is a known graveyard; Opus does plumbing only. |
| **R11** | **multiclock** sequences/properties | **(b) is `[FABLE]`-led too.** Clock-crossing `##1`/`##0` rules are subtle. |
| **R12** | property ops: `not`, `and`, `or`, `if/else`, `implies`, `until`/`s_until`, `eventually`/`s_eventually`, `nexttime` | Strong/liveness operators need a BTOR2 `justice` (or liveness-to-safety) mapping — that mapping decision is a `[FABLE]` (a)-step deliverable. |

### P2.5 — Refuse-loudly gate `[FABLE]` design, `[SONNET]` implementation
**Repo:** sva-frontend · **Depends:** R1 done (then maintained per rung)
**Deliverable:** A construct-coverage table compiled into the frontend: any SVA construct not yet at rung-done status produces a hard error naming the construct and the tracking issue — never a partial lowering. CI check that the table matches the actually-implemented op set.
**Accept:** Feeding an R7 construct before R7 is done yields the named error, exit code per P0.6 spec; no path emits BTOR2 for an unlisted construct.

---

## Phase 3 — Unbounded proofs + portfolio (months 8–14, overlaps Phase 2)

**Milestone M3:** unbounded PROVEN (k-induction or IC3) on a non-trivial benchmark, validated by the soundness audit.

### P3.1 — Pono k-induction + IC3IA `[OPUS]`
**Repo:** fv-engine · **Depends:** P1.6
**Deliverable:** Add Pono's k-induction and IC3IA modes to the runner; per-engine config (solver=Bitwuzla, limits); UNSAT/invariant results mapped to PROVEN in `result.json` with engine + method attribution.
**Accept:** Counter benchmark gets PROVEN (not bounded-clean) by at least one method; CEX benchmarks still report CEX identically to v0.

### P3.2 — AVR integration `[OPUS]` ✅ *(closed: blocked-by-license)*
**Repo:** fv-engine · **Depends:** P3.1, P0.2 (license verdict)
**Deliverable:** AVR as a subprocess engine behind the same interface — only if P0.2 cleared it. If P0.2 blocked it, this card closes as "blocked-by-license" and the portfolio ships without AVR.
**Accept:** Same contract tests as P3.1 pass with AVR; or documented closure.
**Status:** ✅ Closed as blocked-by-license per the P0.2 `[FABLE]` review (2026-06-12): AVR is GPLv3 and was dropped from the portfolio — documented closure with rationale and re-entry conditions in flagship `LICENSES.md`. The P3.3 portfolio ships without AVR (Pono modes + btormc). Do not pick this card up unless the LICENSES.md re-entry conditions are met and a fresh `[FABLE]` sign-off is recorded.

### P3.3 — Portfolio racing `[OPUS]`
**Repo:** fv-engine · **Depends:** P3.1
**Deliverable:** Parallel launch of configured engines per property; first *definitive* answer (PROVEN or CEX) wins and cancels the rest; conflicting definitive answers (one says PROVEN, another CEX) abort with a loud SOUNDNESS-BUG error — never pick one; resource caps (CPU/mem/wall) enforced.
**Accept:** Race produces stable results across runs on the benchmark set; injected fake-conflict test triggers the soundness error.

### P3.4 — Result reporting + exit semantics `[SONNET]`
**Repo:** fv-engine, openfv · **Depends:** P3.3
**Deliverable:** Human-readable summary (per-property table: status, engine, depth, time), `result.json` finalization per spec, exit codes per P0.6.
**Accept:** Golden report tests; codes verified for each status class.

### P3.5 — Induction/monitor soundness audit `[FABLE]`
**Repo:** sva-frontend + fv-engine (`docs/soundness.md`) · **Depends:** P3.1, rungs through R8
**Deliverable:** Written audit: does each monitor construction preserve property semantics under k-induction and IC3 (auxiliary monitor state can hurt completeness — induction failures must surface as UNKNOWN, never as CEX; liveness monitors per R12 audited separately)? Concrete checklist tests added where the audit finds risk.
**Accept:** Audit covers every shipped rung; each identified risk has a regression test or an explicit UNKNOWN-downgrade in the engine.

### P3.6 — Nightly regression + trends `[SONNET]`
**Repo:** openfv · **Depends:** P3.4
**Deliverable:** Nightly job running the full fv-benchmarks set; tracked history of PROVEN/CEX/UNKNOWN counts and solve times; correctness regressions fail the job, speed regressions warn.
**Accept:** Trend artifact published per run; a seeded correctness regression turns the job red.

---

## Phase 4 — Source-level debug (months 12–18)

**Milestone M4:** an engineer opens a failing wave in Surfer/GTKWave with *their* signal names and the failing cycle marked.

### P4.1 — Witness parser `[OPUS]`
**Repo:** witness-remap · **Depends:** P1.6 (golden `.wit` files exist)
**Deliverable:** BTOR2 witness ingestion via btor2tools (linked, MIT) into an internal trace model (per-step assignments, inputs, states); unit tests on golden witnesses including memories/arrays if Phase 1 emitted them.
**Accept:** Round-trip test: parse → dump → equivalent.

### P4.2 — Remapping algorithm `[FABLE]`
**Repo:** witness-remap · **Depends:** P4.1, P1.4
**Deliverable:** Design + core implementation mapping trace-model entries through `.locmap` to hierarchical RTL names, widths, and source locations; explicit policy for signals optimized away in lowering (emit as missing or as derived/reconstructed *with that marking* — never silently fabricate); monitor-internal signals grouped under a dedicated scope.
**Accept:** FIFO CEX wave shows every user-visible signal under its RTL name with correct values per hand-check; missing signals listed in the tool output.

### P4.3 — Clean-room VCD writer `[SONNET]`
**Repo:** witness-remap · **Depends:** P4.2
**Deliverable:** VCD writer implemented solely from the VCD chapter of IEEE 1800 (the format is small); hierarchical scopes, vectors, x/z values; golden VCD tests; output loads in GTKWave and Surfer.
**Accept:** Golden diffs green; manual load check in both viewers documented with screenshots in the PR.

### P4.4 — FST output decision + glue `[OPUS]`
**Repo:** witness-remap · **Depends:** P4.3, P0.2
**Deliverable:** Per the license policy: **no linking GPL libfst.** Implement FST via subprocess conversion (e.g., invoking an externally-installed `vcd2fst`) with graceful VCD-only fallback when the tool is absent; document the user-facing behavior.
**Accept:** With converter installed → `.fst` produced; without → clean message + `.vcd`; nothing GPL in our link line (CI check).

### P4.5 — Failure annotation `[SONNET]`
**Repo:** witness-remap · **Depends:** P4.2
**Deliverable:** Inject monitor/assertion status signals into the wave under an `_openfv/` scope; mark the violation cycle (dedicated marker signal pulsing at the failure step); property name(s) in the signal names.
**Accept:** Opening the FIFO CEX wave, the violated property and its failure cycle are findable in <30 s by someone who didn't run the tool.

### P4.6 — Debug E2E test `[SONNET]`
**Repo:** openfv · **Depends:** P4.4, P4.5
**Deliverable:** Flagship integration test: failing property → `openfv` prints the wave path + a `surfer <file>` hint (per README mock); golden VCD (value-section) diff in CI.
**Accept:** Milestone M4 demonstrably green in CI.

---

## Phase 5 — Visualize-class debugger (months 18+, optional/research) `[FABLE-led]`

Deliberately coarse — do not break down further until M4 ships. Entry conditions: M4 done, Surfer plugin-boundary license review done (P0.2 follow-up), and at least one external user asking for it. Initial cards when opened: cone-of-influence extraction over the lowered IR `[FABLE]`, driver tracing `[OPUS]`, why-is-this-X `[FABLE]`, Surfer extension host `[OPUS]`.

---

## Cross-cutting backlog (any time after their dependencies)

| Task | Tier | Notes |
|---|---|---|
| Documentation site (user guide, construct support matrix auto-generated from the P2.5 table) | `[SONNET]` | After M1. |
| Benchmark expansion: picorv32, OpenTitan blocks, lowRISC IP — each with a license check on import | `[SONNET]` | Imported designs keep their own licenses in-tree; flag anything non-permissive. |
| HWMCC BTOR2 set import for fv-engine stress testing | `[SONNET]` | Engine-only benchmarks; no frontend involved. |
| Upstreaming PRs to CIRCT (each P1.2/P1.5 pass flagged upstream-candidate) | `[OPUS]` impl, `[FABLE]` review | One PR per pass; keep our staging copy until the upstream pin includes it. |
| README/plan drift check — keep README, plan, and this file consistent at each milestone | `[SONNET]` | At M0–M4. |
