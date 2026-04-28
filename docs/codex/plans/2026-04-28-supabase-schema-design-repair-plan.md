# Supabase Schema Design Repair Plan

Date: 2026-04-28
Status: ready for approval
Recommended executor after approval: `orchestrate-plan-execution`

## summary

Repair the TRR Supabase schema by separating canonical data, account/catalog membership, scraper observations, normalized lookup facts, and API read models. The immediate implementation target is Instagram because it has the clearest live duplication: `social.instagram_posts` is the canonical comment FK target, while `social.instagram_account_catalog_posts` is the larger account-wide catalog with duplicated post fields and no FK back to the canonical post row.

This plan makes the schema repair backend-first and staged. Phase 1 locks live evidence and contracts. Phase 2 implements the existing Instagram canonical-post plan. Phase 3 cleans up read/write ownership so backend APIs consume the new model without changing app response envelopes. Phase 4 generalizes the design lessons to other platform catalog tables without bulk rewriting them prematurely. Security and advisor cleanup remain separate gates; this plan must not turn into an unreviewed index-drop or RLS redesign pass.

## saved_path

`/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-supabase-schema-design-repair-plan.md`

## project_context

- Workspace: `/Users/thomashulihan/Projects/TRR`
- Backend owner: `/Users/thomashulihan/Projects/TRR/TRR-Backend`
- App owner: `/Users/thomashulihan/Projects/TRR/TRR-APP`
- Shared schema migrations touching `admin`, `core`, `firebase_surveys`, or `social` belong under `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations`.
- Local Supabase/PostgREST exposes `public`, `graphql_public`, `core`, and `admin` in `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/config.toml`; exposure changes require the existing RLS/grants review gate.
- Current advisor performance cycle is closed for 2026-04-28. Remaining Performance Advisor findings are deferred `unused_index` candidates, not approval for broad destructive DDL.
- Existing Instagram-specific plan: `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-instagram-post-schema-unification-plan.md`.
- Live schema evidence from the current review:
  - `social.instagram_posts`: 1,583 rows, 62 columns, 13 JSONB columns, 39 MB, unique `shortcode`, comment FK target.
  - `social.instagram_account_catalog_posts`: 29,799 rows, 41 columns, 9 JSONB columns, 241 MB, unique `source_id`, assignment fields, no FK to `social.instagram_posts`.
  - `social.instagram_comments`: 152,980 rows, 409 MB, FK to `social.instagram_posts(id)`.
  - The current backend writes `social.instagram_posts` through `_upsert_instagram_post(...)` and the catalog table through `_shared_catalog_instagram_post_payload(...)` / `_batch_upsert_shared_catalog_instagram_posts(...)`.
  - Current backend reads still query both canonical and catalog surfaces in `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py`.

## assumptions

1. `social.instagram_posts` remains the canonical Instagram post table because `social.instagram_comments.post_id` already depends on it.
2. Existing Instagram `shortcode` and catalog `source_id` represent the same logical post identity unless parity scripts find exceptions.
3. Existing backend API response envelopes for admin social profile pages must remain compatible.
4. App follow-through should be limited to fixture/test updates or compatibility route adjustments unless backend contracts change.
5. Current public-read behavior should be preserved for new replacement tables unless a dedicated security pass approves a different policy.
6. No legacy table should be dropped, renamed, or replaced by a view until parity scripts prove the new model works against real data.
7. Generalizing the model to TikTok, Twitter, YouTube, Facebook, and Threads should happen after Instagram validates the pattern.

## goals

1. Remove competing Instagram post truths by creating one canonical post record and separate account/catalog membership.
2. Preserve all existing comments and comment FK relationships.
3. Normalize hot lookup arrays into indexed side tables for entities and media.
4. Keep scraper raw payloads and operational observations available without making them the primary read model.
5. Preserve existing app/admin response shapes.
6. Add parity tooling so schema migration results can be proven by handle and globally.
7. Establish reusable schema rules for future platform catalog cleanup.
8. Keep security/RLS and unused-index work gated instead of bundling broad destructive changes into this design repair.

## non_goals

- No immediate drop of `social.instagram_account_catalog_posts`.
- No wholesale all-platform social schema rewrite in the first implementation pass.
- No app redesign.
- No Supabase capacity or pool-size change.
- No broad RLS/security redesign beyond matching existing behavior on new tables.
- No additional unused-index drops from this plan.
- No change to Instagram scraping transport, proxy, auth, or worker orchestration.
- No production DDL from Codex without the established owner-controlled rollout gate.

## phased_implementation

### Phase 0 - Evidence Lock And Execution Boundaries

Purpose: prevent another plausible schema cleanup from running without live parity evidence.

Concrete changes:

- Add or update a status artifact under `/Users/thomashulihan/Projects/TRR/docs/ai/local-status/` that records current live table sizes, row counts, constraints, FKs, indexes, RLS state, and known duplicate-field overlap for:
  - `social.instagram_posts`
  - `social.instagram_account_catalog_posts`
  - `social.instagram_account_catalog_post_collaborators`
  - `social.instagram_comments`
- Add a read-only backend parity script:
  - Path: `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/instagram_post_schema_parity.py`
  - Inputs: `--handle`, `--all`, `--json`, `--limit-conflicts`.
  - Reports:
    - catalog rows by `lower(source_account)`
    - canonical rows by owner handle
    - catalog rows without canonical `shortcode`
    - canonical rows with comments but no catalog membership
    - conflicting `source_id` / `shortcode`, posted timestamp, owner, media ID, metrics, assignment state
    - JSON/entity/media field coverage
- Add focused tests for the script using fake DB rows or query fixtures.
- Record that implementation must run through backend-owned migrations only.

Affected files/surfaces:

- `/Users/thomashulihan/Projects/TRR/docs/ai/local-status/`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/instagram_post_schema_parity.py`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/db/`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/migration-ownership-policy.md` only if the ownership rule needs clarification.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/instagram_post_schema_parity.py --handle thetraitorsus --json
.venv/bin/python -m pytest -q tests/db -k "instagram_post_schema_parity"
```

Expected result:

- Script is read-only.
- It reports current mismatches without mutating data.
- It identifies the exact counts that must match after backfill.

Acceptance criteria:

- Current schema state is documented with live evidence.
- The execution agent has a concrete parity baseline before writing migrations.
- No destructive DDL exists in this phase.

Commit boundary:

- Docs plus read-only parity tooling only.

### Phase 1 - Canonical Instagram Schema Additions

Purpose: add the relational model needed to separate post identity from account/catalog membership while preserving the existing comment FK root.

Concrete changes:

- Implement the additive migration from `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-instagram-post-schema-unification-plan.md`.
- Keep `social.instagram_posts` as canonical and add missing catalog-grade fields only where needed:
  - `permalink`
  - `first_seen_at`
  - `last_seen_at`
  - `last_catalog_run_id`
  - metric type widening from `integer` to `bigint` where safe.
- Add `social.instagram_account_post_catalog` with `(account_handle, post_id)` as the membership key.
- Add `social.instagram_post_entities` for hashtags, mentions, profile tags, collaborators, and tagged users.
- Add `social.instagram_post_media_assets` for source/hosted media rows.
- Add RLS and grants matching current public-read behavior unless a separate security decision overrides it.
- Add SQL verifier checks for table existence, indexes, FK shape, RLS enabled state, and comments FK preservation.

Affected files/surfaces:

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/db/`

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db tests/api/test_startup_validation.py -k "instagram or social"
python3 ../scripts/migration-ownership-lint.py
```

Expected result:

- New tables exist and are indexed for owner, post, entity, and media lookup.
- Existing `social.instagram_comments.post_id` still points to `social.instagram_posts(id)`.
- No legacy table is removed.

Acceptance criteria:

- Migration is additive and rollback-safe.
- New schema can represent one canonical post, many account memberships, normalized entity facts, and normalized media assets.
- Policy/grant behavior is explicitly verified.

Commit boundary:

- One backend migration plus SQL/tests.

### Phase 2 - Idempotent Backfill And Parity Proof

Purpose: move existing catalog data into the canonical model without losing legacy rollback options.

Concrete changes:

- Add `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/backfill_instagram_post_canonical_schema.py`.
- Script modes:
  - default dry run
  - `--execute`
  - `--handle <account>`
  - `--all`
  - `--batch-size`
  - `--since-run-id`
  - `--json`
- For every `social.instagram_account_catalog_posts` row:
  - resolve canonical post by `social.instagram_posts.shortcode = source_id`
  - insert missing canonical rows where possible
  - preserve existing canonical IDs for rows with comments
  - upsert account membership into `social.instagram_account_post_catalog`
  - sync entities from `hashtags`, `mentions`, `profile_tags`, `collaborators`, `tagged_users_detail`, and `collaborators_detail`
  - sync media from `media_urls`, `thumbnail_url`, hosted media fields, asset manifest fields, and `child_posts_data`
  - emit conflict records rather than silently choosing data when fields disagree.
- Add dry-run and execute tests with representative catalog/canonical/comment fixtures.

Affected files/surfaces:

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/backfill_instagram_post_canonical_schema.py`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/db/`
- `/Users/thomashulihan/Projects/TRR/docs/ai/local-status/`

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/backfill_instagram_post_canonical_schema.py --handle thetraitorsus --dry-run --json
.venv/bin/python scripts/db/backfill_instagram_post_canonical_schema.py --handle thetraitorsus --execute --json
.venv/bin/python scripts/db/instagram_post_schema_parity.py --handle thetraitorsus --json
.venv/bin/python -m pytest -q tests/db -k "instagram_post_canonical"
```

Expected result:

- `thetraitorsus` canonical, membership, entity, and media counts match the known baseline or list explicit exceptions.
- Existing comments still point to the same canonical post IDs.
- Re-running the backfill is safe and produces stable summaries.

Acceptance criteria:

- Backfill is idempotent.
- Backfill can run per handle before global execution.
- Conflicts are visible and reviewable.
- No legacy catalog rows are deleted.

Commit boundary:

- Backfill script, tests, and status docs.

### Phase 3 - Backend Write Path Switch

Purpose: stop creating new divergence after the backfill by writing canonical post state and membership state together.

Concrete changes:

- Refactor `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py`.
- Split persistence helpers into explicit responsibilities:
  - `_upsert_instagram_canonical_post(...)`
  - `_sync_instagram_account_catalog_membership(...)`
  - `_sync_instagram_post_entities(...)`
  - `_sync_instagram_post_media_assets(...)`
  - `_sync_instagram_legacy_catalog_row(...)`
- Update `_upsert_instagram_post(...)` so normal post persistence writes canonical, membership, entity, and media state.
- Update `_shared_catalog_instagram_post_payload(...)`, `_upsert_shared_catalog_instagram_post(...)`, and `_batch_upsert_shared_catalog_instagram_posts(...)` so catalog backfills write canonical/membership state first.
- Keep dual-write to `social.instagram_account_catalog_posts` only as an explicit rollback/compatibility layer during rollout.
- Keep `social.instagram_account_catalog_post_collaborators` synced only as a compatibility table until reads move to `social.instagram_post_entities`.
- Add tests proving materialized-post and shared-account catalog writes both populate the new model.

Affected files/surfaces:

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Instagram posts/comment job tests if they assert persistence side effects.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "instagram and (persist or catalog or canonical or membership)"
```

Expected result:

- New Instagram writes maintain canonical, membership, entity, media, and legacy compatibility rows in one persistence path.
- Existing diagnostics and error handling still work.
- Dual-write is explicit and test-covered.

Acceptance criteria:

- New writes no longer rely on the legacy catalog table as the source of truth.
- New writes do not create catalog-only posts unless explicitly marked as invalid/conflicted.
- Tests cover both single-post and batch catalog paths.

Commit boundary:

- Backend write-path refactor plus focused tests.

### Phase 4 - Backend Read Path Switch

Purpose: make the backend consume the repaired model while keeping app/admin contracts stable.

Concrete changes:

- Update social profile and catalog reads to use:
  - `social.instagram_posts` for canonical post fields
  - `social.instagram_account_post_catalog` for account membership and assignment
  - `social.instagram_post_entities` for hashtag, mention, collaborator, profile tag, and tagged-user lookup
  - `social.instagram_post_media_assets` for media previews and hosted/source media lookup
- Preserve backend response envelopes for:
  - profile dashboard/snapshot
  - profile posts
  - catalog posts
  - catalog post detail
  - comments-only posts
  - hashtags/collaborators/tags tabs
- Replace hot JSON expansion paths with indexed joins where the new side tables cover the field.
- Keep legacy fallback reads behind a named helper and telemetry marker during rollout.
- Add route/repository tests that compare old and new counts for high-value handles.

Affected files/surfaces:

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/socials.py` if route behavior needs explicit stale/fallback status.
- `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx` only if fixtures need updates.
- `/Users/thomashulihan/Projects/TRR/TRR Workspace Brain/api-contract.md` only if a response/freshness contract changes.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py tests/api/routers/test_socials_season_analytics.py -k "instagram and profile"

cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm exec vitest run tests/social-account-profile-page.runtime.test.tsx --reporter=dot
```

Expected result:

- API shapes stay compatible.
- Per-account profile counts match parity reports.
- Comments tab still loads through `social.instagram_comments.post_id`.
- Hashtag/collaborator/tag reads use indexed side tables where possible.

Acceptance criteria:

- Backend reads are primarily canonical/membership/entity/media based.
- Legacy fallback is explicitly temporary.
- App tests pass without UI redesign.

Commit boundary:

- Backend read-path migration and app fixture/test follow-through if required.

### Phase 5 - Rollout Gate And Legacy Retirement Decision

Purpose: prove the new design in live workflows before retiring legacy storage.

Concrete changes:

- Run all-account parity:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/instagram_post_schema_parity.py --all --json
```

- Add an operator diagnostic summary for:
  - canonical post count
  - membership count
  - catalog-only legacy rows
  - comments with missing canonical posts
  - entity sync gaps
  - media sync gaps
  - legacy fallback hits
- Run one bounded live Instagram backfill and verify canonical/membership/entity/media rows update.
- Decide separately whether `social.instagram_account_catalog_posts` should:
  - remain as an archive table
  - become a compatibility view
  - be renamed to a legacy table
  - be dropped in a future plan after retention approval.

Affected files/surfaces:

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/`
- `/Users/thomashulihan/Projects/TRR/docs/ai/local-status/`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/social-profile-dashboard.md` if operator docs need updates.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR
make dev
```

Manual validation:

- Open `http://admin.localhost:3000/social/instagram/thetraitorsus`.
- Verify Posts, Comments, Catalog, Hashtags, Collaborators / Tags, and catalog detail modal.
- Trigger or inspect one bounded Instagram backfill.
- Confirm no unexpected legacy fallback spikes.

Expected result:

- Admin workflows remain stable.
- Parity is clean or exceptions are documented.
- Legacy retirement is a separate approval boundary.

Acceptance criteria:

- No destructive retirement happens without clean parity evidence.
- Operator diagnostics can explain the old/new schema state.
- A future agent can safely decide whether to archive, view-wrap, rename, or drop the legacy table.

Commit boundary:

- Rollout diagnostics only. Legacy table retirement requires a separate commit and approval.

### Phase 6 - Platform Catalog Pattern Review

Purpose: apply the schema-design lesson beyond Instagram without launching a risky all-platform rewrite.

Concrete changes:

- Add a review doc under `/Users/thomashulihan/Projects/TRR/docs/workspace/` comparing the current platform catalog tables:
  - `social.tiktok_account_catalog_posts`
  - `social.twitter_account_catalog_posts`
  - `social.youtube_account_catalog_posts`
  - `social.facebook_account_catalog_posts`
  - `social.threads_account_catalog_posts`
- For each platform, classify whether the existing split should become:
  - canonical post plus account membership
  - existing platform post table plus membership table
  - catalog table retained as archive only
  - no action because row volume or workflow does not justify migration.
- Identify hot JSON fields that deserve normalization for each platform.
- Do not write platform-wide migrations in this phase unless explicitly approved after the review.

Affected files/surfaces:

- `/Users/thomashulihan/Projects/TRR/docs/workspace/`
- Optional read-only inventory script under `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/`.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/social_catalog_schema_inventory.py --json
```

Expected result:

- Platform cleanup is ranked by row volume, query cost, app/admin workflow impact, and migration risk.
- Instagram lessons are documented as a pattern, not blindly copied.

Acceptance criteria:

- The next platform migration has evidence and priority.
- No broad all-platform DDL lands from this phase.

Commit boundary:

- Review doc and optional read-only inventory script only.

### Phase 7 - Security And Governance Follow-Through

Purpose: keep schema design repair from reintroducing exposed-schema or migration-ownership drift.

Concrete changes:

- Run the existing RLS/grants snapshot after new tables are added.
- Confirm new tables follow current exposure decisions and grants.
- Confirm no app-owned shared-schema migration appears.
- Confirm no new `SECURITY DEFINER` function is introduced without pinned `search_path` and explicit execute grants.
- Confirm no raw payload or operational table is newly exposed through PostgREST without product rationale.
- Update the RLS/grants review doc if the snapshot tooling is available.

Affected files/surfaces:

- `/Users/thomashulihan/Projects/TRR/docs/workspace/supabase-rls-grants-review.md`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/`
- `/Users/thomashulihan/Projects/TRR/scripts/migration-ownership-lint.py`

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR
make rls-grants-snapshot
python3 scripts/migration-ownership-lint.py
```

Expected result:

- New schema surfaces are documented.
- Migration ownership lint passes.
- Any intentional public read is documented.

Acceptance criteria:

- Schema repair does not regress RLS, grants, or migration ownership.
- Any blocked snapshot command is recorded with exact blocker text.

Commit boundary:

- Governance snapshot/doc updates only.

## architecture_impact

- Backend remains the schema and API contract owner.
- App remains a consumer of backend-owned social profile contracts.
- Instagram schema becomes layered:
  - canonical identity: `social.instagram_posts`
  - account/catalog membership and assignment: `social.instagram_account_post_catalog`
  - lookup facts: `social.instagram_post_entities`
  - media facts: `social.instagram_post_media_assets`
  - comments: `social.instagram_comments`
  - legacy compatibility: `social.instagram_account_catalog_posts` and `social.instagram_account_catalog_post_collaborators`
- Later platform cleanup should reuse the same layered model only after read/write evidence proves it is worth the migration.

## data_or_api_impact

- Data model changes are additive through Phase 5.
- `social.instagram_comments.post_id` remains unchanged.
- Existing backend response envelopes should remain unchanged.
- New tables need RLS/grant verification.
- Backfill scripts need idempotent conflict handling and JSON output.
- Metric widening to `bigint` must be tested before production DDL.
- If backend response payloads add internal diagnostic metadata, the app compatibility route should ignore or strip it unless explicitly consumed.

## ux_admin_ops_considerations

- Admin social profile pages should keep the same visible behavior.
- Operators need diagnostics that explain whether a row came from canonical state, legacy fallback, or a parity exception.
- Backfill commands should default to dry run.
- Parity output should be JSON so it can be pasted into Codex, archived in docs, or used in follow-up automation.
- Live DDL should stay owner-controlled and should not be auto-applied by local startup reconcile until explicitly allowlisted.

## validation_plan

Primary backend validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db tests/repositories/test_social_season_analytics.py tests/api/routers/test_socials_season_analytics.py -k "instagram or social"
```

Primary app validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm exec vitest run tests/social-account-profile-page.runtime.test.tsx --reporter=dot
```

Workspace validation:

```bash
cd /Users/thomashulihan/Projects/TRR
python3 scripts/migration-ownership-lint.py
make dev
```

Database validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/instagram_post_schema_parity.py --handle thetraitorsus --json
.venv/bin/python scripts/db/instagram_post_schema_parity.py --all --json
```

Manual validation:

- `http://admin.localhost:3000/social/instagram/thetraitorsus`
- Posts tab
- Comments tab
- Catalog tab
- Hashtags tab
- Collaborators / Tags tab
- Catalog detail modal
- One bounded Instagram backfill or recent-sync check

## acceptance_criteria

1. One canonical Instagram post row exists per valid shortcode used by comments and profile reads.
2. Account/catalog membership is represented separately from post identity.
3. Legacy catalog rows have matching membership rows or documented invalid/conflict exceptions.
4. Existing comments remain attached to their canonical post IDs.
5. Entity and media side tables cover hot lookup fields now stored in JSON.
6. Backend write paths maintain canonical, membership, entity, media, and temporary legacy compatibility state.
7. Backend read paths primarily use canonical/membership/entity/media tables.
8. Existing app/admin response envelopes remain compatible.
9. Parity scripts pass for `thetraitorsus` and all known Instagram account handles, or list approved exceptions.
10. No legacy table is dropped or renamed without separate approval.
11. Migration ownership lint passes.
12. RLS/grants behavior for new tables is documented.

## risks_edge_cases_open_questions

- Some catalog rows may have malformed or non-shortcode `source_id` values.
- Some canonical rows may have comments but no catalog account membership.
- Existing canonical rows may have richer metadata than catalog rows; backfill must not overwrite richer data with null or lower-confidence values.
- Metrics may disagree because different scrapers observe different moments. The implementation needs a defined merge policy.
- `source_account` on canonical posts is currently a compatibility field. Long-term ownership may need to move fully to membership rows.
- Existing raw JSON may contain fields not captured by the first normalized entity/media model.
- Public read policies preserve behavior but may expose raw data that deserves a future security pass.
- All-platform normalization could become too broad if started before Instagram proves the pattern.

## follow_up_improvements

- Generalize canonical post plus membership to TikTok, Threads, Facebook, YouTube, and Twitter after the Phase 6 review.
- Move raw scraper payloads into append-only observation tables with source/runtime provenance.
- Add materialized profile summary/read models after canonical write/read paths settle.
- Add field-level provenance and confidence scoring for metrics, media, and assignment decisions.
- Revisit public-read access for raw payload and operational columns in a dedicated security pass.
- Reopen deferred unused-index owner packets only after the new read paths have generated fresh query-plan evidence.

## recommended_next_step_after_approval

Use `orchestrate-plan-execution`. This repair is tightly sequenced: evidence, additive schema, backfill, write switch, read switch, parity gate, then platform review. Parallel subagents can review SQL/tests or run independent validation after each phase, but the main implementation should remain sequential to avoid conflicting schema and persistence edits.

## ready_for_execution

Yes. Start with Phase 0 and do not execute destructive DDL or legacy retirement until the parity gate is clean and explicitly approved.
