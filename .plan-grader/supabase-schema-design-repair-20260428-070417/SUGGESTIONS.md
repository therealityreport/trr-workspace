# Suggestions - Optional Improvements

These are optional follow-ups. Required fixes were incorporated into `REVISED_PLAN.md`.

1. Title: Add source-runtime provenance table
   Type: Medium
   Why: Canonical rows will become more trustworthy if scraper/runtime/source confidence is queryable.
   Where it would apply: `social.instagram_post_observations` or future shared observation tables.
   How it could improve the plan: Makes metric and media conflicts easier to audit after rollout.

2. Title: Add query-plan snapshots for before and after
   Type: Medium
   Why: The plan focuses on schema correctness, but query cost is a core Supabase concern.
   Where it would apply: `TRR-Backend/scripts/db/hot_path_explain/`.
   How it could improve the plan: Gives concrete evidence that JSON expansion was reduced.

3. Title: Add fallback counter to admin health endpoint
   Type: Small
   Why: Fallback reads should be visible without log digging.
   Where it would apply: backend social profile diagnostics or app DB pressure card.
   How it could improve the plan: Gives operators a simple legacy-dependency signal.

4. Title: Create a temporary compatibility view
   Type: Medium
   Why: Some ad hoc SQL may still expect the legacy catalog shape.
   Where it would apply: post-retirement compatibility phase.
   How it could improve the plan: Eases transition away from `instagram_account_catalog_posts`.

5. Title: Add ownership comments on new tables
   Type: Small
   Why: Future agents need to know which tables are canonical, membership, observations, or compatibility.
   Where it would apply: migration DDL `comment on table`.
   How it could improve the plan: Reduces future schema drift.

6. Title: Add generated normalized columns if Postgres expression rules fit
   Type: Medium
   Why: Code-populated normalized keys can drift if helper behavior changes.
   Where it would apply: `account_handle_normalized`, `entity_key_normalized`.
   How it could improve the plan: Moves normalization enforcement closer to the DB.

7. Title: Add retention policy for raw observations
   Type: Medium
   Why: Observation tables can grow quickly.
   Where it would apply: `social.instagram_post_observations`.
   How it could improve the plan: Keeps storage growth bounded while preserving auditability.

8. Title: Build a cross-platform schema inventory report
   Type: Medium
   Why: The platform-review phase needs consistent data.
   Where it would apply: `TRR-Backend/scripts/db/social_catalog_schema_inventory.py`.
   How it could improve the plan: Makes future platform prioritization less subjective.

9. Title: Add RLS policy regression SQL fixtures
   Type: Medium
   Why: New public-read tables can accidentally drift into broader write exposure.
   Where it would apply: `TRR-Backend/tests/db/`.
   How it could improve the plan: Catches security regressions before deployment.

10. Title: Add app fixture snapshots for response-envelope parity
    Type: Small
    Why: The app contract is supposed to remain unchanged.
    Where it would apply: `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`.
    How it could improve the plan: Makes response-shape compatibility easier to verify.
