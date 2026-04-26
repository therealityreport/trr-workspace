# Social Profile Dashboard

The social account profile page now loads through one backend-owned dashboard contract.

## Routes

- Backend route: `GET /api/v1/admin/socials/profiles/{platform}/{handle}/dashboard`
- App compatibility route: `GET /api/admin/trr-api/social/profiles/{platform}/{handle}/snapshot`

The app route keeps the existing snapshot envelope for `SocialAccountProfilePage`, but it proxies the backend dashboard endpoint instead of stitching summary and progress reads itself. Rollback starts at the app snapshot route: restore the previous summary/progress composition there if the backend dashboard endpoint must be bypassed.

## Freshness States

- `fresh`: live backend data was loaded and cached normally.
- `stale`: the app snapshot cache served last-good dashboard data after a backend refresh failed or timed out.
- `missing`: no dashboard summary exists for this account yet.
- `error`: cached data is usable, but the last dashboard refresh failed.

Admins should treat stale data as degraded, not failed. The page should still show profile totals and recent catalog state while diagnostics retry separately.

## Initial Render Budget

Initial render is allowed to issue:

- One `/snapshot` request.
- No `/summary` request after a successful dashboard summary.
- No posts, comments, hashtags, SocialBlade, gap-analysis, or freshness diagnostics requests.

Posts, comments, hashtags, SocialBlade, and catalog diagnostics should load only when the user opens the relevant tab or requests the diagnostic action.

## Diagnostics

Open catalog diagnostics when profile totals and catalog totals disagree, when a catalog action fails, or when an active run needs inspection. Diagnostics are optional panels; they must not decide whether the stats page is usable.

## Dogpile Checks

Use browser network inspection on `http://admin.localhost:3000/social/instagram/thetraitorsus` and reload the stats tab. The initial burst should contain exactly one social profile `/snapshot` request and zero initial `/summary`, `/posts`, `/comments`, `/hashtags`, or `/gap-analysis` requests.

The app snapshot route also emits `social_profile_dashboard_budget` with `initialRequestCount`, `cacheStatus`, `freshnessStatus`, `stale`, `cacheAgeMs`, and `staleCacheHit`. There is no metrics counter yet; use this structured log until dashboard telemetry is promoted into a shared metrics helper.

## Query Plan Prep

Index work is intentionally deferred. Capture query-plan evidence first:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python scripts/db/social_profile_dashboard_explain.py --platform instagram --handle thetraitorsus --dry-run
```

Live EXPLAIN output is written under `TRR-Backend/tmp/social-profile-dashboard-explain/` and exits nonzero if an obvious large-table sequential scan is detected.
