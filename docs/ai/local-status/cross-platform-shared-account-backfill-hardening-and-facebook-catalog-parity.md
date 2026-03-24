# Cross-Platform Shared-Account Backfill Hardening And Facebook Catalog Parity

Date: 2026-03-22

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-22
  current_phase: "shared-account backfill hardening shipped across Twitter, Threads, YouTube, and Facebook, with Facebook catalog support enabled end to end"
  next_action: "apply migration 0202, start fresh Twitter/Threads/YouTube/Facebook account backfills from the admin profile pages, and confirm each platform now reports live progress plus accurate Modal waiting states without false clean completion"
  detail: self
```

## Summary
- Carried the shared Modal dispatch/admin-status hardening forward to the non-Instagram/TikTok shared-account backfill platforms by proving the same progress and dispatch-health contract through Twitter, Threads, YouTube, and Facebook coverage.
- Added platform-specific retrieval error signaling so fallback exhaustion or fetch failure no longer looks like a clean zero-result completion for Twitter, Threads, YouTube, or Facebook.
- Standardized shared catalog progress reporting for Twitter, Threads, YouTube, and Facebook so long-running profile backfills emit live `posts_checked`, `pages_scanned`, and persist progress instead of only updating at terminal completion.
- Enabled Facebook as a first-class shared-account catalog platform across backend routing, persistence, progress payloads, and the admin profile UI.
- Hardened `scripts/reload_postgrest_schema.sh` so repo `.env` values with spaces or quoted browser-style strings no longer break the required PostgREST schema-reload step.

## Backend
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
  - added `facebook` to the catalog-supported platform set and catalog post-table routing
  - added shared helpers to normalize/persist live catalog progress for non-Instagram/TikTok wrappers
  - forwarded `progress_cb` through shared Twitter, Threads, YouTube, and Facebook catalog scrapes
  - enabled Facebook catalog scraping instead of rejecting it
  - added Facebook catalog upsert support and shared URL handling
- `TRR-Backend/trr_backend/socials/twitter/scraper.py`
  - surfaces retryable fallback exhaustion when GraphQL plus Twikit/Playwright-style fallback paths cannot complete history retrieval
  - emits fallback progress and checked counters into retrieval metadata
- `TRR-Backend/trr_backend/socials/threads/scraper.py`
  - surfaces retryable GraphQL page-fetch failure and fallback post-fetch failure metadata instead of silently ending as success
- `TRR-Backend/trr_backend/socials/youtube/scraper.py`
  - records continuation fetch failures as retryable retrieval errors
  - normalizes shared progress metadata to `pages_scanned` and `posts_checked`
- `TRR-Backend/trr_backend/socials/facebook/scraper.py`
  - surfaces retryable surface/candidate fetch failures when catalog retrieval ends empty after fetch errors
- `TRR-Backend/supabase/migrations/0202_shared_account_facebook_catalog.sql`
  - creates `social.facebook_account_catalog_posts`
  - adds indexes, grants, RLS, and review-queue platform support for Facebook
- `TRR-Backend/scripts/reload_postgrest_schema.sh`
  - now parses `.env` safely through a generated quoted export file instead of `xargs`, allowing the schema-reload step to succeed with real workspace env values

## App
- `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts`
  - added `facebook` to `SOCIAL_ACCOUNT_CATALOG_ENABLED_PLATFORMS`
  - preserved the additive dispatch-health contract on run-progress snapshots
- `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`
  - now expects Facebook catalog actions to render through the shared profile UI rather than the old unsupported-platform message

## Validation
- Backend targeted tests
  - `pytest /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/test_social_season_analytics.py -k 'scrape_shared_twitter_posts_catalog_adds_profile_snapshot or scrape_shared_threads_posts_catalog_adds_profile_snapshot or scrape_shared_youtube_posts_catalog_persists_profile_snapshot_and_totals or scrape_shared_facebook_posts_catalog_persists_rows_and_progress or structured_retrieval_error or dispatch_due_social_jobs_skips_redispatch_when_modal_call_is_pending or recover_stale_unclaimed_dispatched_jobs_keeps_pending_modal_calls_in_place or get_social_account_catalog_run_progress_reports_waiting_modal_dispatch_as_queued or build_run_dispatch_health_counts_modal_pending_and_running_jobs'`
  - `pytest /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/api/routers/test_socials_season_analytics.py -k 'post_social_account_catalog_backfill_additional_supported_platforms'`
  - `pytest /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/socials/test_twitter_rate_limiting.py -k 'exhausted_fallback_chain_as_retryable or successful_twikit_fallback'`
  - `pytest /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/socials/test_threads_scraper.py -k 'page_fetch_failure_as_retryable'`
  - `pytest /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/socials/youtube/test_scraper.py -k 'continuation_fetch_failure_as_retryable'`
  - `pytest /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/socials/test_facebook_engagement.py -k 'surface_fetch_failures_as_retryable'`
- Backend hygiene
  - `python -m compileall /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/twitter/scraper.py /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/threads/scraper.py /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/youtube/scraper.py /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/facebook/scraper.py`
  - `ruff check /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/twitter/scraper.py /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/threads/scraper.py /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/youtube/scraper.py /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/facebook/scraper.py /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/test_social_season_analytics.py /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/api/routers/test_socials_season_analytics.py /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/socials/test_threads_scraper.py /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/socials/youtube/test_scraper.py /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/socials/test_twitter_rate_limiting.py /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/socials/test_facebook_engagement.py`
  - `ruff format --check /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/twitter/scraper.py /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/threads/scraper.py /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/youtube/scraper.py /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/facebook/scraper.py /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/test_social_season_analytics.py /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/api/routers/test_socials_season_analytics.py /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/socials/test_threads_scraper.py /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/socials/youtube/test_scraper.py /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/socials/test_twitter_rate_limiting.py /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/socials/test_facebook_engagement.py`
  - `make schema-docs-check`
  - `./scripts/reload_postgrest_schema.sh`
- App validation
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec vitest run tests/social-account-profile-page.runtime.test.tsx -c vitest.config.ts --pool=forks --poolOptions.forks.singleFork`
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec eslint src/lib/admin/social-account-profile.ts tests/social-account-profile-page.runtime.test.tsx`
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec next build --webpack`
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web run lint`

## Caveats
- A full `ruff check .` and `ruff format --check .` in `TRR-Backend` still report unrelated pre-existing issues in baseline files outside this change set, including benchmark scripts and older social scraper/test modules. The touched backfill hardening files listed above pass targeted Ruff checks.
- This implementation establishes Facebook shared-account catalog support and live-progress parity, but it does not add Instagram/TikTok-style discovery/frontier partitioning to Facebook. Facebook remains on the bounded shared catalog runner for now.

## 2026-03-22 Follow-Up
- Facebook shared-account catalog scrapes now persist a `profile_snapshot` into retrieval metadata and shared-account source metadata instead of dropping identity entirely after fetch.
- `get_social_account_profile_summary(...)` now includes Facebook in the identity-field merge path, so the shared admin profile can surface Facebook `display_name`, `avatar_url`, and `profile_url` from source snapshot data the same way it already does for other shared catalog platforms.
- Follow-up validation:
  - `ruff check /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/test_social_season_analytics.py`
  - `pytest /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/test_social_season_analytics.py -k 'scrape_shared_facebook_posts_catalog_persists_rows_and_progress or includes_facebook_identity_from_source_snapshot'`
