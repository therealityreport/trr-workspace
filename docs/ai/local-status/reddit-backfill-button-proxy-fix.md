# Reddit Backfill Button Proxy Fix

Date: 2026-03-26
Workspace: `/Users/thomashulihan/Projects/TRR`

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: active
  last_updated: 2026-03-26
  current_phase: "button proxy fix complete"
  next_action: "reload the Reddit analytics page and verify Rerun Stale Windows starts or attaches to the backfill operation"
  detail: self
```

## Summary

Fixed the `Rerun Stale Windows` app route so it uses the shared social-admin proxy instead of a one-off raw fetch path. This makes the button inherit the standard backend auth fallback, retry policy, trace handling, and structured upstream error normalization.

## What Changed

- Updated `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/api/admin/reddit/runs/backfill/route.ts`
  - switched the route to `fetchSocialBackendJson("/reddit/runs/backfill", ...)`
  - preserved `x-trr-request-id`, `x-trr-tab-session-id`, and `x-trr-flow-key` forwarding
  - removed custom error parsing that collapsed object-shaped backend failures into the generic `Failed to backfill reddit refresh runs`
- Added `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/tests/reddit-runs-backfill-route.test.ts`
  - verifies validated payload forwarding
  - verifies session/request headers are forwarded
  - verifies proxy-standardized error handling on backend failure

## Validation

- `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec eslint src/app/api/admin/reddit/runs/backfill/route.ts tests/reddit-runs-backfill-route.test.ts tests/reddit-sources-manager.test.tsx`
- `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec vitest run tests/reddit-runs-backfill-route.test.ts tests/reddit-sources-manager.test.tsx`
  - `49 passed`

## Notes

- This pass only changed the app proxy path; no backend code or deployment was required.
- Closeout may still report the unrelated workspace policy blocker for `/Users/thomashulihan/Projects/TRR/AGENTS.md` word count.
