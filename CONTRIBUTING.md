# Contributing

This repository is part of the **openfv** project. Before contributing, read the flagship's [PROJECT_PLAN.md](https://github.com/open-fv/openfv/blob/main/PROJECT_PLAN.md) — especially **§1 (legal & clean-room policy)** and **§5 (execution model)** — and pick up work as task cards from [TASKS.md](https://github.com/open-fv/openfv/blob/main/TASKS.md).

## Non-negotiables

1. **DCO sign-off.** Every commit must carry a `Signed-off-by` line (`git commit -s`), certifying the [Developer Certificate of Origin](https://developercertificate.org/).
2. **Clean-room rules** (summary — plan §1 governs):
   - No code copied from anywhere — not from upstreams, not from StackOverflow, not from blog posts, regardless of license. External code is consumed only as a dependency.
   - Never consult proprietary formal-verification tools (Jasper, VC Formal, …) — no docs, no outputs, no behavior comparison.
   - SVA semantics come exclusively from **IEEE 1800-2017** (cite clause numbers) or cited academic papers.
3. **Dependencies.** Allowlist: Apache-2.0, MIT, BSD-2/3, ISC, zlib. Record every dependency in `LICENSES.md` *before* first use. GPL/copyleft is never linked — subprocess boundary only, after explicit review.
4. **Escalate, don't guess.** If a spec or the LRM is ambiguous, stop and flag it (issue tagged `escalation`) rather than picking an interpretation.
5. **PRs** must complete the provenance checklist in the PR template.

## License

By contributing, you agree your contributions are licensed under [Apache-2.0](LICENSE).
