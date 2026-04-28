# Patches

These are plan patches, not code patches.

## Patch 1 - Accept All Prior Suggestions

Integrated every numbered item from `.plan-grader/social-profile-linked-run-cancel-and-progress-20260428-190224/SUGGESTIONS.md` into the plan under the exact phase heading `ADDITIONAL SUGGESTIONS`.

Mapped suggestions:

1. Run Timeline Drawer
2. Cancel All Active Lanes Action
3. One-Account Run-State CLI
4. Active-Lane Debug JSON Button
5. Progress Freshness Badge
6. DB Pressure Hint On Degraded Summary
7. Run-State Contract Fixtures
8. Cancel Audit Event Table
9. Remote Invocation Status Refresh
10. Canary Account Verification

Each task now includes concrete changes, dependencies, affected surfaces, validation, acceptance criteria, and commit boundary.

## Patch 2 - Add Final Reset And Fresh Backfill Phase

Added `Final Phase - Post-Implementation Traitors US Reset And Fresh Backfill`.

This phase:

- runs only after implementation verification,
- requires action-time confirmation before deletion,
- uses Supabase Fullstack preflight and post-checks,
- clears only account-scoped Instagram post-derived rows for `@thetraitorsus`,
- confirms zero state in the UI with Browser Use,
- launches a fresh backfill with Browser Use only after zero-state proof.

## Patch 3 - Update Goals And Non-Goals

Added goals for accepted suggestions and reset/backfill proof.

Replaced the broad `No production data deletion` non-goal with a narrower boundary:

- no deletion during core implementation,
- final reset is destructive, account-scoped, and action-time confirmed,
- no profile/following cleanup,
- no scrape run/job history deletion,
- no `TRUNCATE`.

## Patch 4 - Add Supabase Reset Evidence

Added read-only Supabase facts to `project_context`:

- cascade from `instagram_posts` to `instagram_comments`,
- cascade from catalog posts to catalog collaborators,
- cascade from canonical `social_posts` to canonical child tables,
- current target counts for materialized, catalog, comment, and canonical rows.

## Patch 5 - Update Validation And Acceptance

Added validation for:

- accepted suggestion tests,
- Supabase preflight/post-delete counts,
- Browser Use zero-state confirmation,
- Browser Use fresh backfill launch,
- Supabase confirmation of new run/job rows.

Added acceptance criteria for zero-state proof and fresh backfill ordering.
