# Multi-Browser Admin Polling Optimization

Date: 2026-04-08
Workspace: `/Users/thomashulihan/Projects/TRR`
Repo focus: `TRR-APP`

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: active
  last_updated: 2026-04-08
  current_phase: "first shared-read rollout landed; broader polling snapshot migration remains open"
  next_action: "finish the remaining snapshot routes, client migrations, and invalidation wiring, then run broader TRR-APP validation once unrelated dirty changes are isolated"
  detail: self
```

## Summary

Implemented the first shared-read rollout for multi-browser admin polling in `TRR-APP`:

- added a server-side admin snapshot cache with TTL, in-flight dedupe, stale-if-error fallback, and invalidation
- converted the social live-status route into a cached snapshot surface with freshness metadata
- added snapshot routes for:
  - season social analytics
  - week social status
  - social account profile
- moved the heaviest repeating UI reads onto shared snapshot fetches for:
  - `SeasonSocialAnalyticsSection`
  - `WeekDetailPageView`
  - `SocialAccountProfilePage`

This reduces backend fanout across multiple browsers/pages by sharing reads inside the Next.js server and, for the migrated client loops, inside the browser via `useSharedPollingResource`.

## Files Changed In This Pass

- `TRR-APP/apps/web/src/lib/server/admin/admin-snapshot-cache.ts`
- `TRR-APP/apps/web/src/lib/server/admin/admin-snapshot-route.ts`
- `TRR-APP/apps/web/src/app/api/admin/trr-api/social/ingest/live-status/route.ts`
- `TRR-APP/apps/web/src/app/api/admin/trr-api/shows/[showId]/seasons/[seasonNumber]/social/analytics/snapshot/route.ts`
- `TRR-APP/apps/web/src/app/api/admin/trr-api/shows/[showId]/seasons/[seasonNumber]/social/analytics/week/[weekIndex]/snapshot/route.ts`
- `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/snapshot/route.ts`
- `TRR-APP/apps/web/src/components/admin/season-social-analytics-section.tsx`
- `TRR-APP/apps/web/src/components/admin/social-week/WeekDetailPageView.tsx`
- `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`
- `TRR-APP/apps/web/tests/admin-snapshot-cache.test.ts`
- `TRR-APP/apps/web/tests/social-live-status-route.test.ts`
- `TRR-APP/apps/web/tests/season-social-analytics-polling-wiring.test.ts`
- `TRR-APP/apps/web/tests/social-week-worker-health-polling-wiring.test.ts`

## Validation

Ran:

- `pnpm -C TRR-APP/apps/web exec vitest run -c vitest.config.ts tests/admin-snapshot-cache.test.ts tests/social-live-status-route.test.ts tests/season-social-analytics-polling-wiring.test.ts tests/social-week-worker-health-polling-wiring.test.ts`
- targeted ESLint on the touched snapshot/cache/client files

Results:

- focused tests passed
- focused ESLint passed with no errors after cleanup

## Remaining Gaps

The full plan is only partially implemented in this pass.

Still pending:

- reddit sources manager snapshot route and client migration
- cast socialblade comparison snapshot route and client migration
- dedicated mutation-triggered invalidation wiring for all snapshot families
- broader use of snapshot routes during primary bootstrap/manual refresh flows, not just the heaviest repeating loops
- full repo-wide `TRR-APP` validation (`lint`, `typecheck`, `build`, `test:ci`) once the unrelated dirty app changes are isolated

## Notes

- `TRR-APP` already had many unrelated modified/untracked files before and during this pass; only the files listed above were intentionally changed for this polling optimization.
- Root workspace/backend files from the earlier backend pool and `health-dot` hardening work remain dirty separately from this app-side change.
