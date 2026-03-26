# Supavisor session mode and egress reduction rollout

Last updated: 2026-03-26

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-26
  current_phase: "batches through 2.4 are completed, with Batch 2.4 closed as a summary-only lane; Phase 2 should not be described as fully complete end-to-end because later mixed-ownership families remain in later lanes"
  next_action: "keep later mixed-ownership route families tracked as later lanes, not as retroactive failures of the completed batches through 2.4"
  detail: self
```

## Confirmed March 24 root cause

- Shared Pooler Egress spiked through the Supabase pooled database path.
- The primary self-inflicted drivers were app-side polling loops repeatedly reloading large admin datasets.
- The clearest runtime evidence came from archived app logs:
  - `20260324-062242`: `1007` person gallery requests hitting `/api/admin/trr-api/people/.../photos?limit=500`
  - `20260324-182329`: `598` person gallery requests hitting the same gallery endpoint
  - `20260324-225258`: `654` social summary requests hitting `/api/admin/trr-api/social/profiles/.../summary`

## Exact files patched in this rollout

### Batch 1 admin read boundary cutover

- `TRR-Backend/api/auth.py`
  - added `require_internal_admin(...)` plus `InternalAdminUser` so app proxy routes can authenticate backend admin reads with service role + shared secret
- `TRR-Backend/api/main.py`
  - mounted the new batch-1 admin read routers
- `TRR-Backend/api/routers/admin_covered_shows.py`
  - added backend-owned covered-shows list/detail endpoints
  - added in-process TTL cache, route-level payload/latency/query-count logging, and cache invalidation endpoint
- `TRR-Backend/api/routers/admin_people_reads.py`
  - added backend-owned resolve-slug, person detail, cover-photo GET, and gallery endpoints
  - added per-surface TTL caches, route-level payload/latency/query-count logging, and person cache invalidation endpoint
- `TRR-Backend/trr_backend/repositories/covered_shows.py`
  - added explicit-projection covered-shows queries with no `SELECT *`
- `TRR-Backend/trr_backend/repositories/admin_people_reads.py`
  - added explicit-projection person detail / cover-photo / gallery queries
  - gallery path stays capped at two queries and strips raw/debug metadata from the default list payload
  - fixed the `people_count=0` media-link edge case without increasing query count
- `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts`
  - added shared backend admin read proxy helper
  - added proxy latency logging and backend cache invalidation helper
- `TRR-APP/apps/web/src/app/api/admin/covered-shows/route.ts`
  - GET now proxies to backend covered-shows list
  - POST now busts both app cache and backend cache
- `TRR-APP/apps/web/src/app/api/admin/covered-shows/[showId]/route.ts`
  - GET now proxies to backend covered-shows detail
  - DELETE now busts both app cache and backend cache
- `TRR-APP/apps/web/src/app/api/admin/trr-api/people/resolve-slug/route.ts`
  - GET now proxies to backend resolve-slug and preserves the routed response contract
- `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/route.ts`
  - GET now proxies to backend person detail
  - PATCH now busts both app and backend person-read caches
- `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/cover-photo/route.ts`
  - GET now proxies to backend cover-photo read
  - PUT/DELETE now bust both app and backend person-read caches
- `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/photos/route.ts`
  - GET now proxies to backend gallery page read and preserves page-local pagination metadata
- `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/external-ids/route.ts`
  - write path now busts both app and backend person-detail cache
- `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/photos/[photoId]/thumbnail-crop/route.ts`
  - write path now busts both app and backend person gallery cache
- `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/import-fandom/commit/route.ts`
  - commit path now busts both app and backend person gallery cache

### Runtime DB path switch

- `TRR-APP/apps/web/.env.local`
- `TRR-Backend/.env`
- `screenalytics/.env`

All active local runtime DB URLs that still pointed at Supavisor transaction mode `:6543` were switched to Supavisor session mode `:5432`.

### App egress reductions

- `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/photos/route.ts`
  - Route now fetches `limit + 1` internally and returns `pagination.has_more` plus `pagination.next_offset`.
  - Route now adds short user-scoped response caching and in-flight dedupe so repeated page loads do not stampede direct SQL.
- `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`
  - Person gallery no longer auto-walks the full photo dataset on normal refreshes.
  - Gallery loads page-by-page with a smaller default server page size.
  - "Load More" now escalates from showing already-loaded rows to explicitly loading the next server page.
- `TRR-APP/apps/web/src/lib/admin/paginated-gallery-fetch.ts`
  - Default page size lowered from `500` to `120`.
- `TRR-APP/apps/web/src/app/admin/networks/page.tsx`
  - Background summary polling was throttled from `3500ms` to `15000ms`.
  - Polling now pauses while the tab is hidden.
- `TRR-APP/apps/web/src/lib/server/admin/route-response-cache.ts`
  - Added shared in-flight promise dedupe for admin route caches so concurrent cold misses collapse to one upstream load.
- `TRR-APP/apps/web/src/app/api/admin/covered-shows/route.ts`
  - Covered-shows route now uses in-flight dedupe on cold cache misses.
- `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/summary/route.ts`
  - Added short app-side cache plus in-flight dedupe in front of the backend proxy path.
- `TRR-APP/apps/web/src/lib/server/postgres.ts`
  - Session-mode pool defaults stay small, transient `MaxClientsInSessionMode` faults are retryable, and default direct-SQL concurrency is reduced to one operation at a time while the app is pointed at Supavisor session mode.
- `TRR-APP/apps/web/src/lib/server/trr-api/trr-shows-repository.ts`
  - Person gallery page 1 now tries direct paged person-linked rows first and delays the expensive person-name lookup until fandom ownership filtering or the broad fallback path actually needs it.
- `TRR-APP/apps/web/src/components/admin/social-week/WeekDetailPageView.tsx`
  - Removed idle manual-attach run candidate polling; that surface is now one-shot/manual instead of forever polling in an open tab.

### Backend payload narrowing

- `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
  - Social account summary analysis rows now use a summary projection instead of `p.*`.
  - Summary analysis keeps the scalar fields and arrays the UI needs, plus a reduced `raw_data` subset for identity reconstruction.
  - Full-row reads remain available to detail and search paths through the default `detail` projection.
- `TRR-Backend/trr_backend/db/pg.py`
  - Session-mode psycopg pool defaults were reduced again to `minconn=1` and `maxconn=2`.
- `TRR-Backend/api/routers/admin_show_news.py`
  - Show-name helper no longer does `SELECT *` on `core.shows`.

## Env resolution surfaces verified

- `TRR-APP/apps/web/src/lib/server/postgres.ts`
  - Connection candidate order remains `DATABASE_URL`, `SUPABASE_DB_URL`, `TRR_DB_URL`.
  - No connection-order bug was introduced by the port swap.
- `TRR-APP/scripts/auto-categorize-flairs.ts`
  - Script still inherits the same DB env precedence and does not need code changes for the `:5432` move.

## Backend DB resolution fix

### Exact backend resolution order

- Runtime DB resolution for `TRR-Backend` is centralized in `TRR-Backend/trr_backend/db/connection.py`.
- Local `make dev` loads `TRR-Backend/.env`; there was no workspace-script hostname rewrite in front of the backend process.
- Active resolution order after the fix is:
  1. `SUPABASE_DB_URL`
  2. `TRR_DB_FALLBACK_URL`
  3. `DATABASE_URL`
  4. `TRR_DB_URL`
  5. optional local `supabase status --output env` fallback
- Auto-derived direct-host fallback is no longer part of the default runtime path.
- Direct-host fallback now requires explicit opt-in via `TRR_DB_ENABLE_DIRECT_FALLBACK=1`.

### Actual host class before the fix

- Runtime log / stack traces showed the backend attempting:
  - host class: `direct`
  - host: `db.vwxfvzutyufrkhfgoeaa.supabase.co`
  - port: `5432`
- The bad selection came from `resolve_database_url_candidates(...)` auto-appending direct-host candidates for pooler URLs and the pool builder eventually attempting that derived candidate.

### Actual host class after the fix

- Startup now logs the selected DB target without credentials:
  - `winner_source=SUPABASE_DB_URL`
  - `host_class=pooler`
  - `host=aws-1-us-east-1.pooler.supabase.com`
  - `port=5432`
  - `direct_fallback_enabled=False`
- Pool init logs now also show the active target class during connection attempts:
  - `[db-pool] init_attempt=0 source=SUPABASE_DB_URL host_class=pooler host=aws-1-us-east-1.pooler.supabase.com port=5432`

### Exact files changed for the resolution fix

- `TRR-Backend/trr_backend/db/connection.py`
  - added candidate metadata / host-class helpers
  - removed default auto-promotion from pooler URLs to `db.<project>.supabase.co`
  - made direct fallback opt-in only through `TRR_DB_ENABLE_DIRECT_FALLBACK`
  - added safe startup diagnostics for winning env var, host class, host, and port
- `TRR-Backend/trr_backend/db/pg.py`
  - pool init now logs candidate source / host class / host / port on attempt, success, and failure
- `TRR-Backend/api/main.py`
  - startup validation now emits the DB target summary
- `TRR-Backend/tests/db/test_connection_resolution.py`
  - updated for the new default candidate order and explicit direct-fallback opt-in behavior
- `TRR-Backend/tests/db/test_pg_pool.py`
  - updated pool-init tests to the candidate-detail seam used by the runtime

## Session lifecycle hardening and person-detail fix

- `TRR-Backend/trr_backend/repositories/admin_people_reads.py`
  - removed the invalid `alternative_names` projection from `core.people`
  - person-detail now `LEFT JOIN`s `core.cast_tmdb` and sources `alternative_names` from `core.cast_tmdb.also_known_as`
  - fallback for missing TMDb aliases is now `alternative_names: []`, preserving the app response field while keeping `core.people` unchanged
- `TRR-Backend/trr_backend/db/pg.py`
  - added pool creation / checkout / return diagnostics, including acquire time, hold time, backend pid, transaction status, and pool in-use / available counts
  - standalone read helpers now use `db_read_connection()` / `db_read_cursor()` with autocommit so read-only admin paths do not leave pooled sessions `idle in transaction`
  - pooled connections are now sanitized on checkout and again before return; dirty connections are rolled back or discarded instead of silently re-entering the pool
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
  - narrowed three concrete long-lived connection scopes that held a DB session open across non-SQL work:
    - YouTube details refresh now resolves source media before opening the write transaction and only uses a connection for the actual update/enqueue work
    - Facebook post sync now fetches comments before opening the write transaction
    - Threads post sync now fetches comments before opening the write transaction
  - added cached `_list_matchable_seasons(...)` construction so repeated hashtag/review flows do not refetch season context and targets for every season on every call
- `TRR-Backend/trr_backend/db/pg.py`
  - pool connections now set `idle_in_transaction_session_timeout=60000` by default so leaked sessions cannot remain open indefinitely from this runtime

### Current runtime evidence

- Direct person-detail SQL now succeeds against live schema when selecting:
  - `id`, `full_name`, `known_for`, `external_ids`, `birthday`, `gender`, `biography`, `place_of_birth`, `homepage`, `profile_image_url`
  - `alternative_names` from `core.cast_tmdb.also_known_as`
- Full six-route local smoke after the person-detail and gallery fixes is green through both backend endpoints and app proxies:
  - backend direct:
    - covered-shows list: `200`, cold `617.2ms`, warm `3.0ms`
    - covered-shows detail: `200`, cold `43.0ms`, warm `2.1ms`
    - resolve-slug: `200`, cold `141.6ms`, warm `1.7ms`
    - person detail: `200`, cold `57.4ms`, warm `2.1ms`
    - cover-photo GET: `200`, cold `46.3ms`, warm `2.0ms`
    - gallery GET: `200`, cold `1655.9ms`, warm `7.7ms`, payload `139816` bytes
  - app proxy:
    - covered-shows list: `200`, cold `94.8ms`, warm `8.1ms`, warm `x-trr-cache=hit`
    - covered-shows detail: `200`, cold `922.2ms`, warm `13.2ms`
    - resolve-slug: `200`, cold `44.9ms`, warm `8.2ms`, warm `x-trr-cache=hit`
    - person detail: `200`, cold `626.5ms`, warm `10.6ms`, warm `x-trr-cache=hit`
    - cover-photo GET: `200`, cold `579.7ms`, warm `10.1ms`, warm `x-trr-cache=hit`
    - gallery GET: `200`, cold `605.4ms`, warm `9.7ms`, warm `x-trr-cache=hit`
- Pool diagnostics for the migrated GET routes show clean lifecycle:
  - every logged batch-1 checkout returned with `tx_status=idle`
  - backend route logs emitted expected query counts:
    - covered-shows list/detail: `query_count=1` cold, `0` warm
    - resolve-slug: `query_count=2` cold, `0` warm
    - person detail: `query_count=1` cold, `0` warm
    - cover-photo GET: `query_count=1` cold, `0` warm
    - gallery GET: `query_count=2` cold, `0` warm
- Residual `idle in transaction` sessions still appear, but they are isolated away from the migrated local admin reads:
  - local backend logs show no corresponding social analytics HTTP traffic when the idle-session burst happens
  - the leaked sessions in `pg_stat_activity` use remote client address `2600:1f18:2e13:9d00:dca1:6157:cc55:d8be`, not the local dev runtime
  - the leaked query texts still map to `social_season_analytics.py` season-context / targets / shared-catalog paths (`select e.air_date ...`, `select s.id::text as season_id ...`, `select t.season_id::text as season_id ...`, `BEGIN`)
  - this is consistent with the remote Modal social lane continuing to run older social analytics code against the same database while local `make dev` admin reads stay clean
- Remote leak source was confirmed and cut over:
  - exact runtime: Modal app `trr-backend-jobs` in environment `main`
  - stale deployment before fix: `v100`, commit metadata `417aed7*`, but container inspection showed it was missing local uncommitted transaction/cache hardening and still had `SUPABASE_DB_URL=...pooler.supabase.com:6543`
  - fixed deployment after cutover: `v101`, same commit metadata `417aed7*`, but fresh container inspection confirmed the working-tree code was deployed:
    - `/root/trr_backend/db/pg.py` contains `db_read_connection` and `idle_in_transaction_session_timeout`
    - `/root/trr_backend/repositories/social_season_analytics.py` contains `_get_season_context_cached`, `_get_targets_cached`, and `_list_matchable_seasons_cached`
    - fresh container env now has `SUPABASE_DB_URL=...pooler.supabase.com:5432`
  - stale pre-`v101` containers were stopped after the redeploy so only the fixed runtime remains
  - before action, repeated snapshots showed `7` to `14` `idle in transaction` sessions with the leaked social analytics query texts above
  - after secret refresh, redeploy, and stale-container stop, repeated `pg_stat_activity` snapshots during the observation window showed `idle_in_tx_count=0` and no reappearance of those query texts
- Monitoring window after the cutover stayed clean:
  - repeated `pg_stat_activity` snapshots at `2026-03-26 02:01:58+00` and `2026-03-26 02:05:52+00` both showed `idle_in_tx_count=0`
  - no prior leaked query texts reappeared
  - active Modal containers remained on the post-fix deployment wave only (fresh starts from `2026-03-25 21:39:33-04:00` onward, plus one newer `22:00:09-04:00` container)
  - fresh container env inspection still showed `SUPABASE_DB_URL=...pooler.supabase.com:5432`
  - repo-wide `.env` search found no remaining `:6543` references in active local env surfaces
  - `social.scrape_workers` shows the Modal dispatchers alive and heartbeating (`modal:social-dispatcher`, `modal:reddit-dispatcher`, `modal:google-news-dispatcher`, `modal:admin-dispatcher`)
  - `social.scrape_jobs` did not show a new pileup during the observation window; last-24h status mix remained light (`completed=1`, `retrying=1`)

## Batch 1 completion summary

- Root cause chain:
  - March 24 shared-pooler egress spike was primarily caused by app-side polling loops repeatedly pulling oversized admin datasets through Supabase pooled DB traffic.
  - Switching the active local runtimes from `:6543` to `:5432` exposed additional admin read fragility and stale direct-SQL ownership boundaries in TRR-APP.
  - After batch-1 route migration and local pool hardening, the remaining `idle in transaction` churn was traced to a stale remote Modal social worker still running older code and the old `:6543` DSN.
- Batch-1 scope:
  - moved covered-shows list/detail, resolve-slug, person detail, cover-photo GET, and gallery GET off app-side direct SQL into backend-owned narrow read endpoints
  - added app/backend cache + dedupe for those reads
  - tightened gallery payload shape and page-local pagination behavior
- DSN resolution fix:
  - backend runtime no longer auto-falls back to `db.<project>.supabase.co`
  - active DB resolution now prefers explicit envs and logs the chosen host class safely
  - local and remote runtimes now use the Supavisor session-pooler host on `:5432`
- Pool / transaction hardening:
  - read-only pooled helpers now use short-lived autocommit reads
  - pooled connections are sanitized on checkout / return
  - local runtime now sets `idle_in_transaction_session_timeout=60000`
  - social analytics season-context / target builders now use cached helpers and narrower transaction scopes
- Remote stale-worker fix:
  - Modal secret `trr-backend-runtime` was refreshed from the current backend `.env`
  - Modal app `trr-backend-jobs` was redeployed as `v101`
  - stale pre-`v101` containers were stopped
- Final observed outcome:
  - all six batch-1 admin GET routes are green locally through backend and app proxy paths
  - no new `idle in transaction` sessions reappeared during the post-cutover monitoring window
  - no active local env surface or inspected remote runtime still points at `:6543`

## Ranked batch 2 candidates

1. `TRR-APP/apps/web/src/lib/server/admin/typography-repository.ts`
   - still app-side direct SQL for admin reads
   - likely high admin visibility and cold-read sensitivity
   - should stay app-owned, but needs read-shape / cache hardening and removal of any read-time setup work
2. `TRR-APP/apps/web/src/lib/server/trr-api/trr-shows-repository.ts`
   - multiple remaining `SELECT *` admin-facing show/person/detail helpers
   - backs several list/detail surfaces beyond the batch-1 person routes
   - strongest next candidate for backend-owned narrowing of remaining show/person summary reads
3. `TRR-APP/apps/web/src/app/api/admin/recent-people/route.ts` plus `TRR-APP/apps/web/src/lib/server/admin/recent-people-repository.ts`
   - admin list surface still backed by app-side Postgres
   - likely moderate frequency and worth moving behind a narrow backend summary endpoint
4. `TRR-APP/apps/web/src/lib/server/admin/networks-streaming-repository.ts`
   - heavy summary/list SQL with several `SELECT *` CTE surfaces
   - paired with known polling on the admin networks page
   - likely a good batch-2 candidate once the worst person/show surfaces are cleared
5. `TRR-APP/apps/web/src/app/api/admin/trr-api/seasons/[seasonId]/unassigned-backdrops/route.ts` and `assign-backdrops/route.ts`
   - explicit app-side `pgQuery(...)` use in admin asset flows
   - likely heavier than config reads and should eventually be moved behind backend-owned narrowing
6. `TRR-APP/apps/web/src/lib/server/admin/reddit-sources-repository.ts` and related reddit admin routes
   - still app-side direct SQL with several `SELECT *` paths
   - paired with long-running polling flows; good candidate after higher-frequency show/person/network admin reads
- Live alias verification on the current database target shows:
  - Brandi Glanville has a `core.cast_tmdb` row with `tmdb_id=1686599`, but `also_known_as` is currently empty, so `alternative_names` resolves to `[]`
  - a focused live sample query did not find any current `core.cast_tmdb` rows with non-empty `also_known_as`

## Remaining known high-risk surfaces

### Oversized reads still worth tightening

- `TRR-Backend/api/routers/admin_show_news.py`
  - main helper is narrowed now, but the router still deserves a fuller read-width audit
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
  - `_load_existing_posts(...)` still does `SELECT * FROM social.{table} ...`
  - several social detail/list builders still materialize `raw_data` for richer views
- `TRR-APP/apps/web/src/lib/server/trr-api/trr-shows-repository.ts`
  - `getPersonById(...)` and several legacy person/show detail helpers still use `SELECT *`
- `TRR-APP/apps/web/src/lib/server/admin/covered-shows-repository.ts`
  - route stampede is fixed, but the underlying direct SQL call is still cold-path only and uncached until the first successful load

### Polling surfaces still under review

- `TRR-APP/apps/web/src/components/admin/social-week/WeekDetailPageView.tsx`
- `TRR-APP/apps/web/src/components/admin/season-social-analytics-section.tsx`
- `TRR-APP/apps/web/src/components/admin/reddit-sources-manager.tsx`
- `TRR-APP/apps/web/src/app/admin/reddit-window-posts/page.tsx`
- `TRR-APP/apps/web/src/app/admin/reddit-post-details/page.tsx`

Current classification:

- `networks/page.tsx`: throttled, acceptable for now
- `PersonPageClient.tsx`: fixed from full-gallery reload behavior to paged fetch behavior
- `social summary`: fixed from aggressive live summary polling to one-shot refresh behavior
- `WeekDetailPageView.tsx`
  - safe to keep: sync-session stream fallback polling while an explicit sync is active; sync-run progress polling while an explicit sync is active; 1s elapsed timer because it is local-only UI state
  - should be throttled: 30s worker-health refresh; sync live-health refresh; gallery-only refresh while sync is active
  - should be manual/event-based: 20s manual-attach run candidate polling while idle
- `season-social-analytics-section.tsx`
  - safe to keep: ingest/run polling tied to an active ingest session
  - should be throttled: any analytics/job refresh loop that continues when the tab is hidden or after transient failures
  - should remain local-only: 1s elapsed timer
- `reddit-sources-manager.tsx`
  - safe to keep: backfill/container refresh polling tied to an explicit user-started operation
- `reddit-window-posts/page.tsx`
  - safe to keep: detail-sync polling tied to an explicit refresh/detail run
- `reddit-post-details/page.tsx`
  - safe to keep: detail-sync polling tied to an explicit refresh/detail run

## Rollout verification checklist

- [x] Confirm local app connects successfully on `:5432`
- [x] Confirm local backend starts successfully on `:5432`
- [x] Confirm screenalytics still starts cleanly on `:5432`
- [x] Confirm person gallery page renders on the new gallery paging logic
- [ ] Confirm gallery photo API path stays healthy under session-mode load
- [ ] Confirm social profile summary API path stays healthy under session-mode load
- [x] Confirm no active runtime envs still point to `:6543`
- [x] Run focused app tests for the changed gallery route/runtime wiring
- [x] Run focused backend tests for the summary projection changes
- [x] Re-run repo-wide search for `:6543`
- [x] Re-run repo-wide search for `SELECT *`
- [x] Re-run repo-wide search for `raw_data`
- [x] Re-run repo-wide search for admin polling loops

## Post-change validation notes

- New app proxy/parity tests passed:
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec vitest run tests/covered-shows-route-cache-dedupe.test.ts tests/covered-shows-route-metadata.test.ts tests/covered-show-route-parity.test.ts tests/person-resolve-slug-route-parity.test.ts tests/person-route-parity.test.ts tests/person-cover-photo-route.test.ts tests/person-gallery-route-cache-dedupe.test.ts tests/person-gallery-broken-filter.test.ts`
- New backend admin-read tests passed:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest tests/api/test_admin_covered_shows_reads.py tests/api/test_admin_people_reads.py tests/repositories/test_admin_people_reads_repository.py`
- Backend DB resolution tests passed:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest tests/db/test_connection_resolution.py tests/db/test_pg_pool.py tests/api/test_admin_covered_shows_reads.py tests/api/test_admin_people_reads.py tests/repositories/test_admin_people_reads_repository.py`
- Focused backend lint passed:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ruff check api/auth.py api/main.py api/routers/admin_covered_shows.py api/routers/admin_people_reads.py trr_backend/repositories/covered_shows.py trr_backend/repositories/admin_people_reads.py tests/api/test_admin_covered_shows_reads.py tests/api/test_admin_people_reads.py tests/repositories/test_admin_people_reads_repository.py`
- Focused backend lint passed after the resolution fix:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ruff check api/main.py trr_backend/db/connection.py trr_backend/db/pg.py tests/db/test_connection_resolution.py tests/db/test_pg_pool.py`
- Migrated app GET routes no longer reference the old direct-SQL repositories:
  - repo-wide search across `TRR-APP/apps/web/src/app/api/admin/covered-shows` and `TRR-APP/apps/web/src/app/api/admin/trr-api/people` returned no matches for `getCoveredShows`, `getCoveredShowByTrrShowId`, `getPersonById`, `getPhotosByPersonId`, `resolvePersonSlug`, `resolveShowSlug`, or `getCoverPhoto`
- Updated repo-wide admin-read searches after the cutover:
  - app-side direct SQL search still shows remaining non-batch surfaces like `trr-api/seasons/[seasonId]/assign-backdrops/route.ts`
  - `SELECT *` search still shows known out-of-scope backend surfaces such as `admin_show_links.py`, `social_season_analytics.py`, `cast_screentime.py`, and related docs
  - `raw_data` search still shows known out-of-scope social analytics/detail surfaces
- App tests passed:
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec vitest run tests/person-gallery-broken-filter.test.ts tests/person-gallery-route-cache-dedupe.test.ts tests/person-refresh-request-id-wiring.test.ts tests/covered-shows-route-metadata.test.ts tests/covered-shows-route-cache-dedupe.test.ts tests/social-week-detail-wiring.test.ts tests/postgres-connection-string-resolution.test.ts`
- Backend tests passed:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/db/test_pg_pool.py tests/repositories/test_social_season_analytics.py -k 'social_account_profile_summary or fetch_social_account_profile_rows or pool'`
- Local workspace restart passed and brought up TRR-APP, TRR-Backend, and screenalytics under `:5432`, including the new backend session-pool sizing.
- Live backend smoke after the DSN-resolution fix now proves the target class changed, but the routes still time out against the session pooler:
  - `GET /api/v1/admin/covered-shows` -> client timeout after about `25.0s`, `0` bytes received
  - `GET /api/v1/admin/covered-shows/7782652f-783a-488b-8860-41b97de32e75` -> client timeout after about `25.0s`, `0` bytes received
  - `GET /api/v1/admin/people/resolve-slug?slug=brandi-glanville&show_slug=rhobh` -> client timeout after about `25.0s`, `0` bytes received
  - `GET /api/v1/admin/people/66ce2444-c6c4-46bc-94d0-4c15ae3d04af` -> client timeout after about `25.0s`, `0` bytes received
  - `GET /api/v1/admin/people/66ce2444-c6c4-46bc-94d0-4c15ae3d04af/cover-photo` -> client timeout after about `25.0s`, `0` bytes received
  - `GET /api/v1/admin/people/66ce2444-c6c4-46bc-94d0-4c15ae3d04af/gallery?limit=120&offset=0` -> client timeout after about `25.0s`, `0` bytes received
- Runtime logs now show the backend stalling on the intended pooler target rather than falling over to the direct host:
  - repeated `[db-pool] init_attempt=0 source=SUPABASE_DB_URL host_class=pooler host=aws-1-us-east-1.pooler.supabase.com port=5432`
  - intermittent `[db-pool] init_failed ... error=OperationalError`
  - later retries occasionally reach `[db-pool] init_selected ... host_class=pooler ...`
- No batch-1 route-level cache/query-count logs were emitted during the smoke because the requests did not complete; cache and payload logging remain validated by focused tests, not live curl evidence yet.
- Render smoke passed:
  - `GET /dev-dashboard` -> `200`
  - `GET /people/brandi-glanville/gallery` -> `200`
  - `GET /admin/social/twitter/bravotv` -> `200`
- Direct admin/API smoke after the second reduction pass still shows that cold direct-SQL reads are timing out:
  - `GET /api/admin/covered-shows` -> `500` in about `36.5s`
  - `GET /api/admin/trr-api/people/66ce2444-c6c4-46bc-94d0-4c15ae3d04af/photos?limit=120&offset=0` -> `500` in about `41.5s`
  - `GET /api/admin/trr-api/social/profiles/twitter/bravotv/summary` -> `504` in about `46.6s`
- Concrete root-cause notes from runtime logs:
  - `/api/admin/covered-shows`
    - route stampede is fixed, but the cold request still has to execute one direct SQL query and that query is timing out inside app-side `pg` before it returns.
  - `/api/admin/trr-api/people/.../photos`
    - the route no longer dies on the up-front `getPersonById()` lookup; after the latest patch the first failing query is the first paged `core.cast_photos` fetch, which confirms the load shape is smaller but the cold direct query is still timing out upstream.
  - `/api/admin/trr-api/social/profiles/twitter/bravotv/summary`
    - app-side cache/in-flight dedupe is in place, but cold requests still wait on the backend summary builder, which continues to spend too long in summary totals / queue-status / recent-run helper queries and times out at the app proxy boundary.
- Current runtime takeaway:
  - the March 24 `MaxClientsInSessionMode` failure class was real and these changes reduce the app/backend client footprint materially
  - the backend is now targeting the correct Supavisor session-pooler host, so the old direct-host misresolution is fixed
  - but the current workspace still has broader live session-pooler fragility, so batch-1 authenticated reads are timing out on the correct host before the handlers can complete
- Repo-wide `:6543` search now returns documentation-only references in this note.

## 2026-03-25 Batch 2.2 backend slice

- Implemented backend-owned read infrastructure for the first Batch 2.2 show-read lane in `TRR-Backend` only:
  - `GET /api/v1/admin/trr-api/search`
  - `GET /api/v1/admin/trr-api/shows`
  - `GET /api/v1/admin/trr-api/shows/resolve-slug`
  - `GET /api/v1/admin/trr-api/people/home`
  - `GET /api/v1/admin/trr-api/shows/{show_id}`
  - `GET /api/v1/admin/trr-api/shows/{show_id}/seasons`
- Router behavior now matches the planned Batch 1 admin-read pattern:
  - per-route in-memory TTL caching
  - query-count logging
  - payload-size logging
  - internal-admin auth dependency
- Contract-specific backend decisions for this slice:
  - `search` now calls the actual repository function `search_global(...)` and preserves the existing `query`, `pagination`, `shows`, `people`, and `episodes` response envelope
  - `people/home` now honors `X-TRR-Admin-User-Uid` so the `recentlyViewed` section stays user-scoped, and its cache key includes that UID
  - added backend cache invalidation endpoint at `POST /api/v1/admin/trr-api/shows/{show_id}/cache/invalidate`; it clears the full show-read cache because detail updates can affect list/search/resolve outputs
- Focused backend validation passed:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest tests/api/test_admin_show_reads.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ruff check api/main.py api/routers/admin_show_reads.py trr_backend/repositories/admin_show_reads.py tests/api/test_admin_show_reads.py`

## 2026-03-25 Batch 2.0, 2.1, and 2.2 checkpoint

- Batch 2.0 preflight is complete for the first show-read lane:
  - app proxy/cache helper coverage confirmed in `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts` and `TRR-APP/apps/web/src/lib/server/admin/route-response-cache.ts`
  - backend route-level latency/query-count/payload logging confirmed in `TRR-Backend/api/routers/admin_show_reads.py`
  - focused parity harnesses identified and extended:
    - `tests/admin-global-search-route.test.ts`
    - `tests/people-home-route.test.ts`
    - `tests/show-route-parity.test.ts`
    - `tests/show-seasons-route-episode-signal.test.ts`
    - `tests/api/test_admin_show_reads.py`
  - no polling hooks were found in the primary Batch 2.2 page entry points:
    - `TRR-APP/apps/web/src/app/admin/trr-shows/page.tsx`
    - `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`
    - `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/[[...personTab]]/page.tsx`

- Batch 2.1 typography hardening shipped in parallel and stayed out of the migration critical path:
  - typography GET routes no longer perform schema-creation or seeding work on read
  - admin/public typography GET routes now use route-level cache namespaces with write-time invalidation
  - focused typography tests passed:
    - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web vitest run tests/design-system-typography-routes.test.ts tests/typography-repository.test.ts`
  - live runtime note:
    - the local app log still captured `MaxClientsInSessionMode` on `/api/design-system/typography` during the same observation window, so the code hardening is in place but the workspace is still subject to shared session-pool pressure

- Batch 2.2 app proxy rewires are in place for the approved six GET routes only:
  - `GET /api/admin/trr-api/search`
  - `GET /api/admin/trr-api/shows`
  - `GET /api/admin/trr-api/shows/resolve-slug`
  - `GET /api/admin/trr-api/people/home`
  - `GET /api/admin/trr-api/shows/{show_id}`
  - `GET /api/admin/trr-api/shows/{show_id}/seasons`
  - routes now proxy to `/api/v1/admin/trr-api/...`, not the provisional `/admin/trr-shows/...` namespace
  - `people/home` preserves the `recentlyViewed` contract by forwarding `X-TRR-Admin-User-Uid`
  - `show detail` keeps the existing write-side invalidation flow and now invalidates `POST /api/v1/admin/trr-api/shows/{show_id}/cache/invalidate`

- Focused Batch 2.2 validation passed:
  - app:
    - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web vitest run tests/admin-global-search-route.test.ts tests/people-home-route.test.ts tests/show-route-parity.test.ts tests/show-seasons-route-episode-signal.test.ts tests/show-featured-image-validation-route.test.ts tests/design-system-typography-routes.test.ts tests/typography-repository.test.ts`
    - result: `7` files passed, `29` tests passed
  - backend:
    - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest tests/api/test_admin_show_reads.py`
    - result: `6` tests passed
    - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ruff check api/main.py api/routers/admin_show_reads.py trr_backend/repositories/admin_show_reads.py tests/api/test_admin_show_reads.py`

- Live checkpoint status after restarting the backend onto the new router set:
  - the stale-process 404 issue was resolved by forcing a local backend restart; the new PID now serves `api/routers/admin_show_reads.py`
  - the lane is **not** operationally clean yet because the workspace is currently hitting Supabase session-pool exhaustion before most Batch 2.2 reads can acquire a DB connection
  - backend direct smoke:
    - `search`: cold `500` ~`1689ms`, warm `500` ~`812ms`, payload `21` bytes
    - `shows`: cold `500` ~`826ms`, warm `500` ~`820ms`, payload `21` bytes
    - `resolve-slug`: cold `500` ~`846ms`, warm `500` ~`908ms`, payload `21` bytes
    - `people/home`: cold `200` ~`4174ms`, warm `200` ~`0ms`, payload `1272` bytes
    - `show detail`: cold `500` ~`818ms`, warm `500` ~`872ms`, payload `21` bytes
    - `show seasons`: cold `500` ~`841ms`, warm `500` ~`826ms`, payload `21` bytes
  - app proxy smoke:
    - `search`: cold `500` ~`973ms`, warm `500` ~`1501ms`, payload `41` bytes
    - `shows`: cold `500` ~`1019ms`, warm `500` ~`913ms`, payload `41` bytes
    - `resolve-slug`: cold `500` ~`937ms`, warm `500` ~`866ms`, payload `41` bytes
    - `people/home`: cold `200` ~`4305ms`, warm `200` ~`49ms`, payload `1272` bytes, app cache hit on warm request
    - `show detail`: cold `500` ~`921ms`, warm `500` ~`974ms`, payload `41` bytes
    - `show seasons`: cold `500` ~`905ms`, warm `500` ~`951ms`, payload `41` bytes

- Route-budget takeaway at this checkpoint:
  - only `people/home` completed end-to-end and demonstrated app/backend cache hits
  - the other five routes failed before route-level query-count logging because `ThreadedConnectionPool` could not establish a session-pooler connection
  - backend log evidence for the blocker:
    - repeated `[db-pool] init_failed source=SUPABASE_DB_URL host_class=pooler host=aws-1-us-east-1.pooler.supabase.com port=5432 error=OperationalError`
    - repeated `psycopg2.OperationalError ... MaxClientsInSessionMode: max clients reached - in Session mode max clients are limited to pool_size`
  - this means the Batch 2.2 code migration is in place and test-validated, but the live checkpoint is blocked by shared session-pool capacity, not by route-contract drift

## 2026-03-26 Local process hygiene pass and Batch 2.2 rerun

- Fixed the local startup-flow hygiene in two places:
  - `screenalytics/scripts/dev_auto.sh`
    - replaced blind `lsof | kill -9` port cleanup with safe same-service listener matching
    - added a singleton lock (`.logs/dev_auto.lock`)
    - added runtime PID tracking in `.logs/dev_auto.pids.env`
    - startup now prints the live manager/api/streamlit/web PID snapshot
  - `scripts/dev-workspace.sh`
    - runtime PID values in `.logs/workspace/pids.env` are now upserted instead of append-only, so restart state no longer leaves stale PID values behind

- What the local audit actually found before cleanup:
  - one live workspace manager
  - one live TRR-Backend tree
  - one live TRR-APP tree
  - one live screenalytics API + Streamlit + web tree
  - no duplicate local screenalytics listeners beyond the expected uvicorn reload parent/child pair
  - no local social worker or remote-worker helper processes
  - no local `:5432` / `:6543` established sockets at rest
  - the only stale local artifact was pidfile drift: old backend PID values persisted in `.logs/workspace/pids.env` even after restart

- Clean local validation shape:
  - stopped the full workspace with `scripts/stop-workspace.sh`
  - restarted only TRR-Backend + TRR-APP with `WORKSPACE_SCREENALYTICS=0`
  - confirmed active listeners after restart:
    - `TRR-Backend` on `:8000`
    - `TRR-APP` on `:3000`
    - no `screenalytics` listeners on `:8001`, `:8501`, or `:8080`
  - confirmed current workspace pidfile contains a single live `TRR_BACKEND_PID` and `TRR_APP_PID`

- Screenalytics startup smoke for the new hygiene path passed in degraded smoke mode:
  - `cd screenalytics && SCREENALYTICS_SKIP_DOCKER=1 DEV_AUTO_SMOKE=1 DEV_AUTO_ALLOW_DB_ERROR=1 API_PORT=18001 ./scripts/dev_auto.sh`
  - result:
    - singleton/lock + PID tracking path worked
    - safe startup + cleanup path worked
    - smoke exited `0`
    - `/readyz` stayed pending because DB/Redis were intentionally unavailable in skip-docker mode

- Session-pool headroom evidence after local cleanup:
  - local runtime was no longer the obvious source of pool pressure:
    - no screenalytics listeners remained
    - no local DB sockets were visible on the TRR-Backend/TRR-APP processes at rest
  - `pg_stat_activity` still showed the same remote Supavisor client footprint after local cleanup:
    - `15` idle `Supavisor` sessions from `2600:1f18:2e13:9d02:fa49:ce02:1282:bd60/128`
    - `1` idle `Supavisor` session from `2600:1f18:2e13:9d00:dca1:6157:cc55:d8be/128`
    - query texts still mapped to remote social analytics / scrape-run activity
  - takeaway:
    - local stale-process cleanup is now in place and the local workspace is clean
    - shared pool exhaustion persists because remote Supavisor clients are still occupying the same session pool

- Batch 2.2 rerun after cleanup:
  - backend direct smoke using the same service-role + internal-secret auth path as the app proxy:
    - `search` cold `500` ~`1.44s`, warm `500` ~`2.11s`, payload `21` bytes
    - `shows` cold `500` ~`2.09s`, warm `500` ~`1.61s`, payload `21` bytes
    - `resolve-slug` cold `500` ~`2.25s`, warm `500` ~`1.36s`, payload `21` bytes
    - `people/home` cold `200` ~`7.70s`, warm `200` ~`0.003s`, payload `1066` bytes
    - `show detail` cold `500` ~`1.65s`, warm `500` ~`1.07s`, payload `21` bytes
    - `show seasons` cold `500` ~`2.16s`, warm `500` ~`0.85s`, payload `21` bytes
  - app proxy smoke:
    - `search` cold `500` ~`1.80s`, warm `500` ~`2.49s`, payload `41` bytes
    - `shows` cold `500` ~`1.55s`, warm `500` ~`1.55s`, payload `41` bytes
    - `resolve-slug` cold `500` ~`1.36s`, warm `500` ~`1.36s`, payload `41` bytes
    - `people/home` cold `504` ~`5.09s`, warm `200` ~`0.009s`, payload `1272` bytes
    - `show detail` cold `500` ~`2.15s`, warm `500` ~`1.59s`, payload `41` bytes
    - `show seasons` cold `500` ~`1.83s`, warm `500` ~`1.89s`, payload `41` bytes
  - route-log evidence after rerun:
    - backend only emitted route-level metrics for `people/home`
      - cache misses logged with `query_count=0`, payloads `1062-1272` bytes, latency `3.3s-10.7s`
      - cache hits logged at `0ms`
    - app proxy logged:
      - `admin-global-search status=500`
      - `admin-shows status=500`
      - `show-resolve-slug status=500`
      - `people-home status=200`
      - `show-detail status=500`
      - `show-seasons status=500`

- Operational conclusion at this checkpoint:
  - the stale local process problem is fixed for the Screenalytics/dev flow and the workspace pidfile is no longer misleading
  - the local validation environment is now materially cleaner and trustworthy
  - Batch 2.2 is still **not** operationally green
  - the remaining blocker is remote session-pool contention, not local stale-process buildup
  - do not start Batch 2.3 until the remote Supavisor pressure is reduced and this Batch 2.2 checkpoint is rerun successfully

## 2026-03-26 01:20 EDT — Batch 2.2 green, Batch 2.3 completed

- Remote pool-pressure fix and Batch 2.2 rerun:
  - restored session-pool headroom by reducing the remote Supavisor client pressure enough for local validation to reach SQL consistently again
  - confirmed `psql` to the session-pooler succeeds again from this machine
  - reran the full Batch 2.2 checkpoint and all six migrated routes returned `200` through both backend direct and app proxy paths
  - successful Batch 2.2 live results:
    - backend:
      - `search` cold `133ms`, warm `2ms`, payload `1116B`
      - `shows` cold `44ms`, warm `2ms`, payload `588B`
      - `resolve-slug` cold `1ms`, warm `1ms`, payload `154B`
      - `people/home` cold `387ms`, warm `3ms`, payload `9523B`
      - `show detail` cold `48ms`, warm `2ms`, payload `1746B`
      - `show seasons` cold `41ms`, warm `2ms`, payload `5755B`
    - app proxy:
      - all six routes returned `200`
      - warm reads hit route cache as expected
  - backend log metrics for Batch 2.2 confirmed cold-read query counts of `2/1/0-or-1/4/1/1` and warm cache hits with `query_count=0`

- Batch 2.3 implementation scope completed in the same run:
  - migrated these routes to backend-owned narrow reads with thin app proxies:
    - `GET /api/admin/trr-api/seasons/[seasonId]/episodes`
    - `GET /api/admin/trr-api/shows/[showId]/cast`
    - `GET /api/admin/trr-api/shows/[showId]/seasons/[seasonNumber]/cast`
  - preserved route contracts:
    - episodes: `episodes`, `pagination`
    - show cast: `cast`, `archive_footage_cast`, `cast_source`, `eligibility_warning`, `pagination`
    - season cast: `cast`, `cast_source`, `eligibility_warning`, `include_archive_only`, `pagination`
  - kept app-side `resolveAdminShowId(...)` only on show-cast to preserve the existing slug-like route input behavior

- Batch 2.3 fixes discovered during live validation:
  - initial live smoke exposed one real schema mismatch in the new backend show-cast query:
    - `core.v_show_cast` does **not** expose `latest_season` or `seasons_appeared`
    - removed those invalid projections from the backend query
  - no additional hidden client dependency surfaced after that fix

- Batch 2.3 focused validation:
  - backend:
    - `ruff check api/routers/admin_show_reads.py trr_backend/repositories/admin_show_reads.py tests/repositories/test_admin_show_reads_repository.py`
    - `pytest tests/api/test_admin_show_reads.py tests/repositories/test_admin_show_reads_repository.py -q`
    - result: `17 passed`
  - app:
    - focused Vitest for the migrated 2.3 routes plus Batch 2.2 parity files
    - result: `7 files passed`, `15 tests passed`

- Batch 2.3 live checkpoint after the schema fix:
  - backend direct:
    - `season episodes` cold `80ms`, warm `2ms`, payload `418B`
    - `show cast` cold `253ms`, warm `2ms`, payload `8608B`
    - `season cast` cold `163ms`, warm `7ms`, payload `2232B`
  - app proxy:
    - `season episodes` cold `34ms`, warm `20ms`, payload `418B`
    - `show cast` cold `217ms`, warm `10ms`, payload `8608B`
    - `season cast` cold `32ms`, warm `19ms`, payload `2232B`
  - backend route metrics:
    - `episodes`: `query_count=1` cold miss, `payload_bytes=418`, warm cache hit `query_count=0`
    - `show-cast`: `query_count=1` cold miss, `payload_bytes=8708`, warm cache hit `query_count=0`
    - `season-cast`: `query_count=1` cold miss, `payload_bytes=2232`, warm cache hit `query_count=0`
  - contract spot-check:
    - backend and app responses both matched the expected top-level keys for all three routes
    - episodes remained narrowed and did not reintroduce `SELECT *`

- Handoff / closeout hygiene:
  - the earlier closeout blocker from the stale `bravo-social-account-linking-and-handle-tabs.md` note had already been repaired
  - rerun closeout after this status update to regenerate `docs/ai/HANDOFF.md` with the Batch 2.2 + 2.3 completion state

## 2026-03-26 Accepted audit alignment for batches through 2.4

- Accepted current-repo-state audit verdict:
  - Phase 1 / Batch 1 is complete for scope, with optional cleanup only
  - Batch 2.1 is complete
  - Batch 2.3 is complete
  - Batch 2.4 is complete as a summary-only lane; `networks-streaming/detail` remaining app-owned does not invalidate that lane
  - use `batches through 2.4 completed` wording going forward; do not describe Phase 2 as fully complete end-to-end

- Required audit backfill recorded for Batch 2.2:
  - the backend show-seasons read had one concrete narrowing miss in its default `core.seasons` path
  - accepted backfill: replace the default `SELECT *` with an explicit seasons projection that matches the existing seasons contract

- Carry-forward notes from the accepted audit:
  - screenalytics still has a hidden dependency through direct `admin.covered_shows` DB reads
  - `/people` is a real consumer of the completed show/person read lane
  - `UnifiedBrandsWorkspace` is a real consumer of the completed `networks-streaming` summary lane
