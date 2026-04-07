# TRR Workspace Concerns

## Scope

This document captures notable technical debt, fragility, and operational risk visible in the current workspace state.

The focus is not stylistic preference. These are the areas most likely to create regressions, slowdowns, or coordination failures during future work.

## Concern 1: Cross-Repo Contract Coupling Is High

The workspace has clear ownership rules, but the repos are tightly coupled through shared env names, backend route shapes, DB schema, and trusted-service auth.

Evidence:

- Shared contracts are explicitly documented in `AGENTS.md`
- `TRR-APP` proxies backend admin routes from `TRR-APP/apps/web/src/app/api/admin/trr-api/`
- `screenalytics` shares DB lane resolution and service-token contracts via `screenalytics/apps/api/services/supabase_db.py` and `screenalytics/apps/api/services/trr_ingest.py`

Risk:

- a backend schema or route change can silently break both downstream repos
- cross-repo work requires disciplined sequencing every time

## Concern 2: Large Feature Modules Create Review and Regression Risk

Several high-value modules are very large and appear to centralize a lot of behavior.

Examples:

- `TRR-Backend/api/routers/admin_show_links.py`
- `TRR-Backend/api/routers/admin_brands.py`
- `TRR-Backend/api/routers/admin_show_sync.py`
- `screenalytics/apps/api/routers/episodes.py`
- `TRR-APP/apps/web/src/components/admin/social-week/WeekDetailPageView.tsx`

Risk:

- changes are harder to isolate
- tests may miss edge combinations inside broad files
- onboarding and code review cost rises as files accumulate unrelated logic

## Concern 3: Operational Complexity Is Distributed Across Code and Scripts

The workspace runtime behavior is governed by:

- root `Makefile`
- `scripts/dev-workspace.sh`
- `docs/workspace/env-contract.md`
- repo-local startup code
- Modal/Celery/Vercel specific config

Risk:

- behavior can drift between docs, scripts, and repo-local startup assumptions
- debugging startup issues often requires checking multiple layers before reaching product logic

## Concern 4: Multiple Job Planes Increase Failure Modes

There is not one background-execution model.

Current execution surfaces include:

- Modal in `TRR-Backend/trr_backend/modal_jobs.py`
- backend-side dispatch/recovery in `TRR-Backend/trr_backend/modal_dispatch.py`
- optional Celery/Redis in `screenalytics/apps/api/celery_app.py`
- Vercel cron in `TRR-APP/apps/web/vercel.json`

Risk:

- retry, observability, and ownership semantics vary by subsystem
- failures can be caused by handoff between planes rather than core business logic

## Concern 5: Environment and Secret Contracts Are Safety-Critical

The system relies on a small set of high-impact env vars for database safety and trusted service access.

Examples:

- `TRR_DB_URL`
- `TRR_DB_FALLBACK_URL`
- `TRR_INTERNAL_ADMIN_SHARED_SECRET`
- `SCREENALYTICS_SERVICE_TOKEN`
- `SUPABASE_JWT_SECRET`

Risk:

- misconfiguration can break auth, route access, or runtime database safety
- local and deployed environments can diverge in hard-to-debug ways

Mitigation already present:

- startup validation in `TRR-Backend/api/main.py`
- startup validation in `screenalytics/apps/api/main.py`
- documented env contract in `docs/workspace/env-contract.md`

## Concern 6: Frontend Admin Surface Is Broad and Proxy-Heavy

`TRR-APP` contains a large admin feature set with many app-local proxy routes and server-only helpers.

Examples:

- `TRR-APP/apps/web/src/app/admin/`
- `TRR-APP/apps/web/src/app/api/admin/trr-api/`
- `TRR-APP/apps/web/src/lib/server/trr-api/`

Risk:

- route drift between app-local proxy paths and backend paths
- duplicated translation logic across many route handlers
- permission or trust-boundary mistakes can surface in subtle ways

The repo has strong tests here, but the sheer surface area remains a maintenance burden.

## Concern 7: Screenalytics Carries Heavy Runtime Variability

`screenalytics` supports:

- FastAPI API
- Streamlit UI
- optional Celery workers
- local or S3-compatible storage
- ML-heavy optional dependencies
- v2 APIs behind feature flags

Risk:

- not every combination is exercised equally often
- environment-specific bugs are likely around storage, heavy ML deps, and queue presence
- startup order and optional imports remain a recurring source of fragility

## Concern 8: Migration History Is Extensive

`TRR-Backend/supabase/migrations/` contains a long sequence of historical migrations.

Risk:

- understanding current schema intent requires archaeology
- new contributors can misread deprecated compatibility layers as active design
- drift between migration history, current views, and downstream assumptions can accumulate

This is a normal outcome for a long-lived schema, but it increases planning cost for DB-touching work.

## Concern 9: Browser and Runtime Verification Still Matter for Key Flows

Some important workflows are hard to certify with unit tests alone:

- authenticated admin flows
- route rewrites and deep links
- managed Chrome/browser policy
- Streamlit workspace behavior
- long-running job visibility and progress streaming

Risk:

- a green test run does not fully prove the workspace behaves correctly end to end
- release confidence still depends on targeted manual or browser-tool validation

## Concern 10: Workspace Is Already Changing Frequently

The current root worktree is not clean and includes active changes in scripts, docs, and workspace env tooling.

Risk:

- planning artifacts can become stale quickly
- concurrent workspace-level changes increase merge and coordination cost
- debugging can be confounded by unrelated local modifications

This does not block work, but it means any codebase map should be treated as a point-in-time reference rather than a permanent truth.

## Concern Read

The main risks are not a lack of structure. The workspace is structured, but it is:

- highly integrated across repos
- operationally rich
- dependent on runtime contracts
- heavy on admin/proxy surfaces and background jobs

Future refactors are safest when they preserve the existing boundary model and treat contract drift as the primary failure mode.
