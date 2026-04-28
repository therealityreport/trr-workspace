# Validation

## Files Inspected

- `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-social-profile-linked-run-cancel-and-progress-plan.md`
- `/Users/thomashulihan/Projects/TRR/.plan-grader/social-profile-linked-run-cancel-and-progress-20260428-190224/SUGGESTIONS.md`
- `/Users/thomashulihan/Projects/TRR/.plan-grader/social-profile-linked-run-cancel-and-progress-20260428-190224/REVISED_PLAN.md`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/config.toml`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/`
- `/Users/thomashulihan/Projects/TRR/TRR-APP/package.json`
- `/Users/thomashulihan/Documents/Codex/2026-04-21-create-a-rubric-for-scoring-an/implementation-plan-rubric.md`

## Supabase Fullstack Read-Only Evidence

Read-only FK/counter checks were run through Supabase MCP.

Findings:

- `social.instagram_comments.post_id` references `social.instagram_posts.id` with `ON DELETE CASCADE`.
- `social.instagram_account_catalog_post_collaborators.catalog_post_id` references `social.instagram_account_catalog_posts.id` with `ON DELETE CASCADE`.
- canonical `social_post_entities`, `social_post_legacy_refs`, `social_post_media_assets`, `social_post_memberships`, and `social_post_observations` reference `social.social_posts` with `ON DELETE CASCADE`.
- At `2026-04-28T19:31:37Z`, current `@thetraitorsus` counts included:
  - `431` `social.instagram_posts`,
  - `431` `social.instagram_account_catalog_posts`,
  - `578` `social.instagram_account_catalog_post_collaborators`,
  - `18,765` `social.instagram_comments` by post FK,
  - `431` canonical posts linked by legacy refs,
  - `858` canonical media assets,
  - `2,103` canonical entities,
  - `432` canonical observations.

## Browser Use

No Browser Use action was needed for this planning-only revision. The revised plan specifies Browser Use for final zero-state confirmation and fresh backfill launch.

## Commands Run

```bash
find /Users/thomashulihan/Projects/TRR -maxdepth 3 \( -path '*/node_modules' -o -path '*/.git' -o -path '*/.next' \) -prune -o \( -path '*/supabase/config.toml' -o -path '*/supabase/migrations' -o -name 'package.json' -o -name 'pyproject.toml' \) -print
rg -n "instagram_posts|instagram_comments|source_account|thetraitorsus|delete from social\\.instagram|truncate social\\.instagram|comments saved|Posts" TRR-Backend TRR-APP/apps/web/src -g '!**/node_modules/**'
date +%Y%m%d-%H%M%S
```

## Tests Not Run

No implementation tests were run because this task revised planning artifacts only.

## Remaining Execution Gates

- Before final reset, rerun Supabase preflight counts because counts can drift.
- Before final reset, stop and ask for action-time confirmation.
- Before fresh backfill, capture Browser Use zero-state proof.
