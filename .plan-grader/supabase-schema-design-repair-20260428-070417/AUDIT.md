# Audit - Supabase Schema Design Repair Plan

Source plan: `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-supabase-schema-design-repair-plan.md`

Reviewer mode: Plan Grader with Supabase Fullstack schema, RLS/governance, and Postgres performance review.

## VERDICT

Revise before execution.

The plan has the right architecture direction and correctly centers the Instagram split first, but it is not approval-clean because a key dependency path is missing and several Supabase-specific execution details remain implicit. The revised plan in this package is execution-ready after approval.

## Current-State Fit

Confirmed current state:

- `social.instagram_posts` exists, has RLS enabled, has about `1,583` rows, `62` columns, `13` JSONB columns, and is the FK target for `social.instagram_comments`.
- `social.instagram_account_catalog_posts` exists, has RLS enabled, has about `29,799` rows, `41` columns, `9` JSONB columns, and has no FK to `social.instagram_posts`.
- `social.instagram_account_catalog_post_collaborators` exists, has RLS enabled, and has about `5,874` rows.
- Proposed new tables do not exist yet: `social.instagram_account_post_catalog`, `social.instagram_post_entities`, and `social.instagram_post_media_assets`.
- Current repo plan references `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-instagram-post-schema-unification-plan.md`, but that file is not present in `docs/codex/plans/` at audit time. A cross-platform plan exists instead.

## Benefit Score

High. This work addresses a real schema-design defect that is already visible in live table size, duplication, and backend query shape. Fixing it should reduce catalog/profile inconsistency, make scraper writes more deterministic, and give future platform cleanup a safer model.

## Blocking Plan Errors

1. Missing delegated source plan.
   The source plan delegates Phase 1 to a missing Instagram-specific plan file. That makes the most important migration phase non-executable from the artifact itself.

2. Membership identity is underspecified.
   The plan says `(account_handle, post_id)` but does not define normalized vs display account handles. In this repo, reads commonly use `ltrim(lower(...), '@')`; a case-sensitive text PK would preserve the current inconsistency.

3. Metric merge semantics are still an open question.
   The plan says conflicts should be visible, but the write-path/backfill phases still need a concrete policy for preserving current `max(existing_views, incoming_views)` behavior and recording lower-confidence observations.

4. Additive migration is not detailed enough for Supabase rollout safety.
   The plan needs explicit verifier SQL, rollback boundaries, RLS/grant checks, and type-widening stop rules before production DDL.

5. Read-path migration does not name the legacy fallback kill switch clearly enough.
   The plan asks for fallback telemetry but does not define a switch, expected zero-fallback gate, or how execution should stop before retirement.

## Required Fixes Applied In REVISED_PLAN.md

- Removed dependency on the missing Instagram-specific plan.
- Inlined the additive schema design for canonical support, membership, entities, media, and scraper observations.
- Added normalized display/key columns for account and entity identity.
- Added explicit metric merge and observation rules.
- Added migration verifier, rollback, and production DDL gates.
- Added a legacy fallback flag, fallback counter, and retirement stop rule.
- Tightened execution handoff to sequential `orchestrate-plan-execution`.

## Approval Decision

Approve the revised plan, not the original source plan.

The revised plan is suitable for implementation after owner approval, starting with Phase 0 only. Do not apply destructive DDL or legacy retirement until parity and fallback gates pass.
