# VALIDATION

## Skills / Plugins Used

- `Plan Grader: plan-grader`
- `Plan Grader: audit-plan`
- `Supabase Fullstack: supabase-fullstack-review`
- `Supabase Fullstack: supabase-security-governance`
- `Supabase Fullstack: supabase-postgres-performance`

## Files Inspected

- `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-cross-platform-social-post-schema-unification-plan.md`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/0101_social_scrape_tables.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/0152_add_facebook_and_meta_threads_social_platforms.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/0157_reddit_refresh_pipeline.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/0199_shared_account_catalog_backfill.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/0202_shared_account_youtube_catalog.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/0204_shared_account_facebook_catalog.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py`

## Supabase Live Checks

Read-only SQL confirmed:

- platform post/catalog row counts and sizes;
- source table column counts;
- existing materialized `social.twitter_tweets` and `social.youtube_videos`;
- public-read RLS policies on current social source tables;
- large comment table sizes for Instagram, TikTok, and Reddit.

## Commands Run

```bash
rg -n "create table.*(tiktok|twitter|facebook|threads|reddit|youtube).*posts|account_catalog_posts|_posts \\(" TRR-Backend/supabase/migrations -S
rg -n "PLATFORM_CATALOG_POST_TABLES|PLATFORM_POST_TABLES|PLATFORM_COMMENT_TABLES" TRR-Backend/trr_backend/repositories/social_season_analytics.py
sed -n '220,260p' TRR-Backend/trr_backend/repositories/social_season_analytics.py
```

Supabase MCP read-only queries inspected:

- `information_schema.columns`
- `pg_class` / `pg_stat_user_tables`
- `pg_policy`

## Evidence Gaps

- No migration was applied.
- No test suite was run because this was planning/audit-only.
- Query plans were not collected for proposed new indexes because those tables do not exist yet.

## Recommended Validation Before Execution

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/social_post_schema_parity.py --platform all --json
.venv/bin/python -m pytest -q tests/db tests/repositories/test_social_season_analytics.py tests/api/routers/test_socials_season_analytics.py tests/api/test_admin_reddit_reads.py -k "social or reddit"
```

