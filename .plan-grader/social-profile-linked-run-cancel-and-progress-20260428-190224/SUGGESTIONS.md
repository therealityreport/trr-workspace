# Suggestions

These are optional follow-ups. They are not required for the core fix.

1. Title: Run Timeline Drawer
   Type: Medium
   Why: Operators need a compact history of launch groups, attached followups, reused runs, and cancels.
   Where it would apply: Social account profile run cards.
   How it could improve the plan: It would make future run-state debugging faster without reading DB rows.

2. Title: Cancel All Active Lanes Action
   Type: Medium
   Why: Lane-specific cancel is safer first, but operators may later need a single account-level stop action.
   Where it would apply: Admin-only social profile controls.
   How it could improve the plan: It would reduce confusion after lane semantics are stable.

3. Title: One-Account Run-State CLI
   Type: Small
   Why: A tiny diagnostic script can print active catalog/comments/media truth for one account.
   Where it would apply: `TRR-Backend/scripts/` or `docs/ai/local-status/` workflow.
   How it could improve the plan: It would make future support checks reproducible outside the browser.

4. Title: Active-Lane Debug JSON Button
   Type: Small
   Why: The UI already has debug affordances, and the new bounded payload is useful during development.
   Where it would apply: Admin profile debug drawer.
   How it could improve the plan: It would expose run ids, statuses, source, and freshness without inspecting network logs.

5. Title: Progress Freshness Badge
   Type: Small
   Why: Operators need to know if heartbeat/progress is fresh or stale.
   Where it would apply: Catalog/comments lane cards.
   How it could improve the plan: It would separate actively running jobs from stale running records.

6. Title: DB Pressure Hint On Degraded Summary
   Type: Medium
   Why: Summary timeouts may be caused by backend DB pressure or expensive queries.
   Where it would apply: Degraded summary alert area.
   How it could improve the plan: It would point operators toward system health when summary reads time out.

7. Title: Run-State Contract Fixtures
   Type: Small
   Why: Shared JSON fixtures reduce drift between backend API tests and app Vitest tests.
   Where it would apply: Backend test fixtures and app test fixtures.
   How it could improve the plan: It would keep payload expectations synchronized.

8. Title: Cancel Audit Event Table
   Type: Large
   Why: Metadata in `summary` and `metadata` is enough for this fix, but a durable audit table would be better long term.
   Where it would apply: Supabase schema and backend repository.
   How it could improve the plan: It would preserve cancel history across summary rewrites and status reconciliation.

9. Title: Remote Invocation Status Refresh
   Type: Medium
   Why: Current Modal `remote_invocation_status` is often `unknown`.
   Where it would apply: Worker dispatch metadata refresh.
   How it could improve the plan: It would make active jobs easier to distinguish from orphaned DB records.

10. Title: Canary Account Verification
    Type: Small
    Why: A smaller Instagram account can verify the same UI behavior without waiting for a 431-post account.
    Where it would apply: Browser-use verification notes.
    How it could improve the plan: It would shorten manual verification cycles after the main fix lands.
