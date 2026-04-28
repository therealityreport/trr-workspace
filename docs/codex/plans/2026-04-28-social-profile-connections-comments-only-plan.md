# Social Profile Comments-Only Connection Hardening Plan

Date: 2026-04-28
Status: ready for approval
Recommended executor after approval: `orchestrate-plan-execution`

## summary

Fix the local social-profile connection failure shown during `make dev` by shortening the backend DB hold time for Instagram comments-only post lists and preventing the social page from multiplying slow reads. The immediate failure is not a generic Supabase capacity problem: the backend times out on `GET /api/v1/admin/socials/profiles/instagram/thetraitorsus/posts?page=1&page_size=25&comments_only=true`, inside `instagram_collaborator_catalog_rows`, after holding the `social_profile` pool connection for about 32 seconds.

The plan keeps the current small-pool local contract, does not raise Supavisor/session-pool capacity, and does not change the public admin response envelope. The main implementation is a durable backend collaborator-membership read model plus a paged SQL fast path for Instagram comments-only profile posts, followed by app request de-duplication and route-level validation.

## saved_path

`/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-social-profile-connections-comments-only-plan.md`

## project_context

- Workspace: `/Users/thomashulihan/Projects/TRR`
- Backend owner: `/Users/thomashulihan/Projects/TRR/TRR-Backend`
- App owner: `/Users/thomashulihan/Projects/TRR/TRR-APP`
- Current route contract: backend owns `GET /api/v1/admin/socials/profiles/{platform}/{handle}/dashboard`; the app snapshot route proxies that dashboard and should keep initial page load to one lightweight request.
- Live failure evidence from `/Users/thomashulihan/Projects/TRR/.logs/workspace/trr-backend.log`: `statement_timeout label=social-profile-posts-instagram-comments-only`, followed by a 500 for `/profiles/instagram/thetraitorsus/posts?...comments_only=true`.
- The stack trace shows `get_social_account_profile_posts` calling `_instagram_social_account_profile_dataset_rows`, which then times out in `_fetch_instagram_collaborator_catalog_rows`.
- The collaborator query fails because it asks Postgres to scan `social.instagram_account_catalog_posts`, unnest `collaborators` and `collaborators_detail` JSON for candidate rows, normalize each value at query time, sort by `posted_at`, and only then limit. Existing owner indexes cannot help that JSON membership predicate.
- App log evidence from `/Users/thomashulihan/Projects/TRR/.logs/workspace/trr-app.log`: snapshot reads took 6 to 14 seconds, full summary took about 19 seconds, and the comments-only posts route failed after about 34 seconds.
- Read-only Supabase evidence captured through the Supabase Fullstack surface: the key owner/comment indexes already exist, including `idx_social_instagram_posts_source_account_lower_id`, `idx_social_instagram_posts_source_account_lower_posted_at_id`, `instagram_account_catalog_posts_account_posted_at_idx`, and `idx_social_instagram_comments_post_created_at`.
- Read-only Supabase count evidence for `thetraitorsus`: `431` owner rows in `social.instagram_posts`, `431` owner rows in `social.instagram_account_catalog_posts`, and `9913` saved comments for owner posts.
- Existing backend code already contains the narrow exact-total rewrite for the dedicated comments endpoint. The remaining timeout is the separate comments-only posts list path.

## assumptions

1. The comments-only posts list must keep the existing response shape: `items`, `pagination`, `match_mode`, `source_surface`, post metadata, and `saved_comments`.
2. Local `make dev` should stay within the current direct-lane holder budget instead of hiding bad query shape behind larger pools.
3. Collaborator rows are part of the social-profile contract and should be fixed durably, not bypassed. The no-search comments-only path may prefer owner rows first, but collaborator lookup must become indexed/normalized and remain available to profile posts, summaries, collaborators/tags, and search surfaces.
4. Search plus `comments_only=true` can keep the existing dataset-search path initially because the current failure is the no-search comments tab load.
5. Backend-first sequencing applies; app changes should follow after the backend route is fast and has a stable error contract.

## goals

1. Make `/social/instagram/thetraitorsus/comments` load without a backend `statement_timeout`.
2. Reduce `social-profile-posts-instagram-comments-only` connection hold time from about 32 seconds to under 1 second for page 1.
3. Preserve exact pagination totals or explicitly document any accepted total semantics change before implementation.
4. Keep the backend route under the existing `social_profile` pool and local holder budget.
5. Make app-side social pages avoid duplicate snapshot/summary/posts bursts when a slow read is already in flight.
6. Return classified, retryable backend errors for DB timeouts instead of raw 500s.
7. Replace query-time JSON collaborator expansion with a maintained collaborator membership table or equivalent normalized read model.

## non_goals

- No Supabase compute upgrade.
- No Supavisor pool-size increase.
- No Edge Function, Redis, or broad social-profile read-model migration. A narrow Instagram catalog collaborator membership read model is in scope.
- No rewrite of all social profile tabs.
- No production env mutation.
- No change to scraper/backfill worker behavior except where validation needs existing data.

## phased_implementation

### Phase 0 - Confirm The Exact Runtime Failure

Concrete changes:

- Add a short diagnostic note under `docs/ai/local-status/` or append to the existing social-profile local-status file with:
  - backend stack trace label: `social-profile-posts-instagram-comments-only`
  - failing subquery label: `instagram_collaborator_catalog_rows`
  - app route and backend route URLs
  - current app timings for snapshot, summary, and comments-only posts
  - read-only index evidence from `pg_indexes`
- Add one temporary or scriptable backend timing probe for:
  - `get_social_account_profile_posts("instagram", "thetraitorsus", comments_only=True, page=1, page_size=25)`
  - `get_social_account_profile_comments("instagram", "thetraitorsus", page=1, page_size=25)`
  - `get_social_account_profile_summary("instagram", "thetraitorsus", detail="lite")`

Validation:

- Reproduce the current timeout before code changes or capture the existing log block as baseline evidence.
- Confirm `get_social_account_profile_comments(...)` is not the failing path; the failure is the comments-only posts list.

Acceptance criteria:

- A future implementer can point to one backend call path and one app route as the cause.
- No pool-size or env change is made in this phase.

Commit boundary:

- Docs/diagnostics only.

### Phase 1 - Normalize Instagram Catalog Collaborator Membership

Why this phase exists:

- `_fetch_instagram_collaborator_catalog_rows(...)` currently uses `jsonb_array_elements_text(p.collaborators)` and `jsonb_array_elements(to_jsonb(p) -> 'collaborators_detail')` inside `exists` clauses.
- Those expressions are row-expansion work. They do not use the existing `instagram_account_catalog_posts_account_posted_at_idx`.
- Because the comments-only posts path calls `_instagram_social_account_profile_dataset_rows(...)` with no limit, the collaborator scan can evaluate the whole catalog before Python filters and paginates.

Concrete changes:

- Add a backend migration for a narrow membership table:

```sql
create table if not exists social.instagram_account_catalog_post_collaborators (
  catalog_post_id uuid not null references social.instagram_account_catalog_posts(id) on delete cascade,
  source_id text not null,
  source_account text not null,
  collaborator_handle text not null,
  collaborator_source text not null check (collaborator_source in ('collaborators', 'collaborators_detail')),
  posted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (catalog_post_id, collaborator_handle)
);

create index if not exists instagram_catalog_post_collaborators_handle_posted_idx
  on social.instagram_account_catalog_post_collaborators
  (collaborator_handle, posted_at desc nulls last, catalog_post_id);

create index if not exists instagram_catalog_post_collaborators_source_account_idx
  on social.instagram_account_catalog_post_collaborators
  (lower(source_account), posted_at desc nulls last);
```

- Backfill the table from both current JSON shapes:
  - `instagram_account_catalog_posts.collaborators`, an array of handles.
  - `instagram_account_catalog_posts.collaborators_detail`, when present as an added column or inside `raw_data`, using `username`.
- Normalize handles with the same semantics as `_normalize_social_account_profile_handle_term` / `_canonicalize_social_account_profile_mention_identity`: lowercase, strip leading `@`, remove invalid characters, drop empty values.
- Add a repository helper, likely `_sync_instagram_catalog_post_collaborators(...)`, that deletes/replaces membership rows for one catalog post after catalog upsert.
- Call that helper from both Instagram catalog write paths:
  - `_upsert_shared_catalog_instagram_post(...)`
  - `_batch_upsert_shared_catalog_instagram_posts(...)`
- Add a one-time backfill script or migration SQL that can be re-run safely:
  - `insert ... select ... from social.instagram_account_catalog_posts`
  - `on conflict (catalog_post_id, collaborator_handle) do update`
  - a cleanup step that removes rows whose source post no longer contains the collaborator after future rewrites.
- Rewrite `_fetch_instagram_collaborator_catalog_rows(...)` to join this membership table instead of expanding JSON:

```sql
from social.instagram_account_catalog_post_collaborators m
join social.instagram_account_catalog_posts p on p.id = m.catalog_post_id
where m.collaborator_handle = %s
  and lower(p.source_account) <> %s
order by m.posted_at desc nulls last, m.catalog_post_id desc
limit %s
```

Affected files:

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Optional: `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/` for a repeatable backfill/check script if migration-only SQL is too large.

Validation:

- Unit tests for handle normalization and syncing membership rows after single and batch catalog upserts.
- Repository tests proving `_fetch_instagram_collaborator_catalog_rows(...)` queries the membership table, not `jsonb_array_elements`.
- A DB check that `thetraitorsus` collaborator lookup uses `instagram_catalog_post_collaborators_handle_posted_idx`.
- Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "collaborator_catalog or catalog_post_collaborators"
```

Acceptance criteria:

- Collaborator rows remain part of profile results.
- The collaborator lookup is indexable by `collaborator_handle`.
- Query-time JSON unnesting is removed from hot profile read paths.
- Existing catalog writes maintain collaborator membership automatically.

Commit boundary:

- Backend migration, membership maintenance helpers, and collaborator repository tests.

### Phase 2 - Add An Instagram Comments-Only Posts Fast Path

Concrete changes:

- Add a new backend helper in `TRR-Backend/trr_backend/repositories/social_season_analytics.py`, likely named `_fetch_instagram_comments_only_profile_rows_page`.
- Route only this branch through the helper:
  - platform is `instagram`
  - `comments_only=true`
  - no search query
- Replace the current broad `_instagram_social_account_profile_dataset_rows(... comments_only=True)` call for that branch.
- Build the helper around SQL pagination instead of Python-side full dataset filtering:
  - normalize the account handle once
  - assert the profile exists using the same `social_profile` connection
  - read owner materialized rows from `social.instagram_posts` with `lower(source_account) = %s`
  - read owner catalog rows from `social.instagram_account_catalog_posts` only where needed for metadata/source parity
  - count saved comments with indexed joins against `social.instagram_comments.post_id`
  - filter rows where `greatest(reported comments, saved comments) > 0`
  - return `rows, total` directly for the requested page
- Preserve item serialization through `_social_account_profile_post_item(...)` so UI shape remains unchanged.
- Include collaborator rows through the normalized membership table from Phase 1, not by expanding JSON.
- Merge/dedupe owner materialized rows, owner catalog rows, and collaborator catalog rows inside SQL or in a bounded Python merge after SQL has already paged candidate ids. Do not fetch the entire account catalog.

Affected files:

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/test_social_season_analytics.py`

Validation:

- Add a regression that fails if the Instagram no-search comments-only path calls `_instagram_social_account_profile_dataset_rows`.
- Add a regression that verifies exact total and page slicing are returned from the new helper.
- Add a regression that verifies `saved_comments`, `match_mode`, and `source_surface` survive serialization.
- Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "profile_posts and comments_only"
```

Acceptance criteria:

- The no-search Instagram comments-only posts path no longer executes the broad collaborator catalog scan.
- Collaborator posts are still eligible for comments-only profile results through the membership table.
- Page 1 returns within the target budget using one `social_profile` checkout.
- Existing search behavior remains unchanged.

Commit boundary:

- Backend query/helper and repository tests.

### Phase 3 - Add Or Adjust Additional Indexes Only If Query Evidence Requires It

Concrete changes:

- Before adding migrations, run `EXPLAIN (ANALYZE, BUFFERS)` on the new helper SQL against the local/dev database.
- Do not add duplicate owner indexes; live evidence already shows owner and comment indexes exist.
- Do not add a broad GIN index as the primary collaborator fix unless the normalized membership table is proven inadequate. The long-term fix is membership normalization, not making every social profile read unnest JSON faster.
- Keep migrations in `TRR-Backend/supabase/migrations/`.

Affected files:

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/query-plan-evidence-runbook.md` if evidence docs need updating

Validation:

- Re-run the index inventory query and save only redacted/non-secret evidence.
- Re-run the route timing probe after any migration.

Acceptance criteria:

- No redundant index is added.
- Any new index is tied to a specific `EXPLAIN` bottleneck and query predicate.

Commit boundary:

- One backend migration commit if needed; otherwise no commit for this phase.

### Phase 4 - Classify Statement Timeouts And Stop Raw 500s

Concrete changes:

- Extend backend DB error normalization so `psycopg2.errors.QueryCanceled` from statement timeout becomes a structured database-service response, for example:
  - `code: DATABASE_SERVICE_UNAVAILABLE`
  - `reason: statement_timeout`
  - `retryable: true`
  - safe operator message
- Add route coverage for social profile posts so a DB timeout returns 503 rather than an unhandled 500.
- Revisit app route retry behavior in `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/posts/route.ts`:
  - avoid retrying long comments-only reads after a backend statement timeout
  - keep fast transient transport retries where they do not multiply DB work

Affected files:

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/db/pg.py`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/socials.py`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/api/routers/test_socials_season_analytics.py`
- `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/posts/route.ts`
- App tests for social proxy error handling if existing coverage is present.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/api/routers/test_socials_season_analytics.py -k "profile_posts and unavailable"
```

Acceptance criteria:

- Statement timeout no longer appears as an unclassified backend 500.
- The app displays a degraded comments/posts panel state instead of treating the entire profile page as broken.

Commit boundary:

- Backend error contract plus app retry behavior.

### Phase 5 - Reduce Social Page Request Fanout

Concrete changes:

- Audit `SocialAccountProfilePage` request launch behavior for `/social/instagram/thetraitorsus/comments`.
- Ensure the comments tab does not launch duplicate snapshot reads or full summary fallback while an initial snapshot is already pending.
- Preserve the dashboard contract: initial load is one `/snapshot?detail=lite`; posts/comments/hashtags/socialblade/freshness diagnostics load only when the relevant tab or panel opens.
- Reuse the app snapshot cache and in-flight request keys so two near-identical snapshot calls collapse instead of running concurrently.
- Add tab-level stale/error rendering for comments-only posts so the rest of the profile summary stays usable.

Affected files:

- `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`
- `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`
- Any existing social profile request helper under `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/admin/`

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run -c vitest.config.ts tests/social-account-profile-page.runtime.test.tsx --reporter=dot
pnpm exec eslint src/components/admin/SocialAccountProfilePage.tsx
```

Manual check:

- Open `http://admin.localhost:3000/social/instagram/thetraitorsus/comments`.
- Confirm Network shows one initial snapshot request and one comments-only posts request for the tab, not repeated snapshot/summary bursts.

Acceptance criteria:

- The page stays usable if comments-only posts fail.
- No duplicate first-paint snapshot requests remain for the same profile/query.

Commit boundary:

- App page/request behavior and focused tests.

### Phase 6 - End-To-End Runtime Validation

Concrete changes:

- Restart `make dev` so pool settings and backend code are fresh.
- Capture before/after timings from backend logs and app logs.
- Validate local holder budget remains within documented defaults.
- Add a short closeout note under `docs/ai/local-status/` with:
  - final backend route timing
  - `social_profile` checkout hold time
  - app route render timing
  - manual browser route result
  - remaining risks

Validation commands:

```bash
cd /Users/thomashulihan/Projects/TRR
make preflight
bash scripts/status-workspace.sh --json
```

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "profile_posts or profile_comments"
.venv/bin/python -m pytest -q tests/api/routers/test_socials_season_analytics.py -k "profile_posts or profile_comments"
.venv/bin/python -m pytest -q tests/db/test_pg_pool.py -k "social_profile_pool or db_read_connection"
```

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run -c vitest.config.ts tests/social-account-profile-page.runtime.test.tsx --reporter=dot
```

Acceptance criteria:

- `GET /api/v1/admin/socials/profiles/instagram/thetraitorsus/posts?...comments_only=true` returns 200 locally.
- Backend log shows no `statement_timeout` for `social-profile-posts-instagram-comments-only`.
- Connection hold time for the comments-only route is below 1000 ms for page 1.
- App route completes under 3 seconds warm and under 8 seconds cold, excluding first compile.
- `make dev` attention no longer includes a DB saturation issue for this route.

Commit boundary:

- Validation/docs closeout.

## architecture_impact

- Backend remains the owner of social profile composition and DB access.
- App remains a proxy/cache/UI surface and should not add direct SQL or local DB fanout for this fix.
- The named `social_profile` pool remains the correct lane for these reads, but the fix reduces hold time rather than increasing pool size.
- Query-plan evidence decides whether a new migration is justified.

## data_or_api_impact

- No response-envelope change is planned.
- Possible additive internal helper only.
- Backend migration adds a narrow `social.instagram_account_catalog_post_collaborators` membership table and supporting indexes.
- No Supabase project capacity, Auth DB allocation, or Vercel env mutation is part of this plan.
- Error contract may become more specific by classifying statement timeouts as structured 503s.

## ux_admin_ops_considerations

- Operators should see the profile summary even when the comments-only tab is degraded.
- Comments-only tab failure copy should distinguish backend DB timeout from scraper/auth failure.
- Logs should preserve route labels and pool labels so the next failure can be tied to a DB hold path quickly.
- The browser automation warning on port `9422` is separate from this DB issue; do not mix it into the social-page fix.

## validation_plan

Automated:

- Backend repository tests for Instagram comments-only posts fast path.
- Backend API tests for structured timeout handling.
- Backend pool tests for named pool behavior.
- App runtime tests for request de-duplication and degraded tab rendering.

Manual:

- `make dev`, then open `http://admin.localhost:3000/social/instagram/thetraitorsus/comments`.
- Watch `/Users/thomashulihan/Projects/TRR/.logs/workspace/trr-backend.log` for `statement_timeout`.
- Watch `/Users/thomashulihan/Projects/TRR/.logs/workspace/trr-app.log` for duplicate snapshot/summary bursts.

Expected result:

- One stable profile page load, no backend statement timeout, and no connection-pool widening.

## acceptance_criteria

- Backend no-search Instagram comments-only posts path is paged in SQL and does not call the broad dataset row builder.
- `thetraitorsus` comments tab returns a 200 for comments-only posts.
- Warm comments-only posts route is under 1000 ms backend hold time.
- App does not launch duplicate snapshot/summary requests for the same initial profile load.
- Statement timeouts are classified as 503 with safe details.
- No redundant Supabase index migration is added.
- Local holder budget remains unchanged.

## risks_edge_cases_open_questions

- Exact pagination totals can become expensive if collaborator inclusion is preserved through JSON expansion. This plan resolves that by normalizing collaborator membership first; if totals are still slow after that, investigate dedupe/count shape before relaxing semantics.
- Search plus `comments_only=true` may still be slower because it intentionally stays on the broader search path in this plan.
- Snapshot timings are still higher than ideal in cold runs; this plan fixes the active timeout first, then reduces duplicate fanout.

## follow_up_improvements

- Consider a materialized social profile comments-summary read model only after the fast-path SQL and request de-duplication are measured.
- Add per-route `application_name` suffixing for the highest-volume social profile endpoints if `pg_stat_activity` still cannot identify route pressure.
- Add a lightweight browser/network regression check for the social profile first-paint budget.
- Consider expanding the normalized membership pattern to tags/mentions only if they show the same repeated hot-path scan behavior.

## recommended_next_step_after_approval

Use `orchestrate-plan-execution` because this is a tightly coupled backend-first fix with app follow-through after the backend contract and timing are stable.

## ready_for_execution

Yes. The implementation should begin with Phase 0 baseline capture and Phase 1 backend fast-path tests before touching app request behavior.
