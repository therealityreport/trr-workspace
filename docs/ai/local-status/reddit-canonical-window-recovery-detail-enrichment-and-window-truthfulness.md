# Reddit Canonical Window Recovery, Detail Enrichment, and Window-Page Truthfulness

Last updated: 2026-03-30
Workspace: `/Users/thomashulihan/Projects/TRR`

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

## Summary

Implemented the canonical-window truthfulness pass for Reddit season analytics:

- season summaries, flair filters, and analytics posts now share one canonical container interpretation
- `Enrich Missing Detail` now starts a real detail-refresh async session even when no windows are stale
- the window detail page now loads stored Supabase-backed analytics posts before falling back to live discovery

## What Changed

### Backend

- Updated `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/reddit_refresh.py`
  - added canonical season-window remapping for analytics queries
  - direct canonical keys and stable `container:*` keys still resolve directly
  - legacy `window:*` rows now remap into canonical windows using contained period bounds or `posted_at`
  - season analytics coverage/freshness now scope to canonical windows only
  - additive diagnostics now include:
    - `coverage.scope`
    - `coverage.unmapped_post_count`
    - `coverage.unmapped_tracked_post_count`
    - `freshness.latest_canonical_run_timestamp`
  - detail-refresh target selection now uses coverage gaps, not only stale windows

### App

- Updated `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/admin/reddit-sources-repository.ts`
  - stored counts, flair pills, pending counts, and detail-slug resolution now use canonical remapping instead of only parsing `container:*`
- Added `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/api/admin/reddit/analytics/community/[communityId]/posts/route.ts`
  - app proxy for canonical analytics posts
- Updated `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/components/admin/reddit-sources-manager.tsx`
  - `Enrich Missing Detail` is no longer blocked by stale-window count
  - detail-refresh sessions use detail-specific labels/messages
  - analytics summary continues refreshing after the operation completes
- Updated `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/admin/reddit-window-posts/page.tsx`
  - initial load now uses stored analytics posts for the canonical window
  - discovery remains the source for explicit `Sync Posts` and no-stored-post fallback

## Validation

- `TRR-Backend/.venv/bin/ruff check TRR-Backend/trr_backend/repositories/reddit_refresh.py TRR-Backend/api/routers/socials.py TRR-Backend/tests/repositories/test_reddit_refresh.py TRR-Backend/tests/api/routers/test_socials_reddit_refresh_routes.py`
- `TRR-Backend/.venv/bin/ruff format --check TRR-Backend/trr_backend/repositories/reddit_refresh.py TRR-Backend/tests/repositories/test_reddit_refresh.py TRR-Backend/tests/api/routers/test_socials_reddit_refresh_routes.py`
- `TRR-Backend/.venv/bin/pytest -q TRR-Backend/tests/repositories/test_reddit_refresh.py TRR-Backend/tests/api/routers/test_socials_reddit_refresh_routes.py`
  - `69 passed in 1.69s`
- `pnpm -C TRR-APP/apps/web exec eslint 'src/app/api/admin/reddit/analytics/community/[communityId]/posts/route.ts' src/app/admin/reddit-window-posts/page.tsx src/components/admin/reddit-sources-manager.tsx src/lib/server/admin/reddit-sources-repository.ts tests/reddit-analytics-posts-route.test.ts tests/reddit-window-posts-page.test.tsx tests/reddit-sources-manager.test.tsx`
- `pnpm -C TRR-APP/apps/web exec vitest run tests/reddit-analytics-posts-route.test.ts tests/reddit-window-posts-page.test.tsx tests/reddit-sources-manager.test.tsx`
  - `56 passed`
- `pnpm -C TRR-APP/apps/web exec next build --webpack`

## Notes

- This pass did not deploy.
- The working tree already had many unrelated changes before this session; I left them alone.
- The next practical verification step is to reload:
  - `http://admin.localhost:3000/admin/social/reddit/BravoRealHousewives/rhoslc/s6`
  - `http://admin.localhost:3000/admin/social/reddit/BravoRealHousewives/rhoslc/s6/e1`
