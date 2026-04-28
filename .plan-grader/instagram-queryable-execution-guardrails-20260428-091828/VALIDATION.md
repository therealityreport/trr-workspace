# VALIDATION: Execution Guardrails Revision

## Files Inspected

- `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-instagram-post-queryable-data-plan.md`
- `/Users/thomashulihan/Projects/TRR/.plan-grader/instagram-queryable-schema-first-20260428-090450/REVISED_PLAN.md`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/20260323173500_add_instagram_post_search_columns.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/20260428114500_instagram_catalog_post_collaborators.sql`
- Plan Grader skill files under `/Users/thomashulihan/.codex/plugins/cache/local-plugins/plan-grader/1.0.0/`

## Commands Run

```bash
wc -l TRR-Backend/trr_backend/repositories/social_season_analytics.py
rg -n "_upsert_instagram_post\(" TRR-Backend/trr_backend/repositories/social_season_analytics.py
ls -1 TRR-Backend/supabase/migrations/*instagram*search* TRR-Backend/supabase/migrations/20260428114500_instagram_catalog_post_collaborators.sql
sed -n '1,220p' TRR-Backend/supabase/migrations/20260323173500_add_instagram_post_search_columns.sql
sed -n '1,220p' TRR-Backend/supabase/migrations/20260428114500_instagram_catalog_post_collaborators.sql
```

## Evidence

- `social_season_analytics.py` has `60646` lines.
- `_upsert_instagram_post` is defined once and invoked at seven call sites.
- `20260323173500_add_instagram_post_search_columns.sql` adds `search_text`, `search_hashtags`, `search_handles`, and `search_handle_identities` to `social.instagram_posts`.
- `20260428114500_instagram_catalog_post_collaborators.sql` creates `social.instagram_account_catalog_post_collaborators`, indexes it by collaborator handle and source account, backfills from catalog collaborators, grants read access, and enables RLS.

## Evidence Gaps

- This revision did not run live Supabase schema inspection. Phase 0 still requires static or live schema confirmation before migrations.
- Actual worker ownership must be assigned by the execution orchestrator after Phase 0 approval.

## Required Pre-Execution Checks

1. Phase 0 decision note exists.
2. User explicitly approves Phase 0.
3. `social_season_analytics.py` owner is named.
4. All other worker scopes mark `social_season_analytics.py` read-only.
5. Partial unique indexes and ID-upgrade flow are in the migration/persistence plan.
6. Existing search columns and catalog collaborators table are reconciled.
