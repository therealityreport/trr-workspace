# Cross-Platform Social Scraper Reliability Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Twitter/X, TikTok, YouTube, and Instagram social account flows consistently return post detail, persisted discussion, and saved media through the existing account-profile/admin surfaces, without reviving obsolete lanes or changing public route families.

**Architecture:** Ship this in two waves. Wave 1 stays in `TRR-Backend`: replace the current Instagram-only account discussion/detail guards with a platform capability layer, normalize persisted discussion/detail payloads across Instagram, TikTok, YouTube, and Twitter, and harden launch/runtime capacity so catalog refreshes can reliably backfill comments/media where each platform already supports it. Wave 2 stays in `TRR-APP`: replace the current Instagram-only comments gate with a capability matrix, move the comments/detail UI to generic social-profile components, preserve Instagram bootstrap/deferred-followup semantics, and make the comments tab truthful about whether it can read, refresh, and poll progress for each platform.

**Tech Stack:** FastAPI repository layer, Next.js admin app, Supabase Postgres, Modal dispatch, local worker fallbacks, Crawlee/Scrapling-backed social ingestion, `pytest`, `vitest`, `next build`

---

## Working Rules

- Keep the existing account-profile route families:
  - `/api/admin/trr-api/social/profiles/[platform]/[handle]/comments`
  - `/api/admin/trr-api/social/profiles/[platform]/[handle]/catalog/posts/[sourceId]/detail`
  - `/api/admin/trr-api/social/profiles/[platform]/[handle]/comments/scrape`
  - `/api/admin/trr-api/social/profiles/[platform]/[handle]/catalog/backfill`
- Do not revive a separate YouTube comment-media mirror lane. The existing `youtube_comment_media_mirror_obsolete` sentinel is correct and must stay obsolete.
- Keep `start_social_account_comments_scrape(...)` as the standalone Instagram-only worker lane. TikTok, Twitter, and YouTube comment refresh must route through catalog/backfill orchestration instead of a new dedicated comments worker.
- Preserve the current Instagram launch semantics:
  - already-materialized accounts can skip `post_details`
  - bootstrap-required accounts can defer comments until catalog completion
  - attached followups and selected-task metadata must remain truthful
- Prefer persisted-read parity over scraper reinvention. Fix transport/runtime only after the account read/detail surfaces are reading the right stored data.

## Platform Contract

- `instagram`
  - Read comments: `GET /comments`
  - Refresh comments: `POST /comments/scrape`
  - Run progress: `GET /comments/runs/[runId]/progress`
  - Detail modal: existing catalog detail contract, plus normalized `discussion_items`
- `tiktok`
  - Read comments: `GET /comments` backed by `social.tiktok_comments`
  - Refresh comments: `POST /catalog/backfill` with `selected_tasks=["post_details","comments","media"]`
  - Run progress: reuse catalog run progress, not `/comments/runs/...`
  - Detail modal: persisted `tiktok_posts` + `tiktok_comments` + mirrored media status
- `twitter`
  - Read discussion: `GET /comments` backed by persisted replies and quotes in `social.twitter_tweets`
  - Refresh discussion: `POST /catalog/backfill` with `selected_tasks=["post_details","comments","media"]`
  - Run progress: reuse catalog run progress, not `/comments/runs/...`
  - Detail modal: persisted tweet, replies, quotes, mirrored media status
- `youtube`
  - Read comments: `GET /comments` backed by `social.youtube_comments`
  - Refresh comments: `POST /catalog/backfill` with `selected_tasks=["post_details","comments","media"]`
  - Run progress: reuse catalog run progress, not `/comments/runs/...`
  - Detail modal: persisted `youtube_videos` + `youtube_comments` + post media status only

## File Map

- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
  Purpose: add the cross-platform account discussion/detail capability layer, keep Instagram standalone comments special-cased, normalize discussion payloads, and route non-Instagram refreshes through catalog orchestration.
- Modify: `TRR-Backend/trr_backend/modal_dispatch.py`
  Purpose: keep the dispatch metadata and lane names honest while runtime capacity and local-vs-modal execution get widened.
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
  Purpose: lock the new account-profile comments/detail behavior, launch routing, Instagram regressions, and per-platform selected-task semantics.
- Modify: `TRR-Backend/tests/api/routers/test_socials_season_analytics.py`
  Purpose: keep the backend route contract stable for account comments/detail/catalog refresh.
- Modify: `TRR-Backend/tests/test_modal_dispatch.py`
  Purpose: keep stage-to-function routing and dispatch metadata stable while capacity changes land.
- Modify: `TRR-Backend/tests/test_modal_jobs.py`
  Purpose: verify the widened local/modal worker setup does not break job launch expectations.
- Modify: `TRR-Backend/tests/db/test_pg_pool.py`
  Purpose: preserve the social-profile read-pool lane while raising connection capacity.
- Modify: `profiles/default.env`
  Purpose: raise local social-profile DB capacity, widen remote social worker throughput, and enable a reasonable local fallback lane for debugging.
- Modify: `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts`
  Purpose: replace the Instagram-only comments gate with a platform capability matrix and shared TypeScript contracts.
- Modify: `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`
  Purpose: swap Instagram-only comments/detail composition for capability-driven generic social-profile components.
- Create: `TRR-APP/apps/web/src/components/admin/social-profile/SocialAccountCommentsPanel.tsx`
  Purpose: generic comments/discussion panel that works for Instagram, TikTok, Twitter, and YouTube.
- Create: `TRR-APP/apps/web/src/components/admin/social-profile/SocialAccountCommentsRefreshButton.tsx`
  Purpose: hide the route differences between Instagram standalone comments refresh and catalog-driven comments refresh for other platforms.
- Create: `TRR-APP/apps/web/src/components/admin/social-profile/SocialAccountDiscussionModal.tsx`
  Purpose: render normalized `discussion_items`, media status, and post stats for all four supported platforms.
- Modify: `TRR-APP/apps/web/src/app/admin/social/[platform]/[handle]/comments/page.tsx`
  Purpose: allow the admin comments route for every supported comments platform.
- Modify: `TRR-APP/apps/web/src/app/social/[platform]/[handle]/comments/page.tsx`
  Purpose: keep the public/admin mirrored comments-route gating in sync.
- Modify: `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`
  Purpose: lock comments-tab visibility, refresh-route selection, and normalized detail rendering.
- Modify: `TRR-APP/apps/web/tests/social-season-hint-routes.test.ts`
  Purpose: keep the route hints and supported-platform labels honest.
- Create: `docs/ai/local-status/cross-platform-social-scraper-reliability-2026-04-22.md`
  Purpose: record canary accounts, env changes, live validation evidence, and any third-party scraper/doc findings consulted during execution.

## Acceptance Targets

- `GET /comments` works for `instagram`, `tiktok`, `twitter`, and `youtube` account profiles.
- `GET /catalog/posts/[sourceId]/detail` works for those same four platforms and includes normalized `discussion_items`.
- Instagram keeps standalone `/comments/scrape` plus `/comments/runs/[runId]/progress`.
- TikTok, Twitter, and YouTube use catalog/backfill orchestration for comments refresh and do not attempt to call `/comments/scrape`.
- YouTube does not reintroduce any `youtube_comment_media_mirror` execution path.
- Local reliability improves enough to support repeated manual debugging without pool starvation:
  - `TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=8`
  - `WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=2`
  - `WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=50`
  - `WORKSPACE_SOCIAL_WORKER_ENABLED=1`
- Runtime proof exists for four local canaries:
  - `instagram/thetraitorsus`
  - `tiktok/bravotv`
  - `twitter/bravotv`
  - `youtube/bravo`
- Final outcome verification is executed through the `Computer Use` plugin against the live local admin UI, not only through direct HTTP requests or terminal logs.

## Wave 1: Backend And Runtime

### Task 1: Add Cross-Platform Account Discussion Read Support

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Modify: `TRR-Backend/tests/api/routers/test_socials_season_analytics.py`

- [ ] **Step 1: Write the failing repository and route regressions**

```python
def test_get_social_account_profile_comments_supports_tiktok_youtube_and_twitter(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(social_repo, "_assert_social_account_profile_exists", lambda *_args, **_kwargs: None)
    monkeypatch.setattr(social_repo, "_social_account_profile_summary_connection", lambda *_args, **_kwargs: nullcontext(object()))
    monkeypatch.setattr(social_repo, "_call_profile_summary_loader_with_conn", lambda *_args, **_kwargs: False)

    def _fake_fetch_all_with_cursor(_cur, sql: str, _params: list[object]) -> list[dict[str, object]]:
        normalized = " ".join(sql.lower().split())
        if "from social.tiktok_comments c" in normalized:
            return [{
                "id": "tt-comment-1",
                "comment_id": "7399984975553086214",
                "post_id": "tt-post-1",
                "post_source_id": "6862153058223197445",
                "post_url": "https://www.tiktok.com/@bravotv/video/6862153058223197445",
                "username": "rizqirxq",
                "display_name": "Riz",
                "text": "comment with media",
                "likes": 12,
                "is_reply": False,
                "discussion_type": "comment",
                "media_urls": ["https://source.example/comment-media.jpeg"],
                "hosted_media_urls": ["https://cdn.example/comment-media.jpeg"],
                "created_at": datetime(2025, 1, 2, tzinfo=UTC),
                "parent_comment_id": None,
                "total_count": 1,
            }]
        if "from social.youtube_comments c" in normalized:
            return [{
                "id": "yt-comment-1",
                "comment_id": "c1",
                "post_id": "yt-post-1",
                "post_source_id": "vid123",
                "post_url": "https://www.youtube.com/watch?v=vid123",
                "username": "viewer",
                "display_name": "Viewer",
                "text": "nice",
                "likes": 1,
                "is_reply": False,
                "discussion_type": "comment",
                "media_urls": [],
                "hosted_media_urls": [],
                "created_at": datetime(2025, 1, 1, tzinfo=UTC),
                "parent_comment_id": None,
                "total_count": 1,
            }]
        return [{
            "id": "tw-quote-1",
            "comment_id": "quote-1",
            "post_id": "tweet-db-1",
            "post_source_id": "123",
            "post_url": "https://x.com/bravotv/status/123",
            "username": "viewer2",
            "display_name": "Viewer Two",
            "text": "quoted text",
            "likes": 7,
            "is_reply": False,
            "discussion_type": "quote",
            "media_urls": ["https://img.test/quote.jpg"],
            "hosted_media_urls": ["https://cdn.example/quote.jpg"],
            "created_at": datetime(2025, 1, 1, 2, 0, tzinfo=UTC),
            "parent_comment_id": None,
            "total_count": 1,
        }]

    monkeypatch.setattr(social_repo.pg, "fetch_all_with_cursor", _fake_fetch_all_with_cursor)

    assert social_repo.get_social_account_profile_comments("tiktok", "bravotv")["items"][0]["username"] == "rizqirxq"
    assert social_repo.get_social_account_profile_comments("youtube", "bravo")["items"][0]["post_source_id"] == "vid123"
    assert social_repo.get_social_account_profile_comments("twitter", "bravotv")["items"][0]["discussion_type"] == "quote"


def test_account_comments_scrape_route_keeps_instagram_only_standalone_lane(client: TestClient) -> None:
    response = client.post(
        "/api/v1/social/profiles/twitter/bravotv/comments/scrape",
        json={"mode": "profile", "source_scope": "bravo", "refresh_policy": "all_saved_posts"},
    )
    assert response.status_code == 400
    assert "Instagram" in response.json()["detail"]
```

- [ ] **Step 2: Run the targeted failing slice**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "profile_comments_supports_tiktok_youtube_and_twitter"
.venv/bin/python -m pytest -q tests/api/routers/test_socials_season_analytics.py -k "comments_scrape_route_keeps_instagram_only_standalone_lane"
```

Expected: `FAIL` because `get_social_account_profile_comments(...)` still raises for every non-Instagram platform.

- [ ] **Step 3: Implement a backend capability layer plus normalized account discussion items**

```python
_SOCIAL_ACCOUNT_DISCUSSION_CAPABILITIES: dict[str, dict[str, Any]] = {
    "instagram": {"read_comments": True, "refresh_mode": "comments_scrape", "show_run_progress": True},
    "tiktok": {"read_comments": True, "refresh_mode": "catalog_backfill", "show_run_progress": True},
    "twitter": {"read_comments": True, "refresh_mode": "catalog_backfill", "show_run_progress": False},
    "youtube": {"read_comments": True, "refresh_mode": "catalog_backfill", "show_run_progress": False},
}


def social_account_discussion_capability(platform: str) -> dict[str, Any]:
    capability = _SOCIAL_ACCOUNT_DISCUSSION_CAPABILITIES.get(platform)
    if capability is None or not capability.get("read_comments"):
        raise ValueError("Account-profile comments are not supported for this platform.")
    return dict(capability)


def _normalize_discussion_row(row: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "id": str(row.get("id") or "").strip(),
        "comment_id": str(row.get("comment_id") or "").strip() or None,
        "post_id": str(row.get("post_id") or "").strip() or None,
        "post_source_id": str(row.get("post_source_id") or "").strip() or None,
        "post_url": str(row.get("post_url") or "").strip() or None,
        "username": str(row.get("username") or "").strip() or None,
        "display_name": str(row.get("display_name") or "").strip() or None,
        "text": str(row.get("text") or ""),
        "likes": _normalize_non_negative_int(row.get("likes")),
        "is_reply": bool(row.get("is_reply")),
        "discussion_type": str(row.get("discussion_type") or ("reply" if row.get("is_reply") else "comment")),
        "media_urls": _as_text_list(row.get("media_urls")),
        "hosted_media_urls": _as_text_list(row.get("hosted_media_urls")),
        "created_at": row.get("created_at"),
        "parent_comment_id": str(row.get("parent_comment_id") or "").strip() or None,
    }
```

Then branch in `get_social_account_profile_comments(...)` to platform-specific persisted SQL helpers instead of the current Instagram-only guard:

```python
if normalized_platform == "instagram":
    return _get_instagram_social_account_profile_comments(
        normalized_account,
        page=safe_page,
        page_size=safe_page_size,
        post_source_id=normalized_post_source_id,
    )
if normalized_platform == "tiktok":
    return _get_tiktok_social_account_profile_comments(
        normalized_account,
        page=safe_page,
        page_size=safe_page_size,
        post_source_id=normalized_post_source_id,
    )
if normalized_platform == "youtube":
    return _get_youtube_social_account_profile_comments(
        normalized_account,
        page=safe_page,
        page_size=safe_page_size,
        post_source_id=normalized_post_source_id,
    )
if normalized_platform == "twitter":
    return _get_twitter_social_account_profile_comments(
        normalized_account,
        page=safe_page,
        page_size=safe_page_size,
        post_source_id=normalized_post_source_id,
    )
raise ValueError("Account-profile comments are not supported for this platform.")
```

Rules inside those helpers:

- TikTok: read from `social.tiktok_comments` joined to `social.tiktok_posts`, keep `media_urls`, `hosted_media_urls`, and `aweme_id`-driven `post_source_id`.
- YouTube: read from `social.youtube_comments` joined to `social.youtube_videos`, keep normal comment rows and `video_id`-driven `post_source_id`.
- Twitter: read replies and quotes from `social.twitter_tweets`, emit `discussion_type="reply"` for replies and `discussion_type="quote"` for quotes, then sort the merged rows by `created_at desc`.
- Instagram: keep the current query shape, but pass all rows through `_normalize_discussion_row(...)` so the frontend gets one contract.

- [ ] **Step 4: Run the backend comments contract slice**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "profile_comments or get_post_comments_twitter or get_post_comments_youtube or get_post_comments_tiktok"
.venv/bin/python -m pytest -q tests/api/routers/test_socials_season_analytics.py -k "comments"
```

Expected: the new account-comments regressions pass, existing Instagram comments tests stay green, and the route tests still show Instagram-only standalone scrape behavior.

- [ ] **Step 5: Commit the account discussion read slice**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py TRR-Backend/tests/repositories/test_social_season_analytics.py TRR-Backend/tests/api/routers/test_socials_season_analytics.py
git commit -m "feat: add cross-platform account discussion reads"
```

### Task 2: Normalize Account Catalog Detail Across Instagram, TikTok, Twitter, And YouTube

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Modify: `TRR-Backend/tests/repositories/test_social_mirror_repairs.py`

- [ ] **Step 1: Write the failing detail regressions**

```python
def test_get_social_account_catalog_post_detail_supports_tiktok_youtube_and_twitter(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(social_repo, "_assert_social_account_profile_exists", lambda *_args, **_kwargs: None)
    monkeypatch.setattr(social_repo, "_fetch_shared_catalog_rows", lambda *_args, **_kwargs: [{"id": "row-1", "source_id": "123"}])
    monkeypatch.setattr(
        social_repo,
        "_get_twitter_account_catalog_post_detail",
        lambda *_args, **_kwargs: {
            "source_id": "123",
            "platform": "twitter",
            "hosted_media_urls": ["https://cdn.example/root.jpg"],
            "comments": [],
            "quotes": [{"id": "quote-1", "text": "quoted text", "created_at": "2025-01-01T02:00:00+00:00"}],
        },
    )
    monkeypatch.setattr(
        social_repo,
        "_get_tiktok_account_catalog_post_detail",
        lambda *_args, **_kwargs: {
            "source_id": "6862153058223197445",
            "platform": "tiktok",
            "hosted_media_urls": ["https://cdn.example/tiktok.mp4"],
            "comments": [{"id": "tt-comment-1", "text": "comment with media", "created_at": "2025-01-02T00:00:00+00:00"}],
            "quotes": [],
        },
    )
    monkeypatch.setattr(
        social_repo,
        "_get_youtube_account_catalog_post_detail",
        lambda *_args, **_kwargs: {
            "source_id": "vid123",
            "platform": "youtube",
            "hosted_media_urls": ["https://cdn.example/yt.mp4"],
            "comments": [{"id": "yt-comment-1", "text": "nice", "created_at": "2025-01-01T00:00:00+00:00"}],
            "quotes": [],
        },
    )

    twitter_detail = social_repo.get_social_account_catalog_post_detail("twitter", "bravotv", source_id="123")
    tiktok_detail = social_repo.get_social_account_catalog_post_detail("tiktok", "bravotv", source_id="6862153058223197445")
    youtube_detail = social_repo.get_social_account_catalog_post_detail("youtube", "bravo", source_id="vid123")

    assert twitter_detail["discussion_items"][0]["discussion_type"] == "quote"
    assert tiktok_detail["discussion_items"][0]["text"] == "comment with media"
    assert youtube_detail["hosted_media_urls"] == ["https://cdn.example/yt.mp4"]
```

- [ ] **Step 2: Run the targeted detail slice**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "catalog_post_detail_supports_tiktok_youtube_and_twitter"
```

Expected: `FAIL` because `get_social_account_catalog_post_detail(...)` still raises for non-Instagram platforms.

- [ ] **Step 3: Extract per-platform detail builders and attach normalized `discussion_items`**

```python
def _flatten_discussion_items(
    comments: Sequence[Mapping[str, Any]] | None,
    quotes: Sequence[Mapping[str, Any]] | None = None,
) -> list[dict[str, Any]]:
    items = [
        {**dict(comment), "discussion_type": str(comment.get("discussion_type") or ("reply" if comment.get("is_reply") else "comment"))}
        for comment in list(comments or [])
    ]
    items.extend({**dict(quote), "discussion_type": "quote", "is_reply": False} for quote in list(quotes or []))
    return sorted(items, key=lambda item: str(item.get("created_at") or ""), reverse=True)


_SOCIAL_ACCOUNT_CATALOG_DETAIL_BUILDERS = {
    "instagram": _get_instagram_account_catalog_post_detail,
    "tiktok": _get_tiktok_account_catalog_post_detail,
    "twitter": _get_twitter_account_catalog_post_detail,
    "youtube": _get_youtube_account_catalog_post_detail,
}


def get_social_account_catalog_post_detail(platform: str, account_handle: str, *, source_id: str, conn: Any | None = None) -> dict[str, Any]:
    normalized_platform = _normalize_social_account_profile_platform(platform)
    normalized_account = _normalize_social_account_profile_handle(account_handle)
    normalized_source_id = str(source_id or "").strip()
    if not normalized_source_id:
        raise ValueError("source_id is required.")
    _assert_social_account_profile_exists(normalized_platform, normalized_account)
    builder = _SOCIAL_ACCOUNT_CATALOG_DETAIL_BUILDERS.get(normalized_platform)
    if builder is None:
        raise ValueError("Account catalog detail is not supported for this platform.")
    payload = dict(builder(normalized_account, normalized_source_id, conn=conn))
    payload["discussion_items"] = _flatten_discussion_items(payload.get("comments"), payload.get("quotes"))
    return payload
```

Implementation rules:

- Instagram: keep the current materialized-row merge, metrics, hashtags, mentions, collaborators, tags, and media mirror status.
- TikTok: build the payload from `social.tiktok_posts` plus `social.tiktok_comments`, keep `hosted_media_urls`, `media_mirror_status`, and comment media fields where present.
- Twitter: build from persisted tweet + replies + quotes, keep `total_quotes_in_db`, and flatten quotes into `discussion_items` without losing the original `quotes` array.
- YouTube: build from persisted video + comments, keep post media status, and explicitly leave comment-media mirror empty.

- [ ] **Step 4: Run the detail and media-repair slices**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "catalog_post_detail or get_post_comments_tiktok or get_post_comments_youtube or get_post_comments_twitter"
.venv/bin/python -m pytest -q tests/repositories/test_social_mirror_repairs.py -k "youtube_comment_media_mirror_obsolete or get_post_comments"
```

Expected: the new detail regressions pass, and the obsolete YouTube sentinel test still passes.

- [ ] **Step 5: Commit the detail normalization slice**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py TRR-Backend/tests/repositories/test_social_season_analytics.py TRR-Backend/tests/repositories/test_social_mirror_repairs.py
git commit -m "feat: normalize social account catalog detail across platforms"
```

### Task 3: Harden Launch Routing, Capacity, And Local Debug Throughput

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/trr_backend/modal_dispatch.py`
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Modify: `TRR-Backend/tests/test_modal_dispatch.py`
- Modify: `TRR-Backend/tests/test_modal_jobs.py`
- Modify: `TRR-Backend/tests/db/test_pg_pool.py`
- Modify: `profiles/default.env`

- [ ] **Step 1: Add failing launch-routing and capacity regressions**

```python
def test_launch_social_account_catalog_backfill_non_instagram_comments_force_catalog_route(monkeypatch: pytest.MonkeyPatch) -> None:
    captured: dict[str, object] = {}

    def _fake_start_catalog(*_args, **kwargs):
        captured.update(kwargs)
        return {"run_id": "run-1", "status": "queued"}

    monkeypatch.setattr(social_repo, "start_social_account_catalog_backfill", _fake_start_catalog)
    monkeypatch.setattr(social_repo, "_assert_social_account_profile_exists", lambda *_args, **_kwargs: None)

    payload = social_repo.launch_social_account_catalog_backfill(
        "youtube",
        "bravo",
        selected_tasks=["comments", "media"],
        allow_local_dev_inline_bypass=True,
    )

    assert payload["comments_run_id"] is None
    assert captured["details_refresh_skip_detail_fetch"] is False
    assert captured["details_refresh_skip_media_followups"] is False


def test_social_profile_pool_env_uses_raised_local_capacity(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("TRR_SOCIAL_PROFILE_DB_POOL_MINCONN", "1")
    monkeypatch.setenv("TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN", "8")
    sizing = pg._resolve_pool_sizing(minconn_env_name="TRR_SOCIAL_PROFILE_DB_POOL_MINCONN", maxconn_env_name="TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN")
    assert sizing["maxconn"] == 8
```

- [ ] **Step 2: Run the failing launch/capacity slice**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "launch_social_account_catalog_backfill_non_instagram_comments_force_catalog_route"
.venv/bin/python -m pytest -q tests/db/test_pg_pool.py -k "social_profile_pool_env_uses_raised_local_capacity"
```

Expected: `FAIL` because the current non-Instagram launch path does not normalize comments/media tasks and the pool test still reflects the smaller local max.

- [ ] **Step 3: Normalize non-Instagram comments refresh through catalog launch and widen local defaults**

```python
def _normalize_cross_platform_selected_tasks(platform: str, selected_tasks: Sequence[Any] | None) -> list[str]:
    tasks = _normalize_social_account_catalog_backfill_selected_tasks(selected_tasks)
    if platform in {"tiktok", "twitter", "youtube"} and "comments" in tasks and "post_details" not in tasks:
        tasks = ["post_details", *tasks]
    return list(dict.fromkeys(tasks))
```

Use that helper inside `launch_social_account_catalog_backfill(...)` before any platform branching, and keep these rules:

- TikTok, Twitter, and YouTube never call `start_social_account_comments_scrape(...)`.
- If `comments` is selected for any of those platforms, force `post_details` on so detail rows exist before the comments read surface is refreshed.
- Only Instagram is allowed to attach comment-media followups to the standalone comments lane.

Update local defaults in `profiles/default.env`:

```dotenv
WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=2
WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=50
WORKSPACE_SOCIAL_WORKER_ENABLED=1
WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR=1
WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR=1
TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=8
SOCIAL_CRAWLEE_MAX_CONCURRENCY_TIKTOK=6
SOCIAL_CRAWLEE_MAX_CONCURRENCY_TWITTER=6
SOCIAL_CRAWLEE_MAX_CONCURRENCY_YOUTUBE=4
```

Keep `modal_dispatch.py` metadata truthful when work still routes to the stage-specific Modal functions:

```python
def modal_social_job_function_names() -> list[str]:
    return list(dict.fromkeys([
        modal_social_job_function_name(),
        modal_social_posts_job_function_name(),
        modal_social_media_job_function_name(),
        modal_social_comments_job_function_name(),
    ]))
```

- [ ] **Step 4: Run the routing, modal, and pool slices**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "launch_social_account_catalog_backfill or start_social_account_comments_scrape"
.venv/bin/python -m pytest -q tests/test_modal_dispatch.py tests/test_modal_jobs.py
.venv/bin/python -m pytest -q tests/db/test_pg_pool.py -k "social_profile"
```

Expected: non-Instagram launches stay catalog-driven, Instagram standalone comments still work, and the social-profile pool tests pass with the raised limit.

- [ ] **Step 5: Commit the runtime hardening slice**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py TRR-Backend/trr_backend/modal_dispatch.py TRR-Backend/tests/repositories/test_social_season_analytics.py TRR-Backend/tests/test_modal_dispatch.py TRR-Backend/tests/test_modal_jobs.py TRR-Backend/tests/db/test_pg_pool.py profiles/default.env
git commit -m "perf: harden social scraper launch routing and local capacity"
```

## Wave 2: Admin And Account-Profile Parity

### Task 4: Replace The Instagram-Only Comments Gate With A Shared Capability Matrix

**Files:**
- Modify: `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts`
- Modify: `TRR-APP/apps/web/src/app/admin/social/[platform]/[handle]/comments/page.tsx`
- Modify: `TRR-APP/apps/web/src/app/social/[platform]/[handle]/comments/page.tsx`
- Modify: `TRR-APP/apps/web/tests/social-season-hint-routes.test.ts`

- [ ] **Step 1: Write the failing capability and route-gating tests**

```tsx
it("shows the comments tab for instagram, tiktok, twitter, and youtube", () => {
  expect(SOCIAL_ACCOUNT_COMMENT_CAPABILITIES.instagram.readComments).toBe(true);
  expect(SOCIAL_ACCOUNT_COMMENT_CAPABILITIES.tiktok.readComments).toBe(true);
  expect(SOCIAL_ACCOUNT_COMMENT_CAPABILITIES.twitter.readComments).toBe(true);
  expect(SOCIAL_ACCOUNT_COMMENT_CAPABILITIES.youtube.readComments).toBe(true);
});

it("keeps facebook and threads comments disabled", () => {
  expect(SOCIAL_ACCOUNT_COMMENT_CAPABILITIES.facebook.readComments).toBe(false);
  expect(SOCIAL_ACCOUNT_COMMENT_CAPABILITIES.threads.readComments).toBe(false);
});
```

- [ ] **Step 2: Run the failing frontend capability slice**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web exec vitest run tests/social-season-hint-routes.test.ts tests/social-account-profile-page.runtime.test.tsx
```

Expected: `FAIL` because the app still exports `SOCIAL_ACCOUNT_COMMENTS_ENABLED_PLATFORMS = ["instagram"]`.

- [ ] **Step 3: Add a shared comments capability matrix and use it in both page gates**

```ts
export const SOCIAL_ACCOUNT_COMMENT_CAPABILITIES = {
  instagram: { readComments: true, refreshMode: "comments_scrape", showRunProgress: true },
  tiktok: { readComments: true, refreshMode: "catalog_backfill", showRunProgress: true },
  twitter: { readComments: true, refreshMode: "catalog_backfill", showRunProgress: false },
  youtube: { readComments: true, refreshMode: "catalog_backfill", showRunProgress: false },
  facebook: { readComments: false, refreshMode: "unsupported", showRunProgress: false },
  threads: { readComments: false, refreshMode: "unsupported", showRunProgress: false },
} as const;

export const SOCIAL_ACCOUNT_COMMENTS_ENABLED_PLATFORMS: ReadonlyArray<SocialPlatformSlug> =
  (Object.entries(SOCIAL_ACCOUNT_COMMENT_CAPABILITIES)
    .filter(([, capability]) => capability.readComments)
    .map(([platform]) => platform) as SocialPlatformSlug[]);
```

Use `SOCIAL_ACCOUNT_COMMENTS_ENABLED_PLATFORMS` in both comments pages so admin/public route gating stays in sync.

- [ ] **Step 4: Run the capability and route-hint slice**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web exec vitest run tests/social-season-hint-routes.test.ts tests/social-account-profile-page.runtime.test.tsx
```

Expected: comments-route gating now passes for Instagram, TikTok, Twitter, and YouTube.

- [ ] **Step 5: Commit the capability-matrix slice**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-APP/apps/web/src/lib/admin/social-account-profile.ts TRR-APP/apps/web/src/app/admin/social/[platform]/[handle]/comments/page.tsx TRR-APP/apps/web/src/app/social/[platform]/[handle]/comments/page.tsx TRR-APP/apps/web/tests/social-season-hint-routes.test.ts
git commit -m "feat: add shared social account comments capability matrix"
```

### Task 5: Move The Comments And Detail UI To Generic Social-Profile Components

**Files:**
- Modify: `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`
- Create: `TRR-APP/apps/web/src/components/admin/social-profile/SocialAccountCommentsPanel.tsx`
- Create: `TRR-APP/apps/web/src/components/admin/social-profile/SocialAccountCommentsRefreshButton.tsx`
- Create: `TRR-APP/apps/web/src/components/admin/social-profile/SocialAccountDiscussionModal.tsx`
- Modify: `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`

- [ ] **Step 1: Write the failing runtime tests for refresh-route selection and normalized detail rendering**

```tsx
it("uses catalog backfill for tiktok, twitter, and youtube comment refresh", async () => {
  render(<SocialAccountProfilePage platform="twitter" handle="bravotv" activeTab="comments" />);
  const button = await screen.findByRole("button", { name: "Sync Comments" });
  fireEvent.click(button);
  await waitFor(() => {
    expect(
      mocks.fetchAdminWithAuth.mock.calls.some(
        ([input, init]) =>
          String(input).includes("/api/admin/trr-api/social/profiles/twitter/bravotv/catalog/backfill") &&
          String(init?.body).includes("\"selected_tasks\":[\"post_details\",\"comments\",\"media\"]"),
      ),
    ).toBe(true);
  });
});

it("renders normalized discussion items in the detail modal", async () => {
  render(<SocialAccountProfilePage platform="twitter" handle="bravotv" activeTab="comments" />);
  const link = await screen.findByRole("link", { name: "123" });
  fireEvent.click(link);
  const dialog = await screen.findByRole("dialog", { name: "Saved Discussion for 123" });
  expect(within(dialog).getByText("Quote")).toBeInTheDocument();
  expect(within(dialog).getByText("quoted text")).toBeInTheDocument();
});
```

- [ ] **Step 2: Run the failing runtime slice**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web exec vitest run tests/social-account-profile-page.runtime.test.tsx
```

Expected: `FAIL` because `SocialAccountProfilePage.tsx` still imports `InstagramCommentsPanel` and `PostScrapeCommentsButton`.

- [ ] **Step 3: Create generic components and route refreshes by capability**

```tsx
// SocialAccountCommentsRefreshButton.tsx
const capability = SOCIAL_ACCOUNT_COMMENT_CAPABILITIES[platform];

if (capability.refreshMode === "comments_scrape") {
  await fetchAdminWithAuth(`/api/admin/trr-api/social/profiles/${platform}/${handle}/comments/scrape`, {
    method: "POST",
    body: JSON.stringify({ mode: "profile", source_scope: "bravo", refresh_policy: "all_saved_posts" }),
  });
} else {
  await fetchAdminWithAuth(`/api/admin/trr-api/social/profiles/${platform}/${handle}/catalog/backfill`, {
    method: "POST",
    body: JSON.stringify({ source_scope: "bravo", selected_tasks: ["post_details", "comments", "media"] }),
  });
}
```

```tsx
// SocialAccountDiscussionModal.tsx
{detail.discussion_items.map((item) => (
  <li key={item.id} className="border-b border-zinc-200 py-3">
    <div className="flex items-center justify-between gap-3 text-xs uppercase tracking-[0.18em] text-zinc-500">
      <span>{item.discussion_type === "quote" ? "Quote" : item.is_reply ? "Reply" : "Comment"}</span>
      <span>{formatLocalDateTime(item.created_at)}</span>
    </div>
    <div className="mt-2 text-sm font-medium text-zinc-900">{item.display_name || item.username || "Unknown user"}</div>
    <p className="mt-1 text-sm text-zinc-700">{item.text}</p>
  </li>
))}
```

Update `SocialAccountProfilePage.tsx` to import the new generic components instead of the Instagram-specific ones, and only poll `/comments/runs/[runId]/progress` when `showRunProgress` is true.

- [ ] **Step 4: Run the runtime slice plus a production build**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web exec vitest run tests/social-account-profile-page.runtime.test.tsx
pnpm -C apps/web run lint
pnpm -C apps/web exec next build --webpack
```

Expected: the runtime tests pass, lint stays clean, and the Next build succeeds without route-type regressions.

- [ ] **Step 5: Commit the generic social-profile UI slice**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx TRR-APP/apps/web/src/components/admin/social-profile/SocialAccountCommentsPanel.tsx TRR-APP/apps/web/src/components/admin/social-profile/SocialAccountCommentsRefreshButton.tsx TRR-APP/apps/web/src/components/admin/social-profile/SocialAccountDiscussionModal.tsx TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx
git commit -m "feat: generalize social account comments and detail ui"
```

### Task 6: Record Canary Evidence And Close With Cross-Platform Live Validation

**Files:**
- Create: `docs/ai/local-status/cross-platform-social-scraper-reliability-2026-04-22.md`

- [ ] **Step 1: Create the validation note before live runs**

```md
# Cross-Platform Social Scraper Reliability Validation

## Env changes
- TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=8
- WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=2
- WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=50
- WORKSPACE_SOCIAL_WORKER_ENABLED=1
- WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR=1
- WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR=1
- SOCIAL_CRAWLEE_MAX_CONCURRENCY_TIKTOK=6
- SOCIAL_CRAWLEE_MAX_CONCURRENCY_TWITTER=6
- SOCIAL_CRAWLEE_MAX_CONCURRENCY_YOUTUBE=4

## Canary accounts
- instagram/thetraitorsus
- tiktok/bravotv
- twitter/bravotv
- youtube/bravo

## Evidence to capture
- route used for refresh
- run id
- final run status
- one saved discussion row visible in the comments tab
- one catalog detail modal with mirrored media evidence
- one `Computer Use` screenshot or interaction note per platform proving the UI state after refresh
- any third-party scraper/doc comparison performed
```

- [ ] **Step 2: Start the local stack with the new env**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
make dev
```

Expected: backend on `http://127.0.0.1:8000`, app on `http://127.0.0.1:3000`, and the updated `profiles/default.env` is active in the local workspace.

- [ ] **Step 3: Execute the four local canaries with Computer Use and capture route/runtime truth**

Use the `Computer Use` plugin to open these pages and perform one bounded comments refresh plus one detail-modal verification for each:

```text
http://127.0.0.1:3000/admin/social/instagram/thetraitorsus/comments
http://127.0.0.1:3000/admin/social/tiktok/bravotv/comments
http://127.0.0.1:3000/admin/social/twitter/bravotv/comments
http://127.0.0.1:3000/admin/social/youtube/bravo/comments
```

Per page, record:

- the request path used by the refresh button
- the returned run id
- whether the page showed saved discussion after the run
- whether the detail modal showed `discussion_items` and mirrored media URLs
- for Instagram only, whether `/comments/runs/[runId]/progress` completed successfully
- whether the visible post-refresh UI matched the expected platform contract without manual DOM patching or hard refresh rescue steps

- [ ] **Step 4: Run the focused backend and app validation suites once the live canaries are green**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "social_account_profile_comments or social_account_catalog_post_detail or launch_social_account_catalog_backfill or start_social_account_comments_scrape"
.venv/bin/python -m pytest -q tests/api/routers/test_socials_season_analytics.py
.venv/bin/python -m pytest -q tests/test_modal_dispatch.py tests/test_modal_jobs.py tests/db/test_pg_pool.py

cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web exec vitest run tests/social-account-profile-page.runtime.test.tsx tests/social-season-hint-routes.test.ts
pnpm -C apps/web run lint
pnpm -C apps/web exec next build --webpack
```

Expected: all targeted suites pass after the live canaries have already proven real account behavior.

- [ ] **Step 5: Commit the validation note and close the plan**

```bash
cd /Users/thomashulihan/Projects/TRR
git add docs/ai/local-status/cross-platform-social-scraper-reliability-2026-04-22.md
git commit -m "docs: record cross-platform social scraper reliability evidence"
```
