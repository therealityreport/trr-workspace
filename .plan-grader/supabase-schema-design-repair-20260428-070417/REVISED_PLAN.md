# Supabase Schema Design Repair Plan - Revised

Date: 2026-04-28
Status: ready for approval
Recommended executor after approval: `orchestrate-plan-execution`

## summary

Repair the TRR Supabase schema by separating canonical Instagram post identity from account/catalog membership, normalized entity/media lookup facts, scraper observations, and legacy compatibility storage. The immediate implementation target is Instagram because live Supabase evidence shows the clearest split: `social.instagram_posts` is the comment FK target with about `1,583` rows, while `social.instagram_account_catalog_posts` is a larger catalog table with about `29,799` rows and no FK back to the canonical post row.

This revised plan is self-contained. It does not depend on a missing Instagram-specific plan artifact. It keeps backend-owned migrations in `TRR-Backend`, preserves app/admin response envelopes, maintains legacy dual-write and fallback during rollout, and prevents destructive retirement until parity and fallback gates are clean.

## saved_path

`.plan-grader/supabase-schema-design-repair-20260428-070417/REVISED_PLAN.md`

## project_context

- Workspace: `/Users/thomashulihan/Projects/TRR`
- Backend owner: `/Users/thomashulihan/Projects/TRR/TRR-Backend`
- App owner: `/Users/thomashulihan/Projects/TRR/TRR-APP`
- Shared-schema migrations touching `admin`, `core`, `firebase_surveys`, or `social` belong under `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations`.
- Local PostgREST exposes `public`, `graphql_public`, `core`, and `admin`; exposure changes require the existing RLS/grants review gate.
- Current Performance Advisor remediation is closed for this cycle. Remaining `unused_index` findings are deferred owner-review candidates, not permission to drop indexes in this plan.
- Current backend persistence and reads live mainly in `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py`.

## assumptions

1. `social.instagram_posts` remains the canonical table because `social.instagram_comments.post_id` already depends on it.
2. Existing catalog `source_id` usually equals Instagram `shortcode`, but Phase 0 must identify exceptions before migration.
3. Existing backend API response envelopes remain compatible for the app.
4. App changes should be limited to tests/fixtures unless backend contracts change.
5. Current public-read behavior is preserved on new replacement tables until a separate security pass changes it.
6. Legacy catalog storage remains available until all parity and fallback gates pass.

## goals

1. Establish one canonical Instagram post row per valid shortcode.
2. Represent account/catalog membership separately from post identity.
3. Normalize hot lookup facts for hashtags, mentions, collaborators, profile tags, tagged users, and media assets.
4. Preserve raw scraper observations without making raw JSON the primary read model.
5. Preserve all existing comment FK relationships.
6. Keep app/admin response envelopes stable.
7. Add parity, fallback, RLS/grant, and migration ownership checks before rollout and retirement.
8. Capture a reusable pattern for later platform cleanup without starting a broad rewrite now.

## non_goals

- No immediate drop, rename, or view replacement of `social.instagram_account_catalog_posts`.
- No all-platform schema rewrite in this implementation pass.
- No app redesign.
- No Supabase pool/capacity change.
- No broad RLS/security redesign beyond matching current behavior on new tables.
- No unused-index drop work.
- No scraper/proxy/auth transport rewrite.
- No production DDL from Codex without owner-controlled rollout approval.

## phased_implementation

### Phase 0 - Evidence Lock

Concrete changes:

- Add `/Users/thomashulihan/Projects/TRR/docs/ai/local-status/instagram-post-schema-repair-baseline-2026-04-28.md`.
- Add `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/instagram_post_schema_parity.py`.
- The parity script must support `--handle`, `--all`, `--json`, and `--limit-conflicts`.
- Report table row counts, sizes, constraints, indexes, RLS state, FK state, duplicate identities, catalog-only rows, canonical-only rows, comments without canonical post rows, and conflicting metrics/media/assignment fields.
- Record the current missing-table state for `social.instagram_account_post_catalog`, `social.instagram_post_entities`, `social.instagram_post_media_assets`, and `social.instagram_post_observations`.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/instagram_post_schema_parity.py --handle thetraitorsus --json
.venv/bin/python -m pytest -q tests/db -k "instagram_post_schema_parity"
```

Acceptance criteria:

- Script is read-only.
- Baseline file records live evidence and known mismatches.
- No DDL or data mutation occurs in this phase.

Commit boundary:

- Read-only script, tests, and baseline docs only.

### Phase 1 - Add Canonical Support Schema

Concrete changes:

- Add a timestamped backend migration under `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/`.
- Add missing canonical columns to `social.instagram_posts` only when absent:
  - `permalink text`
  - `first_seen_at timestamptz not null default now()`
  - `last_seen_at timestamptz not null default now()`
  - `last_catalog_run_id uuid references social.scrape_runs(id) on delete set null`
- Widen Instagram metrics to `bigint` only after a verifier confirms no incompatible dependent views/functions block the change.
- Add `social.instagram_account_post_catalog`:
  - `account_handle_display text not null`
  - `account_handle_normalized text not null`
  - `post_id uuid not null references social.instagram_posts(id) on delete cascade`
  - assignment fields currently in legacy catalog
  - `last_backfill_run_id`, `first_seen_at`, `last_seen_at`, timestamps
  - primary key `(account_handle_normalized, post_id)`
  - indexes on `(post_id)`, `(account_handle_normalized, last_seen_at desc, post_id)`, and assignment filters.
- Add `social.instagram_post_entities`:
  - `post_id`
  - `entity_type`
  - `entity_key_display`
  - `entity_key_normalized`
  - `source`
  - `raw_detail`
  - primary key `(post_id, entity_type, entity_key_normalized)`
  - lookup index `(entity_type, entity_key_normalized, post_id)`.
- Add `social.instagram_post_media_assets`:
  - `post_id`
  - `position`
  - source and hosted URL fields
  - thumbnail, dimensions, duration, mirror status/error/attempt fields
  - `raw_detail`
  - unique `(post_id, position)`.
- Add `social.instagram_post_observations`:
  - `post_id`
  - `source_table text not null`
  - `source_run_id uuid`
  - `observed_at timestamptz not null default now()`
  - metric snapshot fields
  - `raw_observation jsonb not null default '{}'::jsonb`
  - indexes on `(post_id, observed_at desc)` and `(source_run_id)`.
- Enable RLS and apply grants/policies matching current public-read behavior.
- Add comments on new tables documenting canonical, membership, lookup, media, and observation responsibilities.
- Add verifier SQL that checks table existence, keys, indexes, RLS, grants, FK state, and comments FK preservation.
- Add rollback SQL for additive objects and policy changes. Type widening rollback can be documented as manual-only if data may exceed `integer`.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR
python3 scripts/migration-ownership-lint.py

cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db tests/api/test_startup_validation.py -k "instagram or social"
./scripts/db/run_sql.sh scripts/db/verify_instagram_post_schema_repair_phase1.sql
```

Acceptance criteria:

- New tables exist with normalized keys and FK constraints.
- Existing comments FK remains unchanged.
- RLS and grants are verified.
- Migration is backend-owned and additive.

Commit boundary:

- Migration, verifier SQL, rollback notes, and DB tests.

### Phase 2 - Backfill Canonical Membership, Entities, Media, And Observations

Concrete changes:

- Add `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/backfill_instagram_post_canonical_schema.py`.
- Support default dry run, `--execute`, `--handle`, `--all`, `--batch-size`, `--since-run-id`, and `--json`.
- Resolve canonical post by `shortcode = source_id`.
- Insert missing canonical rows only when required fields can be safely derived.
- Preserve existing canonical IDs for rows with comments.
- Upsert membership using normalized account handles.
- Sync entities from catalog JSON, canonical JSON, and known detail fields.
- Sync media rows from media URLs, thumbnail fields, hosted fields, asset manifest fields, and child post data.
- Insert scraper observations for metric/source/raw snapshots.
- Metric merge policy:
  - preserve current monotonic view behavior for `views`
  - never overwrite richer non-null canonical values with nulls or empty arrays
  - store conflicting or lower-confidence values in observations
  - emit conflict summaries for operator review.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/backfill_instagram_post_canonical_schema.py --handle thetraitorsus --dry-run --json
.venv/bin/python scripts/db/backfill_instagram_post_canonical_schema.py --handle thetraitorsus --execute --json
.venv/bin/python scripts/db/instagram_post_schema_parity.py --handle thetraitorsus --json
.venv/bin/python -m pytest -q tests/db -k "instagram_post_canonical"
```

Acceptance criteria:

- Backfill is idempotent.
- Per-handle execution is safe before global execution.
- Conflicts are visible and bounded.
- Legacy catalog rows are not deleted.

Commit boundary:

- Backfill script, tests, and updated status docs.

### Phase 3 - Switch Backend Write Paths

Concrete changes:

- Refactor `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py`.
- Add explicit helpers:
  - `_upsert_instagram_canonical_post(...)`
  - `_sync_instagram_account_catalog_membership(...)`
  - `_sync_instagram_post_entities(...)`
  - `_sync_instagram_post_media_assets(...)`
  - `_record_instagram_post_observation(...)`
  - `_sync_instagram_legacy_catalog_row(...)`
- Update `_upsert_instagram_post(...)` to write canonical, membership, entity, media, and observation state.
- Update `_shared_catalog_instagram_post_payload(...)`, `_upsert_shared_catalog_instagram_post(...)`, and `_batch_upsert_shared_catalog_instagram_posts(...)` so catalog backfills write canonical state first.
- Keep legacy catalog dual-write during rollout.
- Keep `social.instagram_account_catalog_post_collaborators` synced as a compatibility table until reads fully move to `social.instagram_post_entities`.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "instagram and (persist or catalog or canonical or membership)"
```

Acceptance criteria:

- Materialized and catalog write paths both populate the new model.
- Legacy dual-write is explicit and test-covered.
- New writes do not create unlinked catalog-only rows.

Commit boundary:

- Backend write-path refactor plus focused tests.

### Phase 4 - Switch Backend Read Paths

Concrete changes:

- Update profile, catalog, hashtags, collaborators/tags, comments-only, and detail reads to use canonical/membership/entity/media tables as primary.
- Keep existing response envelopes stable.
- Add a named compatibility fallback flag, for example `TRR_INSTAGRAM_SCHEMA_REPAIR_LEGACY_FALLBACK=1`.
- Emit fallback telemetry with route, account handle, and reason.
- Add tests that prove new-path reads match legacy counts for high-value handles.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py tests/api/routers/test_socials_season_analytics.py -k "instagram and profile"

cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm exec vitest run tests/social-account-profile-page.runtime.test.tsx --reporter=dot
```

Acceptance criteria:

- Backend reads primarily use the repaired model.
- App tests pass without UI redesign.
- Legacy fallback hits are measurable.

Commit boundary:

- Backend read-path migration plus app fixture updates only if required.

### Phase 5 - Rollout And Retirement Gate

Concrete changes:

- Run all-account parity.
- Add an operator diagnostic summary for canonical rows, membership rows, entity/media sync gaps, comment FK gaps, legacy-only rows, and fallback hits.
- Run one bounded Instagram backfill or recent-sync validation.
- Stop if any of these are true:
  - parity has unexplained catalog-only or canonical-only rows
  - comments are missing canonical posts
  - legacy fallback hits remain above the approved threshold
  - RLS/grants snapshot fails or is blocked without a recorded blocker.
- Decide legacy storage fate in a separate approval:
  - archive table
  - compatibility view
  - rename to legacy table
  - future drop.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/instagram_post_schema_parity.py --all --json

cd /Users/thomashulihan/Projects/TRR
make dev
```

Manual validation:

- `http://admin.localhost:3000/social/instagram/thetraitorsus`
- Posts, Comments, Catalog, Hashtags, Collaborators / Tags, and detail modal.

Acceptance criteria:

- Admin workflows remain stable.
- Parity is clean or exceptions are approved.
- No legacy retirement happens in this phase.

Commit boundary:

- Rollout diagnostics and docs only.

### Phase 6 - Cross-Platform Pattern Review

Concrete changes:

- Add a review doc comparing TikTok, Twitter/X, YouTube, Facebook, Threads, and Reddit post/catalog shapes.
- Add an optional read-only inventory script if useful.
- Rank next-platform cleanup by row volume, query pain, operational value, and migration risk.
- Do not write cross-platform DDL in this phase.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/social_catalog_schema_inventory.py --json
```

Acceptance criteria:

- Instagram lessons are documented without being blindly copied.
- Next-platform cleanup has evidence and priority.

Commit boundary:

- Review doc and optional read-only inventory only.

### Phase 7 - Governance And Cleanup

Concrete changes:

- Run RLS/grants snapshot after new tables are added.
- Confirm no app-owned shared-schema migration appears.
- Confirm no new `SECURITY DEFINER` function lacks pinned `search_path` and explicit grants.
- Confirm new raw/observation surfaces are not accidentally exposed beyond intended policies.
- Update governance docs with final status and blockers.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR
make rls-grants-snapshot
python3 scripts/migration-ownership-lint.py
```

Acceptance criteria:

- Schema repair does not regress RLS, grants, or migration ownership.
- Any blocked snapshot command is recorded with exact blocker text.

Commit boundary:

- Governance docs only.

### ADDITIONAL SUGGESTIONS

These tasks incorporate every numbered suggestion from `SUGGESTIONS.md` as accepted plan requirements. They should be executed in the listed order where dependencies apply, while preserving the earlier phase gates.

#### Suggestion 1 - Add source-runtime provenance table

Source number and title: `1. Add source-runtime provenance table`

Concrete changes:

- Keep `social.instagram_post_observations` from Phase 1 as a required table, not an optional enhancement.
- Add fields that make scraper/runtime/source confidence queryable:
  - `runtime_name text`
  - `runtime_version text`
  - `worker_lane text`
  - `source_confidence text check (source_confidence in ('high', 'medium', 'low', 'unknown'))`
  - `observed_field_set jsonb not null default '[]'::jsonb`
- Populate the provenance fields in Phase 2 backfill and Phase 3 write-path helpers.

Dependencies or ordering constraints:

- Depends on Phase 1 table creation.
- Must be wired before Phase 3 write-path switch so new writes capture provenance immediately.

Affected files or surfaces:

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/db/`

Validation steps and expected result:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./scripts/db/run_sql.sh scripts/db/verify_instagram_post_schema_repair_phase1.sql
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "instagram and observation"
```

Expected result: observation rows include runtime/source metadata for backfilled and newly persisted posts.

Acceptance criteria:

- Provenance columns exist and are documented.
- At least one test proves runtime/source fields are written.
- Conflict summaries can reference observation provenance.

Commit boundary:

- Same commit as Phase 1 table creation and Phase 3 write-path wiring if implementation is small; otherwise split migration and persistence into adjacent commits.

#### Suggestion 2 - Add query-plan snapshots for before and after

Source number and title: `2. Add query-plan snapshots for before and after`

Concrete changes:

- Add read-only hot-path EXPLAIN SQL for representative social profile reads before read-path migration.
- Capture before and after plans for:
  - owner catalog list
  - collaborator lookup
  - hashtag/entity lookup
  - comments-only post lookup
  - catalog detail lookup
- Save outputs under a dated workspace evidence file.

Dependencies or ordering constraints:

- Before snapshots should be captured in Phase 0 or before Phase 4.
- After snapshots should be captured after Phase 4 read-path switch and before Phase 5 retirement decisions.

Affected files or surfaces:

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/hot_path_explain/`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/`

Validation steps and expected result:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./scripts/db/run_sql.sh scripts/db/hot_path_explain/instagram_schema_repair_before.sql
./scripts/db/run_sql.sh scripts/db/hot_path_explain/instagram_schema_repair_after.sql
```

Expected result: before/after evidence shows the new reads use membership/entity/media indexes instead of unbounded JSON expansion for common paths.

Acceptance criteria:

- Before and after plans are saved.
- Plans identify index usage or explicitly document why a sequential scan is acceptable.
- Evidence is linked from the rollout/status doc.

Commit boundary:

- EXPLAIN scripts and evidence docs can land with Phase 4 read-path migration.

#### Suggestion 3 - Add fallback counter to admin health endpoint

Source number and title: `3. Add fallback counter to admin health endpoint`

Concrete changes:

- Add a lightweight fallback counter to the backend social profile diagnostics or app DB pressure/health surface.
- Track count, route, platform, account handle, and fallback reason.
- Include a reset/window timestamp so operators can tell whether fallback usage is current.

Dependencies or ordering constraints:

- Depends on Phase 4 named legacy fallback helper.
- Must be available before Phase 5 retirement gate.

Affected files or surfaces:

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Backend health/social diagnostics route if one already owns this state.
- `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/tests/` if the app health card consumes the data.

Validation steps and expected result:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/api tests/repositories/test_social_season_analytics.py -k "fallback or health or instagram"
```

Expected result: tests can force a legacy fallback and verify the counter increments with a route/account/reason.

Acceptance criteria:

- Fallback counter is visible to an operator route or diagnostic command.
- Phase 5 can use the counter as a retirement gate.
- Counter output is sanitized and does not include raw payloads or secrets.

Commit boundary:

- Backend diagnostic/counter change and focused tests.

#### Suggestion 4 - Create a temporary compatibility view

Source number and title: `4. Create a temporary compatibility view`

Concrete changes:

- In the legacy-retirement decision phase, add an approved option to replace `social.instagram_account_catalog_posts` with a compatibility view only after parity is clean.
- The view should project the legacy catalog shape from canonical, membership, entity, media, and observation tables.
- Do not create the view in early phases unless retirement is approved.

Dependencies or ordering constraints:

- Depends on Phase 5 parity success.
- Must not run in the same commit as initial read-path migration.
- Requires explicit owner approval before replacing or renaming the legacy table.

Affected files or surfaces:

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/`
- `/Users/thomashulihan/Projects/TRR/docs/ai/local-status/`
- Any ad hoc SQL/docs that reference `social.instagram_account_catalog_posts`.

Validation steps and expected result:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/instagram_post_schema_parity.py --all --json
./scripts/db/run_sql.sh scripts/db/verify_instagram_catalog_compatibility_view.sql
```

Expected result: the compatibility view returns the same required legacy columns and matching counts for approved handles.

Acceptance criteria:

- View creation is a separate approved migration.
- Legacy table is not dropped in the schema-repair implementation cycle.
- Any view limitations are documented.

Commit boundary:

- Separate future commit after owner approval; do not include in Phases 0-5 implementation commits.

#### Suggestion 5 - Add ownership comments on new tables

Source number and title: `5. Add ownership comments on new tables`

Concrete changes:

- Add `comment on table` and key `comment on column` statements for all new tables.
- Comments must identify each table as canonical support, membership, normalized entities, normalized media, observations, or compatibility support.
- Include owner guidance: backend-owned, no app direct-SQL ownership, and no destructive retirement without parity approval.

Dependencies or ordering constraints:

- Belongs in Phase 1 migration.

Affected files or surfaces:

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/`
- Phase 1 verifier SQL should check at least table comments exist.

Validation steps and expected result:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./scripts/db/run_sql.sh scripts/db/verify_instagram_post_schema_repair_phase1.sql
```

Expected result: verifier confirms comments are present on every new table.

Acceptance criteria:

- Every new table has a comment.
- Important normalized key and observation columns have comments.
- Future agents can tell which table owns which layer.

Commit boundary:

- Same commit as Phase 1 migration.

#### Suggestion 6 - Add generated normalized columns if Postgres expression rules fit

Source number and title: `6. Add generated normalized columns if Postgres expression rules fit`

Concrete changes:

- During Phase 1 migration design, evaluate whether `account_handle_normalized` and `entity_key_normalized` should be generated stored columns instead of application-populated columns.
- If generated columns fit Postgres immutability requirements and local helper needs, use generated columns for normalization.
- If not, keep explicit text columns plus check constraints/tests proving normalized values are lowercased and stripped of leading `@`.

Dependencies or ordering constraints:

- Must be decided before Phase 1 migration lands.
- Must not block the migration if generated expressions are too brittle for platform-specific normalization.

Affected files or surfaces:

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/db/`

Validation steps and expected result:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db -k "normalized"
./scripts/db/run_sql.sh scripts/db/verify_instagram_post_schema_repair_phase1.sql
```

Expected result: either generated columns enforce normalization or tests/checks prove application-populated normalized keys cannot drift.

Acceptance criteria:

- The implementation records the generated-vs-explicit decision.
- Duplicate memberships for `@Foo`, `foo`, and `FOO` are impossible.
- Entity lookup uses normalized keys.

Commit boundary:

- Same commit as Phase 1 migration and DB tests.

#### Suggestion 7 - Add retention policy for raw observations

Source number and title: `7. Add retention policy for raw observations`

Concrete changes:

- Add a documented retention policy for `social.instagram_post_observations`.
- Decide whether retention is:
  - no automatic deletion during initial rollout
  - manual purge script only
  - later scheduled cleanup after volume is measured.
- If a purge path is added, it must preserve the latest observation per post/source and any observation referenced by conflict docs.

Dependencies or ordering constraints:

- Initial policy belongs in Phase 1 or Phase 5 docs.
- Automated deletion should not be added until after rollout volume is measured.

Affected files or surfaces:

- `/Users/thomashulihan/Projects/TRR/docs/ai/local-status/`
- Optional `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/purge_instagram_post_observations.py`

Validation steps and expected result:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/backfill_instagram_post_canonical_schema.py --handle thetraitorsus --dry-run --json
```

Expected result: operator docs explain expected observation growth and no automatic purge removes needed audit evidence during rollout.

Acceptance criteria:

- Retention decision is documented.
- No automated purge runs before the first parity/rollout cycle is complete.
- Future purge rules preserve audit-critical rows.

Commit boundary:

- Documentation in the Phase 1/Phase 5 status commit; purge script only in a separate later commit if approved.

#### Suggestion 8 - Build a cross-platform schema inventory report

Source number and title: `8. Build a cross-platform schema inventory report`

Concrete changes:

- Make Phase 6 inventory concrete by adding `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/social_catalog_schema_inventory.py`.
- Report row counts, sizes, JSONB counts, indexes, RLS state, canonical/comment FK targets, catalog table presence, and recommended migration priority for each platform.
- Save a dated output under `/Users/thomashulihan/Projects/TRR/docs/workspace/`.

Dependencies or ordering constraints:

- Runs after Instagram phases are underway or complete.
- Must stay read-only.

Affected files or surfaces:

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/social_catalog_schema_inventory.py`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/`

Validation steps and expected result:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/social_catalog_schema_inventory.py --json
```

Expected result: report ranks next-platform cleanup with evidence rather than intuition.

Acceptance criteria:

- Script is read-only.
- Report covers Instagram, TikTok, Twitter/X, YouTube, Facebook, Threads, and Reddit.
- No cross-platform DDL is generated.

Commit boundary:

- Phase 6 read-only inventory script and report only.

#### Suggestion 9 - Add RLS policy regression SQL fixtures

Source number and title: `9. Add RLS policy regression SQL fixtures`

Concrete changes:

- Add SQL fixtures/tests that verify anon/authenticated/service-role behavior for new tables.
- Cover public read, blocked public write, service-role write, and any observation/raw-data exposure decision.
- Integrate the fixtures into existing DB test patterns or verifier SQL.

Dependencies or ordering constraints:

- Depends on Phase 1 table/policy creation.
- Must run before production DDL approval.

Affected files or surfaces:

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/db/`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/verify_instagram_post_schema_repair_phase1.sql`

Validation steps and expected result:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db -k "rls or grants or instagram_post_schema"
./scripts/db/run_sql.sh scripts/db/verify_instagram_post_schema_repair_phase1.sql
```

Expected result: tests prove the new public-read surfaces do not accidentally expose public writes.

Acceptance criteria:

- RLS behavior is tested for all new tables.
- Grant expectations are documented.
- Any blocked permission check records the exact blocker.

Commit boundary:

- Same commit as Phase 1 verifier/tests or a dedicated security-test commit before rollout.

#### Suggestion 10 - Add app fixture snapshots for response-envelope parity

Source number and title: `10. Add app fixture snapshots for response-envelope parity`

Concrete changes:

- Add or update app test fixtures that capture the social profile response envelope before and after backend read-path migration.
- Cover the profile snapshot/dashboard, posts, catalog, comments, hashtags, and collaborators/tags data shapes.
- Keep UI behavior unchanged unless a backend contract update is explicitly recorded.

Dependencies or ordering constraints:

- Capture/update alongside Phase 4 backend read-path switch.
- If backend response changes, update `/Users/thomashulihan/Projects/TRR/TRR Workspace Brain/api-contract.md` in the same commit.

Affected files or surfaces:

- `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`
- App route/repository tests if profile fixture loading is split elsewhere.
- `/Users/thomashulihan/Projects/TRR/TRR Workspace Brain/api-contract.md` only if response/freshness contract changes.

Validation steps and expected result:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm exec vitest run tests/social-account-profile-page.runtime.test.tsx --reporter=dot
```

Expected result: app runtime tests prove response-envelope compatibility after backend reads move to the repaired schema.

Acceptance criteria:

- Fixture assertions cover all affected social profile tabs.
- No visible UI redesign is required.
- Any contract change is documented in the workspace API contract ledger.

Commit boundary:

- Same commit as Phase 4 app follow-through, or a focused app-test commit immediately after backend read-path migration.

## architecture_impact

- Backend remains schema and API contract owner.
- App remains a backend API consumer.
- Instagram data becomes layered:
  - canonical post: `social.instagram_posts`
  - membership and assignment: `social.instagram_account_post_catalog`
  - normalized lookup facts: `social.instagram_post_entities`
  - normalized media facts: `social.instagram_post_media_assets`
  - scraper/source evidence: `social.instagram_post_observations`
  - comments: `social.instagram_comments`
  - temporary compatibility: `social.instagram_account_catalog_posts` and `social.instagram_account_catalog_post_collaborators`.

## data_or_api_impact

- Additive schema changes through rollout.
- `social.instagram_comments.post_id` remains unchanged.
- Backend response envelopes remain unchanged unless contract docs are explicitly updated.
- New tables require RLS, grants, comments, verifier SQL, and rollback docs.
- Type widening requires dependency checks and a manual rollback note.
- Observations keep conflicting source data out of the canonical row.

## ux_admin_ops_considerations

- Admin pages should look unchanged.
- Operators should see parity and fallback diagnostics.
- Backfill defaults to dry run.
- Production DDL remains owner-controlled and should not be added to auto-apply without a separate runtime reconcile decision.

## validation_plan

Backend:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db tests/repositories/test_social_season_analytics.py tests/api/routers/test_socials_season_analytics.py -k "instagram or social"
```

App:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm exec vitest run tests/social-account-profile-page.runtime.test.tsx --reporter=dot
```

Workspace:

```bash
cd /Users/thomashulihan/Projects/TRR
python3 scripts/migration-ownership-lint.py
make dev
```

Database:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/instagram_post_schema_parity.py --handle thetraitorsus --json
.venv/bin/python scripts/db/instagram_post_schema_parity.py --all --json
./scripts/db/run_sql.sh scripts/db/verify_instagram_post_schema_repair_phase1.sql
```

Manual:

- `http://admin.localhost:3000/social/instagram/thetraitorsus`
- Posts, Comments, Catalog, Hashtags, Collaborators / Tags, and catalog detail modal.

## acceptance_criteria

1. One canonical Instagram post row exists per valid shortcode used by comments and profile reads.
2. Account/catalog membership uses normalized handle keys and preserves display handles.
3. Legacy catalog rows have matching membership rows or documented invalid/conflict exceptions.
4. Existing comments remain attached to canonical post IDs.
5. Entity and media side tables cover hot lookup fields currently stored in JSON.
6. Scraper observations preserve conflicting metric/raw evidence.
7. Backend write paths maintain canonical, membership, entity, media, observation, and temporary legacy compatibility state.
8. Backend read paths primarily use canonical/membership/entity/media tables.
9. App/admin response envelopes remain compatible.
10. Parity scripts pass for `thetraitorsus` and all known Instagram account handles, or list approved exceptions.
11. Legacy fallback hits are measurable and accepted before retirement.
12. No legacy table is dropped or renamed without separate approval.
13. Migration ownership lint passes.
14. RLS/grants behavior for new tables is documented.

## risks_edge_cases_open_questions

- Some `source_id` values may not be valid shortcodes.
- Some canonical posts may have comments but no catalog membership.
- Existing canonical rows may contain richer fields than catalog rows.
- Metric observations can disagree by scrape runtime and time.
- Normalization must prevent `@Handle`, `handle`, and `HANDLE` from diverging.
- Raw payload public-read behavior may need a later security pass.
- Cross-platform generalization should not begin until Instagram proves the model.

## follow_up_improvements

- Generalize the canonical/membership model to other platforms after Phase 6 review.
- Add materialized social profile summaries after canonical reads settle.
- Reopen deferred unused-index owner packets only after new read paths have generated fresh evidence.

## Cleanup Note

After this plan is completely implemented and verified, delete any temporary planning artifacts that are no longer needed, including generated audit, scorecard, suggestions, comparison, patch, benchmark, and validation files. Do not delete them before implementation is complete because they are part of the execution evidence trail.

## recommended_next_step_after_approval

Use `orchestrate-plan-execution`. This implementation is tightly sequenced and should start with Phase 0 only. Use subagents only for later independent review or validation work after the main sequence has produced concrete artifacts.

## ready_for_execution

Yes, after owner approval. Start with Phase 0 and stop before destructive legacy retirement until parity and fallback gates are clean.
