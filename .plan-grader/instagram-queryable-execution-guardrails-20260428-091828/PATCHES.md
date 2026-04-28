# PATCHES: Execution Guardrails Revision

## Patch 1: Protect `social_season_analytics.py`

Added a hard hot-file ownership rule:

- exactly one writer owns `TRR-Backend/trr_backend/repositories/social_season_analytics.py`;
- all other workers are read-only on that file;
- patch requests route through the monolith owner;
- Phase 4 and Phase 5 explicitly call out this ownership boundary.

## Patch 2: Add Human Approval Gate After Phase 0

Added a required pause after Phase 0:

- write `docs/ai/local-status/instagram-queryable-schema-decision-2026-04-28.md`;
- request user approval;
- do not start Phase 1, migrations, normalizers, or subagent fan-out until approval.

## Patch 3: Fix Profile Identity Uniqueness

Replaced vague uniqueness with explicit partial unique indexes:

- unique `profile_id` only where `profile_id is not null`;
- unique `(source_scope, normalized_username)` only where `profile_id is null`.

Added an ID-upgrade flow:

- resolve id-bearing row;
- resolve id-less fallback row;
- merge when both exist;
- update in place when safe;
- report and skip unsafe collisions.

## Patch 4: Reconcile Recent Migrations

Added Phase 0 requirements to inspect and reconcile:

- `20260323173500_add_instagram_post_search_columns.sql`;
- `20260428114500_instagram_catalog_post_collaborators.sql`.

The plan now requires reuse/extension/canonicalization of existing search and collaborator surfaces before any new duplicate schema is proposed.

## Patch 5: Validation And Acceptance Updates

Added checks for:

- monolith one-writer ownership;
- Phase 0 user approval;
- partial unique indexes;
- ID-upgrade merge behavior;
- recent migration reconciliation.

## Patch 6: Sync Canonical Plan

The revised plan was copied back to `docs/codex/plans/2026-04-28-instagram-post-queryable-data-plan.md`.
