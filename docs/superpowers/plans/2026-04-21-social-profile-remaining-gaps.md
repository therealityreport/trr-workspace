# TRR Social Profile Remaining Gaps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the cold `instagram/thetraitorsus` summary and comments repository paths into the target latency band without changing the admin API contract, while removing the remaining unlabeled social-profile pool contention on ordinary admin reloads.

**Architecture:** Keep this surface in `TRR-Backend`, profile the repository functions directly, and close the remaining gap in three layers: route-local timing attribution, fewer SQL scans / fewer decoded rows, and a dedicated read pool lane for the social profile surface. Keep exact comments pagination totals, keep the existing in-process summary/comment caches, and leave Edge Functions, Redis, and frontend contract changes out of scope.

**Tech Stack:** FastAPI repository layer, psycopg2 `ThreadedConnectionPool`, Supabase Postgres, `pg_stat_statements`, `pytest`, local `profiles/default.env`

---

## File Map

- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
  Purpose: add route-local timing spans, collapse the comments count/page work into one exact query, introduce a shared Instagram detail rollup, and route the summary/comments surface through a dedicated read pool lane.
- Modify: `TRR-Backend/trr_backend/db/pg.py`
  Purpose: support named read pools so social profile reads can use a small dedicated pool instead of fighting background control-plane traffic on the default pool.
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
  Purpose: lock in exact-total comments pagination, shared-rollup reuse, perf logging toggles, and route-level connection-lane reuse.
- Modify: `TRR-Backend/tests/db/test_pg_pool.py`
  Purpose: verify the named social-profile read pool is created with the expected sizing and that `db_read_connection(label="social-profile-summary", pool_name="social_profile")` uses that lane.
- Modify: `profiles/default.env`
  Purpose: define local-only defaults for the social-profile read pool and the temporary perf-debug flag.
- Create: `docs/ai/local-status/instagram-social-profile-cold-path-gap-closure-2026-04-21.md`
  Purpose: store the reproducible benchmark commands, `pg_stat_statements` queries, before/after timings, and acceptance thresholds for this exact page.

## Acceptance Targets

- Cold comments repository payload: under `1000 ms`
- Warm comments repository payload: under `250 ms`
- Cold full-summary repository payload: under `5000 ms`
- Warm full-summary repository payload: under `750 ms`
- `4` concurrent full summaries: no generic `[db-pool] acquire_failed label=fetch_one` or equivalent unlabeled summary-path noise
- Admin UI contract remains unchanged:
  - comments page still returns exact totals
  - `post_url` still uses the existing fallback chain instead of a physical `p.url` dependency
  - no Edge Functions, Redis, or API response-shape changes

### Task 1: Add Route-Local Timing Attribution For The Real Backend Path

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Modify: `profiles/default.env`

- [ ] **Step 1: Write the failing repository tests for opt-in perf logging**

```python
def test_social_profile_perf_span_records_elapsed_time(monkeypatch: pytest.MonkeyPatch) -> None:
    perf_values = iter([100.0, 100.35])
    monkeypatch.setattr(social_repo.time, "perf_counter", lambda: next(perf_values))
    breakdown: dict[str, float] = {}

    with social_repo._social_profile_perf_span(breakdown, "comments_page_sql"):
        pass

    assert breakdown["comments_page_sql"] == pytest.approx(350.0, abs=0.1)


def test_log_social_profile_perf_is_noop_when_disabled(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("TRR_SOCIAL_PROFILE_PERF_DEBUG", raising=False)
    logged: list[str] = []
    monkeypatch.setattr(social_repo.logger, "info", lambda message, *args: logged.append(message % args))

    social_repo._log_social_profile_perf(
        route="summary",
        platform="instagram",
        handle="thetraitorsus",
        breakdown={"base": 12.5, "comments_saved_summary": 410.0},
    )

    assert logged == []


def test_log_social_profile_perf_logs_breakdown_when_enabled(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("TRR_SOCIAL_PROFILE_PERF_DEBUG", "1")
    logged: list[str] = []
    monkeypatch.setattr(social_repo.logger, "info", lambda message, *args: logged.append(message % args))

    social_repo._log_social_profile_perf(
        route="comments",
        platform="instagram",
        handle="thetraitorsus",
        breakdown={"account_exists": 10.0, "comments_page_sql": 825.2},
    )

    assert any("[social-profile-perf] route=comments" in entry for entry in logged)
    assert any("comments_page_sql" in entry for entry in logged)
```

- [ ] **Step 2: Run the new tests and verify they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "social_profile_perf_span or log_social_profile_perf"
```

Expected: `FAIL` because `_social_profile_perf_span` and `_log_social_profile_perf` do not exist yet.

- [ ] **Step 3: Add the perf helpers and wire them into the summary/comments hot path**

```python
def _social_profile_perf_enabled() -> bool:
    return os.getenv("TRR_SOCIAL_PROFILE_PERF_DEBUG", "0").strip().lower() in {"1", "true", "yes", "on"}


@contextmanager
def _social_profile_perf_span(
    breakdown: dict[str, float],
    key: str,
) -> Iterator[None]:
    started_at = time.perf_counter()
    try:
        yield
    finally:
        breakdown[key] = breakdown.get(key, 0.0) + ((time.perf_counter() - started_at) * 1000.0)


def _log_social_profile_perf(
    *,
    route: str,
    platform: str,
    handle: str,
    breakdown: Mapping[str, float],
) -> None:
    if not _social_profile_perf_enabled():
        return
    rounded = {key: round(value, 1) for key, value in breakdown.items()}
    logger.info(
        "[social-profile-perf] route=%s platform=%s handle=%s total_ms=%.1f timings_ms=%s",
        route,
        platform,
        handle,
        round(sum(rounded.values()), 1),
        rounded,
    )
```

Use those helpers inside both repository entrypoints:

```python
perf_breakdown: dict[str, float] = {}

with _social_profile_perf_span(perf_breakdown, "account_exists"):
    _assert_social_account_profile_exists(platform, normalized_account, conn=read_conn)

with _social_profile_perf_span(perf_breakdown, "comments_page_sql"):
    rows = pg.fetch_all_with_cursor(cur, comments_sql, params)

_log_social_profile_perf(
    route="comments",
    platform=platform,
    handle=normalized_account,
    breakdown=perf_breakdown,
)
```

Add the local-only env toggle:

```dotenv
TRR_SOCIAL_PROFILE_PERF_DEBUG=0
```

- [ ] **Step 4: Run the targeted repository tests and make sure they pass**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "social_profile_perf_span or log_social_profile_perf"
```

Expected: `3 passed`

- [ ] **Step 5: Commit the instrumentation slice**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py TRR-Backend/tests/repositories/test_social_season_analytics.py profiles/default.env
git commit -m "feat: add social profile perf timing breakdowns"
```

### Task 2: Collapse Comments Total And Page Into One Exact Query

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`

- [ ] **Step 1: Write the failing regression tests for single-query exact totals**

```python
def test_get_social_account_profile_comments_reads_total_from_window_count(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    fetch_one_calls = 0

    def _unexpected_fetch_one(*_args, **_kwargs):  # noqa: ANN001
        nonlocal fetch_one_calls
        fetch_one_calls += 1
        raise AssertionError("separate count query should not run")

    rows = [
        {
            "id": "comment-1",
            "comment_id": "c1",
            "text": "first",
            "username": "traitorsfan",
            "created_at": "2026-04-21T12:00:00+00:00",
            "post_id": "post-1",
            "post_shortcode": "abc123",
            "post_url": None,
            "likes_count": 7,
            "full_count": 42,
        }
    ]

    monkeypatch.setattr(social_repo.pg, "fetch_one_with_cursor", _unexpected_fetch_one)
    monkeypatch.setattr(social_repo.pg, "fetch_all_with_cursor", lambda *_args, **_kwargs: rows)
    monkeypatch.setattr(social_repo, "_assert_social_account_profile_exists", lambda *_args, **_kwargs: None)
    monkeypatch.setattr(social_repo, "_comment_lifecycle_supported", lambda *_args, **_kwargs: False)

    payload = social_repo.get_social_account_profile_comments("instagram", "thetraitorsus", page=1, page_size=25)

    assert payload["total"] == 42
    assert fetch_one_calls == 0


def test_get_social_account_profile_comments_keeps_post_url_fallback_with_window_count(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    rows = [
        {
            "id": "comment-1",
            "comment_id": "c1",
            "text": "first",
            "username": "traitorsfan",
            "created_at": "2026-04-21T12:00:00+00:00",
            "post_id": "post-1",
            "post_shortcode": "abc123",
            "post_url": None,
            "likes_count": 7,
            "full_count": 1,
        }
    ]

    monkeypatch.setattr(social_repo.pg, "fetch_all_with_cursor", lambda *_args, **_kwargs: rows)
    monkeypatch.setattr(social_repo, "_assert_social_account_profile_exists", lambda *_args, **_kwargs: None)
    monkeypatch.setattr(social_repo, "_comment_lifecycle_supported", lambda *_args, **_kwargs: False)

    payload = social_repo.get_social_account_profile_comments("instagram", "thetraitorsus", page=1, page_size=25)

    assert payload["items"][0]["post_url"].endswith("/p/abc123/")
```

- [ ] **Step 2: Run the targeted comments tests and verify they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "window_count and profile_comments"
```

Expected: `FAIL` because the comments route still performs a separate count read and does not read `total` from the page rows.

- [ ] **Step 3: Replace the separate count/page queries with one exact window-count query**

```python
comments_sql = f"""
with filtered_posts as (
    select
        p.id,
        p.code as post_shortcode,
        coalesce(
            {post_url_sql}
        ) as post_url
    from social.instagram_posts p
    where lower(p.source_account) = %s
),
filtered_comments as (
    select
        c.id,
        c.comment_id,
        c.text,
        c.username,
        c.created_at,
        c.likes_count,
        c.post_id,
        fp.post_shortcode,
        fp.post_url,
        count(*) over()::int as full_count
    from social.instagram_comments c
    join filtered_posts fp on fp.id = c.post_id
)
select *
from filtered_comments
order by created_at desc nulls last, id desc
limit %s offset %s
"""

with pg.db_cursor(conn=read_conn) as cur:
    rows = pg.fetch_all_with_cursor(
        cur,
        comments_sql,
        [normalized_account, page_size, offset],
    )

total = int(rows[0]["full_count"]) if rows else 0
```

Keep the existing serializer fallback:

```python
if not post_url and post_shortcode:
    post_url = f"https://www.instagram.com/p/{post_shortcode}/"
```

- [ ] **Step 4: Run the comments regression slice and the existing comments-path tests**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "profile_comments or post_url"
```

Expected: all comments-path tests pass, including the `post_url` regression coverage.

- [ ] **Step 5: Commit the comments-path consolidation**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py TRR-Backend/tests/repositories/test_social_season_analytics.py
git commit -m "perf: collapse social profile comments count and page query"
```

### Task 3: Replace Separate Instagram Summary Rollups With One Shared Detail Aggregate

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`

- [ ] **Step 1: Write the failing tests that prove the full-summary path reuses one shared rollup**

```python
def test_get_social_account_profile_summary_uses_shared_instagram_detail_rollup(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    rollup_calls: list[object] = []

    def _fake_rollup(account: str, *, conn=None):  # noqa: ANN001
        rollup_calls.append(conn)
        return {
            "comment_target_posts": 431,
            "posts_with_saved_comments": 63,
            "saved_comments": 9912,
            "saved_comment_media_files": 184,
            "total_post_media_files": 742,
            "saved_post_media_files": 742,
            "hosted_author_profile_pic_urls": ["https://cdn.example.com/avatar-a.jpg"],
        }

    monkeypatch.setattr(social_repo, "_instagram_social_account_detail_rollup", _fake_rollup)
    monkeypatch.setattr(social_repo, "_assert_social_account_profile_exists", lambda *_args, **_kwargs: None)

    payload = social_repo.get_social_account_profile_summary("instagram", "thetraitorsus", detail="full")

    assert payload["comments_saved_summary"]["saved_comments"] == 9912
    assert payload["media_coverage"]["saved_comment_media_files"] == 184
    assert len(rollup_calls) == 1
    assert rollup_calls[0] is not None


def test_instagram_social_account_detail_rollup_shapes_saved_and_target_counts(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        social_repo.pg,
        "fetch_one",
        lambda *_args, **_kwargs: {
            "comment_target_posts": 431,
            "posts_with_saved_comments": 63,
            "saved_comments": 9912,
            "saved_comment_media_files": 184,
            "total_post_media_files": 742,
            "saved_post_media_files": 742,
            "hosted_author_profile_pic_urls": ["https://cdn.example.com/avatar-a.jpg"],
        },
    )

    rollup = social_repo._instagram_social_account_detail_rollup("thetraitorsus")

    assert rollup["comment_target_posts"] == 431
    assert rollup["posts_with_saved_comments"] == 63
    assert rollup["saved_comments"] == 9912
```

- [ ] **Step 2: Run the shared-rollup tests and verify they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "shared_instagram_detail_rollup or detail_rollup_shapes"
```

Expected: `FAIL` because `_instagram_social_account_detail_rollup` does not exist and the summary path still fans out across separate helper queries.

- [ ] **Step 3: Introduce a single shared rollup query and make the summary helpers derive from it**

```python
def _instagram_social_account_detail_rollup(
    normalized_account: str,
    *,
    conn: Any | None = None,
) -> dict[str, Any]:
    sql = """
    with filtered_posts as (
        select
            p.id,
            coalesce(p.media_count, 1)::int as media_count,
            coalesce(p.has_comments_disabled, false) as has_comments_disabled
        from social.instagram_posts p
        where lower(p.source_account) = %s
    ),
    post_totals as (
        select
            count(*)::int as total_posts,
            count(*) filter (where has_comments_disabled is false)::int as comment_target_posts,
            coalesce(sum(media_count), 0)::int as total_post_media_files
        from filtered_posts
    ),
    comment_rollup as (
        select
            count(*)::int as saved_comments,
            count(distinct c.post_id)::int as posts_with_saved_comments,
            (
                count(c.hosted_media_asset_id)
                + count(c.hosted_thumbnail_media_asset_id)
            )::int as saved_comment_media_files,
            array_remove(
                array_agg(distinct nullif(c.hosted_author_profile_pic_url, '')),
                null
            ) as hosted_author_profile_pic_urls
        from social.instagram_comments c
        join filtered_posts fp on fp.id = c.post_id
    )
    select
        post_totals.comment_target_posts,
        comment_rollup.posts_with_saved_comments,
        comment_rollup.saved_comments,
        post_totals.total_post_media_files,
        post_totals.total_post_media_files as saved_post_media_files,
        comment_rollup.saved_comment_media_files,
        coalesce(comment_rollup.hosted_author_profile_pic_urls, array[]::text[]) as hosted_author_profile_pic_urls
    from post_totals
    cross join comment_rollup
    """
    return pg.fetch_one(sql, [normalized_account], conn=conn, label="instagram_detail_rollup") or {}
```

Refactor the existing helpers to derive from the shared row instead of issuing fresh scans:

```python
rollup = _instagram_social_account_detail_rollup(normalized_account, conn=conn)

comments_saved_summary = {
    "saved_comments": int(rollup.get("saved_comments") or 0),
    "posts_with_saved_comments": int(rollup.get("posts_with_saved_comments") or 0),
    "posts_without_saved_comments": max(
        int(rollup.get("comment_target_posts") or 0) - int(rollup.get("posts_with_saved_comments") or 0),
        0,
    ),
}

media_coverage = {
    "total_post_media_files": int(rollup.get("total_post_media_files") or 0),
    "saved_post_media_files": int(rollup.get("saved_post_media_files") or 0),
    "saved_comment_media_files": int(rollup.get("saved_comment_media_files") or 0),
}
```

Keep any detail rows that the UI already needs, but stop re-querying equivalent totals once the shared rollup row is already loaded.

- [ ] **Step 4: Run the full Instagram summary repository slice**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "get_social_account_profile_summary and instagram"
```

Expected: the Instagram summary regressions pass, including the newer comments/media truth tests.

- [ ] **Step 5: Commit the shared-rollup refactor**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py TRR-Backend/tests/repositories/test_social_season_analytics.py
git commit -m "perf: share instagram detail rollup across summary helpers"
```

### Task 4: Add A Dedicated Social-Profile Read Pool Lane

**Files:**
- Modify: `TRR-Backend/trr_backend/db/pg.py`
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/tests/db/test_pg_pool.py`
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Modify: `profiles/default.env`

- [ ] **Step 1: Write the failing pool tests**

```python
def test_db_read_connection_uses_social_profile_pool_sizing(monkeypatch: pytest.MonkeyPatch) -> None:
    created: list[tuple[int, int]] = []

    def _fake_threaded_pool(minconn: int, maxconn: int, **_kwargs):  # noqa: ANN001
        created.append((minconn, maxconn))
        return _FakePool()

    monkeypatch.setenv("TRR_SOCIAL_PROFILE_DB_POOL_MINCONN", "1")
    monkeypatch.setenv("TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN", "2")
    monkeypatch.setattr(pg, "ThreadedConnectionPool", _fake_threaded_pool)
    monkeypatch.setattr(
        pg,
        "resolve_database_url_candidate_details",
        lambda: (_detail("postgresql://db.example.com/postgres"),),
    )

    with pg.db_read_connection(label="social-profile-summary", pool_name="social_profile"):
        pass

    assert created == [(1, 2)]


def test_social_account_profile_summary_connection_uses_social_profile_pool(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[tuple[str, str]] = []

    @contextmanager
    def _fake_db_read_connection(*, label: str, pool_name: str = "default"):
        calls.append((label, pool_name))
        yield object()

    monkeypatch.setattr(social_repo.pg, "db_read_connection", _fake_db_read_connection)

    with social_repo._social_account_profile_summary_connection("social-profile-summary"):
        pass

    assert calls == [("social-profile-summary", "social_profile")]
```

- [ ] **Step 2: Run the pool tests and verify they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db/test_pg_pool.py -k "social_profile_pool"
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "social_profile_pool"
```

Expected: `FAIL` because `db_read_connection` does not accept `pool_name` yet and the social profile connection wrapper still uses the default pool.

- [ ] **Step 3: Add named-pool support in `pg.py` and route the social profile surface through it**

```python
@dataclass(frozen=True)
class _PoolConfig:
    pool_name: str
    minconn_env: str
    maxconn_env: str


_POOL_CONFIGS = {
    "default": _PoolConfig("default", "TRR_DB_POOL_MINCONN", "TRR_DB_POOL_MAXCONN"),
    "social_profile": _PoolConfig(
        "social_profile",
        "TRR_SOCIAL_PROFILE_DB_POOL_MINCONN",
        "TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN",
    ),
}

_pools: dict[str, ThreadedConnectionPool] = {}


def _build_pool(pool_name: str, url: str) -> ThreadedConnectionPool:
    config = _POOL_CONFIGS[pool_name]
    minconn = _env_int(config.minconn_env, 1, minimum=1)
    maxconn = _env_int(config.maxconn_env, 2, minimum=minconn)
    return ThreadedConnectionPool(minconn=minconn, maxconn=maxconn, **connect_kwargs)


def db_read_connection(*, label: str = "read", pool_name: str = "default"):
    pool, conn, checkout_id = _get_connection_with_retry(label=label, pool_name=pool_name)
    previous_autocommit = getattr(conn, "autocommit", False)
    try:
        if not previous_autocommit:
            conn.autocommit = True
        yield conn
    finally:
        if not previous_autocommit and not _is_connection_closed(conn):
            conn.autocommit = False
        _log_return(pool=pool, conn=conn, checkout_id=checkout_id, label=label)
        pool.putconn(conn)
```

Route the summary/comments scope to that named lane:

```python
@contextmanager
def _social_account_profile_summary_connection(label: str):
    with pg.db_read_connection(label=label, pool_name="social_profile") as conn:
        yield conn
```

Add the local defaults:

```dotenv
TRR_SOCIAL_PROFILE_DB_POOL_MINCONN=1
TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=2
```

- [ ] **Step 4: Run the pool and repository regression slices**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db/test_pg_pool.py
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "reuses_read_connection or social_profile_pool or get_social_account_profile_summary"
```

Expected: pool tests pass and the summary/comments connection-reuse tests still pass with the named lane.

- [ ] **Step 5: Commit the pool-isolation slice**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/trr_backend/db/pg.py TRR-Backend/trr_backend/repositories/social_season_analytics.py TRR-Backend/tests/db/test_pg_pool.py TRR-Backend/tests/repositories/test_social_season_analytics.py profiles/default.env
git commit -m "perf: isolate social profile reads in dedicated pool"
```

### Task 5: Validate Cold/Warm Performance And Write The Runbook

**Files:**
- Create: `docs/ai/local-status/instagram-social-profile-cold-path-gap-closure-2026-04-21.md`

- [ ] **Step 1: Write the runbook markdown with the exact benchmark and planner commands**

````markdown
# Instagram Social Profile Cold-Path Gap Closure

## Direct repository benchmarks

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
set -a
source /Users/thomashulihan/Projects/TRR/profiles/default.env
set +a
PYTHONPATH=. .venv/bin/python - <<'PY'
import time
from trr_backend.repositories import social_season_analytics as repo

def timed(label, fn):
    started = time.perf_counter()
    payload = fn()
    elapsed_ms = (time.perf_counter() - started) * 1000.0
    print(label, round(elapsed_ms, 1))
    return payload

timed("comments_cold", lambda: repo.get_social_account_profile_comments("instagram", "thetraitorsus", page=1, page_size=25))
timed("summary_cold", lambda: repo.get_social_account_profile_summary("instagram", "thetraitorsus", detail="full"))
timed("comments_warm", lambda: repo.get_social_account_profile_comments("instagram", "thetraitorsus", page=1, page_size=25))
timed("summary_warm", lambda: repo.get_social_account_profile_summary("instagram", "thetraitorsus", detail="full"))
PY
```

Expected thresholds:
- `comments_cold < 1000`
- `summary_cold < 5000`
- `comments_warm < 250`
- `summary_warm < 750`

## pg_stat_statements snapshot

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
set -a
source /Users/thomashulihan/Projects/TRR/profiles/default.env
set +a
PYTHONPATH=. .venv/bin/python - <<'PY'
from trr_backend.db import pg

rows = pg.fetch_all(
    """
    select
        calls,
        round(total_exec_time::numeric, 1) as total_ms,
        round(mean_exec_time::numeric, 1) as mean_ms,
        regexp_replace(query, '\\s+', ' ', 'g') as query
    from pg_stat_statements
    where query ilike '%filtered_posts%'
       or query ilike '%count(*) over()%'
       or query ilike '%instagram_detail_rollup%'
    order by total_exec_time desc
    limit 10
    """
)
for row in rows:
    print(row["calls"], row["total_ms"], row["mean_ms"], row["query"][:220])
PY
```

## Concurrency smoke

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
set -a
source /Users/thomashulihan/Projects/TRR/profiles/default.env
set +a
PYTHONPATH=. .venv/bin/python - <<'PY'
from concurrent.futures import ThreadPoolExecutor
from trr_backend.repositories import social_season_analytics as repo

def run_once() -> int:
    payload = repo.get_social_account_profile_summary("instagram", "thetraitorsus", detail="full")
    return int(payload["comments_saved_summary"]["saved_comments"])

with ThreadPoolExecutor(max_workers=4) as executor:
    print(list(executor.map(lambda _index: run_once(), range(4))))
PY
```

Expected:
- all four calls succeed
- no generic `[db-pool] acquire_failed label=fetch_one` entries in the backend log
````

- [ ] **Step 2: Verify the runbook file exists after saving the markdown from Step 1**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
test -f docs/ai/local-status/instagram-social-profile-cold-path-gap-closure-2026-04-21.md && echo "runbook exists"
```

Expected: no output before the file is created.

- [ ] **Step 3: Execute the benchmark and planner commands after Tasks 1-4 land**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
set -a
source /Users/thomashulihan/Projects/TRR/profiles/default.env
set +a
PYTHONPATH=. .venv/bin/python - <<'PY'
import time
from trr_backend.repositories import social_season_analytics as repo

for label, fn in (
    ("comments_cold", lambda: repo.get_social_account_profile_comments("instagram", "thetraitorsus", page=1, page_size=25)),
    ("summary_cold", lambda: repo.get_social_account_profile_summary("instagram", "thetraitorsus", detail="full")),
    ("comments_warm", lambda: repo.get_social_account_profile_comments("instagram", "thetraitorsus", page=1, page_size=25)),
    ("summary_warm", lambda: repo.get_social_account_profile_summary("instagram", "thetraitorsus", detail="full")),
):
    started = time.perf_counter()
    fn()
    print(label, round((time.perf_counter() - started) * 1000.0, 1))
PY
```

Expected: the four printed timings meet the target thresholds above.

- [ ] **Step 4: Run the backend validation suite**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
ruff check .
ruff format --check .
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py
.venv/bin/python -m pytest -q tests/db/test_pg_pool.py
.venv/bin/python -m pytest -q tests/api/routers/test_socials_season_analytics.py -k "comments or summary"
```

Expected:
- `ruff` exits `0`
- repository tests pass
- pool tests pass
- targeted router tests pass

- [ ] **Step 5: Commit the validation runbook and evidence**

```bash
cd /Users/thomashulihan/Projects/TRR
git add docs/ai/local-status/instagram-social-profile-cold-path-gap-closure-2026-04-21.md
git commit -m "docs: add social profile cold-path performance runbook"
```

## Self-Review

- Spec coverage check:
  - Direct backend profiling: covered by Task 1 and Task 5
  - Exact comments totals with faster comments page: covered by Task 2
  - Fewer repeated summary scans and fewer decoded rows: covered by Task 3
  - Remaining pool noise / read-lane isolation: covered by Task 4
  - Before/after evidence and acceptance thresholds: covered by Task 5
- Placeholder scan:
  - No `TODO`, `TBD`, or "implement later" placeholders remain
  - Every code-changing task includes concrete file paths, code, commands, and commit steps
- Type consistency:
  - The plan uses the same helper names across tasks:
    - `_social_profile_perf_span`
    - `_log_social_profile_perf`
    - `_instagram_social_account_detail_rollup`
    - `db_read_connection(label="social-profile-summary", pool_name="social_profile")`
