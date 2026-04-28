# PATCHES: Original Plan To Revised Plan

## Patch 1: Add Phase 0 Current-State Gate

Why: The source plan was strong but began directly with field inventory and migrations. For this repo, the executor needs to verify current columns, optional-column guards, raw profile payload availability, and scrape job-stage routing before writing schema.

Applied in `REVISED_PLAN.md`:

- Added `Phase 0: Current-State Gate And Workstream Routing`.
- Added required inspection targets for schema, runtimes, posts/comments Scrapling lanes, and `social_season_analytics.py`.
- Added baseline note requirement under `docs/ai/local-status/`.
- Added stop rule if an existing profile/relationship table is discovered.

## Patch 2: Link Profiles To Shared Account Sources

Why: The source plan correctly kept `social.shared_account_sources` as the source registry, but `social.instagram_profiles` did not explicitly link back to it. That could create a typed profile table that admin profile reads cannot reliably join.

Applied in `REVISED_PLAN.md`:

- Added `shared_account_source_id`, `source_scope`, and `source_account` to `social.instagram_profiles`.
- Added optional `social.instagram_profile_source_links` for many-to-many or historical mapping.
- Added schema validation proving profile rows can join back to shared account sources.

## Patch 3: Add Profile/Relationship Job-Stage Contract

Why: The source plan named profile and relationship fetchers but did not define how they enter the existing scrape job/run system.

Applied in `REVISED_PLAN.md`:

- Added recommended stages `instagram_profile_snapshot` and `instagram_profile_relationships`.
- Added runtime/fetcher requirements for profile snapshot and one page of following.
- Added job-runner requirements for config validation, progress metadata, and classified failure statuses.
- Added tests for ambiguous relationship direction and capped/checkpoint/rate-limit status.

## Patch 4: Make Profile Backfill Evidence-Based

Why: Current repo evidence shows reduced `ProfileInfo` support, but not a confirmed full raw profile/about payload store. The source plan could overpromise backfill.

Applied in `REVISED_PLAN.md`:

- Added assumption that profile backfill is full only where raw payloads exist.
- Added Phase 0 check to confirm raw full profile payload availability.
- Added manual validation requiring partial-backfill reporting when full payloads are absent.

## Patch 5: Change Execution Handoff

Why: The work can be split safely after Phase 0 across schema, normalizers, profile/following fetchers, persistence/backfill, API/admin, and observability. The source plan preferred sequential execution.

Applied in `REVISED_PLAN.md`:

- Changed `recommended_next_step_after_approval` to `orchestrate-subagents`.
- Added a concrete workstream map and coordination point.

## Patch 6: Remove Follower-List Scraping Scope

Why: The user explicitly clarified that follower lists do not need to be scraped. The plan should keep follower counts from profile payloads but avoid follower-list stages, tables, and API routes.

Applied in `REVISED_PLAN.md` and the source docs plan:

- Made follower-list scraping an explicit non-goal.
- Changed profile relationships to following-only rows.
- Changed `relationship_type` to `following` only.
- Removed follower-page fetcher requirements and follower API routes.
- Added negative fixture requirements for payloads marked `type: "Followers"` so they are not accidentally persisted as follower rows.

## Cleanup Note

Added the required Plan Grader cleanup note to `REVISED_PLAN.md`.
