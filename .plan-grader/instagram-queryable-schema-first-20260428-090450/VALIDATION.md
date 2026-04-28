# VALIDATION: Schema-First Instagram Queryable Plan Revision

## Files Inspected

- `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-instagram-post-queryable-data-plan.md`
- `/Users/thomashulihan/Projects/TRR/.plan-grader/instagram-queryable-data-20260428-085436/REVISED_PLAN.md`
- `/Users/thomashulihan/Projects/TRR/.plan-grader/instagram-queryable-data-20260428-085436/SUGGESTIONS.md`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/0101_social_scrape_tables.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/0179_shared_social_account_ingest.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/0199_shared_account_catalog_backfill.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/20260428152000_social_post_canonical_foundation.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py` via targeted `rg`
- Plan Grader skill files under `/Users/thomashulihan/.codex/plugins/cache/local-plugins/plan-grader/1.0.0/`
- Supabase Fullstack guidance under `/Users/thomashulihan/.codex/plugins/cache/local-plugins/supabase-fullstack/1.0.0/skills/`

## Commands Run

```bash
sed -n '1,180p' /Users/thomashulihan/.codex/plugins/cache/local-plugins/plan-grader/1.0.0/SKILL.md
sed -n '1,260p' .plan-grader/instagram-queryable-data-20260428-085436/SUGGESTIONS.md
sed -n '1,130p' TRR-Backend/supabase/migrations/0101_social_scrape_tables.sql
sed -n '1,240p' TRR-Backend/supabase/migrations/0199_shared_account_catalog_backfill.sql
sed -n '1,220p' TRR-Backend/supabase/migrations/20260428152000_social_post_canonical_foundation.sql
sed -n '220,360p' TRR-Backend/supabase/migrations/20260428152000_social_post_canonical_foundation.sql
rg -n "instagram_account_catalog_posts|instagram_posts|instagram_comments|shared_account_sources|social_post" TRR-Backend/trr_backend/repositories/social_season_analytics.py
python3 -m json.tool .plan-grader/instagram-queryable-schema-first-20260428-090450/result.json
```

## Evidence Notes

- `0101_social_scrape_tables.sql` creates legacy `social.instagram_posts` and `social.instagram_comments`.
- `0199_shared_account_catalog_backfill.sql` creates `social.instagram_account_catalog_posts` and grants public read policies.
- `20260428152000_social_post_canonical_foundation.sql` creates the newer cross-platform canonical tables and keeps raw observations/legacy refs private from public/anon/authenticated grants.
- `social_season_analytics.py` still has many direct legacy Instagram table reads/writes, so bridge and compatibility decisions are necessary.

## Evidence Gaps

- This revision did not run live Supabase MCP/schema queries. Phase 0 requires live or static schema confirmation before migrations.
- The storage map still needs to be written as an implementation artifact before any schema worker starts.

## Recommended Validation Before Execution

1. Run Phase 0 and save `docs/ai/local-status/instagram-queryable-schema-decision-2026-04-28.md`.
2. Confirm RLS/grants for canonical, legacy, profile, following, and raw observation surfaces.
3. Confirm which legacy reads require temporary bridge columns.
4. Confirm no follower-list scrape stage, table, or route is introduced.
