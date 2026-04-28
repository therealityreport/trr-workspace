# PATCHES: Schema-First Revision

## Patch 1: Add Schema Architecture Decision Gate

Integrated into `REVISED_PLAN.md` as `Phase 0: Schema Architecture Decision Gate`.

This requires a field-to-table storage map before migrations and explicitly checks legacy Instagram tables, `shared_account_sources`, and the `social.social_posts` canonical foundation.

## Patch 2: Align Post Fields With Canonical Foundation

Changed Phase 2 from "add columns to Instagram tables" to "add additive canonical schema." The plan now prefers:

- `social.social_posts` for platform-neutral post identity and counts.
- `social.social_post_entities` for hashtags, mentions, collaborators, tags, and similar entities.
- `social.social_post_media_assets` for media variants and hosted media.
- `social.social_post_observations` for raw/normalized payload snapshots.
- `social.social_post_legacy_refs` for compatibility mapping.

Legacy `instagram_posts` and `instagram_account_catalog_posts` stay source/compatibility tables unless a documented bridge column is needed.

## Patch 3: Add RLS And Raw-Observation Boundary

Added explicit rules that raw observations and typed-vs-raw diff routes are service-role/admin-only, while curated fields are exposed through backend/admin APIs.

## Patch 4: Keep Following-Only Scope

Preserved the previous correction: no follower-list scraping. Follower counts remain profile scalar fields; following-list rows remain in scope.

## Patch 5: Integrate All Prior Suggestions

Added the exact `ADDITIONAL SUGGESTIONS` phase and converted all ten prior suggestions into concrete tasks with:

- source number/title,
- concrete changes,
- dependencies,
- affected surfaces,
- validation,
- acceptance criteria,
- commit boundary.

## Patch 6: Update Execution Handoff

Kept `orchestrate-subagents` as the next execution skill, but made Phase 0 the required coordination gate before workers split.

## Patch 7: Sync Canonical Plan

Copied the revised plan back to `docs/codex/plans/2026-04-28-instagram-post-queryable-data-plan.md` so the canonical docs plan matches the latest artifact.
