# Shared account catalog backfill and profile UI

Last updated: 2026-03-17

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-17
  current_phase: "complete"
  next_action: "Use the clean Supabase preview branch for schema-doc validation until staging drift is reconciled"
  detail: self
```

- `TRR-Backend` now supports `shared_account_catalog_backfill` for shared `instagram`, `tiktok`, `twitter`, and `threads` accounts. The mode stages lightweight catalog rows, classifies them with known hashtag assignments, and queues unknown hashtags for async review instead of materializing heavy post data immediately.
- Added new staging tables for those four platforms plus `social.account_hashtag_review_queue` in migration `0199_shared_account_catalog_backfill.sql`.
- Added account-scoped catalog endpoints in `/api/v1/social/profiles/{platform}/{handle}/...` for summary counts, paginated catalog posts, review queue reads, historical backfill, recent sync, and review resolution.
- `TRR-APP` account profile pages at `/admin/social/[platform]/[handle]` now expose catalog-aware summary cards, `Backfill History` and `Sync Recent` actions for supported platforms, a new `catalog` tab, and an `Unknown Hashtags` review section in the hashtags tab.
- `facebook` and `youtube` remain read-only in v1; catalog actions are intentionally hidden on those account pages.
- Validation:
  - `python -m py_compile /Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/socials.py /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ruff check api/routers/socials.py trr_backend/repositories/social_season_analytics.py tests/repositories/test_social_season_analytics.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ruff format --check api/routers/socials.py trr_backend/repositories/social_season_analytics.py tests/repositories/test_social_season_analytics.py`
  - `pytest -q /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/test_social_season_analytics.py -k 'ingest_shared_accounts or social_account_profile_summary_includes_catalog_fields or social_account_profile_summary_includes_avatar_url'`
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec vitest run tests/show-admin-routes.test.ts -t 'builds and parses canonical social account profile URLs'`
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec eslint src/components/admin/SocialAccountProfilePage.tsx src/lib/admin/social-account-profile.ts src/lib/admin/show-admin-routes.ts 'src/app/admin/social/[platform]/[handle]/catalog/page.tsx' 'src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/catalog/posts/route.ts' 'src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/catalog/review-queue/route.ts' 'src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/catalog/backfill/route.ts' 'src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/catalog/sync-recent/route.ts' 'src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/catalog/review-queue/[itemId]/resolve/route.ts'`
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web run typecheck`
  - Managed Chrome validation on `http://admin.localhost:3000/admin/social/instagram/bravotv`, `/catalog`, and `/hashtags`
- Outstanding follow-up:
  - `scripts/supabase/generate_schema_docs.py` now auto-loads `TRR-Backend/.env.local` and `TRR-Backend/.env`, so schema-doc verification no longer depends on Docker or exported shell vars.
  - Migration `0199_shared_account_catalog_backfill.sql` has now been applied to the staging Supabase project (`vwxfvzutyufrkhfgoeaa`), and the staging database now contains:
    - `social.instagram_account_catalog_posts`
    - `social.tiktok_account_catalog_posts`
    - `social.twitter_account_catalog_posts`
    - `social.threads_account_catalog_posts`
    - `social.account_hashtag_review_queue`
  - `make schema-docs-check` was rerun against that same staging project and still fails, but the remaining diff is broader than `0199`:
    - `core.show_cast_overrides` is absent from the staging schema even though migration `0095_cast_overrides.sql` is recorded in `supabase_migrations.schema_migrations`.
    - Archive columns/indexes from `0096_image_archive_columns.sql` are missing on `core.cast_photos`, `core.episode_images`, and `core.season_images` even though `0096` is also recorded in `schema_migrations`.
    - Older indexes from `0087_screenalytics_cast_views.sql` are missing on `core.credits` and `core.credit_occurrences`.
    - `core.shows` still reflects legacy `external_ids` structure/indexes inconsistent with the repo's current schema-doc baseline.
  - Conclusion: schema-doc output generated from the current staging database is not safe to commit as the repo truth. The next schema-doc pass should target either:
    - a corrected staging environment after older drift is reconciled, or
    - a clean Supabase branch/database built from the repo's canonical migration stream.
  - A clean preview branch has now been created from the Supabase project:
    - branch name: `schema-docs-0199`
    - branch project ref: `tegzubwfzolwpsedxpvj`
  - The full local migration stream was pushed into that preview branch with `supabase db push --db-url <branch-db-url> --include-all`, and `make schema-docs-check` then passed cleanly with `SUPABASE_DB_URL` pointed at the branch.
  - Result: schema-doc verification is now complete on a clean remote Supabase environment, and there is no schema-doc diff to commit from that branch because the generated output matches the repo baseline.
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec next build --webpack` stalls locally without surfacing a compiler error, including under Node `v24.14.0`.
  - The app-wide `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web run typecheck` failure currently comes from unrelated `src/app/admin/games/flashback/page.tsx` Supabase typing errors, not from the shared-account catalog changes.
