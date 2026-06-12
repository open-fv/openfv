# Dependency licenses

Per [PROJECT_PLAN.md §1.3](PROJECT_PLAN.md): every dependency is recorded here **before first use**, with how it is consumed. Allowlist: Apache-2.0 (incl. LLVM exception), MIT, BSD-2/3, ISC, zlib. Anything else needs an explicit review entry and may only sit across a process boundary, never linked.

Licenses verified by reading each upstream's LICENSE/COPYING file directly (not from memory or secondary sources). Upstream repo and file noted per entry. Audit performed for task P0.2.

---

## Tier-0 upstreams (plan §2 table)

| Dependency | Upstream | License (verified) | How consumed | Verdict |
|---|---|---|---|---|
| **slang** | [MikePopoloski/slang](https://github.com/MikePopoloski/slang) — `LICENSE` | MIT | Linked library: SV-2017 parse + elaboration via CIRCT ImportVerilog | **APPROVED** — MIT is on the allowlist |
| **CIRCT** | [llvm/circt](https://github.com/llvm/circt) — `LICENSE` | Apache-2.0 with LLVM Exceptions | Linked; our passes (rtl-lowering, sva-frontend, btor2-emit) target CIRCT dialects; generic passes upstreamed to CIRCT | **APPROVED** — Apache-2.0/LLVM exception is on the allowlist |
| **Pono** | [stanford-centaur/pono](https://github.com/stanford-centaur/pono) — `LICENSE` | BSD-3-Clause | Subprocess (preferred) or linked for BMC, k-induction, IC3IA; not modified | **APPROVED** — BSD-3 is on the allowlist |
| **AVR** | [aman-goel/avr](https://github.com/aman-goel/avr) — `LICENSE` | **GPLv3** | **Not used.** Dropped from the engine portfolio by `[FABLE]` review, 2026-06-12 | **DO NOT USE (dropped)** — see review note below for rationale and re-entry conditions |
| **Bitwuzla** | [bitwuzla/bitwuzla](https://github.com/bitwuzla/bitwuzla) — `COPYING` | MIT | Linked internally by Pono/AVR; we do not link Bitwuzla directly | **APPROVED** — MIT; consumed transitively across the engine subprocess boundary, not by us directly |
| **btor2tools** | [hwmcc/btor2tools](https://github.com/hwmcc/btor2tools) — `LICENSE.txt` | MIT | Linked in `witness-remap` for BTOR2 witness parsing | **APPROVED** — MIT is on the allowlist |
| **Boolector / btormc** | [Boolector/boolector](https://github.com/Boolector/boolector) — `COPYING` | MIT | Subprocess: `btormc` is the BMC/k-induction engine used by fv-engine from P1.6 onward | **APPROVED** — MIT is on the allowlist. *(Added during the P0.2 audit: btormc is used by P1.6 but was missing from the plan §2 table.)* |
| **Verilator** | [verilator/verilator](https://github.com/verilator/verilator) — `LICENSE` | LGPLv3 | Subprocess only; dev/CI conformance reference simulator; never linked; never shipped in release | **APPROVED (process-boundary)** — LGPLv3 is not on the allowlist; explicit review records: never linked, invoked only across a process boundary during CI conformance runs; LGPL linking restrictions do not apply |
| **Icarus Verilog** | [steveicarus/iverilog](https://github.com/steveicarus/iverilog) — `COPYING` | GPLv2 | Subprocess only; dev/CI conformance reference simulator for constructs Verilator does not support; never linked; never shipped | **APPROVED (process-boundary)** — GPLv2 is not on the allowlist; explicit review records: never linked, process-boundary-only dev/CI use; GPL does not propagate |
| **GTKWave / libfst** | [gtkwave/gtkwave](https://github.com/gtkwave/gtkwave) — `COPYING` | GPLv2 | **Never linked.** FST output produced via external `vcd2fst` subprocess (user-installed); VCD-only fallback when converter absent; P4.4 implements and CI-checks the no-GPL-link invariant | **APPROVED (process-boundary)** — GPLv2 is not on the allowlist; explicit review records: libfst never enters our link line; vcd2fst (if present) is a user-provided external tool invoked across a process boundary |
| **Surfer** | [surfer-project/surfer](https://gitlab.com/surfer-project/surfer) | EUPL-1.2 | External program launched independently by the end user; we emit VCD/FST files the user opens in Surfer; we do not distribute Surfer or invoke it as a subprocess | **APPROVED for current use** — EUPL-1.2 does not apply to our code when Surfer is an independent user-launched program we do not distribute or extend; **Phase 5 plugin API work: PENDING \[FABLE\] REVIEW** — see note below |

---

## Review notes

### AVR (GPLv3) — `[FABLE]` review, 2026-06-12: **dropped from the plan**

AVR's `LICENSE` file is the GNU General Public License Version 3 — strong copyleft, **not on the project allowlist**.

**Legal finding:** subprocess-only use *would* be permissible. A GPL program invoked as a separate process, communicating via files at arm's length, does not make the invoking program a derivative work, provided we (a) never link AVR code, (b) never incorporate AVR source, and (c) never redistribute AVR binaries in our releases, containers, or convenience bundles.

**Decision: dropped anyway.** The product question is separate from the legal one, and the answer is that AVR isn't worth its carrying cost:

- **Redundant for every milestone.** AVR's role (plan §2) was a *second* unbounded engine for portfolio diversity. Pono (BSD-3) supplies IC3IA + k-induction + BMC; btormc (MIT) supplies BMC + k-induction. Milestone M3 (unbounded PROVEN) does not depend on AVR.
- **Copyleft all the way down.** AVR's default SMT backend is Yices 2, which is itself GPLv3 (per AVR's README) — clearing AVR would mean auditing and carrying a second non-allowlist dependency underneath it.
- **Low-activity research code** (last upstream commit 2025-08-26 as of this review) is a weak foundation for a path whose output is a "trustworthy PROVEN."
- **Every non-allowlist dependency is permanent compliance surface** — distribution audits, CI no-bundle guards, documentation footnotes — not justified by a redundant engine.

**Consequences:** P3.2 (AVR integration) closes as *blocked-by-license / dropped* — its acceptance criteria explicitly allow documented closure, which this note is. The P3.3 portfolio ships with Pono modes + btormc.

**Re-entry conditions:** if Phase-3 benchmarking demonstrates a concrete capacity gap — a property class where the Pono+btormc portfolio fails and AVR demonstrably succeeds — AVR may be reconsidered as an *optional, user-installed, subprocess-only* engine: never linked, never bundled or redistributed by us, absence handled gracefully at runtime. That reconsideration requires a fresh `[FABLE]` sign-off recorded in this file.

### Surfer (EUPL-1.2) — Phase 5 plugin work needs a fresh review

The European Union Public Licence 1.2 (EUPL-1.2) is a copyleft license with a compatibility table that allows relicensing derivative works under certain other copyleft licenses, but **not** under Apache-2.0 for distribution. For Phase 5 (Surfer plugin / extension-host integration, plan §4), the plugin boundary must be examined:

- If the plugin API requires our code to be dynamically loaded into the Surfer process (or vice versa), the copyleft may apply to our plugin.
- A `[FABLE]` review of the Surfer plugin boundary license implications is required **before any Phase 5 implementation work begins.**
- Current VCD/FST file-based interaction (Phase 4) is unaffected — file formats are not a derivative work.
