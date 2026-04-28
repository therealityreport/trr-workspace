# COMPARISON

| Area | Previous revised plan | New revised plan | Impact |
| --- | --- | --- | --- |
| Matrix validation | Inline validator snippet in Phase 6. | Required reusable script `validate_unused_index_decision_matrix.py`. | Makes the core artifact enforceable and reusable. |
| Destructive SQL safety | Stop rules and proposed SQL wording. | Required scanner `scan_no_destructive_sql.py`. | Makes the no-DDL boundary machine-checkable. |
| Stats-window evidence | Captured in preflight and rows. | Required JSON artifact consumed by validator. | Prevents hand-wavy seven-day evidence. |
| Social hashtag blocker | Stop rule and social review rule. | Required architecture stub referenced by social packet and canonical plan. | Makes the product blocker explicit and durable. |
| Query patterns | Free-form `query_pattern_supported`. | Controlled `query_pattern_labels` plus free-form explanation. | Keeps 1,000+ row analysis groupable. |
| Owner packets | Six paths listed. | Filenames generated from workload slugs, README schema required. | Reduces packet drift and merge cleanup. |
| Prior approvals | Historical evidence warning. | README quarantine section required. | Makes old Phase 3 SQL harder to misuse. |
| Time budgets | Not included. | Soft triage posture by workload. | Limits sprawl without rushing approvals. |
| Advisor closeout | Canonical status update. | Optional post-review Advisor delta snapshot. | Captures drift without creating an artificial blocker. |

## score movement

| Topic | Previous Score | Revised Score | Delta | Reason |
| --- | ---: | ---: | ---: | --- |
| A.1 Goal clarity | 4.9 | 5.0 | +0.1 | Required guardrail artifacts make the end state more concrete. |
| A.2 Repo awareness | 4.8 | 5.0 | +0.2 | Names exact script and workspace artifact paths. |
| A.3 Sequencing | 4.8 | 5.0 | +0.2 | Validation tooling and architecture stub are sequenced before approval/batching. |
| A.4 Specificity | 4.7 | 5.0 | +0.3 | Required script behaviors and schemas are explicit. |
| A.5 Verification | 4.8 | 5.0 | +0.2 | Validator/scanner turn key checks into commands. |
| B Coverage | 4.8 | 5.0 | +0.2 | Closes packet drift, prior-approval bleed, stats evidence, and search architecture gaps. |
| C Tooling | 4.7 | 4.9 | +0.2 | Tooling is more concrete while still scoped. |
| E Safety | 5.0 | 5.0 | +0.0 | Already strong; scanner and validator preserve the top score. |
| F Scope | 4.8 | 4.9 | +0.1 | Promoted guardrails are directly tied to the core artifact. |
| H Bonus | 4.7 | 4.9 | +0.2 | Optional Advisor delta and triage budgets add useful operational polish. |

## result

The revised plan remains blocked for execution until Phase 0 resolves the report-universe mismatch and dirty worktree state, but the plan itself is now stronger and more enforceable.
