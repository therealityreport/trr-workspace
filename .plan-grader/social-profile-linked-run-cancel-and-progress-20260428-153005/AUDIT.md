# Audit

Verdict: approved after revision

Previous revised score: 94 / 100

New revised score estimate: 96 / 100

Approval decision: use this revised plan instead of the prior package.

## Current-State Fit

The prior plan correctly fixed the main active-lane, cancel, summary-timeout, and comments-count issues. This revision incorporates all ten previously optional suggestions as required work under `ADDITIONAL SUGGESTIONS` and adds the user's requested final reset/backfill phase.

The reset phase is deliberately placed after implementation verification because it is destructive. It uses Supabase Fullstack for read-only preflight and post-checks, then requires action-time confirmation before any delete. It then uses Browser Use to confirm zero UI state before launching a fresh backfill.

## Supabase Fullstack Fit

Read-only Supabase checks confirmed the reset cannot safely target only `social.instagram_posts` if the UI needs to show zero everywhere:

- `social.instagram_comments.post_id` cascades from `social.instagram_posts.id`.
- `social.instagram_account_catalog_post_collaborators.catalog_post_id` cascades from `social.instagram_account_catalog_posts.id`.
- canonical `social_post_*` child tables cascade from `social.social_posts`.
- Current `@thetraitorsus` post-derived rows exist in materialized, catalog, comments, and canonical tables.

## Required Fixes Added

- Integrated all ten prior suggestions into the plan body as required tasks.
- Added the final account-scoped reset/backfill phase.
- Added a destructive-action safety gate requiring action-time user confirmation.
- Added Supabase preflight/post-check requirements for target counts and cascade rules.
- Added Browser Use zero-state UI confirmation before fresh backfill.
- Added Browser Use fresh backfill launch and Supabase confirmation of the new run.

## Biggest Risks

- The final reset deletes local/cloud database rows and must not run from plan text alone.
- A partial reset could leave catalog or canonical rows that keep UI counters nonzero.
- A fresh backfill can repopulate rows quickly, so zero-state evidence must be captured before the launch.

## Benefit Score

Benefit score: 9 / 10

The accepted suggestions improve operator diagnosis and durability. The reset/backfill workflow provides a clean proof loop for the fixed ingest UI while keeping destructive work gated.
