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

## Instagram Comments Summary Contract

`summary.comments_saved_summary` is the shared contract for Instagram comments totals on the top cards, comments tab, lite header stats, and detail rollups.

- `reported_comments`: total comments reported by stored Instagram post details before subtracting known external surfaces.
- `external_facebook_comments`: known Facebook-side comments attached to Instagram/Facebook crossposts. These remain visible, but they are not Instagram scrape debt.
- `instagram_fetchable_comments`: expected Instagram comments that the scraper can still target. Formula: `max(reported_comments - external_facebook_comments, 0)`.
- `active_saved_comment_rows`: active rows in `social.instagram_comments`; this is Instagram-only captured comment storage and must not include Facebook comments.
- `classified_missing_comments`: Instagram comments already classified as unavailable or terminally missing, so they are accounted outside active scrape debt.
- `accounted_instagram_comments`: captured plus classified Instagram comments. Formula: `active_saved_comment_rows + classified_missing_comments`.
- `comment_gap`: remaining Instagram scrape gap. Formula: `max(instagram_fetchable_comments - accounted_instagram_comments, 0)`.
- `latest_post_detail_scraped_at`: newest stored post-detail scrape timestamp that can move the expected total.
- `latest_comment_saved_at`: newest comment-row save timestamp.
- `latest_comment_seen_at`: newest observed Instagram comment timestamp in active saved rows.
- `saved_comments` and `retrieved_comments`: compatibility aliases only. New UI should read the explicit fields above.

The gap can rise during a healthy refresh. Post-detail scraping updates expected Instagram totals first; comment scraping then reduces `comment_gap` as rows are saved or classified.

## Initial Render Budget

Initial render is allowed to issue:

- One `/snapshot` request.
- No `/summary` request after a successful dashboard summary.
- No posts, comments, hashtags, SocialBlade, gap-analysis, or freshness diagnostics requests.

Posts, comments, hashtags, SocialBlade, and catalog diagnostics should load only when the user opens the relevant tab or requests the diagnostic action.

## Diagnostics

Open catalog diagnostics when profile totals and catalog totals disagree, when a catalog action fails, or when an active run needs inspection. Diagnostics are optional panels; they must not decide whether the stats page is usable.

## Dogpile Checks

Use the shared Portless URL runbook in `docs/workspace/portless-clean-urls.md`,
then inspect `https://admin.trr.localhost/social/instagram/thetraitorsus` and
reload the stats tab. The initial burst should contain exactly one social
profile `/snapshot` request and zero initial `/summary`, `/posts`, `/comments`,
`/hashtags`, or `/gap-analysis` requests.

The app snapshot route also emits `social_profile_dashboard_budget` with `initialRequestCount`, `cacheStatus`, `freshnessStatus`, `stale`, `cacheAgeMs`, and `staleCacheHit`. There is no metrics counter yet; use this structured log until dashboard telemetry is promoted into a shared metrics helper.

## Query Plan Prep

Index work is intentionally deferred. Capture query-plan evidence first:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python scripts/db/social_profile_dashboard_explain.py --platform instagram --handle thetraitorsus --dry-run
```

Live EXPLAIN output is written under `TRR-Backend/tmp/social-profile-dashboard-explain/` and exits nonzero if an obvious large-table sequential scan is detected.
