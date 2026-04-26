# Optional Suggestions

These are not required to execute the revised plan.

1. Title: Add a dashboard payload fixture
   Type: Small
   Why: Route and component tests can reuse one stable dashboard object.
   Where it would apply: `TRR-APP/apps/web/tests/fixtures/`
   How it could improve the plan: Reduces duplicated JSON setup across snapshot and page tests.

2. Title: Add a backend dashboard schema model
   Type: Medium
   Why: The endpoint currently returns a raw dict contract.
   Where it would apply: `TRR-Backend/api/routers/socials.py` or a social dashboard schema module.
   How it could improve the plan: Gives FastAPI validation and OpenAPI docs a stronger contract.

3. Title: Emit `x-trr-dashboard-freshness`
   Type: Small
   Why: Operators can inspect freshness from browser network headers.
   Where it would apply: app snapshot route response headers.
   How it could improve the plan: Makes stale/fresh behavior easier to verify manually.

4. Title: Add a one-page operator runbook
   Type: Small
   Why: Degraded states will be visible to admins.
   Where it would apply: `docs/workspace/` or the TRR Workspace Brain.
   How it could improve the plan: Explains what stale dashboard data means and when to retry diagnostics.

5. Title: Add request-count telemetry
   Type: Medium
   Why: The plan relies on reducing initial fanout.
   Where it would apply: app proxy logs or admin read proxy observability.
   How it could improve the plan: Lets the team detect regressions where initial render fanout creeps back up.

6. Title: Add a live EXPLAIN capture script later
   Type: Medium
   Why: Index work should be based on actual query plans.
   Where it would apply: `TRR-Backend/scripts/db/`
   How it could improve the plan: Prepares the next read-model/index phase without guessing.

7. Title: Add a dashboard endpoint smoke command
   Type: Small
   Why: Backend-only verification should be easy without opening the UI.
   Where it would apply: `docs/workspace/dev-commands.md`.
   How it could improve the plan: Gives future agents a quick route-level health check.

8. Title: Track stale-cache hit rate
   Type: Medium
   Why: Stale fallback should be rare but valuable.
   Where it would apply: app snapshot cache or backend dashboard logs.
   How it could improve the plan: Helps distinguish healthy resilience from backend degradation.

9. Title: Add a hidden-tab polling regression test
   Type: Small
   Why: `shared-live-resource.ts` already handles visibility, but future edits could regress it.
   Where it would apply: app tests for shared live resources.
   How it could improve the plan: Protects the anti-dogpile behavior independently of the page test.

10. Title: Add a dashboard read-model decision stub
    Type: Small
    Why: This plan explicitly defers materialized tables.
    Where it would apply: `TRR Workspace Brain/api-contract.md` or a follow-up plan.
    How it could improve the plan: Keeps the future read-model phase discoverable without expanding this phase.

