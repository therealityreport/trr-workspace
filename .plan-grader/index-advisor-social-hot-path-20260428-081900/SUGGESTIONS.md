# SUGGESTIONS

These are optional follow-ups. They are not required for approval of `REVISED_PLAN.md`.

## 1. Add Advisor Report Diffing

Type: Medium

Why: It would let operators compare recommendation drift across runs without manually reading two JSON files.

Where it would apply: `TRR-Backend/scripts/db/` and `docs/workspace/`.

How it could improve the plan: It would make later reviews faster and reduce stale recommendation churn.

## 2. Add Query Registry Tests

Type: Small

Why: If the helper uses a YAML or Python registry, invalid labels or missing casts could break live runs.

Where it would apply: `TRR-Backend/tests/db/`.

How it could improve the plan: It would catch malformed advisor queries before operators run them.

## 3. Add A Redaction Unit Test

Type: Small

Why: The helper writes reports from a DB-connected process.

Where it would apply: `TRR-Backend/tests/db/test_index_advisor_social_hot_paths.py`.

How it could improve the plan: It would ensure reports never include DB URLs or secrets.

## 4. Add JSON Schema For Report Output

Type: Medium

Why: Stable output enables future dashboards, diffs, or owner packets.

Where it would apply: `TRR-Backend/scripts/db/index_advisor_social_hot_paths.schema.json`.

How it could improve the plan: It would turn evidence artifacts into a reusable contract.

## 5. Include Existing Index Context Per Recommendation

Type: Medium

Why: Many advisor recommendations may duplicate or overlap existing indexes.

Where it would apply: helper output generation.

How it could improve the plan: It would reduce false-positive index proposals.

## 6. Add A `--labels` Filter

Type: Small

Why: Operators may want to run one route/query group.

Where it would apply: helper CLI.

How it could improve the plan: It would make targeted investigations cheaper.

## 7. Add Statement Timing To Reports

Type: Medium

Why: Advisor output alone does not show route pain.

Where it would apply: optional report metadata from existing app/backend logs.

How it could improve the plan: It would help prioritize recommendations that matter.

## 8. Add A Review Packet Generator

Type: Large

Why: Candidate indexes need owner approval before DDL.

Where it would apply: `TRR-Backend/scripts/db/` and `docs/workspace/index-advisor-owner-review-*`.

How it could improve the plan: It would standardize later review packages.

## 9. Add Local Reset Verification

Type: Medium

Why: The extension exists live but must also be reproducible in local reset.

Where it would apply: backend migration validation docs or CI-like local check.

How it could improve the plan: It would prove the migration contract works outside the live database.

## 10. Link Reports From Supabase Advisor Workflow Docs

Type: Small

Why: This helper is adjacent to the existing Supabase Advisor snapshot workflow.

Where it would apply: `docs/workspace/supabase-advisor-snapshot-workflow.md`.

How it could improve the plan: It would make the new workflow discoverable from the existing operator path.
