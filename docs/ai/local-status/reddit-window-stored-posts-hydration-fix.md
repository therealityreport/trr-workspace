# Reddit Window Stored Posts Hydration Fix

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

## Problem

The Reddit community season page showed tracked Supabase-backed counts for episode windows, but clicking `View All Posts` could still land on a window page that rendered `0` posts and an empty state.

For RHOSLC Season 6 Episode 1, the community page showed `31 tracked flair posts in window`, while the canonical window page at `/admin/social/reddit/BravoRealHousewives/rhoslc/s6/e1` could still display `No posts found for this window yet.`

## Root Cause

The community page and the window page were using different initial data sources:

- The community page used app-side Postgres-backed stored counts derived from canonical season-window mapping.
- The window page tried the backend analytics posts route first, silently fell through on non-OK responses, and only then hit discovery.

That meant stored Supabase posts could exist and be counted on the community page while the window page still rendered an empty discovery-based fallback.

## Changes

### App-side canonical stored window posts route

Added a new app route:

- `TRR-APP/apps/web/src/app/api/admin/reddit/communities/[communityId]/stored-posts/route.ts`

This route serves canonical stored window posts directly from the app-side Postgres path the community page already trusts.

### App repository helper

Added:

- `getStoredWindowPostsByCommunityAndSeason(...)`

in:

- `TRR-APP/apps/web/src/lib/server/admin/reddit-sources-repository.ts`

This helper:

- resolves canonical container membership with the same SQL used by stored counts
- filters to tracked-flair posts for the requested canonical container
- returns paginated stored posts for direct window hydration

### Window page behavior

Updated:

- `TRR-APP/apps/web/src/app/admin/reddit-window-posts/page.tsx`

New load order for non-refresh page loads:

1. app-side stored window posts
2. backend analytics posts cache
3. live discovery fallback

Also hardened the UX so failed cache loads are no longer swallowed silently before falling back.

### Community-page copy improvement

Updated:

- `TRR-APP/apps/web/src/components/admin/reddit-sources-manager.tsx`

When a window has tracked posts but no linked discussion threads, the page now says that tracked flair posts are still available via `View All Posts`, which better matches what the user sees.

## Validation

- `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec eslint src/lib/server/admin/reddit-sources-repository.ts 'src/app/api/admin/reddit/communities/[communityId]/stored-posts/route.ts' src/app/admin/reddit-window-posts/page.tsx src/components/admin/reddit-sources-manager.tsx tests/reddit-window-posts-page.test.tsx tests/reddit-community-stored-posts-route.test.ts`
- `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec vitest run tests/reddit-window-posts-page.test.tsx tests/reddit-community-stored-posts-route.test.ts`
- `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec next build --webpack`

All passed.

## Notes

Live Supabase checks during debugging confirmed Episode 1 still has canonical tracked posts stored for Season 6, so this was a page hydration mismatch rather than missing Reddit sync data.
