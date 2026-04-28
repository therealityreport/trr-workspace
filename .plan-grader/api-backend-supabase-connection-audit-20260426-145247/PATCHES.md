# Patches: Original To Revised Plan

## Patch 1: Add no-write production gate

Applied in `REVISED_PLAN.md` under `Execution Rules` and `Phase 0`.

Reason: the original plan correctly says production truth is missing, but it does not make that a hard gate before pool/env/migration work.

## Patch 2: Persist production evidence artifacts

Applied in `Phase 0`.

Added required docs:

- `docs/workspace/production-supabase-connection-inventory.md`
- `docs/workspace/supabase-capacity-budget.md`
- `docs/workspace/vercel-env-review.md`

Reason: production inventory should not live only in chat or command output.

## Patch 3: Disambiguate Vercel project ownership

Applied in `Current State Summary`, `Phase 0`, and `Phase 6`.

Reason: the audit found `trr-app` production ready and nested `web` latest deployment errored. The plan now requires one project of record.

## Patch 4: Make direct-SQL reduction measurable

Applied in `Phase 3`.

Original direction:

```md
Inventory all imports ... classify each ...
Success criterion: the count decreases each phase.
```

Revised direction:

```md
Generate docs/workspace/app-direct-sql-inventory.md.
Classify every caller by owner/risk.
Pick the first migration slice from high-fan-out read paths only.
Remaining direct SQL must have an owner label.
```

Reason: "count decreases" is too weak without an inventory artifact and first-slice rule.

## Patch 5: Fix RLS SQL

Applied in `Phase 5`.

Original query referenced `pg_tables.hasrls`. Revised query uses `pg_class.relrowsecurity` and `relforcerowsecurity`, plus `information_schema.role_table_grants`.

Reason: the original SQL was not a safe executable audit query.

## Patch 6: Add safer migration validation

Applied in `Phase 4`.

Revised plan avoids casual remote `supabase db push` and requires linked project, target branch/environment, and approved connection lane before any remote migration application.

Reason: remote migration commands are high-risk in a production Supabase audit plan.

## Patch 7: Make request-time DDL removal testable

Applied in `Phase 4`.

Added static guard:

```bash
rg -n "CREATE TABLE|ALTER TABLE|CREATE OR REPLACE FUNCTION|CREATE TRIGGER|DROP TABLE|DROP FUNCTION" apps/web/src/lib/server apps/web/src/app/api
```

Reason: the original plan said to add a test but did not define the failure condition.

## Patch 8: Add rollback and stop conditions

Applied across `Execution Rules`, `Phase 0`, `Phase 2`, `Phase 3`, `Phase 4`, `Phase 6`, and `Phase 8`.

Reason: production DB and deployment plans need explicit stop rules before execution by agents.

## Patch 9: Include every prior suggestion as required plan work

Applied in `REVISED_PLAN.md` under the exact required heading `ADDITIONAL SUGGESTIONS`.

Reason: the follow-up request selected all numbered suggestions from `SUGGESTIONS.md`; they are no longer optional.

## Suggestion Mapping

| Source suggestion | Revised plan task | Concrete plan changes |
| --- | --- | --- |
| 1. Add a connection budget dashboard card | `Task S1` | Adds admin health card work with dependencies on Phase 0/6 capacity evidence, app/backend affected surfaces, validation, acceptance criteria, and commit boundary. |
| 2. Add `application_name` conventions to the env contract | `Task S2` | Adds env-contract conventions, generator/example updates, preflight validation, and Phase 0 attribution requirements. |
| 3. Add a one-command direct-SQL inventory script | `Task S3` | Adds deterministic inventory tooling tied to Phase 3 direct-SQL reduction and before/after counts. |
| 4. Add a migration ownership linter | `Task S4` | Adds preflight/CI guard after Phase 4 clarifies app-local vs backend-owned migration boundaries. |
| 5. Add a Vercel project guard script | `Task S5` | Adds a project-of-record guard before production Vercel env review or mutation. |
| 6. Add an RLS/grants snapshot artifact | `Task S6` | Adds durable before/after RLS and grant snapshot documentation tied to Phase 5. |
| 7. Track prepared-statement compatibility explicitly | `Task S7` | Adds transaction-mode compatibility evidence for prepared statements, session state, and auth/RLS behavior. |
| 8. Add a production env redaction helper | `Task S8` | Adds shape-only env inventory tooling for safe Vercel/Supabase env review. |
| 9. Add an API migration ledger | `Task S9` | Adds per-slice app direct-SQL to backend-route ledger requirements tied to Phase 7 and `api-contract.md`. |
| 10. Add a post-implementation cleanup checklist | `Task S10` | Adds final cleanup requirements after verification, including Plan Grader artifacts, generated snapshots, obsolete migrations, aliases, and stale project references. |

## Patch 10: Integrate incorporated suggestions into execution order

Applied in `Priority Order`, `Recommended Execution Shape`, and `Verification Checklist`.

Reason: accepted suggestions must affect dependencies, workstreams, validation, and acceptance criteria rather than appearing only as a copied list.
