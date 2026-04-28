# Optional Suggestions

These are non-blocking improvements. Required fixes are already integrated into `REVISED_PLAN.md`.

## 1. Title: Supavisor Evidence Template

Type: Small

Why: Manual dashboard evidence is easy to forget or capture inconsistently.

Where it would apply: `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-capacity-budget.md` or a new runbook.

How it could improve the plan: Add a short table for timestamp, pool size, active sessions, internal headroom, reason, and rollback target.

## 2. Title: Route Fan-Out Inventory Snapshot

Type: Medium

Why: The social landing route is one visible failure, but adjacent admin routes may have similar fan-out.

Where it would apply: `TRR-APP/apps/web/src/app/api/admin` and `TRR-APP/apps/web/src/lib/server/trr-api`.

How it could improve the plan: Generate a periodic route-to-upstream inventory so future polling regressions are easier to spot.

## 3. Title: Holder Budget Simulator

Type: Medium

Why: Budget math is currently spread across profiles, scripts, and docs.

Where it would apply: `/Users/thomashulihan/Projects/TRR/scripts/`.

How it could improve the plan: A small read-only CLI could compute holder totals for each profile before running `make dev`.

## 4. Title: App Pressure Log Parser

Type: Small

Why: Raw logs are useful but noisy during live debugging.

Where it would apply: `/Users/thomashulihan/Projects/TRR/scripts/` or a docs-only command snippet.

How it could improve the plan: Summarize `postgres_pool_init`, queue depth, retry count, and max-client errors by route.

## 5. Title: Feature Flag For Backend Landing Summary

Type: Small

Why: Route migration risk is lower if the app can temporarily fall back to direct SQL.

Where it would apply: `TRR-APP/apps/web/src/lib/server/admin/social-landing-repository.ts`.

How it could improve the plan: Add a short-lived env flag for backend landing summary rollout, with a removal note after validation.

## 6. Title: Local Admin Landing Load Probe

Type: Medium

Why: One curl verifies correctness, but not the burst shape that triggered the session limit.

Where it would apply: `/Users/thomashulihan/Projects/TRR/scripts/` or `TRR-APP/apps/web/tests/`.

How it could improve the plan: Add a tiny local probe that fires concurrent landing requests and reports response codes, timing, and fresh pool errors.

## 7. Title: Runtime DB Lane ADR

Type: Small

Why: The env-lane split is a durable architecture decision.

Where it would apply: `/Users/thomashulihan/Projects/TRR/docs/workspace/` or `TRR Workspace Brain`.

How it could improve the plan: Capture why session remains default, when direct is allowed, and what must be proven before transaction mode.

## 8. Title: Production Alert Threshold Draft

Type: Medium

Why: The plan adds logs and readiness, but alerting policy is a later operational layer.

Where it would apply: production monitoring docs or alert configuration.

How it could improve the plan: Define candidate warning and critical conditions for max-client errors and repeated route retries.

## 9. Title: Cache Invalidation Matrix

Type: Small

Why: Cache changes are safest when each mutation has a named invalidation target.

Where it would apply: Phase 9 implementation notes and backend/app cache tests.

How it could improve the plan: Add a table mapping mutation routes to invalidated freshness, gap, catalog, photo, and landing summary keys.

## 10. Title: Admin Pressure Banner

Type: Medium

Why: Operators may benefit from seeing degraded DB pressure without checking logs.

Where it would apply: admin dashboard UI after backend pressure endpoint is stable.

How it could improve the plan: Show a restrained warning when pressure is degraded, without blocking normal reads.

## 11. Title: Transaction Mode Compatibility Spike

Type: Large

Why: Transaction pooling may help serverless-style app reads, but client compatibility must be proven.

Where it would apply: a future isolated branch touching app/backend DB clients and test fixtures.

How it could improve the plan: Verify prepared statement behavior, session state assumptions, and safe code paths before any runtime switch.

## 12. Title: Per-Route DB Acquisition Labels

Type: Medium

Why: Pool logs are more actionable when acquisition labels identify the route or backend job.

Where it would apply: app postgres wrapper and backend DB context helpers.

How it could improve the plan: Make future max-client incidents easier to attribute without increasing log volume.
