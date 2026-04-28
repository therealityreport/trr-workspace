# Patches From Original Plan To Revised Plan

These are plan patches, not source-code diffs.

## Patch 1: Add Multi-Repo Ownership

Original issue: the source plan recommended subagent-driven execution but did not specify nested git ownership or staging boundaries.

Replacement: `REVISED_PLAN.md` adds an execution model table for workspace root, `TRR-APP`, `TRR-Backend`, and `screenalytics`, plus mandatory `git status --short` checks before editing.

## Patch 2: Separate Local Pool Pressure From Supavisor Pressure

Original issue: `pool_pressure_snapshot()` implied a backend endpoint could represent overall Supavisor session pressure.

Replacement: `REVISED_PLAN.md` renames the helper to `local_pool_pressure_snapshot()`, adds `"scope": "local_process_pool"`, and requires separate Supabase/Supavisor evidence capture in Phase 0.

## Patch 3: Replace Placeholder Router And Helper Names With Discovery Locks

Original issue: Task 5 said `admin_social_landing.py` "or existing closest admin social router", and Task 7 referenced `scripts/runtime-db-env.sh` "or current helper".

Replacement: Phase 1 makes discovery a blocking step and requires the executor to record the actual router, registration point, runtime DB env helper, and Screenalytics repo state before implementation.

## Patch 4: Validate Backend Burst Needs Before Locking Pool Max

Original issue: lowering the backend general pool to max `2` was correct directionally but could create new backend `PoolError` failures if normal admin burst needs were not tested.

Replacement: Phase 2 adds a backend burst guard requiring at least one normal admin backend route and one social admin route after restart before committing the lower default.

## Patch 5: Tighten Screenalytics `.env` Behavior

Original issue: the source plan said not to load `.env` DB values when disabled, but did not distinguish `.env` values from explicitly exported operator env vars.

Replacement: Phase 7 requires skipping `.env` DB values while preserving pre-existing explicit environment variables.

## Patch 6: Reorder Fan-Out And Migration Work

Original issue: original Tasks 4 and 5 both touched the social landing path and could overlap.

Replacement: Phase 5 first measures and hardens the current app route. Phase 6 then moves only the narrow landing summary reads into backend.

## Patch 7: Defer Transaction-Mode Adoption

Original issue: the plan introduced transaction/direct/session env names but could be read as an invitation to start using transaction mode.

Replacement: Phase 8 explicitly names the lanes while keeping transaction mode unselected until compatibility is proven.

## Patch 8: Make Validation More Targeted

Original issue: some validation commands were broad enough to create unrelated noise during early phases.

Replacement: each phase now lists targeted commands first; broad backend/app sweeps remain in release validation.

## Patch 9: Add Production Capacity Budget Gate

Original issue: the plan claimed local and production coverage but only gave local holder math.

Replacement: `REVISED_PLAN.md` now includes a production session formula and a production rollout gate requiring Supavisor pool size, Postgres `max_connections`, app instance/concurrency caps, backend replica counts, Screenalytics capacity, other session users, and internal-service headroom.

## Patch 10: Require DB-Level Holder Attribution

Original issue: local app/backend pool counters could not prove which global clients were consuming Supavisor sessions.

Replacement: Phase 0 and Phase 4 now require a `pg_stat_activity` snapshot grouped by `application_name`, role, client, and state, plus Dashboard/Grafana evidence before pool-size changes.

## Patch 11: Set `application_name` For Every Runtime

Original issue: logs named the application, but the database itself would still be hard to attribute.

Replacement: Phase 4 requires explicit application names for app, backend named pools, Screenalytics, and scripts, with tests that names are present and secret-free.

## Patch 12: Protect Detailed Pressure Endpoints

Original issue: `/health/db-pressure` exposed detailed topology if implemented literally.

Replacement: Phase 4 splits unauthenticated status-only `/health/db-pressure` from internal/admin detailed pressure endpoints.

## Patch 13: Fix Backend Social Landing Endpoint Contract

Original issue: the plan mixed `/api/v1/admin/socials/landing-summary` with app helper paths.

Replacement: Phase 6 picks one contract: `fetchSocialBackendJson("/landing-summary", ...)` resolves to `GET /admin/socials/landing-summary`.

## Patch 14: Add Task 5B For Remaining Direct SQL

Original issue: the first backend slice moved covered shows and Reddit summary, but left SocialBlade/cast direct SQL in the landing path.

Replacement: Phase 7 requires moving SocialBlade/cast reads behind backend APIs and removing `@/lib/server/postgres` from `social-landing-repository.ts`.

## Patch 15: Define Stale, Partial, And Cache Error Semantics

Original issue: stale-on-error and zeroed optional counts could silently show incorrect data.

Replacement: Phase 5 adds `AdminDataEnvelope<T>` and section-specific rules; Phase 9 forbids caching backend saturation responses as fresh.

## Patch 16: Add App Pressure Diagnostics And Polling Controls

Original issue: backend pressure alone did not cover the app node-postgres pool, and route caching did not address frontend polling.

Replacement: Phase 4 adds app pressure logs and an admin app pressure endpoint; Phase 9 adds one-poller, hidden-tab, backoff, terminal-state, and abort requirements.

## Patch 17: Use Single-Checkout Subagent Orchestration

Original issue: the plan recommended subagent-driven execution but did not explicitly prohibit branch/worktree workflows or define how workers coordinate in one checkout.

Replacement: `REVISED_PLAN.md` now forbids creating or switching branches and forbids additional git worktrees. It adds a subagent orchestration model where the main session owns the current checkout, assigns disjoint write sets, integrates worker patches serially, and runs cross-surface validation at each checkpoint.
