# Instagram Comments Sync Full Account Start Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove why clicking `Sync Comments` for `thetraitorsus` does not start a full-account comments run, then apply the smallest fix so the Instagram comments launcher targets every saved account post.

**Architecture:** Trace the action from `InstagramCommentsPanel` through the Next.js admin proxy, FastAPI route, backend kickoff, and saved-post target selection. Existing tests already prove the UI emits a POST body and the proxy/backend accept `refresh_policy: "all_saved_posts"`; this plan adds a live trace and a backend regression for the saved-post coverage gap that can still prevent a true full-account sync. The smallest code change is to make `all_saved_posts` target selection use the canonical saved-post inventory from both `social.instagram_posts` and `social.instagram_account_catalog_posts`, deduped in existing display order.

**Tech Stack:** Next.js App Router, Vitest, FastAPI, pytest, Postgres/Supabase, TRR social scrape run/job tables.

---

## Current Evidence

- `TRR-APP/apps/web/src/components/admin/instagram/InstagramCommentsPanel.tsx:237-275` sends `POST /api/admin/trr-api/social/profiles/${platform}/${handle}/comments/scrape` with `{ mode: "profile", source_scope: "bravo", refresh_policy: "all_saved_posts" }`.
- `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/comments/scrape/route.ts:14-30` requires admin, reserializes the request JSON, and forwards it to `/profiles/{platform}/{handle}/comments/scrape` with `Content-Type: application/json`.
- `TRR-Backend/api/routers/socials.py:4516-4566` forwards the FastAPI request to `start_social_account_comments_scrape(...)`.
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py:55540-55730` creates a comments run and job from `target_source_ids`.
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py:55337-55413` currently uses `social.instagram_posts` first for `all_saved_posts` and only falls back to `social.instagram_account_catalog_posts` when that first query returns zero rows. That is the likely saved-post coverage break for full-account sync: a partial materialized table can block catalog-only saved posts from being targeted.
- Targeted existing tests passed on 2026-04-24:
  - `pnpm -C TRR-APP/apps/web exec vitest run tests/social-account-comments-scrape-route.test.ts tests/social-account-profile-page.runtime.test.tsx -t "queues a profile comments scrape|forwards comments scrape"`: 2 passed.
  - `TRR-Backend/.venv/bin/python -m pytest -q TRR-Backend/tests/api/routers/test_socials_season_analytics.py -k "comments_scrape_accepts_all_saved_posts"`: 1 passed.
  - `TRR-Backend/.venv/bin/python -m pytest -q TRR-Backend/tests/repositories/test_social_season_analytics.py -k "comment_target_shortcodes_all_saved_posts or comments_scrape_all_saved_posts_uses_uncapped_profile_defaults"`: 2 passed.

## Execution Update

Live Task 1 execution on 2026-04-24 disproved the original saved-post target-selection hypothesis for `thetraitorsus`:

- Saved inventory was complete in both stores: `materialized_posts=431`, `catalog_posts=431`, `materialized_shortcodes=431`, `catalog_source_ids=431`.
- A live POST did create a queued comments run with all saved posts targeted: run `ecb22422-547f-42ba-a3f4-50ee6179d3af`, job `59c4dd37-e0bf-44ed-afc1-f541d605cbfa`, `target_source_ids_count=431`.
- The operator-facing "nothing happens" symptom came from the route blocking on synchronous Modal dispatch before returning the queued payload. The run later failed downstream in the worker with `redirect_to_homepage`, which is a separate runtime/auth issue.

The implemented fix therefore moved queued comments dispatch out of the request path instead of changing saved-post target selection:

- `start_social_account_comments_scrape(..., dispatch_immediately=True)` preserves existing repository default behavior.
- The FastAPI comments scrape route calls `start_social_account_comments_scrape(..., dispatch_immediately=not queue_enabled)`.
- Queued comments launches schedule `_dispatch_due_social_jobs_in_background(run_id=...)`, the repo's existing exception-isolating dispatcher wrapper, before returning the unchanged queued response.
- Non-queue inline fallback still uses `_start_runs_in_background(...)`.

## File Structure

| Path | Responsibility |
| --- | --- |
| `TRR-Backend/tests/repositories/test_social_season_analytics.py` | Add failing regressions for full-account target selection and coverage when saved posts live in the shared account catalog. |
| `TRR-Backend/trr_backend/repositories/social_season_analytics.py` | Add the minimal saved-post shortcode helper and use it for `all_saved_posts` startup. Optionally align coverage counts with the same saved-post source if the live trace proves coverage is stale. |
| `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx` | Keep as verification only; no app edit unless the live browser trace proves the click never sends the POST. |
| `TRR-APP/apps/web/src/components/admin/instagram/InstagramCommentsPanel.tsx` | Touch only if Task 1 proves the click handler is blocked before the POST. |
| `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/comments/scrape/route.ts` | Touch only if Task 1 proves the proxy body/header contract regressed. |
| `TRR Workspace Brain/api-contract.md` | Update only if the response shape changes. The preferred fix does not change the API contract. |

## Scope Check

This is one cross-boundary bug, not multiple independent projects. Backend-first still applies because the likely failure is saved-post target selection. App work is verification-only unless the live trace contradicts the existing tests.

### Task 1: Prove The Exact Broken Hop

**Files:**
- Read: `TRR-APP/apps/web/src/components/admin/instagram/InstagramCommentsPanel.tsx`
- Read: `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/comments/scrape/route.ts`
- Read: `TRR-Backend/api/routers/socials.py`
- Read: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`

- [ ] **Step 1: Confirm the current page route and button path**

Run:

```bash
rg -n "Sync Comments|comments/scrape|startProfileScrape" \
  TRR-APP/apps/web/src/components/admin/instagram/InstagramCommentsPanel.tsx \
  'TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/comments/scrape/route.ts' \
  TRR-Backend/api/routers/socials.py \
  TRR-Backend/trr_backend/repositories/social_season_analytics.py
```

Expected: the UI button calls `startProfileScrape`, the Next route forwards to `/profiles/{platform}/{handle}/comments/scrape`, FastAPI calls `start_social_account_comments_scrape`, and the backend builds `target_source_ids`.

- [ ] **Step 2: Probe the live saved-post inventory without starting a run**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
scripts/db/run_sql.sh <<'SQL'
select
  (select count(*) from social.instagram_posts where lower(source_account) = 'thetraitorsus') as materialized_posts,
  (select count(*) from social.instagram_account_catalog_posts where lower(source_account) = 'thetraitorsus') as catalog_posts,
  (select count(distinct shortcode) from social.instagram_posts where lower(source_account) = 'thetraitorsus' and nullif(shortcode, '') is not null) as materialized_shortcodes,
  (select count(distinct shortcode) from social.instagram_account_catalog_posts where lower(source_account) = 'thetraitorsus' and nullif(shortcode, '') is not null) as catalog_shortcodes;
SQL
```

Expected current-break signature: `catalog_posts` or `catalog_shortcodes` is greater than `materialized_posts` or `materialized_shortcodes`. If the counts are identical, continue to Step 3 because the break is not saved-post selection.

- [ ] **Step 3: Probe the launcher through the app route once**

Only run this when it is acceptable to create or reuse a comments run:

```bash
curl -sS -X POST \
  'http://admin.localhost:3000/api/admin/trr-api/social/profiles/instagram/thetraitorsus/comments/scrape' \
  -H 'Content-Type: application/json' \
  --data '{"mode":"profile","source_scope":"bravo","refresh_policy":"all_saved_posts"}' \
  | jq '{run_id,status,required_execution_backend,target_source_ids_count: (.target_source_ids | length), error, code, upstream_detail}'
```

Expected before fix: either no `run_id`, a non-2xx proxy/backend error, or a `target_source_ids_count` lower than the saved catalog shortcode count from Step 2. Expected after fix: JSON includes `run_id`, `status`, and `target_source_ids_count` equal to the saved catalog shortcode count unless there is already an active comments run.

- [ ] **Step 4: Inspect the created or active run**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
scripts/db/run_sql.sh <<'SQL'
select
  r.id::text as run_id,
  r.status as run_status,
  r.config->>'refresh_policy' as refresh_policy,
  r.config->>'stage' as stage,
  jsonb_array_length(coalesce(j.config->'target_source_ids', '[]'::jsonb)) as target_source_ids_count,
  j.status as job_status,
  j.error_message
from social.scrape_runs r
join social.scrape_jobs j on j.run_id = r.id
where j.platform = 'instagram'
  and coalesce(j.config->>'stage', j.metadata->>'stage', j.job_type) = 'instagram_comments_scrapling'
  and ltrim(lower(coalesce(j.config->>'account', j.metadata->>'account', '')), '@') = 'thetraitorsus'
order by r.created_at desc
limit 3;
SQL
```

Expected before fix: the most recent run is absent, failed before job creation, or has a target count below the saved catalog shortcode count. Expected after fix: a queued or pending job exists with a full target count.

- [ ] **Step 5: Commit no code in this task**

Do not commit after evidence collection. Record the exact broken hop in the implementation notes before Task 2.

### Task 2: Add A Failing Backend Regression For Full Saved-Post Targets

**Files:**
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Test: `TRR-Backend/tests/repositories/test_social_season_analytics.py`

- [ ] **Step 1: Add a failing unit test for unioning materialized and catalog saved posts**

Append this test near `test_instagram_social_account_comment_target_shortcodes_all_saved_posts_ignores_stale_filters`:

```python
def test_instagram_social_account_comment_target_shortcodes_all_saved_posts_includes_catalog_saved_posts(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    queries: list[str] = []
    params_seen: list[list[Any]] = []

    def _fake_fetch_all(sql: str, params: list[Any]) -> list[dict[str, Any]]:
        queries.append(sql)
        params_seen.append(list(params))
        if "from social.instagram_posts p" in sql:
            return [{"shortcode": "C2"}]
        if "from social.instagram_account_catalog_posts p" in sql:
            return [{"shortcode": "C3"}, {"shortcode": "C2"}, {"shortcode": "C1"}]
        raise AssertionError(sql)

    monkeypatch.setattr(social_repo.pg, "fetch_all", _fake_fetch_all)

    shortcodes = social_repo._instagram_social_account_comment_target_shortcodes(
        "thetraitorsus",
        limit=None,
        refresh_policy="all_saved_posts",
    )

    assert shortcodes == ["C2", "C3", "C1"]
    assert any("from social.instagram_posts p" in query for query in queries)
    assert any("from social.instagram_account_catalog_posts p" in query for query in queries)
    assert params_seen == [["thetraitorsus"], ["thetraitorsus"]]
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
TRR-Backend/.venv/bin/python -m pytest -q \
  TRR-Backend/tests/repositories/test_social_season_analytics.py \
  -k "comment_target_shortcodes_all_saved_posts_includes_catalog_saved_posts"
```

Expected: FAIL because the current `all_saved_posts` path stops after `social.instagram_posts` returns `["C2"]` and never includes catalog-only `["C3", "C1"]`.

- [ ] **Step 3: Commit the failing test only if the project workflow allows red commits**

Preferred for this repo: do not commit a red test alone. Keep the test unstaged until Task 3 passes.

### Task 3: Implement The Minimal Saved-Post Target Fix

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Test: `TRR-Backend/tests/repositories/test_social_season_analytics.py`

- [ ] **Step 1: Add a tiny dedupe helper near `_instagram_social_account_comment_target_shortcodes`**

Insert this helper immediately before `_instagram_social_account_comment_target_shortcodes`:

```python
def _dedupe_shortcodes_preserving_order(rows: Sequence[Mapping[str, Any]], *, limit: int | None) -> list[str]:
    seen: set[str] = set()
    shortcodes: list[str] = []
    for row in rows:
        shortcode = str(row.get("shortcode") or "").strip()
        if not shortcode or shortcode in seen:
            continue
        seen.add(shortcode)
        shortcodes.append(shortcode)
        if limit is not None and len(shortcodes) >= limit:
            break
    return shortcodes
```

- [ ] **Step 2: Replace the `all_saved_posts` branch with canonical saved-post collection**

Replace lines `55347-55373` in `TRR-Backend/trr_backend/repositories/social_season_analytics.py` with:

```python
    if normalized_refresh_policy == "all_saved_posts":
        materialized_sql = f"""
        select p.shortcode
        from social.instagram_posts p
        where {owner_match_clause}
          and nullif(p.shortcode, '') is not null
        order by p.posted_at desc nulls last, p.shortcode desc
        """
        materialized_params: list[Any] = [normalized_account]
        if safe_limit is not None:
            materialized_sql += " limit %s"
            materialized_params.append(safe_limit)
        materialized_rows = pg.fetch_all(materialized_sql, materialized_params)

        table, source_id_column, posted_at_column = _shared_catalog_base_query_parts("instagram")
        shared_sql = f"""
        select p.{source_id_column}::text as shortcode
        from social.{table} p
        where lower(p.source_account) = %s
          and nullif(p.{source_id_column}::text, '') is not null
        order by p.{posted_at_column} desc nulls last, p.{source_id_column}::text desc
        """
        shared_params: list[Any] = [normalized_account]
        if safe_limit is not None:
            shared_sql += " limit %s"
            shared_params.append(safe_limit)
        shared_rows = pg.fetch_all(shared_sql, shared_params)
        rows = _dedupe_shortcodes_preserving_order(
            [*list(materialized_rows or []), *list(shared_rows or [])],
            limit=safe_limit,
        )
        return rows
```

- [ ] **Step 3: Run the new backend regression**

Run:

```bash
TRR-Backend/.venv/bin/python -m pytest -q \
  TRR-Backend/tests/repositories/test_social_season_analytics.py \
  -k "comment_target_shortcodes_all_saved_posts_includes_catalog_saved_posts"
```

Expected: PASS.

- [ ] **Step 4: Run the existing backend comments startup tests**

Run:

```bash
TRR-Backend/.venv/bin/python -m pytest -q \
  TRR-Backend/tests/repositories/test_social_season_analytics.py \
  -k "comment_target_shortcodes_all_saved_posts or comments_scrape_all_saved_posts_uses_uncapped_profile_defaults or comments_scrape_reuses_lock_connection"
```

Expected: PASS. This verifies the new union behavior, uncapped full-account startup, and lock-connection reuse.

- [ ] **Step 5: Commit the backend fix**

Run:

```bash
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py \
  TRR-Backend/tests/repositories/test_social_season_analytics.py
git commit -m "fix: target catalog posts for Instagram comments sync"
```

Expected: commit succeeds.

### Task 4: Align Comments Coverage Only If The Live Trace Proves It Is Stale

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`

- [ ] **Step 1: Add a failing coverage-count test**

Add this test near `test_get_social_account_profile_summary_adds_effective_comments_coverage_fields` only if Task 1 showed coverage counts coming from materialized posts while catalog saved posts exist:

```python
def test_instagram_social_account_comments_target_counts_reports_catalog_available_posts(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[tuple[str, list[Any]]] = []

    monkeypatch.setattr(social_repo, "_comment_lifecycle_supported", lambda *_args, **_kwargs: True)

    def _fake_fetch_one(sql: str, params: list[Any]) -> dict[str, Any]:
        calls.append((sql, list(params)))
        if "from posts" in sql and "catalog_available_posts" not in sql:
            return {
                "available_posts": 1,
                "eligible_posts": 1,
                "missing_posts": 1,
                "stale_posts": 0,
            }
        if "catalog_available_posts" in sql:
            return {
                "available_posts": 3,
                "eligible_posts": 1,
                "missing_posts": 1,
                "stale_posts": 0,
            }
        raise AssertionError(sql)

    monkeypatch.setattr(social_repo.pg, "fetch_one", _fake_fetch_one)

    payload = social_repo._instagram_social_account_comments_target_counts("thetraitorsus")

    assert payload["available_posts"] == 3
    assert payload["eligible_posts"] == 1
    assert payload["missing_posts"] == 1
    assert payload["stale_posts"] == 0
```

- [ ] **Step 2: Run the coverage test**

Run:

```bash
TRR-Backend/.venv/bin/python -m pytest -q \
  TRR-Backend/tests/repositories/test_social_season_analytics.py \
  -k "comments_target_counts_reports_catalog_available_posts"
```

Expected before coverage fix: FAIL because `_instagram_social_account_comments_target_counts` only counts `social.instagram_posts`.

- [ ] **Step 3: Keep the coverage fix minimal**

Change `_instagram_social_account_comments_target_counts` so `available_posts` is the greater of materialized available posts and catalog saved-post count, without changing `eligible_posts`, `missing_posts`, or `stale_posts`.

Use this implementation pattern inside `_instagram_social_account_comments_target_counts` after the existing `row` is loaded:

```python
    catalog_table, catalog_source_id_column, _catalog_posted_at_column = _shared_catalog_base_query_parts("instagram")
    catalog_sql = f"""
        select count(distinct p.{catalog_source_id_column}::text)::int as available_posts
        from social.{catalog_table} p
        where lower(p.source_account) = %s
          and nullif(p.{catalog_source_id_column}::text, '') is not null
    """
    if conn is None:
        catalog_row = pg.fetch_one(catalog_sql, [normalized_account]) or {}
    else:
        with pg.db_cursor(conn=conn, label="instagram_comments_catalog_target_counts") as cur:
            catalog_row = pg.fetch_one_with_cursor(cur, catalog_sql, [normalized_account]) or {}
    available_posts = max(
        _normalize_non_negative_int(row.get("available_posts")),
        _normalize_non_negative_int(catalog_row.get("available_posts")),
    )
```

Then return:

```python
    return {
        "available_posts": available_posts,
        "eligible_posts": _normalize_non_negative_int(row.get("eligible_posts")),
        "missing_posts": _normalize_non_negative_int(row.get("missing_posts")),
        "stale_posts": _normalize_non_negative_int(row.get("stale_posts")),
    }
```

- [ ] **Step 4: Run coverage and summary tests**

Run:

```bash
TRR-Backend/.venv/bin/python -m pytest -q \
  TRR-Backend/tests/repositories/test_social_season_analytics.py \
  -k "comments_target_counts_reports_catalog_available_posts or get_social_account_profile_summary_adds_effective_comments_coverage_fields"
```

Expected: PASS.

- [ ] **Step 5: Commit the coverage alignment if applied**

Run:

```bash
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py \
  TRR-Backend/tests/repositories/test_social_season_analytics.py
git commit -m "fix: align Instagram comments coverage with saved catalog posts"
```

Expected: commit succeeds. Skip this commit if Task 1 showed coverage counts were not part of the break.

### Task 5: Verify End-To-End Launch Through The App

**Files:**
- Test: `TRR-APP/apps/web/tests/social-account-comments-scrape-route.test.ts`
- Test: `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`
- Test: `TRR-Backend/tests/api/routers/test_socials_season_analytics.py`
- Test: `TRR-Backend/tests/repositories/test_social_season_analytics.py`

- [ ] **Step 1: Run app launch tests**

Run:

```bash
pnpm -C TRR-APP/apps/web exec vitest run \
  tests/social-account-comments-scrape-route.test.ts \
  tests/social-account-profile-page.runtime.test.tsx \
  -t "queues a profile comments scrape|forwards comments scrape"
```

Expected: PASS.

- [ ] **Step 2: Run backend route and repository tests**

Run:

```bash
TRR-Backend/.venv/bin/python -m pytest -q \
  TRR-Backend/tests/api/routers/test_socials_season_analytics.py \
  -k "comments_scrape_accepts_all_saved_posts"

TRR-Backend/.venv/bin/python -m pytest -q \
  TRR-Backend/tests/repositories/test_social_season_analytics.py \
  -k "comment_target_shortcodes_all_saved_posts or comments_scrape_all_saved_posts_uses_uncapped_profile_defaults or comments_scrape_reuses_lock_connection"
```

Expected: PASS.

- [ ] **Step 3: Start or reuse local dev servers**

Run if `make dev` is not already running:

```bash
make dev
```

Expected: app is available at `http://admin.localhost:3000` and backend is available at `http://127.0.0.1:8000`.

- [ ] **Step 4: Launch the `thetraitorsus` sync through the same route the button uses**

Run:

```bash
curl -sS -X POST \
  'http://admin.localhost:3000/api/admin/trr-api/social/profiles/instagram/thetraitorsus/comments/scrape' \
  -H 'Content-Type: application/json' \
  --data '{"mode":"profile","source_scope":"bravo","refresh_policy":"all_saved_posts"}' \
  | tee /tmp/thetraitorsus-comments-sync-launch.json \
  | jq '{run_id,status,required_execution_backend,target_source_ids_count: (.target_source_ids | length), error, code, upstream_detail}'
```

Expected: a `run_id` is returned. If the backend returns `SOCIAL_ACCOUNT_COMMENTS_RUN_ALREADY_ACTIVE`, extract the active `run_id` from `upstream_detail.run_id` and treat that as launch success.

- [ ] **Step 5: Verify saved-post target count on the run/job**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
scripts/db/run_sql.sh <<'SQL'
with catalog as (
  select count(distinct shortcode)::int as saved_shortcode_count
  from social.instagram_account_catalog_posts
  where lower(source_account) = 'thetraitorsus'
    and nullif(shortcode, '') is not null
),
latest as (
  select
    r.id,
    r.status as run_status,
    j.status as job_status,
    jsonb_array_length(coalesce(j.config->'target_source_ids', '[]'::jsonb)) as target_source_ids_count,
    j.error_message
  from social.scrape_runs r
  join social.scrape_jobs j on j.run_id = r.id
  where j.platform = 'instagram'
    and coalesce(j.config->>'stage', j.metadata->>'stage', j.job_type) = 'instagram_comments_scrapling'
    and ltrim(lower(coalesce(j.config->>'account', j.metadata->>'account', '')), '@') = 'thetraitorsus'
  order by r.created_at desc
  limit 1
)
select
  latest.id::text as run_id,
  latest.run_status,
  latest.job_status,
  latest.target_source_ids_count,
  catalog.saved_shortcode_count,
  latest.error_message
from latest cross join catalog;
SQL
```

Expected: `target_source_ids_count = saved_shortcode_count`, and `run_status` is `queued`, `pending`, or `running` immediately after kickoff. A later worker failure such as Instagram auth or redirect handling is a separate runtime bug and does not invalidate launch success.

- [ ] **Step 6: Commit verification notes only if a doc was changed**

Do not create a docs-only commit for verification. If `TRR Workspace Brain/api-contract.md` was updated because the response shape changed, commit it with the code change that required it.

## Prevention

- Keep the existing app tests that prove the button sends the `all_saved_posts` body and the proxy preserves JSON.
- Keep the backend route test that proves FastAPI accepts `refresh_policy: "all_saved_posts"` and forwards uncapped defaults.
- Add the new backend repository regression so future edits cannot treat `social.instagram_posts` as the only saved-post inventory for full-account comments sync.
- During final verification, distinguish launch success from downstream worker/runtime failures. A queued run with full `target_source_ids` proves the button/backend kickoff works; later `redirect_to_homepage`, auth, proxy, or Modal failures belong to the comments worker runtime path.

## Self-Review

- Spec coverage: The plan covers frontend click, admin route, proxy, backend kickoff, saved-post coverage logic, minimal backend fix, and live `thetraitorsus` verification.
- Placeholder scan: Passed; no banned placeholder phrases remain.
- Type consistency: Test snippets use existing `social_repo`, `pytest.MonkeyPatch`, `Any`, `Sequence`, and `Mapping` symbols already imported in `test_social_season_analytics.py` and `social_season_analytics.py`.
