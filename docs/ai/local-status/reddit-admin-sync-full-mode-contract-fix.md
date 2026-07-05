# Reddit Admin sync_full mode contract fix

Last updated: 2026-03-30

## Handoff Snapshot
```yaml
handoff:
  include: false
  state: archived
  last_updated: 2026-03-30
  current_phase: "archived continuity note"
  next_action: "Refer to newer status notes if follow-up work resumes on this thread."
  detail: self
```

## Problem

The Reddit admin season page at `http://admin.localhost:3000/admin/social/reddit/BravoRealHousewives/rhoslc/s6` showed repeated `Failed to start reddit refresh run` errors after the episode-discussion auto-sync step succeeded.

## Root Cause

`TRR-APP` starts per-window refresh runs with `mode: "sync_full"` from the community discover route, but the FastAPI `RedditRefreshRunRequest` schema in `TRR-Backend` only accepted `"sync_posts"` and `"sync_details"`.

That schema mismatch caused the backend to reject valid full-sync run requests before any refresh run could be created, which surfaced in the UI as the generic kickoff failure.

## Changes

- Updated `TRR-Backend/api/routers/socials.py` so `RedditRefreshRunRequest.mode` accepts `"sync_full"` in addition to the existing modes.
- Added a regression test in `TRR-Backend/tests/api/routers/test_socials_reddit_refresh_routes.py` that posts a `sync_full` run request and asserts the backend forwards that mode into refresh-run creation.

## Evidence

- `TRR-APP/apps/web/src/app/api/admin/reddit/communities/[communityId]/discover/route.ts` posts `mode: effectiveMode`, and the affected flow sets that to `sync_full`.
- `TRR-Backend/trr_backend/repositories/reddit_refresh.py` already contains explicit `sync_full` execution behavior, so the failure was at request validation, not execution logic.

## Validation

- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/api/routers/test_socials_reddit_refresh_routes.py`
