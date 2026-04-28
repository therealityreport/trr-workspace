# AUDIT

Source plan: `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-index-advisor-social-hot-path-plan.md`

Verdict: `APPROVED_WITH_REVISIONS`

Original score: `85`
Revised score estimate: `92`

## Current-State Fit

The plan is directionally correct and grounded in current TRR state:

- Live DB check showed `index_advisor` installed in schema `extensions` with installed version `0.2.0`.
- Repo search found no `index_advisor` migration, script, test, or docs contract.
- Existing backend DB tooling already has `scripts/db/hot_path_explain/hot_path_explain.sql` and a README that requires route labels, EXPLAIN evidence, RLS/grants review, and no blind index creation.
- Existing Supabase advisor remediation docs explicitly leave remaining unused-index work deferred, so this plan correctly avoids destructive cleanup.

## Approval Decision

Approve the revised plan for sequential implementation after the fixes in `REVISED_PLAN.md` replace the source plan.

The source plan was strong but not quite execution-grade because it left these avoidable ambiguities:

1. It did not include the mandatory Plan Grader cleanup note.
2. It did not explicitly require the helper to run inside a read-only transaction with local statement and lock timeouts.
3. It used `TRR_DB_URL` in one EXPLAIN command even though TRR's current runtime contract prefers `TRR_DB_SESSION_URL` before `TRR_DB_URL`.
4. It left generated artifact check-in policy as an open question instead of a default execution rule.
5. It did not name a helper output schema tightly enough for tests.
6. It did not make the "no returned DDL execution" stop rule prominent enough for an automated executor.

## Biggest Risks

- `index_advisor` only recommends single-column B-tree indexes, so it will miss many TRR social-query needs. The revised plan keeps EXPLAIN as the authority.
- Helper queries may need explicit casts for placeholders. The revised plan adds this to the helper contract and validation.
- Existing advisor cleanup work is easy to confuse with fresh index creation. The revised plan keeps this package recommendation-only and requires a separate approval for any index DDL.

## Required Fixes Applied

- Rewrote the canonical plan and package `REVISED_PLAN.md` with a stricter helper contract.
- Added read-only transaction, timeout, output-schema, generated-artifact, and stop-rule requirements.
- Changed execution handoff to sequential/inline rather than subagent orchestration.
- Added cleanup note.

## Approval Conditions

Implementation may proceed if the executor uses `REVISED_PLAN.md` or the updated canonical docs plan as source of truth. Do not execute from the original ungraded plan text.
