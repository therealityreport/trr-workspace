# Validation - Supabase Schema Design Repair Plan

## Files Inspected

- `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-supabase-schema-design-repair-plan.md`
- `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-cross-platform-social-post-schema-unification-plan.md`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/config.toml`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/local-postgrest-schema-exposure.md`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/migration-ownership-policy.md`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-advisor-performance-closeout-2026-04-28.md`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/0101_social_scrape_tables.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/0199_shared_account_catalog_backfill.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/20260428114500_instagram_catalog_post_collaborators.sql`

## Commands Run

```bash
sed -n '1,260p' /Users/thomashulihan/.codex/plugins/cache/local-plugins/plan-grader/1.0.0/SKILL.md
sed -n '1,260p' /Users/thomashulihan/.codex/plugins/cache/local-plugins/supabase-fullstack/1.0.0/skills/supabase-fullstack-review/SKILL.md
sed -n '1,220p' /Users/thomashulihan/.codex/plugins/cache/local-plugins/supabase-fullstack/1.0.0/skills/supabase-postgres-performance/SKILL.md
sed -n '1,220p' /Users/thomashulihan/.codex/plugins/cache/local-plugins/supabase-fullstack/1.0.0/skills/supabase-security-governance/SKILL.md
sed -n '1,260p' /Users/thomashulihan/Documents/Codex/2026-04-21-create-a-rubric-for-scoring-an/implementation-plan-rubric.md
ls -la docs/codex/plans
rg -n "instagram_account_post_catalog|instagram_post_entities|instagram_post_media_assets|instagram_account_catalog_posts|instagram_posts|source_account|shortcode" ...
```

## Supabase MCP Evidence

Query confirmed:

- Existing tables:
  - `social.instagram_posts`
  - `social.instagram_account_catalog_posts`
  - `social.instagram_account_catalog_post_collaborators`
  - `social.instagram_comments`
- Missing proposed tables:
  - `social.instagram_account_post_catalog`
  - `social.instagram_post_entities`
  - `social.instagram_post_media_assets`
- RLS is enabled on the existing Instagram target tables.

## Evidence Gaps

- No plan implementation commands were run.
- No tests were run because this task is Plan Grader artifact generation, not implementation.
- Live row counts are approximate via Postgres stats and should be refreshed in Phase 0 before migration execution.
- Security Advisor residuals were not rechecked in this Plan Grader run; the revised plan keeps them as a dedicated governance gate.

## Assumptions

- The source plan under `docs/codex/plans/2026-04-28-supabase-schema-design-repair-plan.md` is the plan the user wanted graded.
- The missing Instagram-specific plan should not remain a required dependency because it is absent from the current repo state.
- Supabase MCP SQL evidence is sufficient for plan validation; production DDL remains owner-controlled.
