# Comparison

## Summary

The revised plan preserves the source plan's intent but makes the execution path more deterministic. The largest deltas are in repo surface specificity, local/cloud mode separation, and safety validation.

## Score Delta

| Topic | Original | Revised | Delta | Reason |
|---|---:|---:|---:|---|
| A.1 Goal clarity | 8 | 9 | +1 | Exact `WORKSPACE_DEV_MODE=local/cloud` contract added. |
| A.2 Repo/file awareness | 6 | 8 | +2 | Names concrete scripts, docs, tests, and migration decision artifact. |
| A.3 Sequencing | 8 | 9 | +1 | Adds dirty-worktree gate and separates preflight before migration action. |
| A.4 Execution specificity | 6 | 8 | +2 | Adds helper/source-label/sanitizer requirements. |
| A.5 Verification | 8 | 9 | +1 | Adds negative tests for secret leakage and cloud direct inheritance. |
| B Coverage | 7 | 8 | +1 | Covers fail-closed direct derivation, cloud mode, and record persistence. |
| C Tooling | 7 | 8 | +1 | Recommends sequential execution suited to coupled dirty surfaces. |
| D.5 Durability | 1 | 2 | +1 | Adds docs/status/decision artifacts. |
| E Safety | 8 | 9 | +1 | Adds no-secret scan and explicit stop rules. |
| H Bonus | 2 | 3 | +1 | Adds reusable identity/status diagnostics as follow-up. |

## Original Strengths Preserved

- Correctly treats direct DB URL as local-only secret-bearing config.
- Correctly rejects silent session-pooler fallback.
- Correctly requires one migration decision at a time.
- Correctly keeps deployed runtime direct-lane rejection in scope.

## Main Original Weaknesses Fixed

- Cloud/local mode behavior is no longer implicit.
- Preflight behavior is no longer left cloud-shaped by default.
- Migration verdict records now have a durable path.
- Remote inheritance proof names the launcher and remote worker surfaces.
- Secret redaction is now testable.
