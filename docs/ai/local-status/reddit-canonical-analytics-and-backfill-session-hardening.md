# Reddit Canonical Analytics and Backfill Session Hardening

Date: 2026-03-26
Workspace: `/Users/thomashulihan/Projects/TRR`

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: active
  last_updated: 2026-03-26
  current_phase: "implementation complete"
  next_action: "optional deploy and live verification of async reddit backfill session UX"
  detail: self
```

## Summary

Implemented Phase 1 and Phase 2 of the follow-on Reddit analytics hardening pass:

- season Reddit analytics now scope recovery/freshness/coverage to canonical season containers only
- stale-window backfill now runs as an async admin operation instead of inline request fanout

## What Changed

### Backend

- Added canonical season-container helpers in `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/reddit_refresh.py`
  - canonical keys now resolve to `period-preseason`, `episode-*`, and `period-postseason`
  - season analytics coverage queries now filter `social.reddit_period_post_matches` to canonical container keys only
  - latest run freshness/container status now use canonical latest runs only
  - missing canonical windows now surface as `stale_reason_code = no_previous_run`
- Added async Reddit backfill operation producer in `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/reddit_refresh.py`
  - operation type: `admin_reddit_refresh_backfill`
  - sequentially kicks off stale windows and waits for each run to reach a terminal state before moving on
  - emits progress/complete payloads through `core.admin_operations`
- Replaced synchronous backfill kickoff in `/Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/socials.py`
  - `POST /api/v1/admin/socials/reddit/runs/backfill` now returns an admin-operation envelope immediately
- Registered the new admin-operation type for remote execution in:
  - `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/pipeline/admin_operations.py`
  - `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/modal_dispatch.py`

### App

- Updated `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/api/admin/reddit/runs/backfill/route.ts`
  - now forwards tab-session / flow-key headers to backend so repeated clicks can attach to the same backfill session
- Updated `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/components/admin/reddit-sources-manager.tsx`
  - canonical-only client filtering for Reddit container statuses
  - backfill button now starts or attaches to an async admin operation
  - polls `/api/admin/trr-api/operations/:id` for live recovery progress
  - applies started/current run payloads back into the existing per-window progress UI
  - recovery card now reflects active recovery-session progress instead of stale noncanonical latest-run metadata

## Validation

- `./.venv/bin/ruff check api/routers/socials.py trr_backend/repositories/reddit_refresh.py trr_backend/pipeline/admin_operations.py trr_backend/modal_dispatch.py tests/api/routers/test_socials_reddit_refresh_routes.py tests/repositories/test_reddit_refresh.py tests/test_modal_dispatch.py`
- `./.venv/bin/pytest -q tests/api/routers/test_socials_reddit_refresh_routes.py tests/repositories/test_reddit_refresh.py tests/test_modal_dispatch.py`
  - `73 passed in 1.41s`
- `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec eslint src/app/api/admin/reddit/runs/backfill/route.ts src/components/admin/reddit-sources-manager.tsx tests/reddit-sources-manager.test.tsx`
- `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec vitest run tests/reddit-sources-manager.test.tsx`
  - `46 passed`

## Notes

- This pass did not deploy changes.
- The next practical verification step is to reload the Reddit analytics page locally and confirm:
  - recovery cards sum to canonical season windows only
  - `Rerun Stale Windows` returns quickly and shows session progress instead of hanging the POST request
