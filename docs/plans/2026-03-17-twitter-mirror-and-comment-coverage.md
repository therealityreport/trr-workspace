# Twitter Video Mirror Fix + Comment Coverage Improvement

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix 13/13 failing Twitter post media mirrors (expired video URLs) and improve comment coverage from ~50% to ~75-85%.

**Architecture:** Two independent fixes in TRR-Backend. (1) Add yt-dlp fallback in `mirror_url_to_s3()` for Twitter video URLs that fail HTTP download — resolves fresh video URLs via the tweet page. (2) Change `fetch_tweet_replies()` to always combine TweetDetail results with SearchTimeline results (not just fallback), deduplicating by tweet ID for better coverage.

**Tech Stack:** Python 3.11, yt-dlp (already a dependency), Twitter GraphQL API, S3/R2 object storage

---

## Task 1: Add yt-dlp video fallback to `mirror_url_to_s3()`

The core mirror function only does HTTP GET. Twitter video URLs (`video.twimg.com`) expire and return 403/404. Add a yt-dlp fallback that resolves fresh video URLs from the tweet page when direct download fails.

**Files:**
- Modify: `TRR-Backend/trr_backend/media/s3_mirror.py:886-999` (`mirror_url_to_s3()`)
- Test: `TRR-Backend/tests/media/test_s3_mirror.py`

**Step 1: Write failing test for yt-dlp Twitter video fallback**

Add to `tests/media/test_s3_mirror.py`:

```python
def test_mirror_url_to_s3_falls_back_to_ytdlp_for_twitter_video(monkeypatch: pytest.MonkeyPatch) -> None:
    """When a video.twimg.com URL returns 403, fall back to yt-dlp resolution."""
    import subprocess
    monkeypatch.setenv("OBJECT_STORAGE_REGION", "us-east-1")
    monkeypatch.setenv("OBJECT_STORAGE_BUCKET", "bucket")
    monkeypatch.setenv("OBJECT_STORAGE_PUBLIC_BASE_URL", "https://cdn.example.com")

    # Simulate 403 on direct download
    class _Forbidden:
        status_code = 403
    class _ForbiddenError(s3_mirror.requests.exceptions.HTTPError):
        def __init__(self):
            self.response = _Forbidden()
            super().__init__(response=self.response)

    call_count = {"http": 0, "ytdlp": 0}

    def _fake_get(*args, **kwargs):
        call_count["http"] += 1
        if call_count["http"] == 1:
            # First call: original URL fails with 403
            raise _ForbiddenError()
        # Second call: resolved URL succeeds
        class _OK:
            headers = {"Content-Type": "video/mp4"}
            def __enter__(self): return self
            def __exit__(self, *a): return False
            def raise_for_status(self): pass
            def iter_content(self, chunk_size):
                yield b"video-bytes-here"
        return _OK()

    # yt-dlp returns a fresh URL
    def _fake_subprocess_run(cmd, **kwargs):
        call_count["ytdlp"] += 1
        result = types.SimpleNamespace()
        result.returncode = 0
        result.stdout = '{"url": "https://video.twimg.com/fresh/video.mp4", "ext": "mp4"}'
        result.stderr = ""
        return result

    monkeypatch.setattr(s3_mirror.requests, "get", _fake_get)
    monkeypatch.setattr(s3_mirror, "_head_object", lambda *a, **kw: None)
    monkeypatch.setattr(subprocess, "run", _fake_subprocess_run)
    upload_mock = MagicMock(return_value=("etag-1", 16))
    monkeypatch.setattr(s3_mirror, "upload_bytes_to_s3", upload_mock)

    result = s3_mirror.mirror_url_to_s3(
        "https://video.twimg.com/ext_tw_video/12345/pu/vid/avc1/1280x720/expired.mp4?tag=12",
        s3_client=MagicMock(),
        bucket="bucket",
        tweet_url="https://x.com/BravoTV/status/1973085683721052254",
    )

    assert result.status == "mirrored"
    assert result.error is None
    assert call_count["ytdlp"] == 1
    upload_mock.assert_called_once()
```

**Step 2: Run test to verify it fails**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/media/test_s3_mirror.py::test_mirror_url_to_s3_falls_back_to_ytdlp_for_twitter_video -v
```
Expected: FAIL — `mirror_url_to_s3()` does not accept `tweet_url` parameter yet.

**Step 3: Implement yt-dlp fallback in `mirror_url_to_s3()`**

In `TRR-Backend/trr_backend/media/s3_mirror.py`:

1. Add `tweet_url: str | None = None` parameter to `mirror_url_to_s3()` signature (line 886).

2. Add a helper function above `mirror_url_to_s3()`:

```python
def _is_twitter_video_url(url: str) -> bool:
    """Check if URL is a Twitter video that may need yt-dlp resolution."""
    host = urlparse(url).netloc.lower()
    return "video.twimg.com" in host


def _resolve_twitter_video_via_ytdlp(tweet_url: str) -> str | None:
    """Use yt-dlp to resolve a fresh video URL from a tweet page."""
    import shutil
    import subprocess

    if not shutil.which("yt-dlp"):
        return None
    cmd = [
        "yt-dlp",
        "--dump-single-json",
        "--no-playlist",
        "--skip-download",
        "--format", "best[ext=mp4]/best",
        tweet_url,
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120, check=False)
    except Exception:
        return None
    if proc.returncode != 0:
        return None
    try:
        import json
        payload = json.loads(proc.stdout or "{}")
        return str(payload.get("url") or "").strip() or None
    except (json.JSONDecodeError, ValueError):
        return None
```

3. In `mirror_url_to_s3()`, after the `except requests.exceptions.HTTPError` block (around line 988-999), add a yt-dlp fallback before returning the error:

```python
    except requests.exceptions.HTTPError as exc:
        status_code = getattr(getattr(exc, "response", None), "status_code", None)
        reason = f"http_{int(status_code)}" if status_code is not None else "http_error"

        # --- NEW: yt-dlp fallback for expired Twitter video URLs ---
        if (
            status_code in (401, 403, 404)
            and tweet_url
            and _is_twitter_video_url(source_url)
        ):
            resolved_url = _resolve_twitter_video_via_ytdlp(tweet_url)
            if resolved_url and resolved_url != source_url:
                # Retry download with the fresh resolved URL
                return mirror_url_to_s3(
                    resolved_url,
                    s3_client=s3,
                    bucket=target_bucket,
                    max_bytes=max_bytes_limit,
                    tweet_url=None,  # prevent infinite recursion
                )
        # --- END yt-dlp fallback ---

        return MirrorResult(
            source_url=source_url,
            ...  # existing error return
        )
```

**Step 4: Run test to verify it passes**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/media/test_s3_mirror.py::test_mirror_url_to_s3_falls_back_to_ytdlp_for_twitter_video -v
```
Expected: PASS

**Step 5: Run existing mirror tests to verify no regressions**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/media/test_s3_mirror.py -v
```
Expected: All tests PASS (existing tests don't pass `tweet_url`, so new param defaults to None and old behavior is unchanged).

**Step 6: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && git add trr_backend/media/s3_mirror.py tests/media/test_s3_mirror.py
git commit -m "feat: add yt-dlp fallback for expired Twitter video mirror URLs"
```

---

## Task 2: Thread `tweet_url` through the post media mirror pipeline

The orchestrator that calls `mirror_url_to_s3()` needs to pass the tweet URL so the fallback can work.

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py` (post media mirror execution path)
- Modify: `TRR-Backend/trr_backend/media/s3_mirror.py` (`mirror_urls_to_s3()` wrapper)

**Step 1: Add `tweet_url` passthrough to `mirror_urls_to_s3()`**

In `s3_mirror.py`, find `mirror_urls_to_s3()` (around line 1087). Add `tweet_url: str | None = None` parameter and pass it through to `mirror_url_to_s3()`.

**Step 2: Find and update the post media mirror call site in `social_season_analytics.py`**

Search for where `mirror_urls_to_s3` or `mirror_url_to_s3` is called for Twitter post media. The mirror execution function should have access to the post's `source_id`. Construct the tweet URL as `f"https://x.com/i/status/{source_id}"` and pass it as `tweet_url`.

Note: Only pass `tweet_url` when `platform == "twitter"`. Other platforms should continue passing `None`.

**Step 3: Run the full mirror test suite**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/media/test_s3_mirror.py tests/repositories/test_media_assets_mirroring.py tests/repositories/test_social_mirror_repairs.py -v
```
Expected: All PASS

**Step 4: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && git add trr_backend/media/s3_mirror.py trr_backend/repositories/social_season_analytics.py
git commit -m "feat: thread tweet_url through mirror pipeline for yt-dlp fallback"
```

---

## Task 3: Combine TweetDetail + SearchTimeline for reply coverage

Currently `fetch_tweet_replies()` only falls back to SearchTimeline when TweetDetail fails. Change it to **always combine** both sources, deduplicating by tweet ID.

**Files:**
- Modify: `TRR-Backend/trr_backend/socials/twitter/scraper.py:1857-1998` (`fetch_tweet_replies()`)
- Test: `TRR-Backend/tests/socials/test_comment_scraper_fixes.py`

**Step 1: Write failing test for combined reply fetching**

Add to `tests/socials/test_comment_scraper_fixes.py`:

```python
def test_fetch_tweet_replies_combines_detail_and_search(monkeypatch):
    """TweetDetail results are supplemented with SearchTimeline results, deduped."""
    from trr_backend.socials.twitter.scraper import TwitterScraper, Tweet

    scraper = TwitterScraper.__new__(TwitterScraper)
    # ... set up minimal scraper state (follow existing test patterns in the file)

    detail_replies = [
        Tweet(tweet_id="AAA", ...),  # unique to TweetDetail
        Tweet(tweet_id="BBB", ...),  # appears in both
    ]
    search_replies = [
        Tweet(tweet_id="BBB", ...),  # duplicate
        Tweet(tweet_id="CCC", ...),  # unique to SearchTimeline
    ]

    # Mock TweetDetail to return detail_replies
    # Mock _fetch_tweet_replies_via_search to return search_replies

    replies = scraper.fetch_tweet_replies("root-tweet", delay=0)
    ids = {r.tweet_id for r in replies}
    assert ids == {"AAA", "BBB", "CCC"}  # combined and deduped
    assert len(replies) == 3
```

Adapt this to match the existing test patterns in `test_comment_scraper_fixes.py`. Use the same `monkeypatch` / mock approach the file already uses.

**Step 2: Run test to verify it fails**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/socials/test_comment_scraper_fixes.py::test_fetch_tweet_replies_combines_detail_and_search -v
```
Expected: FAIL — current code returns only TweetDetail results when they exist.

**Step 3: Implement combined fetching in `fetch_tweet_replies()`**

In `scraper.py`, modify `fetch_tweet_replies()` (line 1857):

After the TweetDetail parsing (after line 1981), instead of returning immediately or only falling back when empty, **always** run SearchTimeline as a supplement:

```python
        # ... existing TweetDetail parsing produces `replies` list ...

        # Always supplement with SearchTimeline results for better coverage
        seen_ids = {r.tweet_id for r in replies}
        search_replies = self._fetch_tweet_replies_via_search(
            tweet_id=tweet_id,
            delay=delay,
            max_pages=search_max_pages,
        )
        for sr in search_replies:
            if sr.tweet_id not in seen_ids:
                seen_ids.add(sr.tweet_id)
                replies.append(sr)

        if not replies and self._twikit_credentials:
            twikit_replies = self._fetch_tweet_replies_via_twikit(
                tweet_id=tweet_id,
                max_pages=twikit_max_pages,
                delay=max(delay, 0.2),
            )
            for tr in twikit_replies:
                if tr.tweet_id not in seen_ids:
                    seen_ids.add(tr.tweet_id)
                    replies.append(tr)

        return replies
```

This replaces the current logic at lines 1983-1998 where SearchTimeline only runs if `not replies and self.last_reply_fetch_reason`.

**Step 4: Run test to verify it passes**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/socials/test_comment_scraper_fixes.py::test_fetch_tweet_replies_combines_detail_and_search -v
```
Expected: PASS

**Step 5: Run all Twitter scraper tests**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/socials/test_comment_scraper_fixes.py tests/api/routers/test_socials_twitter_admin_routes.py -v
```
Expected: All PASS

**Step 6: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && git add trr_backend/socials/twitter/scraper.py tests/socials/test_comment_scraper_fixes.py
git commit -m "feat: combine TweetDetail + SearchTimeline for better reply coverage"
```

---

## Task 4: Increase default SearchTimeline max_pages

The default `search_max_pages=8` is conservative. For posts with 90+ replies, 8 pages (~160 results) isn't enough. The page budget calculator already supports up to 60 pages — but the default in the scraper signature is only 8.

**Files:**
- Modify: `TRR-Backend/trr_backend/socials/twitter/scraper.py:1862` (default parameter)

**Step 1: Increase default `search_max_pages` from 8 to 20**

In `fetch_tweet_replies()` signature (line 1862):
```python
        search_max_pages: int = 20,  # was 8
```

Note: The orchestrator at line 17741 passes `reply_pages` from the dynamic budget calculator (max 60), so this only affects direct API calls without explicit budget. 20 is a safe middle ground — it won't cause excessive requests for small posts because the SearchTimeline pagination breaks when results are exhausted (line 2064: `if not next_cursor: break`).

**Step 2: Update the `_fetch_tweet_replies_via_search` default too**

In line 2000:
```python
    def _fetch_tweet_replies_via_search(self, *, tweet_id: str, delay: float, max_pages: int = 20) -> list[Tweet]:
```

**Step 3: Run tests**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/socials/test_comment_scraper_fixes.py tests/api/routers/test_socials_twitter_admin_routes.py -v
```
Expected: All PASS (existing tests that pass explicit `search_max_pages=17` etc. are unaffected).

**Step 4: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && git add trr_backend/socials/twitter/scraper.py
git commit -m "feat: increase default Twitter reply search pages from 8 to 20"
```

---

## Task 5: Validation — re-run sync and verify improvements

**Step 1: Trigger a fresh sync for RHOSLC S6 Week 2 Twitter**

Use the admin UI "Start X Sync Session" button, or via API:
```bash
curl -X POST http://127.0.0.1:8000/api/v1/admin/socials/seasons/e9161955-6ee4-4985-865e-3386a0f670fb/sync-sessions \
  -H "Content-Type: application/json" \
  -d '{"platforms": ["twitter"], "source_scope": "bravo", "week_index": 2}'
```

**Step 2: Monitor the sync dashboard**

Watch for:
- Mirror status should now show "Complete" or "Partial" (not "Failed") for video posts
- Comment coverage should improve from 49.4% toward 70-85%
- The `twitter_incomplete_or_capped` reason should trigger at a higher threshold

**Step 3: Document results**

Compare before/after:
- Mirror: was 126/142 (88.7%) with 13 failed → target: 139/142 (97.9%) or better
- Comments: was 304/615 (49.4%) → target: 450+/615 (73%+)
