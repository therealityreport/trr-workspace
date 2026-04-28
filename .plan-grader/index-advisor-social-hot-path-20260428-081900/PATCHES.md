# PATCHES

## Summary

The revised plan preserves the original structure and intent, then tightens execution details needed for approval.

## Patch Map

| Source Section | Change In Revised Plan | Reason |
| --- | --- | --- |
| `summary` | Adds that the helper is read-only and does not replace EXPLAIN evidence. | Prevents advisor output from becoming implicit DDL approval. |
| `assumptions` | Adds `index_advisor` function signature expectations, read-only transaction, and generated artifact policy. | Removes executor guesswork. |
| `Phase 0` | Adds baseline artifact name and no-DDL scope guard. | Makes current-state evidence durable. |
| `Phase 1` | Adds static test expectations and live verification. | Ensures extension is reproducible in `extensions`, not `public`. |
| `Phase 2` | Adds exact script contract, CLI flags, output schema, transaction mode, timeout, and redaction requirements. | Turns helper from concept into executable implementation. |
| `Phase 3` | Makes Make target/docs integration concrete but still bounded. | Improves adoption without scope creep. |
| `Phase 4` | Keeps first recommendation review optional and evidence-only. | Prevents hidden index churn. |
| `validation_plan` | Adds canonical DB URL resolver command and JSON schema checks. | Aligns with TRR runtime env contract. |
| End of plan | Adds required `Cleanup Note`. | Satisfies Plan Grader artifact contract. |

## No Diff Block

The full replacement plan is in `REVISED_PLAN.md`; applying a line-level patch would be less clear than replacing the original plan with the revised artifact.
