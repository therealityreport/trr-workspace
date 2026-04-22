# TikTok Backfill Auto Cookie Repair

Last updated: 2026-04-22

## Status

- State: implemented
- Scope: complete for the approved TikTok `Backfill Posts` admin workflow
- Rollback gate: `SOCIAL_TIKTOK_CATALOG_BACKFILL_COMMENT_OVERRIDE_ENABLED`

## Goal

Make TikTok `Backfill Posts` launch the full selected workflow in one run, automatically repair unhealthy-but-refreshable cookies before launch, and keep run progress truthful across repair, launch, comments, media, and post-detail follow-up.

## Implemented Behavior

- The app now always launches TikTok catalog backfills with:
  - `selected_tasks: ["post_details", "comments", "media"]`
- The app now auto-starts cookie repair before TikTok backfill when:
  - cookie health is unhealthy
  - refresh is available
  - the repair action is `cookie_refresh`
- TikTok keeps a single catalog-run model:
  - `catalog_run_id` is the real run
  - `comments_run_id` remains `null`
  - `selected_tasks` and `effective_selected_tasks` are preserved on the catalog run
- The backend repair flow is platform-aware:
  - Instagram still uses `repair_instagram_auth`
  - TikTok now uses `cookie_refresh`
- TikTok shared-account ingest now explicitly enables:
  - post details
  - comments
  - media follow-ups
- TikTok direct comment API enablement is now available as a workflow-scoped override for catalog backfills even when the global experiment flag is off.
- The workflow-scoped comment override can be disabled independently through:
  - `SOCIAL_TIKTOK_CATALOG_BACKFILL_COMMENT_OVERRIDE_ENABLED`

## Files Landed

- `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`
- `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts`
- `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`
- `TRR-Backend/api/routers/socials.py`
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- `TRR-Backend/trr_backend/socials/tiktok/scraper.py`
- `TRR-Backend/tests/api/routers/test_socials_season_analytics.py`
- `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- `TRR-Backend/tests/socials/test_comment_scraper_fixes.py`

## Validation

- Backend targeted validation passed:
  - `pytest TRR-Backend/tests/api/routers/test_socials_season_analytics.py -q`
  - `pytest TRR-Backend/tests/repositories/test_social_season_analytics.py -q`
  - `pytest TRR-Backend/tests/socials/test_comment_scraper_fixes.py -q`
- App targeted validation passed:
  - `pnpm -C TRR-APP/apps/web exec vitest run tests/social-account-profile-page.runtime.test.tsx`
- Repo validation follow-ups completed:
  - `pnpm -C TRR-APP/apps/web run lint`
  - `pnpm -C TRR-APP/apps/web exec next build --webpack`
  - `pnpm -C TRR-APP/apps/web run test:ci`
- Additional app follow-ups fixed during validation:
  - refreshed stale generated admin API references inventory
  - hardened `admin-social-page-auth-bypass` against accessible-name drift

## Notes

- `ruff check .` and `ruff format --check .` in `TRR-Backend` still fail on broad pre-existing repo-baseline issues outside this TikTok scope.
- No TikTok task picker was added.
- No global TikTok direct-comment enablement was added.
