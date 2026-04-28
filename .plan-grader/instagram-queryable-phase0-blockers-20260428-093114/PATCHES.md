# Patch Map

Source plan: `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-instagram-post-queryable-data-plan.md`

Revised plan: `/Users/thomashulihan/Projects/TRR/.plan-grader/instagram-queryable-phase0-blockers-20260428-093114/REVISED_PLAN.md`

## Required Changes Applied

1. Added Commit -1 preflight before Phase 0 requiring target-branch and live/local proof of the canonical social post foundation tables.
2. Added Phase 0 legacy raw-data exposure audit covering `instagram_posts.raw_data`, `instagram_comments.raw_data`, `instagram_account_catalog_posts.raw_data`, `social_post_observations.raw_payload`, `social_post_observations.normalized_payload`, and planned profile raw columns.
3. Added a required raw exposure strategy decision with preferred, transitional, and minimal paths before Phase 2/5 implementation.
4. Made profile snapshot/following job-type or `config.stage` compatibility a hard Phase 0 and Phase 2 criterion.
5. Replaced loose child table parent strategy with default `canonical_post_id` ownership and `social.social_post_legacy_refs` traceability.
6. Removed embedded/latest comment persistence from scope:
   - no `social.instagram_post_embedded_comments`;
   - no `_sync_instagram_post_embedded_comments`;
   - no `latestComments` upsert to `social.instagram_comments`;
   - no embedded sample API count or UI section.
7. Reclassified `latestComments`, `firstComment`, and XDT embedded comment snapshots as raw-only diagnostics or ignored partial sample fields.
8. Narrowed backfill acceptance by payload family:
   - post/comment rows only where `raw_data` contains required source fields;
   - profile/about/external links only where full profile payloads exist;
   - following rows generally require fresh bounded following scrapes unless prior following raw payloads exist.
9. Added API contract appendix gate before Phase 5 with route names, response examples, pagination, admin-only fields, and excluded public/client fields.
10. Expanded RLS/grant validation to classify both legacy and new raw-data surfaces.
11. Added profile/about privacy and session-dependence classification requirements with the requested `about.accounts_with_shared_followers` example.
12. Added Phase 2 index/performance gate for broad GIN/trigram indexes, table-size/lock notes, concurrent/maintenance-window preference, and rollback/disable notes.
13. Changed `ready_for_execution` to Phase 0 only, with Phase 1+ conditional and Phase 2+ blocked.
14. Updated final acceptance criteria to reflect canonical homes, no silent duplicate child storage, comments only from full comments scrape, legacy raw grant reality, and constrained backfill.
15. Revised Phase 1 field inventory to use actual Instagram source families from repo code as canonical field/tag inputs:
   - XDT profile timeline GraphQL connection;
   - shortcode GraphQL;
   - media-info REST;
   - permalink HTML/meta fallbacks;
   - web profile info;
   - comments REST;
   - following-list source pending actual fetcher/job-stage selection.
16. Reclassified Apify names as adapter/reference aliases only.
17. Added the Phase 0 decision artifact at `docs/ai/local-status/instagram-queryable-schema-decision-2026-04-28.md` with storage map, live Supabase evidence, raw exposure classification, job-stage recommendation, actual Phase 1 source-family direction, comment-scope decision, and Phase 1+ approval blockers.

## Supabase Fullstack Confirmation Inputs

- Static migration evidence:
  - `TRR-Backend/supabase/migrations/20260428152000_social_post_canonical_foundation.sql`
  - `TRR-Backend/supabase/migrations/0101_social_scrape_tables.sql`
  - `TRR-Backend/supabase/migrations/0199_shared_account_catalog_backfill.sql`
  - `TRR-Backend/supabase/migrations/0179_shared_social_account_ingest.sql`
  - `TRR-Backend/supabase/migrations/20260323175500_add_social_post_search_indexes.sql`
- Live Supabase read-only checks:
  - canonical foundation tables exist in `social`;
  - legacy raw-data tables have `anon` and `authenticated` table-level `SELECT` grants/policies;
  - `social.social_post_observations` is service-role only;
  - live `scrape_jobs_job_type_check_v6` does not include profile-specific job types.
- Target branch check:
  - `TRR-Backend/supabase/migrations/20260428152000_social_post_canonical_foundation.sql` exists on disk but is untracked in the nested backend checkout, so target-branch proof remains incomplete.
