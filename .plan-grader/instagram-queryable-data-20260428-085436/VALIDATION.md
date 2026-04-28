# VALIDATION: Instagram Queryable Data Plan

## Files Inspected

- `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-instagram-post-queryable-data-plan.md`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/0179_shared_social_account_ingest.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/0101_social_scrape_tables.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/0147_instagram_enhanced_metadata.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/0199_shared_account_catalog_backfill.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/20260421124500_instagram_comment_hosted_author_profile_pic.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/20260421133000_instagram_comments_parent_same_post_trigger.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/instagram/posts_scrapling/persistence.py`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/instagram/runtimes/protocol.py`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py` via targeted `rg`
- Plan Grader skill files under `/Users/thomashulihan/.codex/plugins/cache/local-plugins/plan-grader/1.0.0/`
- Scrapling routing skill under `/Users/thomashulihan/.codex/plugins/cache/local-plugins/scrapling/0.3.0/skills/scrapling/SKILL.md`
- Rubric at `/Users/thomashulihan/Documents/Codex/2026-04-21-create-a-rubric-for-scoring-an/implementation-plan-rubric.md`

## Commands Run

```bash
sed -n '1,240p' /Users/thomashulihan/.codex/plugins/cache/local-plugins/plan-grader/1.0.0/skills/plan-grader/SKILL.md
sed -n '1,320p' /Users/thomashulihan/.codex/plugins/cache/local-plugins/plan-grader/1.0.0/SKILL.md
sed -n '1,220p' /Users/thomashulihan/.codex/plugins/cache/local-plugins/scrapling/0.3.0/skills/scrapling/SKILL.md
sed -n '1,260p' /Users/thomashulihan/Documents/Codex/2026-04-21-create-a-rubric-for-scoring-an/implementation-plan-rubric.md
sed -n '260,620p' /Users/thomashulihan/Documents/Codex/2026-04-21-create-a-rubric-for-scoring-an/implementation-plan-rubric.md
rg -n "PROFILE_INFO_URL|fetch_profile|web_profile_info|following_count|biography|instagram_comments|instagram_posts|instagram_account_catalog_posts|shared_account_sources|comments_scrapling|posts_scrapling|profile_pic|external_url|followers_count|follows_count" TRR-Backend/trr_backend TRR-Backend/supabase/migrations TRR-Backend/tests -g '!**/__pycache__/**'
rg -n "create table if not exists social\.shared_account_sources|shared_account_sources" TRR-Backend/supabase/migrations/0179_shared_social_account_ingest.sql TRR-Backend/supabase/migrations -g '*.sql'
rg -n "create table.*instagram_posts|create table.*instagram_comments|instagram_account_catalog_posts|author_profile_pic_url|reply_count|parent_comment_id" TRR-Backend/supabase/migrations -g '*.sql'
sed -n '49,90p' TRR-Backend/supabase/migrations/0179_shared_social_account_ingest.sql
sed -n '1,260p' TRR-Backend/trr_backend/socials/instagram/posts_scrapling/persistence.py
sed -n '1,260p' TRR-Backend/trr_backend/socials/instagram/runtimes/protocol.py
```

## Evidence Notes

- `social.shared_account_sources` has `id`, `platform`, `source_scope`, `account_handle`, metadata, scrape run/job pointers, RLS, and service-role grants. The revised profile table must link back here.
- `posts_scrapling/persistence.py` defines `_ScraplingPostDTO` and narrows Graph/XDT fields before `_upsert_instagram_post`, matching the plan's normalization concern.
- `runtimes/protocol.py` currently exposes reduced `ProfileInfo` with username/user id/full name/biography/follower/following/post/private/verified fields only.
- Instagram comments already have parent/reply shape and author avatar support in migrations, so the plan's comment work should be additive and gap-focused.

## Evidence Gaps

- This audit did not query the live Supabase schema. Phase 0 in the revised plan requires current table/column verification before migrations.
- This audit did not perform live Instagram/Scrapling extraction. The Scrapling plugin was not needed because the plan question was execution quality, not live site behavior.
- Raw full profile/about payload availability is not confirmed. Revised plan requires proving it before promising full backfill.

## Recommended Validation Before Execution

1. Run Phase 0 baseline and save it under `docs/ai/local-status/`.
2. Confirm live/local schema columns for the Instagram tables and `shared_account_sources`.
3. Confirm chosen job-stage names can be claimed and observed by the existing scrape job system.
4. Confirm whether raw full profile payloads currently exist; if not, mark profile backfill as partial and queue bounded profile snapshot scrape.
