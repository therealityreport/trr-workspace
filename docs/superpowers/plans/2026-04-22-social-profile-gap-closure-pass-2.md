# TRR Social Profile Gap Closure Pass 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the remaining comments-page timeout and make four concurrent `instagram/thetraitorsus` full-summary renders succeed locally, using only planner-proven fixes and without changing the admin API contract.

**Architecture:** Keep the work in `TRR-Backend`. Replace the current wide comments-window plan with a narrow exact-total statement that pages comment ids first and only joins post metadata after the limit is known, add the missing functional owner-match index on `social.instagram_posts`, and raise the dedicated local social-profile read lane enough to satisfy the bounded `4`-way validation target. Do not move this surface to Edge Functions, do not introduce Redis, and do not change response shapes.

**Tech Stack:** FastAPI repository layer, psycopg2 `ThreadedConnectionPool`, Supabase Postgres, Supabase SQL migrations, `pg_stat_statements`, `pytest`, local `profiles/default.env`

---

## File Map

- Create: `TRR-Backend/supabase/migrations/20260422153000_instagram_posts_source_account_lower_id_idx.sql`
  Purpose: add the first planner-backed functional index for owner-match lookups on Instagram posts.
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
  Purpose: rewrite the comments query so exact totals stay correct while the expensive wide-row window aggregation disappears.
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
  Purpose: keep exact-total comments coverage, empty-page totals, and `post_url` fallback locked while the SQL shape changes.
- Modify: `profiles/default.env`
  Purpose: raise the local dedicated social-profile pool lane so `4` concurrent full summaries can complete during validation.
- Modify: `docs/ai/local-status/instagram-social-profile-cold-path-gap-closure-2026-04-21.md`
  Purpose: append post-fix timings, plans, and acceptance results after the pass is executed.

## Acceptance Targets

- Cold comments repository payload: under `1000 ms`
- Warm comments repository payload: under `250 ms`
- Cold full-summary repository payload: under `5000 ms`
- Warm full-summary repository payload: under `750 ms`
- `4` concurrent full summaries: all succeed with no generic unlabeled pool noise
- Admin contract unchanged:
  - comments payload still returns exact totals
  - `post_url` still comes from the existing fallback chain
  - no API shape changes
  - no Edge Functions or Redis

### Task 1: Add The Planner-Proven Owner-Match Index

**Files:**
- Create: `TRR-Backend/supabase/migrations/20260422153000_instagram_posts_source_account_lower_id_idx.sql`
- Modify: `docs/ai/local-status/instagram-social-profile-cold-path-gap-closure-2026-04-21.md`

- [ ] **Step 1: Verify the current index gap before writing the migration**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
source /Users/thomashulihan/Projects/TRR/scripts/lib/runtime-db-env.sh
trr_export_runtime_db_env_from_file /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/.env.local
PYTHONPATH=. .venv/bin/python - <<'PY'
from trr_backend.db import pg
rows = pg.fetch_all(
    """
    select indexname, indexdef
    from pg_indexes
    where schemaname = 'social'
      and tablename = 'instagram_posts'
      and indexdef ilike '%%source_account%%'
    order by indexname
    """
)
for row in rows:
    print(f"{row['indexname']} :: {row['indexdef']}")
PY
```

Expected: only the existing season/summary indexes appear; no index matches `lower(source_account), id`.

- [ ] **Step 2: Add the migration**

```sql
create index concurrently if not exists idx_social_instagram_posts_source_account_lower_id
on social.instagram_posts (lower(source_account), id);
```

- [ ] **Step 3: Apply the migration to the local validation database**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
source /Users/thomashulihan/Projects/TRR/scripts/lib/runtime-db-env.sh
trr_export_runtime_db_env_from_file /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/.env.local
supabase db push --db-url "$TRR_DB_URL" --include-all
```

Expected: the new index migration applies cleanly.

- [ ] **Step 4: Re-run the index check and append the result to the local-status note**

Expected: `idx_social_instagram_posts_source_account_lower_id` is now visible in `pg_indexes`.

- [ ] **Step 5: Commit the migration slice**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/supabase/migrations/20260422153000_instagram_posts_source_account_lower_id_idx.sql docs/ai/local-status/instagram-social-profile-cold-path-gap-closure-2026-04-21.md
git commit -m "perf: add instagram source account owner-match index"
```

### Task 2: Rewrite The Comments Query To Page Narrow Rows First

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`

- [ ] **Step 1: Add the failing regression for empty-page exact totals**

```python
def test_get_social_account_profile_comments_keeps_exact_total_when_page_rows_are_empty(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    rows = [
        {
            "id": None,
            "comment_id": None,
            "post_id": None,
            "post_source_id": None,
            "post_url": None,
            "username": None,
            "text": None,
            "likes": None,
            "is_reply": None,
            "created_at": None,
            "parent_comment_id": None,
            "total_count": 42,
        }
    ]

    monkeypatch.setattr(
        social_repo.pg,
        "fetch_all_with_cursor",
        lambda *_args, **_kwargs: rows,
    )
    monkeypatch.setattr(
        social_repo,
        "_assert_social_account_profile_exists",
        lambda *_args, **_kwargs: None,
    )
    monkeypatch.setattr(
        social_repo,
        "_call_profile_summary_loader_with_conn",
        lambda *_args, **_kwargs: True,
    )

    payload = social_repo.get_social_account_profile_comments("instagram", "thetraitorsus", page=3, page_size=25)

    assert payload["items"] == []
    assert payload["pagination"]["total"] == 42
    assert payload["pagination"]["page"] == 3
```

- [ ] **Step 2: Run the comments regression slice and verify the new test fails**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "profile_comments and empty_total"
```

Expected: `FAIL` because the current query still reads `full_count` from the windowed row shape.

- [ ] **Step 3: Replace the current wide window query with a narrow exact-total statement**

Use this SQL shape inside `get_social_account_profile_comments(...)`:

```python
rows = pg.fetch_all_with_cursor(
    cur,
    f"""
    with filtered_posts as materialized (
      select p.id
      from social.instagram_posts p
      where {owner_match_clause}
        {post_filter_sql}
    ),
    comment_total as (
      select count(*)::int as total_count
      from social.instagram_comments c
      join filtered_posts fp on fp.id = c.post_id
      where 1 = 1
        {active_filter}
    ),
    page_ids as (
      select c.id, c.post_id, c.created_at
      from social.instagram_comments c
      join filtered_posts fp on fp.id = c.post_id
      where 1 = 1
        {active_filter}
      order by c.created_at desc nulls last, c.id desc
      limit %s
      offset %s
    ),
    page_rows as (
      select
        c.id::text as id,
        c.comment_id,
        c.post_id::text as post_id,
        p.shortcode as post_source_id,
        coalesce(
          nullif(to_jsonb(p) ->> 'post_url', ''),
          nullif(to_jsonb(p) ->> 'permalink', ''),
          nullif(to_jsonb(p) ->> 'permalink_url', ''),
          nullif(to_jsonb(p) ->> 'canonical_url', ''),
          nullif(to_jsonb(p) ->> 'url', ''),
          nullif(to_jsonb(p) ->> 'link', '')
        ) as post_url,
        c.username,
        c.text,
        c.likes,
        c.is_reply,
        c.created_at,
        c.parent_comment_id::text as parent_comment_id,
        comment_total.total_count
      from page_ids ids
      join social.instagram_comments c on c.id = ids.id
      join social.instagram_posts p on p.id = ids.post_id
      cross join comment_total
    )
    select *
    from (
      select * from page_rows
      union all
      select
        null::text as id,
        null::text as comment_id,
        null::text as post_id,
        null::text as post_source_id,
        null::text as post_url,
        null::text as username,
        null::text as text,
        null::int as likes,
        null::boolean as is_reply,
        null::timestamptz as created_at,
        null::text as parent_comment_id,
        comment_total.total_count
      from comment_total
      where not exists (select 1 from page_rows)
    ) comment_rows
    order by created_at desc nulls last, id desc nulls last
    """,
    [normalized_account, *post_filter_params, safe_page_size, (safe_page - 1) * safe_page_size],
)
```

And read totals from `total_count` instead of `full_count`:

```python
total = _normalize_non_negative_int((rows[0] or {}).get("total_count")) if rows else 0
```

- [ ] **Step 4: Run the comments regression slice and the existing comments-path coverage**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "profile_comments or post_url"
```

Expected: all comments-path tests pass, including the exact-total and `post_url` fallback coverage.

- [ ] **Step 5: Capture the post-rewrite comments timing and statement shape**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
source /Users/thomashulihan/Projects/TRR/scripts/lib/runtime-db-env.sh
trr_export_runtime_db_env_from_file /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/.env.local
set -a
source /Users/thomashulihan/Projects/TRR/profiles/default.env
set +a
PYTHONPATH=. .venv/bin/python - <<'PY'
import logging
from trr_backend.repositories import social_season_analytics as repo

logging.basicConfig(level=logging.INFO)
repo._clear_social_hot_path_caches()
repo._SOCIAL_PROFILE_TOTAL_POSTS_CACHE.clear()
repo._SOCIAL_PROFILE_SNAPSHOT_CACHE.clear()
repo._relation_columns_cache.clear()
repo._column_exists_cache.clear()
repo.get_social_account_profile_comments("instagram", "thetraitorsus", page=1, page_size=25)
PY
```

Then run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
source /Users/thomashulihan/Projects/TRR/scripts/lib/runtime-db-env.sh
trr_export_runtime_db_env_from_file /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/.env.local
PYTHONPATH=. .venv/bin/python - <<'PY'
from trr_backend.db import pg
rows = pg.fetch_all(
    """
    select
      calls,
      round(total_exec_time::numeric, 1) as total_ms,
      round(mean_exec_time::numeric, 1) as mean_ms,
      left(regexp_replace(query, '\\s+', ' ', 'g'), 220) as query
    from pg_stat_statements
    where query ilike '%%social.instagram_comments%%'
    order by total_exec_time desc
    limit 5
    """
)
for row in rows:
    print(f"calls={row['calls']} total_ms={row['total_ms']} mean_ms={row['mean_ms']} query={row['query']}")
PY
```

Expected: the route-local perf log no longer shows a multi-second `comments_query` span, and the comments statement no longer dominates the snapshot at roughly the current `~8122 ms` mean.

- [ ] **Step 6: Commit the comments-query rewrite**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py TRR-Backend/tests/repositories/test_social_season_analytics.py
git commit -m "perf: narrow social profile comments query"
```

### Task 3: Raise The Local Social-Profile Pool Lane For Four-Way Validation

**Files:**
- Modify: `profiles/default.env`
- Modify: `docs/ai/local-status/instagram-social-profile-cold-path-gap-closure-2026-04-21.md`

- [ ] **Step 1: Raise the local named pool cap**

Update the local validation profile:

```dotenv
TRR_SOCIAL_PROFILE_DB_POOL_MINCONN=1
TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=4
```

- [ ] **Step 2: Re-run the four-way concurrency smoke**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
source /Users/thomashulihan/Projects/TRR/scripts/lib/runtime-db-env.sh
trr_export_runtime_db_env_from_file /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/.env.local
set -a
source /Users/thomashulihan/Projects/TRR/profiles/default.env
set +a
PYTHONPATH=. .venv/bin/python - <<'PY'
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from trr_backend.repositories import social_season_analytics as repo

repo._clear_social_hot_path_caches()
repo._SOCIAL_PROFILE_TOTAL_POSTS_CACHE.clear()
repo._SOCIAL_PROFILE_SNAPSHOT_CACHE.clear()
repo._relation_columns_cache.clear()
repo._column_exists_cache.clear()

def load_one(i):
    started = time.perf_counter()
    payload = repo.get_social_account_profile_summary("instagram", "thetraitorsus", detail="full")
    return i, (time.perf_counter() - started) * 1000.0, payload["comments_saved_summary"]["saved_comments"]

results = []
errors = []
with ThreadPoolExecutor(max_workers=4) as executor:
    futures = [executor.submit(load_one, i) for i in range(4)]
    for fut in as_completed(futures):
        try:
            results.append(fut.result())
        except Exception as exc:
            errors.append(type(exc).__name__ + ":" + str(exc))

print(f"results={sorted(results)}")
print(f"errors={errors}")
PY
```

Expected: four successes, zero `PoolError`, and any pool logging remains labeled `profile-summary:instagram:thetraitorsus`.

- [ ] **Step 3: Commit the local validation profile change**

```bash
cd /Users/thomashulihan/Projects/TRR
git add profiles/default.env docs/ai/local-status/instagram-social-profile-cold-path-gap-closure-2026-04-21.md
git commit -m "chore: raise local social profile validation pool cap"
```

### Task 4: Re-Run The Acceptance Benchmark And Close The Loop

**Files:**
- Modify: `docs/ai/local-status/instagram-social-profile-cold-path-gap-closure-2026-04-21.md`

- [ ] **Step 1: Re-run the cold/warm repository benchmark**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
source /Users/thomashulihan/Projects/TRR/scripts/lib/runtime-db-env.sh
trr_export_runtime_db_env_from_file /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/.env.local
set -a
source /Users/thomashulihan/Projects/TRR/profiles/default.env
set +a
PYTHONPATH=. .venv/bin/python - <<'PY'
import time
from trr_backend.repositories import social_season_analytics as repo

repo._clear_social_hot_path_caches()
repo._SOCIAL_PROFILE_TOTAL_POSTS_CACHE.clear()
repo._SOCIAL_PROFILE_SNAPSHOT_CACHE.clear()
repo._relation_columns_cache.clear()
repo._column_exists_cache.clear()

def timed(label, fn):
    started = time.perf_counter()
    payload = fn()
    elapsed_ms = (time.perf_counter() - started) * 1000.0
    print(f"{label}_ms={elapsed_ms:.1f}")
    return payload

timed("comments_cold", lambda: repo.get_social_account_profile_comments("instagram", "thetraitorsus", page=1, page_size=25))
timed("summary_cold", lambda: repo.get_social_account_profile_summary("instagram", "thetraitorsus", detail="full"))
timed("comments_warm", lambda: repo.get_social_account_profile_comments("instagram", "thetraitorsus", page=1, page_size=25))
timed("summary_warm", lambda: repo.get_social_account_profile_summary("instagram", "thetraitorsus", detail="full"))
PY
```

Expected:
- `comments_cold < 1000`
- `comments_warm < 250`
- `summary_cold < 5000`
- `summary_warm < 750`

- [ ] **Step 2: Re-run the perf-debug breakdown**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
source /Users/thomashulihan/Projects/TRR/scripts/lib/runtime-db-env.sh
trr_export_runtime_db_env_from_file /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/.env.local
set -a
source /Users/thomashulihan/Projects/TRR/profiles/default.env
set +a
export TRR_SOCIAL_PROFILE_PERF_DEBUG=1
PYTHONPATH=. .venv/bin/python - <<'PY'
import logging
from trr_backend.repositories import social_season_analytics as repo

logging.basicConfig(level=logging.INFO)
repo._clear_social_hot_path_caches()
repo._SOCIAL_PROFILE_TOTAL_POSTS_CACHE.clear()
repo._SOCIAL_PROFILE_SNAPSHOT_CACHE.clear()
repo._relation_columns_cache.clear()
repo._column_exists_cache.clear()
repo.get_social_account_profile_comments("instagram", "thetraitorsus", page=1, page_size=25)
repo.get_social_account_profile_summary("instagram", "thetraitorsus", detail="full")
PY
```

Expected: comments breakdown no longer dominated by a multi-second `comments_query`, and summary remains labeled with stable loader timings.

- [ ] **Step 3: Update the local-status note with post-fix timings and final acceptance status**

Append:
- final cold/warm timings
- updated planner summary
- four-way concurrency result
- explicit PASS / FAIL lines for every acceptance target

- [ ] **Step 4: Run the targeted backend validation suite**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "profile_comments or post_url or get_social_account_profile_summary"
.venv/bin/python -m pytest -q tests/db/test_pg_pool.py -k "social_profile_pool or db_read_connection"
```

Expected: all targeted tests pass.

- [ ] **Step 5: Commit the validation closeout**

```bash
cd /Users/thomashulihan/Projects/TRR
git add docs/ai/local-status/instagram-social-profile-cold-path-gap-closure-2026-04-21.md
git commit -m "docs: capture social profile gap closure validation"
```
