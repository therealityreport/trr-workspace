# Supabase Performance Audit Plan: Admin Page Load Time

Date: 2026-06-16

## Objective

Reduce backend and database latency that affects TRR ADMIN page load time, with priority on admin pages that read Supabase-backed social, show, survey, screenalytics, and diagnostics data.

This is an audit and implementation plan. It does not apply database migrations or app/backend code changes yet.

## Beneficial Capabilities For This Plan

- `@supabase-fullstack` / Supabase connector
  - Used for live Performance Advisor output, `pg_stat_statements`, cache hit rates, table scan stats, and index usage evidence.
  - Validation contribution: confirms current database behavior instead of relying on migration files alone.
- Plan Grader / Plan Architect
  - Used to structure findings, fixes, dependencies, validation gates, and risk controls in this `Plan.md`.
  - Validation contribution: keeps each recommendation tied to evidence and an executable follow-through path.
- TRR repo inspection
  - Used to map database findings to ADMIN routes, app proxy routes, backend routers, and repository files.
  - Validation contribution: prevents generic database tuning that does not affect admin page load time.

## Live Evidence Summary

- Supabase Performance Advisor returned active performance lints:
  - 5 unindexed foreign key warnings on `social.instagram_profile_following_snapshots` and `social.instagram_profile_relationship_snapshot_items`.
  - Many unused-index warnings across `social`, `core`, `ml`, `screenalytics`, `surveys`, and `public`.
- Cache hit rates are below the usual target for a hot read-heavy admin workload:
  - Index hit rate: `97.72%`.
  - Table hit rate: `94.08%`.
  - Supabase docs recommend investigating cache/index usage when rates are below about `99%`.
- `pg_stat_statements` shows social admin reads dominate cumulative query time:
  - Social landing progress rollup: about `1,453,210 ms` total, `34,600 ms` mean, `53,213 ms` max across 42 calls.
  - Social account profile and post/comment rollups include several query shapes with `5,000 ms` to `47,000 ms` mean time.
  - Queue and scrape-run status queries have high call volume and large outliers, including max times from about `40,225 ms` to `102,528 ms`.
- Table stats show repeated scans on admin-hot tables:
  - `social.scrape_workers`: `650,179` sequential scans, `82.62%` index scan share.
  - `core.google_news_sync_jobs`: `300,481` sequential scans, `73.38%` index scan share.
  - `social.scrape_jobs`: `88,793` sequential scans, `50,621` live rows.
  - `social.instagram_account_catalog_posts`: `15,503` sequential scans, `30,524` live rows.
  - `social.instagram_comments`: `947,957` live rows and appears in slow profile/comment reads despite high index usage.
- Largest zero-scan indexes should be reviewed, not dropped automatically:
  - `social.instagram_comments_username_created_idx`: `51 MB`, `0` scans.
  - Several trigram/search indexes on social post tables have `0` scans but may support low-frequency admin search features.

## ADMIN Surface Map

Primary ADMIN page families found in the live repo:

- Admin dashboard: `TRR-APP/apps/web/src/app/admin/page.tsx`
  - Defers diagnostics with dynamic client-only cards.
  - Shows a load-time badge but does not persist route-level timings.
- Social landing: `TRR-APP/apps/web/src/app/admin/social/page.tsx`
  - Reads `/api/admin/social/landing`.
  - Backend source includes `TRR-APP/apps/web/src/lib/server/admin/social-landing-repository.ts`.
- Social account profile pages: `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`
  - Loads summary/snapshot, live profile total, posts, catalog posts, hashtags, comments, freshness, queue/run progress, and remediation panels.
  - Backend proxy path is under `/api/admin/trr-api/social/profiles/...`.
- Social week/detail pages: `TRR-APP/apps/web/src/components/admin/social-week/WeekDetailPageView.tsx`
  - Loads week snapshots, summary, post details, comments coverage, mirror coverage, runs, sync sessions, and streams.
- Show detail pages: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/...`
  - Reads many show, cast, gallery, season, social, news, and asset endpoints.
- Diagnostics/system health: `TRR-APP/apps/web/src/components/admin/SystemHealthModal.tsx`
  - Reads queue status, active job state, and operation health.
- Backend social/admin routers:
  - `TRR-Backend/api/routers/socials/__init__.py`
  - `TRR-Backend/trr_backend/socials/analytics/read_models.py`
  - `TRR-Backend/trr_backend/repositories/*admin*`

## Findings

### P0: Social landing progress rollup scans all platform tables before narrowing targets

Practical result: ADMIN social landing can spend tens of seconds on progress math before the page has useful data.

Evidence:

- `pg_stat_statements` shows `/* landing_social_progress */` with about `34.6s` mean time and `53.2s` max.
- App fallback query in `TRR-APP/apps/web/src/lib/server/admin/social-landing-repository.ts` builds `materialized_rows` and `catalog_rows` from all platform post/catalog tables, then joins to requested targets later.
- Backend route logic in `TRR-Backend/api/routers/socials/__init__.py` uses the better target-first shape for some rollup paths, but the app fallback remains expensive.

Fix:

- Make the app-side fallback query target-first like the backend query:
  - Join `targets` into each platform table inside each UNION branch.
  - Avoid computing JSON/media/comment expressions for accounts not on the landing page.
  - Keep the backend route as the primary path and treat app SQL fallback as emergency-only.
- Add expression indexes only where confirmed by `EXPLAIN`:
  - Example shape: lower/ltrim source account plus date/id ordering for platform post/catalog tables.
  - Prefer generated normalized handle columns if repeated expression indexes become hard to maintain.

### P0: Social profile page fires multiple secondary reads after initial snapshot

Practical result: opening one profile can trigger summary/snapshot, live total, catalog preview, posts/catalog reads, hashtags, freshness, and run progress. That makes one page load look like a small batch job.

Evidence:

- `SocialAccountProfilePage.tsx` loads `/summary` or `/snapshot`, then secondary reads such as `/live-profile-total`, `/catalog/posts?page=1&page_size=1`, `/posts`, `/catalog/posts`, hashtags, timeline, freshness, and progress endpoints.
- Several matching query shapes in `pg_stat_statements` have mean runtimes above `5s`, and some max runtimes above `20s`.

Fix:

- Define one load-time critical payload for first paint:
  - Summary/snapshot.
  - Last run state.
  - Counts already cached in the snapshot.
- Move all secondary reads behind explicit tab visibility or operator interaction:
  - Live total.
  - Catalog preview.
  - Hashtag timeline.
  - Comment detail.
  - Gap analysis.
- Add a single per-profile server snapshot cache for all first-paint fields with stale-if-error behavior.

### P0: Instagram comments and catalog detail reads are too expensive for synchronous ADMIN page loading

Practical result: comments-heavy accounts and posts can block UI load or saturate the backend when an admin opens post/comment detail panels.

Evidence:

- `social.instagram_comments` has about `947,957` live rows.
- `pg_stat_statements` shows comment/post detail queries with means from about `56 ms` to `16,467 ms`, and high row counts in reply fetches.
- `TRR-Backend/trr_backend/socials/analytics/read_models.py` returns all comments for an Instagram post and orders by likes/created time.

Fix:

- Paginate comments by default for ADMIN post detail:
  - Return top-level comments first.
  - Load replies per parent or in bounded pages.
  - Keep an explicit "load all" operator action for rare deep inspection.
- Add or validate indexes for the exact comment read shapes:
  - `post_id`, `is_missing`, `is_reply`, `parent_comment_id`, `created_at`, and `likes`.
  - Use partial indexes for active comments where `is_missing = false` and `deleted_at is null`.
- Add route-level query timing headers for comment detail endpoints.

### P1: Queue and operations health endpoints are high-frequency and can amplify load

Practical result: diagnostics cards and system health panels can add pressure while the database is already busy.

Evidence:

- `social.scrape_jobs` has `50,621` live rows and high read/update volume.
- `pg_stat_statements` shows `social.scrape_jobs` and `social.scrape_runs` status queries with high call counts and large outliers.
- `SystemHealthModal.tsx` and dashboard diagnostics hit queue status and operation health endpoints.

Fix:

- Keep summary-first defaults and make full diagnostics explicit:
  - `summary_only=true` should remain the default.
  - Full stuck-job/run diagnostics should require a refresh/detail action.
- Increase cache and singleflight coverage for queue status under load:
  - Cache summary status for 5-15 seconds.
  - Reuse stale summary on backend saturation.
- Add covering/partial indexes only after `EXPLAIN` on current queue summary queries.

### P1: Live cache hit rates suggest memory or query-shape pressure

Practical result: even indexed reads may wait on disk/OS cache more often than expected, making admin load time inconsistent.

Evidence:

- Live index hit rate: `97.72%`.
- Live table hit rate: `94.08%`.
- Supabase docs recommend using `pg_stat_statements`, cache hit rates, and `EXPLAIN` to identify hot or slow queries.

Fix:

- First reduce hot read volume and broad scans in social/admin routes.
- Then re-check hit rates after the query-shape fixes.
- If hit rates stay below `99%`, evaluate whether the current Supabase compute/memory tier is undersized for social ingestion plus admin reads.

### P1: Performance Advisor unindexed FK warnings are valid but currently small-table

Practical result: these are easy hardening fixes, but they are not the current main page-load bottleneck.

Evidence:

- Advisor flags these unindexed foreign keys:
  - `social.instagram_profile_following_snapshots.last_scrape_job_id`
  - `social.instagram_profile_following_snapshots.last_scrape_run_id`
  - `social.instagram_profile_relationship_snapshot_items.relationship_row_id`
  - `social.instagram_profile_relationship_snapshot_items.last_scrape_job_id`
  - `social.instagram_profile_relationship_snapshot_items.last_scrape_run_id`
- Live sizes are currently small:
  - `instagram_profile_following_snapshots`: `2` live rows, `64 kB`.
  - `instagram_profile_relationship_snapshot_items`: `54` live rows, `216 kB`.

Fix:

- Add small partial FK indexes in one migration:
  - Use `WHERE <column> IS NOT NULL` for nullable FK columns.
  - Use regular migration DDL locally; use concurrent index creation only if production row count is no longer small at execution time.

### P2: Unused index warnings need a retention policy before drops

Practical result: dropping unused indexes blindly could break rare admin workflows or unique/constraint enforcement.

Evidence:

- Largest zero-scan indexes include `social.instagram_comments_username_created_idx` at `51 MB`.
- Some zero-scan indexes are primary keys or unique constraints and must not be treated as cleanup candidates.
- Some search/trigram indexes may support rare admin search paths and should be validated against route behavior first.

Fix:

- Classify unused indexes into:
  - Required constraints: keep.
  - Rare admin/search support: keep unless replaced.
  - Write-path drag with no route owner: candidate for drop.
- For drop candidates, produce a rollback migration and compare write latency before and after.

## Implementation Plan

### Phase 1: Add measurement and guardrails

- Add server timing for the critical ADMIN API families:
  - `/api/admin/social/landing`
  - `/api/admin/trr-api/social/profiles/.../snapshot`
  - `/api/admin/trr-api/social/profiles/.../posts`
  - `/api/admin/trr-api/social/profiles/.../catalog/posts`
  - `/api/admin/trr-api/social/ingest/queue-status`
- Log route family, cache status, backend duration, and database duration without logging raw query text or secrets.
- Persist client-side ADMIN load-time samples for dashboard, social landing, social profile, show detail, and system health surfaces.

### Phase 2: Fix social landing query shape

- Prefer backend `/landing-progress-rollup` as the only normal progress source.
- Rewrite app SQL fallback to join `targets` inside each platform branch.
- Add a bounded timeout and stale fallback for social landing enrichment.
- Validate with `EXPLAIN` and a real target list before adding indexes.

### Phase 3: Collapse social profile first-paint reads

- Make `/snapshot?detail=lite` the single first-paint route.
- Move `/live-profile-total`, catalog preview, hashtag timeline, and gap analysis behind tab visibility or explicit action.
- Ensure snapshot responses include enough stale metadata for the UI to show usable cached data when backend saturation occurs.

### Phase 4: Paginate comments and heavy catalog details

- Change Instagram post comments detail to return:
  - `comments_preview`
  - `top_level_count`
  - `reply_count`
  - `next_cursor`
- Add follow-up endpoints for reply pages and full export.
- Add targeted partial indexes only after `EXPLAIN` confirms they match the new paginated query shape.

### Phase 5: Apply low-risk advisor hardening

- Add partial indexes for the five unindexed FK advisor findings.
- Re-run Supabase Performance Advisor.
- Record before/after advisor output in `TRR-Backend/docs/db/advisor-performance/`.

### Phase 6: Build an unused-index decision ledger

- Export zero-scan indexes with size, constraint ownership, table write volume, and route owner.
- Keep all unique, primary key, exclusion, and active route-owned indexes.
- Prepare a separate cleanup migration only for confirmed drop candidates.

## Proposed Migration Candidates

Do not run these until Phase 2-4 `EXPLAIN` confirms shape and selectivity.

Low-risk advisor hardening candidates:

```sql
create index if not exists instagram_profile_following_snapshots_last_scrape_job_id_idx
  on social.instagram_profile_following_snapshots (last_scrape_job_id)
  where last_scrape_job_id is not null;

create index if not exists instagram_profile_following_snapshots_last_scrape_run_id_idx
  on social.instagram_profile_following_snapshots (last_scrape_run_id)
  where last_scrape_run_id is not null;

create index if not exists instagram_profile_relationship_snapshot_items_relationship_row_id_idx
  on social.instagram_profile_relationship_snapshot_items (relationship_row_id)
  where relationship_row_id is not null;

create index if not exists instagram_profile_relationship_snapshot_items_last_scrape_job_id_idx
  on social.instagram_profile_relationship_snapshot_items (last_scrape_job_id)
  where last_scrape_job_id is not null;

create index if not exists instagram_profile_relationship_snapshot_items_last_scrape_run_id_idx
  on social.instagram_profile_relationship_snapshot_items (last_scrape_run_id)
  where last_scrape_run_id is not null;
```

Likely hot-path candidates to validate with `EXPLAIN`:

```sql
-- Validate against social landing/profile target-first queries before use.
create index concurrently if not exists instagram_posts_source_account_posted_id_idx
  on social.instagram_posts (lower(ltrim(source_account, '@')), posted_at desc, id desc);

create index concurrently if not exists instagram_catalog_source_account_posted_id_idx
  on social.instagram_account_catalog_posts (lower(ltrim(source_account, '@')), posted_at desc, id desc);

-- Validate against paginated comment detail before use.
create index concurrently if not exists instagram_comments_active_post_parent_created_idx
  on social.instagram_comments (post_id, parent_comment_id, created_at asc)
  where coalesce(is_missing, false) = false and deleted_at is null;
```

## Validation Gates

- Backend/API validation:
  - Run focused backend tests for social profile, landing progress, queue status, and comment detail routes.
  - Run `EXPLAIN (ANALYZE, BUFFERS)` on the exact before/after query shapes in staging or a safe live read-only path.
  - Re-run Supabase Performance Advisor after the FK index migration.
- App validation:
  - Run lightweight app validation before any full build.
  - Browser-check admin dashboard, social landing, one Instagram profile, one catalog tab, and one comment detail route with `make dev-hybrid`.
  - Capture route timing headers and load-time badge values before and after.
- Database validation:
  - Re-check cache hit rates.
  - Re-check top `pg_stat_statements` rows for the affected query fingerprints.
  - Confirm no new lock waits during index creation.
- Completion validation:
  - If backend, worker, scraper, job, runtime, or Modal-deployed code changes are made, complete Modal follow-through before calling the implementation done.

## Risks And Controls

- Risk: broad index additions improve reads but slow ingestion writes.
  - Control: add only indexes proven by `EXPLAIN`, prefer partial indexes, and compare table write volume.
- Risk: unused-index cleanup removes rare admin search support.
  - Control: create an ownership ledger before any drop migration.
- Risk: secondary reads still fire due React effects after first-paint consolidation.
  - Control: add tab/visibility gates and one integration test for no extra first-load requests.
- Risk: backend cache hides slow query regressions.
  - Control: include cache status and uncached refresh timing in timing headers.

## Readiness Score

- Current plan readiness: `92/100`.
- Main remaining gap: query-shape fixes need `EXPLAIN` evidence against real parameters before exact indexes and migrations are final.
- Safe next action: implement Phase 1 timing and Phase 2 social landing target-first fallback, then gather before/after SQL plans.
