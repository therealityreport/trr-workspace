# VALIDATION

## Files Inspected

- `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-27-supabase-connection-capacity-hardening-plan.md`
- `/Users/thomashulihan/Documents/Codex/2026-04-21-create-a-rubric-for-scoring-an/implementation-plan-rubric.md`
- `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/shows/shows-repository.ts`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/app-direct-sql-inventory.md`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-rls-grants-review.md`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-capacity-budget.md`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/api-migration-ledger.md`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/config.toml`

## Commands Run

```bash
rg -n "^#|^##|^###|Acceptance criteria|Validation|Dependencies|Commit boundary|Cleanup Note" docs/codex/plans/2026-04-27-supabase-connection-capacity-hardening-plan.md
wc -l docs/codex/plans/2026-04-27-supabase-connection-capacity-hardening-plan.md
rg -n "placeholder|pending|TODO|blocked|TBD|empty|not yet|needs" docs/workspace/supabase-rls-grants-review.md docs/workspace/supabase-capacity-budget.md docs/workspace/api-migration-ledger.md docs/workspace/app-direct-sql-inventory.md
rg -n "runtime DDL|ALTER TABLE|CREATE TABLE|CREATE INDEX|CREATE OR REPLACE FUNCTION|CREATE TRIGGER" TRR-APP/apps/web/src/lib/server/shows/shows-repository.ts
rg -n "high-fanout|needs owner label|Summary|Total direct SQL call sites" docs/workspace/app-direct-sql-inventory.md
```

Follow-up suggestion-incorporation validation:

```bash
rg -n "^## ADDITIONAL SUGGESTIONS|^### Suggestion [0-9]+" .plan-grader/supabase-connection-capacity-hardening-20260427-131550/REVISED_PLAN.md
python3 -m json.tool .plan-grader/supabase-connection-capacity-hardening-20260427-131550/result.json
```

Existence checks were also run for the plan's named scripts, tests, docs, and config files. All checked paths existed:

- `scripts/env_contract_report.py`
- `scripts/workspace-env-contract.sh`
- `scripts/check-workspace-contract.sh`
- `scripts/migration-ownership-lint.py`
- `scripts/app-direct-sql-inventory.py`
- `scripts/redact-env-inventory.py`
- `scripts/vercel-project-guard.py`
- `scripts/status-workspace.sh`
- `scripts/dev-workspace.sh`
- `TRR-Backend/tests/db/test_connection_resolution.py`
- `TRR-Backend/tests/db/test_pg_pool.py`
- `TRR-Backend/tests/api/test_health.py`
- `TRR-Backend/tests/api/test_admin_socials_landing_summary.py`
- `TRR-Backend/tests/socials/test_profile_dashboard.py`
- `TRR-APP/apps/web/tests/postgres-connection-string-resolution.test.ts`
- `TRR-APP/apps/web/tests/admin-app-db-pressure-route.test.ts`
- `TRR-APP/apps/web/tests/social-landing-repository.test.ts`
- `TRR-APP/apps/web/tests/shared-live-resource-polling.test.tsx`

## Evidence Confirmed

- Runtime DDL exists in app request-time repository code.
- Direct-SQL inventory reports `108` app direct SQL call sites and `22` owner-label gaps.
- RLS/grants review is still pending live snapshot.
- API migration ledger contains placeholder rows.
- Plan validation commands mostly reference real files.
- All 10 suggestions are now represented as detailed tasks in `REVISED_PLAN.md`.

## Evidence Gaps

- Supabase advisors remain permission-dependent.
- Production Supabase capacity values were not verified during this grading pass.
- Vercel production env cleanup was not executed; the plan correctly requires review artifacts first.
- No full test suite was run because this was plan grading, not implementation.

## Assumptions

- The additional audit pasted by the user is accepted as source evidence where it matches repo checks.
- Production mutation requires explicit human approval.
- Execution will use `REVISED_PLAN.md`, not the older source plan, if Plan Grader output is accepted.

## RECOMMENDED NEXT SKILL

`orchestrate-subagents` after Phases 0-2 are completed inline.
