# Twitter Hashtag & Mention Scrape — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the existing Twitter scraper so operators can reliably scrape all tweets matching a specific hashtag **or** a specific @mention within a given date window, and optionally persist the results to the database without requiring a season context.

**Architecture:** Fix a silent bug in `build_search_query()` that produces nonsensical queries for `@mention` terms; add a `scrape_query` label column to `social.twitter_tweets` so standalone (non-season) scrapes are discoverable; implement a thin `upsert_standalone_tweets()` repository function that reuses the existing `_pg_upsert_many()` primitive; wire `--persist` into the CLI and an optional `persist` flag into the existing API endpoint. No new endpoints, no new tables, no new auth paths.

**Tech Stack:** Python 3.11, psycopg2, FastAPI/Pydantic, Supabase Postgres, pytest, FastAPI TestClient + JWT

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `TRR-Backend/trr_backend/socials/twitter/scraper.py` | **Modify** | Fix `@mention` query normalization in `build_search_query()` |
| `TRR-Backend/supabase/migrations/20260322120000_twitter_scrape_query_column.sql` | **Create** | Add `scrape_query text` column + index to `social.twitter_tweets` |
| `TRR-Backend/trr_backend/repositories/twitter_standalone.py` | **Create** | `upsert_standalone_tweets(tweets, scrape_query)` function |
| `TRR-Backend/scripts/socials/twitter/scrape.py` | **Modify** | Add `--persist` and `--scrape-query` CLI flags; top-level import of `upsert_standalone_tweets` |
| `TRR-Backend/api/routers/socials.py` | **Modify** | Add `persist: bool` and `scrape_query: str \| None` to `TwitterSearchRequest`; top-level import; call upsert in handler |
| `TRR-Backend/tests/socials/test_twitter_query_building.py` | **Create** | Tests for `@mention`, `#hashtag`, and advanced query normalization |
| `TRR-Backend/tests/repositories/test_twitter_standalone_upsert.py` | **Create** | Tests for `upsert_standalone_tweets()` |
| `TRR-Backend/tests/scripts/test_twitter_scrape_persist.py` | **Create** | Tests for CLI `--persist` flag behaviour |
| `TRR-Backend/tests/api/routers/test_twitter_persist_endpoint.py` | **Create** | Tests for API `persist=True` path |

---

## Background: What Already Works

The existing CLI and API already handle hashtag + date-range scraping:
```bash
# These work today — no changes needed:
python -m scripts.socials.twitter.scrape --query "#RHOSLC" --start 2026-01-01 --end 2026-01-11
python -m scripts.socials.twitter.scrape --query RHOSLC   --start 2026-01-01 --end 2026-01-11
# POST /api/v1/admin/socials/twitter/search with {"query":"#RHOSLC","date_start":"...","date_end":"..."}
```

**What does NOT work today:**
- `@mention` queries are silently mangled (see Task 1)
- No way to persist results to the database from the CLI or API search endpoint

**`_pg_upsert_many` table name convention:** The function internally prepends `social.` — existing call sites pass the bare table name (e.g. `_pg_upsert_many("twitter_tweets", ..., conflict_col="tweet_id")`). Always pass `"twitter_tweets"`, not `"social.twitter_tweets"`.

---

## Task 1: Fix `@mention` Query Normalization

**Files:**
- Modify: `TRR-Backend/trr_backend/socials/twitter/scraper.py`
- Create: `TRR-Backend/tests/socials/test_twitter_query_building.py`

**Root cause:** `build_search_query()` has two explicit cases (`#hashtag` → pass-through, advanced query → pass-through) and an `else` branch that wraps everything else as `"term" OR #term`. When the term is `@BravoTV`, the result is `"@BravoTV" OR #@BravoTV since:... until:...`. The `#@BravoTV` fragment is meaningless on Twitter and can cause unexpected results.

The fix: add a third explicit case — if the query starts with `@`, pass it through as-is (same treatment as `#hashtag`).

- [ ] **Step 1: Create the test file and write failing tests**

```python
# tests/socials/test_twitter_query_building.py
from datetime import datetime

from trr_backend.socials.twitter.scraper import TwitterScrapeConfig

DATE_START = datetime(2026, 1, 1)
DATE_END   = datetime(2026, 1, 11)


def _config(query: str) -> TwitterScrapeConfig:
    return TwitterScrapeConfig(query=query, date_start=DATE_START, date_end=DATE_END)


def test_hashtag_passthrough():
    # #RHOSLC should appear exactly once, not as "#RHOSLC OR ##RHOSLC"
    q = _config("#RHOSLC").build_search_query()
    assert q.startswith("#RHOSLC ")  # space confirms the date filter follows directly
    assert "OR ##RHOSLC" not in q


def test_mention_passthrough():
    q = _config("@BravoTV").build_search_query()
    # Should be "@BravoTV since:... until:..." — no quoting, no #@BravoTV
    assert q.startswith("@BravoTV ")
    assert "#@BravoTV" not in q
    assert '"@BravoTV"' not in q


def test_plain_text_wrapped():
    q = _config("RHOSLC").build_search_query()
    assert '"RHOSLC" OR #RHOSLC' in q


def test_advanced_passthrough():
    raw = 'from:BravoTV OR from:Andy'
    q = _config(raw).build_search_query()
    assert q.startswith(raw)


def test_date_filters_always_appended():
    for term in ("#RHOSLC", "@BravoTV", "RHOSLC"):
        q = _config(term).build_search_query()
        assert "since:2026-01-01" in q
        assert "until:2026-01-11" in q
```

- [ ] **Step 2: Run — verify `test_mention_passthrough` fails**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python -m pytest tests/socials/test_twitter_query_building.py -v
```
Expected: `test_mention_passthrough` FAIL, others PASS.

- [ ] **Step 3: Apply the one-line fix in `scraper.py`**

Find `build_search_query` (around line 69) and change the condition:

```python
# BEFORE:
        elif normalized_query.startswith("#"):
            parts.append(normalized_query)
```
```python
# AFTER:
        elif normalized_query.startswith("#") or normalized_query.startswith("@"):
            parts.append(normalized_query)
```

- [ ] **Step 4: Run tests — all 5 must pass**

```bash
python -m pytest tests/socials/test_twitter_query_building.py -v
```
Expected: 5/5 PASS.

- [ ] **Step 5: Check no regressions in the existing socials test suite**

```bash
python -m pytest tests/socials/ -q --tb=short
```
Expected: green.

- [ ] **Step 6: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add trr_backend/socials/twitter/scraper.py tests/socials/test_twitter_query_building.py
git commit -m "fix: pass @mention queries through without mangling in build_search_query"
```

---

## Task 2: Add `scrape_query` Column (Migration)

**Files:**
- Create: `TRR-Backend/supabase/migrations/20260322120000_twitter_scrape_query_column.sql`

`scrape_query` records the search term (e.g., `#RHOSLC`, `@BravoTV`) that produced each tweet row in a standalone scrape. It is separate from `source_account` (which tracks the profile being scraped in the existing season pipeline). Nullable so all existing rows are unaffected and no backfill is needed.

- [ ] **Step 1: Create the migration file**

```sql
-- 20260322120000_twitter_scrape_query_column.sql
-- Add scrape_query to twitter_tweets for standalone hashtag/mention scrapes.
-- Nullable: existing season-pipeline rows do not need it.

begin;

alter table social.twitter_tweets
  add column if not exists scrape_query text;

comment on column social.twitter_tweets.scrape_query is
  'Search term that produced this row in a standalone (non-season) scrape, e.g. "#RHOSLC" or "@BravoTV". NULL for season-pipeline rows.';

create index if not exists twitter_tweets_scrape_query_idx
  on social.twitter_tweets (scrape_query)
  where scrape_query is not null;

commit;
```

- [ ] **Step 2: Apply the migration to the local dev DB**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
supabase migration up
```
Expected: migration applies cleanly (exit 0, no errors).

- [ ] **Step 3: Verify the column exists**

```bash
supabase db execute "select column_name, data_type, is_nullable from information_schema.columns where table_schema='social' and table_name='twitter_tweets' and column_name='scrape_query';"
```
Expected: one row — `scrape_query | text | YES`.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260322120000_twitter_scrape_query_column.sql
git commit -m "feat: add scrape_query column to twitter_tweets for standalone scrapes"
```

---

## Task 3: Implement `upsert_standalone_tweets()`

**Files:**
- Create: `TRR-Backend/trr_backend/repositories/twitter_standalone.py`
- Create: `TRR-Backend/tests/repositories/test_twitter_standalone_upsert.py`

Thin wrapper around `_pg_upsert_many()` that converts `Tweet` dataclass instances into DB-compatible dicts. The table arg to `_pg_upsert_many` must be `"twitter_tweets"` (unqualified) because the function prepends `social.` internally — verified from existing call sites (`_pg_upsert_many("twitter_tweets", chunk, conflict_col="tweet_id")`).

- [ ] **Step 1: Write the failing tests**

The tests patch `_pg_upsert_many` at the location where `twitter_standalone.py` imports it: `trr_backend.repositories.twitter_standalone._pg_upsert_many`.

```python
# tests/repositories/test_twitter_standalone_upsert.py
"""Tests for upsert_standalone_tweets(). Does not hit a real database."""
from unittest.mock import patch

from trr_backend.socials.twitter.scraper import Tweet


def _make_tweet(tweet_id: str, text: str = "hello") -> Tweet:
    return Tweet(
        tweet_id=tweet_id,
        date_time="2026-01-05 20:00:00",
        created_at=1736114400,
        text=text,
        hashtags=["RHOSLC"],
        mentions=[],
        likes=10,
        retweets=2,
        replies=1,
        quotes=0,
        views=500,
        url=f"https://x.com/user/status/{tweet_id}",
        username="testuser",
        display_name="Test User",
        user_verified=False,
        is_reply=False,
        is_retweet=False,
        is_quote=False,
    )


_PATCH = "trr_backend.repositories.twitter_standalone._pg_upsert_many"


def test_upsert_empty_list_is_noop():
    from trr_backend.repositories.twitter_standalone import upsert_standalone_tweets
    with patch(_PATCH) as mock_upsert:
        result = upsert_standalone_tweets([], scrape_query="#RHOSLC")
    mock_upsert.assert_not_called()
    assert result == []


def test_upsert_passes_correct_table_and_conflict_col():
    from trr_backend.repositories.twitter_standalone import upsert_standalone_tweets
    tweets = [_make_tweet("111"), _make_tweet("222")]
    with patch(_PATCH) as mock_upsert:
        mock_upsert.return_value = [{"tweet_id": "111"}, {"tweet_id": "222"}]
        upsert_standalone_tweets(tweets, scrape_query="#RHOSLC")

    args, kwargs = mock_upsert.call_args
    # _pg_upsert_many prepends "social." internally — always pass the bare table name
    assert args[0] == "twitter_tweets"
    assert kwargs.get("conflict_col") == "tweet_id"


def test_upsert_sets_scrape_query_on_each_row():
    from trr_backend.repositories.twitter_standalone import upsert_standalone_tweets
    tweets = [_make_tweet("333")]
    with patch(_PATCH) as mock_upsert:
        mock_upsert.return_value = [{"tweet_id": "333"}]
        upsert_standalone_tweets(tweets, scrape_query="@BravoTV")

    payloads = mock_upsert.call_args[0][1]
    assert payloads[0]["scrape_query"] == "@BravoTV"


def test_upsert_maps_core_tweet_fields():
    from trr_backend.repositories.twitter_standalone import upsert_standalone_tweets
    tweet = _make_tweet("444", text="Watch now #RHOSLC")
    with patch(_PATCH) as mock_upsert:
        mock_upsert.return_value = [{"tweet_id": "444"}]
        upsert_standalone_tweets([tweet], scrape_query="#RHOSLC")

    payload = mock_upsert.call_args[0][1][0]
    assert payload["tweet_id"] == "444"
    assert payload["text"] == "Watch now #RHOSLC"
    assert payload["username"] == "testuser"
    assert payload["likes"] == 10
    assert payload["hashtags"] == ["RHOSLC"]


def test_upsert_returns_upserted_rows():
    from trr_backend.repositories.twitter_standalone import upsert_standalone_tweets
    expected = [{"tweet_id": "555", "text": "hi"}]
    with patch(_PATCH) as mock_upsert:
        mock_upsert.return_value = expected
        result = upsert_standalone_tweets([_make_tweet("555")], scrape_query="#RHOSLC")
    assert result == expected
```

- [ ] **Step 2: Run — verify they fail (module not found)**

```bash
python -m pytest tests/repositories/test_twitter_standalone_upsert.py -v
```
Expected: `ModuleNotFoundError: trr_backend.repositories.twitter_standalone`.

- [ ] **Step 3: Create `twitter_standalone.py`**

```python
# trr_backend/repositories/twitter_standalone.py
"""
Standalone (non-season) tweet persistence.

Provides upsert_standalone_tweets() for persisting tweets scraped by
arbitrary hashtag or @mention queries, without requiring a season_id.
"""
from __future__ import annotations

import logging
from datetime import UTC, datetime
from typing import Any

from trr_backend.repositories.social_season_analytics import _pg_upsert_many
from trr_backend.socials.twitter.scraper import Tweet

logger = logging.getLogger(__name__)


def upsert_standalone_tweets(
    tweets: list[Tweet],
    *,
    scrape_query: str,
) -> list[dict[str, Any]]:
    """Upsert a list of Tweet objects into social.twitter_tweets.

    Uses tweet_id as the conflict key. Sets scrape_query on every row
    so callers can later filter by search term.

    Returns the list of upserted rows as returned by _pg_upsert_many.
    """
    if not tweets:
        return []

    now = datetime.now(UTC).isoformat()
    payloads = [_tweet_to_payload(t, scrape_query=scrape_query, scraped_at=now) for t in tweets]
    rows = _pg_upsert_many("twitter_tweets", payloads, conflict_col="tweet_id")
    logger.info("upsert_standalone_tweets: %d upserted for query %r", len(rows), scrape_query)
    return rows


def _tweet_to_payload(tweet: Tweet, *, scrape_query: str, scraped_at: str) -> dict[str, Any]:
    """Convert a Tweet dataclass to a social.twitter_tweets insert payload."""
    created_at_ts: str | None = None
    if tweet.created_at:
        try:
            created_at_ts = datetime.fromtimestamp(tweet.created_at, tz=UTC).isoformat()
        except (OSError, OverflowError, ValueError):
            created_at_ts = None

    return {
        "tweet_id": tweet.tweet_id,
        "username": tweet.username,
        "display_name": tweet.display_name or "",
        "user_verified": tweet.user_verified,
        "text": tweet.text,
        "hashtags": tweet.hashtags or [],
        "mentions": tweet.mentions or [],
        "media_urls": tweet.media_urls or [],
        "likes": tweet.likes,
        "retweets": tweet.retweets,
        "replies_count": tweet.replies,
        "quotes": tweet.quotes,
        "views": tweet.views,
        "is_reply": tweet.is_reply,
        "is_retweet": tweet.is_retweet,
        "is_quote": tweet.is_quote,
        "reply_to_tweet_id": tweet.reply_to_tweet_id,
        "quoted_tweet_id": tweet.quoted_tweet_id,
        "created_at": created_at_ts,
        "scraped_at": scraped_at,
        "scrape_query": scrape_query,
        # season_id, job_id, show_id, person_id intentionally omitted (NULL)
    }
```

- [ ] **Step 4: Run tests — all 5 must pass**

```bash
python -m pytest tests/repositories/test_twitter_standalone_upsert.py -v
```
Expected: 5/5 PASS.

- [ ] **Step 5: Commit**

```bash
git add trr_backend/repositories/twitter_standalone.py \
        tests/repositories/test_twitter_standalone_upsert.py
git commit -m "feat: add upsert_standalone_tweets for hashtag/mention scrapes without season context"
```

---

## Task 4: Add `--persist` Flag to the CLI

**Files:**
- Modify: `TRR-Backend/scripts/socials/twitter/scrape.py`
- Create: `TRR-Backend/tests/scripts/test_twitter_scrape_persist.py`

When `--persist` is supplied, call `upsert_standalone_tweets()` after a successful search. When `--scrape-query` is omitted, default to the value of `--query`.

**Important:** Add the `upsert_standalone_tweets` import at the **top** of `scrape.py` (not inline), so that tests can patch it via the `scripts.socials.twitter.scrape` module namespace.

- [ ] **Step 1: Write the failing tests**

The tests use `monkeypatch.setattr` on the module-level name — the same pattern used throughout this project's test suite (see `test_socials_twitter_admin_routes.py`). They drive `main()` by patching `sys.argv`.

```python
# tests/scripts/test_twitter_scrape_persist.py
"""
Tests for the --persist flag on the Twitter scrape CLI.
Patches via monkeypatch.setattr on the module-level import so the
binding at call time is intercepted correctly.
"""
import sys
import pytest
from trr_backend.socials.twitter.scraper import Tweet


def _make_tweet(tweet_id: str = "t1") -> Tweet:
    return Tweet(
        tweet_id=tweet_id, date_time="2026-01-05 20:00:00", created_at=1736114400,
        text="hi", hashtags=[], mentions=[], likes=0, retweets=0, replies=0,
        quotes=0, views=0, url="https://x.com/u/status/t1",
        username="u", display_name="U", user_verified=False,
        is_reply=False, is_retweet=False, is_quote=False,
    )


def _run(argv: list[str], monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(sys, "argv", ["scrape"] + argv)
    import scripts.socials.twitter.scrape as scrape_mod
    scrape_mod.main()


def test_persist_calls_upsert_with_default_scrape_query(monkeypatch: pytest.MonkeyPatch) -> None:
    import scripts.socials.twitter.scrape as scrape_mod
    from trr_backend.socials.twitter.scraper import TwitterScraper

    upsert_calls: list[dict] = []

    monkeypatch.setattr(TwitterScraper, "scrape", lambda self, config: [_make_tweet()])
    monkeypatch.setattr(
        scrape_mod,
        "upsert_standalone_tweets",
        lambda tweets, *, scrape_query: upsert_calls.append({"tweets": tweets, "scrape_query": scrape_query}) or [],
    )

    _run(["--query", "#RHOSLC", "--start", "2026-01-01", "--end", "2026-01-11", "--persist"], monkeypatch)

    assert len(upsert_calls) == 1
    assert upsert_calls[0]["scrape_query"] == "#RHOSLC"


def test_persist_uses_explicit_scrape_query_when_provided(monkeypatch: pytest.MonkeyPatch) -> None:
    import scripts.socials.twitter.scrape as scrape_mod
    from trr_backend.socials.twitter.scraper import TwitterScraper

    upsert_calls: list[dict] = []

    monkeypatch.setattr(TwitterScraper, "scrape", lambda self, config: [_make_tweet()])
    monkeypatch.setattr(
        scrape_mod,
        "upsert_standalone_tweets",
        lambda tweets, *, scrape_query: upsert_calls.append({"scrape_query": scrape_query}) or [],
    )

    _run(
        ["--query", "@BravoTV", "--start", "2026-01-01", "--end", "2026-01-11",
         "--persist", "--scrape-query", "@BravoTV-jan2026"],
        monkeypatch,
    )

    assert upsert_calls[0]["scrape_query"] == "@BravoTV-jan2026"


def test_no_persist_does_not_call_upsert(monkeypatch: pytest.MonkeyPatch) -> None:
    import scripts.socials.twitter.scrape as scrape_mod
    from trr_backend.socials.twitter.scraper import TwitterScraper

    upsert_calls: list = []

    monkeypatch.setattr(TwitterScraper, "scrape", lambda self, config: [_make_tweet()])
    monkeypatch.setattr(
        scrape_mod,
        "upsert_standalone_tweets",
        lambda *a, **kw: upsert_calls.append(1) or [],
    )

    _run(["--query", "#RHOSLC", "--start", "2026-01-01", "--end", "2026-01-11"], monkeypatch)

    assert upsert_calls == []


def test_persist_with_empty_results_does_not_call_upsert(monkeypatch: pytest.MonkeyPatch) -> None:
    import scripts.socials.twitter.scrape as scrape_mod
    from trr_backend.socials.twitter.scraper import TwitterScraper

    upsert_calls: list = []

    monkeypatch.setattr(TwitterScraper, "scrape", lambda self, config: [])
    monkeypatch.setattr(
        scrape_mod,
        "upsert_standalone_tweets",
        lambda *a, **kw: upsert_calls.append(1) or [],
    )

    _run(["--query", "#RHOSLC", "--start", "2026-01-01", "--end", "2026-01-11", "--persist"], monkeypatch)

    # Guard at the call site: `if args.persist and tweets` skips upsert when empty
    assert upsert_calls == []
```

- [ ] **Step 2: Run — verify tests fail (argument not recognised)**

```bash
python -m pytest tests/scripts/test_twitter_scrape_persist.py -v
```
Expected: all 4 FAIL with `SystemExit` / unrecognised argument `--persist`.

- [ ] **Step 3: Add top-level import + new arguments to `scrape.py`**

At the **top** of `scrape.py`, alongside the other imports:
```python
from trr_backend.repositories.twitter_standalone import upsert_standalone_tweets
```

Then in `main()`, after the `--mirror` argument (around line 222), add:
```python
    parser.add_argument(
        "--persist",
        action="store_true",
        help="Upsert results to social.twitter_tweets (standalone, no season required)",
    )
    parser.add_argument(
        "--scrape-query",
        help="Label stored on each persisted row (defaults to --query value)",
    )
```

- [ ] **Step 4: Call `upsert_standalone_tweets` in the search-mode block**

At the end of the search-mode block in `main()`, after the `save_results` call:
```python
    if args.persist and tweets:
        label = args.scrape_query or args.query
        upserted = upsert_standalone_tweets(tweets, scrape_query=label)
        logger.info("Persisted %d tweets to DB with scrape_query=%r", len(upserted), label)
```

- [ ] **Step 5: Run tests — all 4 must pass**

```bash
python -m pytest tests/scripts/test_twitter_scrape_persist.py -v
```
Expected: 4/4 PASS.

- [ ] **Step 6: Smoke-test the help output**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python -m scripts.socials.twitter.scrape --help
```
Expected: `--persist` and `--scrape-query` appear in the help text.

- [ ] **Step 7: Commit**

```bash
git add scripts/socials/twitter/scrape.py tests/scripts/test_twitter_scrape_persist.py
git commit -m "feat: add --persist and --scrape-query flags to twitter scrape CLI"
```

---

## Task 5: Add `persist` Field to the API Endpoint

**Files:**
- Modify: `TRR-Backend/api/routers/socials.py`
- Create: `TRR-Backend/tests/api/routers/test_twitter_persist_endpoint.py`

Add two optional fields to `TwitterSearchRequest`: `persist: bool = False` and `scrape_query: str | None = None`. When `persist=True`, call `upsert_standalone_tweets()`. The endpoint still returns the full `TwitterSearchResponse` either way.

**Important:** Add the `upsert_standalone_tweets` import at the **top** of `socials.py` (not inline), so tests can patch it as `api.routers.socials.upsert_standalone_tweets` via `monkeypatch.setattr`.

Pattern used here matches the existing `tests/api/routers/test_socials_twitter_admin_routes.py`: `TestClient(app)`, JWT token via `_make_admin_token()`, `monkeypatch.setattr` for patching.

- [ ] **Step 1: Write the failing tests**

```python
# tests/api/routers/test_twitter_persist_endpoint.py
"""
Tests for the persist=True path on POST /api/v1/admin/socials/twitter/search.
Follows the same pattern as test_socials_twitter_admin_routes.py.
"""
from __future__ import annotations

from datetime import UTC, datetime, timedelta

import jwt
import pytest
from fastapi.testclient import TestClient

import api.routers.socials as socials_router
from api.main import app
from trr_backend.socials.twitter.scraper import Tweet, TwitterScraper


def _make_admin_token(secret: str = "test-secret-32-bytes-minimum-abcdef") -> str:
    now = datetime.now(tz=UTC)
    payload = {
        "sub": "admin-twitter-persist",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=5)).timestamp()),
        "role": "service_role",
    }
    return jwt.encode(payload, secret, algorithm="HS256")


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


def _make_tweet(tweet_id: str = "t99") -> Tweet:
    return Tweet(
        tweet_id=tweet_id, date_time="2026-01-05 20:00:00", created_at=1736114400,
        text="hello world", hashtags=["RHOSLC"], mentions=[],
        likes=5, retweets=1, replies=0, quotes=0, views=100,
        url=f"https://x.com/u/status/{tweet_id}", username="user",
        display_name="User", user_verified=False,
        is_reply=False, is_retweet=False, is_quote=False,
    )


_SECRET = "test-secret-32-bytes-minimum-abcdef"


def test_persist_true_calls_upsert(client: TestClient, monkeypatch: pytest.MonkeyPatch) -> None:
    """When persist=True, upsert_standalone_tweets is called with the scraped tweets."""
    monkeypatch.setenv("SUPABASE_JWT_SECRET", _SECRET)
    upsert_calls: list[dict] = []

    monkeypatch.setattr("trr_backend.repositories.social_season_analytics._load_twitter_auth", lambda: ({}, None))
    monkeypatch.setattr(
        "trr_backend.repositories.social_season_analytics._load_twikit_credentials",
        lambda *_a, **_kw: {},
    )
    monkeypatch.setattr(TwitterScraper, "scrape", lambda self, config: [_make_tweet()])
    monkeypatch.setattr(
        socials_router,
        "upsert_standalone_tweets",
        lambda tweets, *, scrape_query: upsert_calls.append({"tweets": tweets, "scrape_query": scrape_query}) or [],
    )

    resp = client.post(
        "/api/v1/admin/socials/twitter/search",
        headers={"Authorization": f"Bearer {_make_admin_token()}"},
        json={
            "query": "#RHOSLC",
            "date_start": "2026-01-01T00:00:00",
            "date_end": "2026-01-11T00:00:00",
            "persist": True,
        },
    )
    assert resp.status_code == 200
    assert resp.json()["success"] is True
    assert len(upsert_calls) == 1
    assert upsert_calls[0]["scrape_query"] == "#RHOSLC"


def test_persist_true_uses_explicit_scrape_query(client: TestClient, monkeypatch: pytest.MonkeyPatch) -> None:
    """When scrape_query is provided, it is used instead of query."""
    monkeypatch.setenv("SUPABASE_JWT_SECRET", _SECRET)
    upsert_calls: list[dict] = []

    monkeypatch.setattr("trr_backend.repositories.social_season_analytics._load_twitter_auth", lambda: ({}, None))
    monkeypatch.setattr(
        "trr_backend.repositories.social_season_analytics._load_twikit_credentials",
        lambda *_a, **_kw: {},
    )
    monkeypatch.setattr(TwitterScraper, "scrape", lambda self, config: [_make_tweet()])
    monkeypatch.setattr(
        socials_router,
        "upsert_standalone_tweets",
        lambda tweets, *, scrape_query: upsert_calls.append({"scrape_query": scrape_query}) or [],
    )

    client.post(
        "/api/v1/admin/socials/twitter/search",
        headers={"Authorization": f"Bearer {_make_admin_token()}"},
        json={
            "query": "#RHOSLC",
            "date_start": "2026-01-01T00:00:00",
            "date_end": "2026-01-11T00:00:00",
            "persist": True,
            "scrape_query": "RHOSLC-S4-premiere",
        },
    )
    assert upsert_calls[0]["scrape_query"] == "RHOSLC-S4-premiere"


def test_persist_defaults_scrape_query_to_query_value(client: TestClient, monkeypatch: pytest.MonkeyPatch) -> None:
    """When persist=True and scrape_query is omitted, the query value is used as the label."""
    monkeypatch.setenv("SUPABASE_JWT_SECRET", _SECRET)
    upsert_calls: list[dict] = []

    monkeypatch.setattr("trr_backend.repositories.social_season_analytics._load_twitter_auth", lambda: ({}, None))
    monkeypatch.setattr(
        "trr_backend.repositories.social_season_analytics._load_twikit_credentials",
        lambda *_a, **_kw: {},
    )
    monkeypatch.setattr(TwitterScraper, "scrape", lambda self, config: [_make_tweet()])
    monkeypatch.setattr(
        socials_router,
        "upsert_standalone_tweets",
        lambda tweets, *, scrape_query: upsert_calls.append({"scrape_query": scrape_query}) or [],
    )

    client.post(
        "/api/v1/admin/socials/twitter/search",
        headers={"Authorization": f"Bearer {_make_admin_token()}"},
        json={
            "query": "@BravoTV",
            "date_start": "2026-01-01T00:00:00",
            "date_end": "2026-01-11T00:00:00",
            "persist": True,
            # scrape_query intentionally omitted
        },
    )
    assert upsert_calls[0]["scrape_query"] == "@BravoTV"


def test_persist_false_does_not_call_upsert(client: TestClient, monkeypatch: pytest.MonkeyPatch) -> None:
    """When persist is not set, upsert is never called."""
    monkeypatch.setenv("SUPABASE_JWT_SECRET", _SECRET)
    upsert_calls: list = []

    monkeypatch.setattr("trr_backend.repositories.social_season_analytics._load_twitter_auth", lambda: ({}, None))
    monkeypatch.setattr(
        "trr_backend.repositories.social_season_analytics._load_twikit_credentials",
        lambda *_a, **_kw: {},
    )
    monkeypatch.setattr(TwitterScraper, "scrape", lambda self, config: [_make_tweet()])
    monkeypatch.setattr(
        socials_router,
        "upsert_standalone_tweets",
        lambda *a, **kw: upsert_calls.append(1) or [],
    )

    client.post(
        "/api/v1/admin/socials/twitter/search",
        headers={"Authorization": f"Bearer {_make_admin_token()}"},
        json={
            "query": "#RHOSLC",
            "date_start": "2026-01-01T00:00:00",
            "date_end": "2026-01-11T00:00:00",
        },
    )
    assert upsert_calls == []
```

- [ ] **Step 2: Run — verify tests fail (`persist` field rejected)**

```bash
python -m pytest tests/api/routers/test_twitter_persist_endpoint.py -v
```
Expected: 422 Unprocessable Entity (unknown field) or import error.

- [ ] **Step 3: Add top-level import to `socials.py`**

At the top of `api/routers/socials.py`, alongside the other internal imports:
```python
from trr_backend.repositories.twitter_standalone import upsert_standalone_tweets
```

- [ ] **Step 4: Add fields to `TwitterSearchRequest` (around line 1247)**

```python
    # Persistence options
    persist: bool = Field(default=False, description="Upsert results to social.twitter_tweets")
    scrape_query: str | None = Field(
        default=None,
        description="Label stored on persisted rows; defaults to query value when omitted",
    )
```

- [ ] **Step 5: Call `upsert_standalone_tweets` in `search_twitter()` handler**

Inside `search_twitter()`, after `tweets = scraper.scrape(config)` and the optional S3 mirror, add:
```python
        if request.persist and tweets:
            label = request.scrape_query or request.query
            upsert_standalone_tweets(tweets, scrape_query=label)
```

- [ ] **Step 6: Run tests — all 4 must pass**

```bash
python -m pytest tests/api/routers/test_twitter_persist_endpoint.py -v
```
Expected: 4/4 PASS.

- [ ] **Step 7: Run the full test suite**

```bash
python -m pytest tests/ -q --tb=short -x
```
Expected: green (no regressions across the full suite).

- [ ] **Step 8: Commit**

```bash
git add api/routers/socials.py tests/api/routers/test_twitter_persist_endpoint.py
git commit -m "feat: add persist flag to twitter search endpoint for DB storage without season context"
```

---

## Usage Examples (After All Tasks Complete)

### Hashtag scrape — CLI, to disk only (already works; no change)
```bash
python -m scripts.socials.twitter.scrape \
  --query "#RHOSLC" --start 2026-01-01 --end 2026-01-11
```

### Mention scrape — CLI, to disk only (fixed in Task 1)
```bash
python -m scripts.socials.twitter.scrape \
  --query "@BravoTV" --start 2026-01-01 --end 2026-01-11
```

### Hashtag scrape — CLI, persist to DB (Task 4)
```bash
python -m scripts.socials.twitter.scrape \
  --query "#RHOSLC" --start 2026-01-01 --end 2026-01-11 --persist
```

### Mention scrape — CLI, persist to DB with custom label (Tasks 1 + 4)
```bash
python -m scripts.socials.twitter.scrape \
  --query "@BravoTV" --start 2026-01-01 --end 2026-01-11 \
  --persist --scrape-query "@BravoTV-jan2026-premiere"
```

### Via API — persist and return in one call (Task 5)
```json
POST /api/v1/admin/socials/twitter/search
{
  "query": "#RHOSLC",
  "date_start": "2026-01-01T00:00:00",
  "date_end": "2026-01-11T00:00:00",
  "persist": true,
  "scrape_query": "RHOSLC-S4-premiere"
}
```

### Query persisted rows by scrape term
```sql
SELECT tweet_id, username, text, likes, created_at
FROM social.twitter_tweets
WHERE scrape_query = '#RHOSLC'
ORDER BY created_at DESC;
```
