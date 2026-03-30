# Twitter/X Catalog Backfill Fix + Workspace Hardening Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the Twitter/X catalog backfill to scrape the account's full content (posts, media, quotes, replies) instead of being silently limited to ~315 original tweets, and harden the Getty server lifecycle in the workspace Makefile.

**Architecture:** Three independent bugs compound to limit Twitter scraping to ~315 posts: (1) `include_replies=False` in the scraper config excludes most tweet types, (2) a post-scrape list comprehension at line 26820 double-filters replies even if the scraper returns them, and (3) `max_pages` is hard-capped at 20 regardless of account size. Additionally, `_cached_live_profile_total_posts()` returns `None` for Twitter, so the system never knows the real post count.

**Tech Stack:** Python (FastAPI backend), TypeScript/React (Next.js admin frontend), PostgreSQL (Supabase)

**Part A (Getty Makefile):** Already completed — port-in-use guard added to `getty-server` target.

**Part B (Instagram Gap-Fill):** Existing plan at `docs/superpowers/plans/2026-03-26-instagram-catalog-gap-fill.md` — 9 tasks, execute separately.

**Part C (Twitter/X Backfill Fix):** Tasks 1–5 below.

---

## File Structure

### Backend (TRR-Backend)
| File | Action | Responsibility |
|------|--------|----------------|
| `trr_backend/repositories/social_season_analytics.py:26791-26899` | Modify | Fix `_scrape_shared_twitter_posts` — remove reply filters, raise page cap |
| `trr_backend/repositories/social_season_analytics.py:32659-32669` | Modify | Enable `_cached_live_profile_total_posts` for Twitter |
| `trr_backend/repositories/social_season_analytics.py:25571` | Modify | Raise `_shared_stage_post_limit` default for Twitter catalog context |
| `trr_backend/socials/twitter/scraper.py:55` | Modify | Add `tweet_types` config field to TwitterScrapeConfig |
| `tests/repositories/test_social_season_analytics.py` | Modify | Add regression tests for new scraping behavior |

---

## Task 1: Fix `_scrape_shared_twitter_posts` — remove double reply filter and include all tweet types

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py:26809-26820`

The function currently has two compounding filters that strip replies:
1. `TwitterScrapeConfig(include_replies=False)` at line 26813 — tells the scraper to skip replies during fetch
2. `catalog_posts = [tweet for tweet in posts if not bool(getattr(tweet, "is_reply", False))]` at line 26820 — strips replies AGAIN from results

The user wants: posts + media + quotes + replies (the account's own content). `from:handle` already limits to the account's tweets only.

- [ ] **Step 1: Change `include_replies` to `True` and raise `max_pages`**

In `_scrape_shared_twitter_posts` at line 26809, change the config construction:

```python
# BEFORE (line 26809-26816):
scrape_config = TwitterScrapeConfig(
    query=f"from:{account_handle}",
    date_start=date_start,
    date_end=date_end,
    include_replies=False,
    include_links=True,
    delay_seconds=0.35,
    max_pages=min(_shared_stage_post_limit(config, default=10) or 10, 20),
)

# AFTER:
scrape_config = TwitterScrapeConfig(
    query=f"from:{account_handle}",
    date_start=date_start,
    date_end=date_end,
    include_replies=True,
    include_links=True,
    delay_seconds=0.35,
    max_pages=_shared_stage_post_limit(config, default=500),
)
```

Changes:
- `include_replies=False` → `include_replies=True` (fetch all tweet types)
- `max_pages=min(..., 20)` → `_shared_stage_post_limit(config, default=500)` (remove the hard cap of 20, use 500 as default for catalog full-history)

- [ ] **Step 2: Remove the double reply filter at line 26820**

```python
# BEFORE (line 26820):
catalog_posts = [tweet for tweet in posts if not bool(getattr(tweet, "is_reply", False))]

# AFTER:
catalog_posts = list(posts)
```

This preserves all tweet types (posts, replies, quotes, media) in the catalog. The `from:handle` query already ensures only this account's content is returned.

- [ ] **Step 3: Run existing tests to verify nothing breaks**

Run:
```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/repositories/test_social_season_analytics.py -k "scrape_shared_twitter" -v
```

Expected: Existing tests pass (they may need updates if they assert on `include_replies=False`).

- [ ] **Step 4: Commit**

```bash
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py
git commit -m "fix(catalog): include all tweet types in Twitter catalog backfill and remove 20-page cap"
```

---

## Task 2: Enable `_cached_live_profile_total_posts` for Twitter

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py:32659-32669`

Currently, `_cached_live_profile_total_posts()` returns `None` for Twitter (lines 32668-32669: `if normalized_platform != "instagram": return None`). This means `_best_known_social_account_total_posts()` never gets a live count for Twitter, so the system thinks the account only has as many posts as are already materialized in the database.

The fix: add a Twitter branch that uses the TwitterScraper to fetch the user's profile and extract their tweet count (statuses_count). This gives the system the real number (~124.4K) instead of the stale materialized count (~315).

- [ ] **Step 1: Read the TwitterScraper to find profile info methods**

Read:
```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && grep -n "def.*profile\|statuses_count\|tweet_count\|total_posts\|followers_count" trr_backend/socials/twitter/scraper.py | head -30
```

Check if the scraper already has a `fetch_profile_info` or `get_user_info` method. If not, we need to check what profile data is available from the GraphQL user endpoint.

- [ ] **Step 2: Add Twitter branch to `_cached_live_profile_total_posts`**

At line 32664, modify the early-return logic to include Twitter:

```python
# BEFORE (lines 32664-32669):
if normalized_platform in {"tiktok", "youtube"}:
    return _normalize_non_negative_int(
        _cached_live_profile_snapshot(normalized_platform, normalized_account).get("total_posts")
    )
if normalized_platform != "instagram":
    return None

# AFTER:
if normalized_platform in {"tiktok", "youtube"}:
    return _normalize_non_negative_int(
        _cached_live_profile_snapshot(normalized_platform, normalized_account).get("total_posts")
    )
if normalized_platform == "twitter":
    return _normalize_non_negative_int(
        _cached_live_profile_snapshot(normalized_platform, normalized_account).get("total_posts")
    )
if normalized_platform != "instagram":
    return None
```

If `_cached_live_profile_snapshot` already supports Twitter, this is sufficient. If not, we need to also add a Twitter path in `_cached_live_profile_snapshot`.

- [ ] **Step 3: Verify `_cached_live_profile_snapshot` handles Twitter**

Read the function to check if it has a Twitter code path. If not, add one that queries the `social.twitter_tweets` table count OR uses the Twitter scraper's user profile endpoint. The most reliable approach is to delegate to the existing catalog freshness data.

If `_cached_live_profile_snapshot` does NOT support Twitter, add a fallback in `_cached_live_profile_total_posts` instead:

```python
if normalized_platform == "twitter":
    # Use the catalog freshness endpoint which already queries live social data
    snapshot = _cached_live_profile_snapshot(normalized_platform, normalized_account)
    total = _normalize_non_negative_int(snapshot.get("total_posts"))
    if total:
        return total
    # Fallback: use materialized count from catalog table
    return _normalize_non_negative_int(_shared_catalog_total_posts("twitter", normalized_account)) or None
```

- [ ] **Step 4: Commit**

```bash
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py
git commit -m "fix(catalog): enable live profile total posts for Twitter accounts"
```

---

## Task 3: Add regression tests for Twitter catalog backfill breadth

**Files:**
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`

- [ ] **Step 1: Read the existing Twitter catalog test**

Read:
```
TRR-Backend/tests/repositories/test_social_season_analytics.py:3960-4040
```

Understand the existing test structure for `_scrape_shared_twitter_posts`.

- [ ] **Step 2: Add test asserting replies are NOT filtered out**

```python
def test_scrape_shared_twitter_posts_catalog_includes_replies(
    monkeypatch, social_repo, mock_twitter_auth
):
    """Catalog backfill should include replies (the account's own replies)."""
    from trr_backend.socials.twitter import TwitterScrapeConfig

    captured_configs: list[TwitterScrapeConfig] = []

    def fake_scrape(self, config, progress_cb=None):
        captured_configs.append(config)
        # Return mix of regular tweets and replies
        return [
            _make_mock_tweet(id="1", text="Regular post", is_reply=False),
            _make_mock_tweet(id="2", text="Reply to someone", is_reply=True),
            _make_mock_tweet(id="3", text="Quote tweet", is_reply=False),
        ]

    monkeypatch.setattr("trr_backend.socials.twitter.TwitterScraper.scrape", fake_scrape)

    rows, meta = social_repo._scrape_shared_twitter_posts(
        run_id="test-run",
        account_handle="bravotv",
        config={"catalog_mode": True},
        job_id="test-job",
    )

    # Verify include_replies=True in config
    assert len(captured_configs) == 1
    assert captured_configs[0].include_replies is True

    # Verify ALL tweets (including replies) are persisted
    assert len(rows) == 3  # Not 2 — the reply must be included
```

- [ ] **Step 3: Add test asserting max_pages is not hard-capped at 20**

```python
def test_scrape_shared_twitter_posts_catalog_max_pages_not_capped_at_20(
    monkeypatch, social_repo, mock_twitter_auth
):
    """Catalog backfill max_pages should not be artificially capped at 20."""
    from trr_backend.socials.twitter import TwitterScrapeConfig

    captured_configs: list[TwitterScrapeConfig] = []

    def fake_scrape(self, config, progress_cb=None):
        captured_configs.append(config)
        return []

    monkeypatch.setattr("trr_backend.socials.twitter.TwitterScraper.scrape", fake_scrape)

    social_repo._scrape_shared_twitter_posts(
        run_id="test-run",
        account_handle="bravotv",
        config={"catalog_mode": True, "max_posts_per_target": 1000},
        job_id="test-job",
    )

    assert len(captured_configs) == 1
    # max_pages should be 1000, not min(1000, 20) = 20
    assert captured_configs[0].max_pages == 1000
```

- [ ] **Step 4: Run the new tests**

Run:
```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/repositories/test_social_season_analytics.py -k "scrape_shared_twitter" -v
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add TRR-Backend/tests/repositories/test_social_season_analytics.py
git commit -m "test(catalog): add regression tests for Twitter catalog backfill breadth"
```

---

## Task 4: Update admin UI freshness display for Twitter post counts

**Files:**
- Modify: `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`

The admin UI currently shows "315 posts" for a Twitter account that actually has 124.4K. Once Task 2 is implemented, the freshness endpoint will return the live count. But the UI should also clarify what the count represents.

- [ ] **Step 1: Read the freshness display area**

Read the section of `SocialAccountProfilePage.tsx` where `stored_total_posts`, `live_total_posts_current`, and `delta_posts` are rendered. Find where the "X posts stored / Y live" display is shown.

- [ ] **Step 2: Verify the display works with large numbers**

After Tasks 1–2 are deployed and a fresh catalog run completes, verify at `http://admin.localhost:3000/social/twitter/bravotv`:
- `live_total_posts_current` shows ~124.4K (not 315)
- `stored_total_posts` grows as the backfill progresses
- `delta_posts` reflects the real gap

No code changes needed here if the existing display already uses `formatInteger` — just verification.

- [ ] **Step 3: Commit any display fixes if needed**

```bash
git add TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx
git commit -m "fix(admin): ensure Twitter post count display handles large counts correctly"
```

---

## Task 5: Integration test — run Twitter catalog backfill with new settings

- [ ] **Step 1: Start the dev stack**

```bash
cd /Users/thomashulihan/Projects/TRR && make dev
```

- [ ] **Step 2: Navigate to the Twitter admin page**

Open `http://admin.localhost:3000/social/twitter/bravotv`

- [ ] **Step 3: Check Freshness and verify live count**

Click "Check Freshness". Expected:
- `live_total_posts_current` shows a number close to 124.4K (the real count)
- `stored_total_posts` shows the current materialized count (likely ~315)
- `delta_posts` shows the real gap (~124K)

- [ ] **Step 4: Run a catalog backfill**

Click "Backfill Posts". Monitor progress:
- Scraper should fetch pages beyond 20 (the old cap)
- Posts, replies, quotes, and media should all be captured
- Progress should show thousands of posts being processed
- The frontier should save cursor progress for resumption

Note: A full 124K backfill will take significant time. Let it run for a few minutes to verify it's working, then optionally cancel and use the gap-fill features (from the Instagram plan, adapted for Twitter) to fill in incrementally.

- [ ] **Step 5: Verify catalog posts include replies**

After some posts are scraped, check the database:
```sql
SELECT
  source_id,
  substring(raw_content from 1 for 80) as preview,
  assignment_status,
  created_at
FROM social.shared_catalog_posts
WHERE platform = 'twitter'
  AND lower(source_account) = 'bravotv'
ORDER BY created_at DESC
LIMIT 20;
```

Expected: Mix of post types including replies and quotes, not just original tweets.

- [ ] **Step 6: Commit any integration fixes**

```bash
git add -A
git commit -m "fix: integration adjustments for Twitter catalog backfill breadth"
```

---

## Design Notes

### Why `include_replies=True` is correct for catalog backfills

The `from:handle` Twitter search query already limits results to tweets BY the specified account. With `include_replies=True`, we get:
- **Original posts** — the account's tweets
- **Media posts** — tweets with images/video
- **Quote tweets** — the account quoting others
- **Thread replies** — the account replying to their own tweets
- **Replies to others** — the account replying to other accounts

All of these are the account's own content. The 124.4K count on Twitter includes all of these. By previously setting `include_replies=False`, we were only getting ~315 original non-reply tweets.

The user specified: "MEDIA + QUOTES + REPLIES + POSTS" — they want all content types. For replies specifically, the `from:handle` constraint already ensures only this account's replies are returned (not other people replying to them).

### Why `max_pages=20` was wrong

At ~20 tweets per page, 20 pages = ~400 tweets maximum. For an account with 124.4K tweets, that's 0.3% coverage. The cap likely existed as a safety guard during development but was never raised for production catalog backfills. The new default of 500 pages (~10K tweets) is more reasonable, and the frontier system handles pagination resumption for accounts with even more content.

### Interaction with Instagram Gap-Fill plan

The Instagram gap-fill plan (`2026-03-26-instagram-catalog-gap-fill.md`) adds `sync_newer` and `resume_tail` actions. Once implemented, these same concepts could be adapted for Twitter. The frontier system already works for Twitter — the issue was that the scraper never got far enough to need frontier resumption because of the 20-page cap.

### Post count sources after fix

| Source | Before Fix | After Fix |
|--------|-----------|-----------|
| `materialized_total_posts` | 315 (stale) | Grows with each backfill |
| `catalog_total_posts` | ~315 | Grows with each backfill |
| `_cached_live_profile_total_posts` | None (Twitter unsupported) | ~124.4K (live from profile) |
| `_best_known_social_account_total_posts` | max(315, ~315, None) = 315 | max(growing, growing, ~124.4K) = ~124.4K |
