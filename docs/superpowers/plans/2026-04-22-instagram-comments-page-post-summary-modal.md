# Instagram Comments Page Post Summary Modal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Change the Instagram Comments page so it loads one row per post with post-level metadata and opens a popup comment feed when the post link is clicked.

**Architecture:** Reuse the existing social-account post dataset for the table instead of inventing a second post-summary pipeline. Extend the Instagram post payload with a `saved_comments` count and let the comments page fetch `/posts?comments_only=true` for the summary table, then keep the existing comments route as the drill-down feed by adding an optional `post_source_id` filter for the popup. On the app side, keep the current coverage cards and sync button, replace the raw comment table with a post table, and move the per-comment rows into a dedicated modal component.

**Tech Stack:** FastAPI, Postgres/Supabase, Next.js App Router, React, pytest, Vitest

---

## Summary

The current comments tab already has the right shell and admin auth, but it renders raw comment rows:

- `TRR-APP/apps/web/src/components/admin/instagram/InstagramCommentsPanel.tsx` currently fetches `/comments?page=...` and renders `Post | User | Comment | Likes | Created`.
- `TRR-Backend/api/routers/socials.py` proxies that request to `get_social_account_profile_comments(...)`.
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py` pages `social.instagram_comments` rows, not post summaries.

The requested behavior is:

1. Load one row per post on the comments page.
2. Show post-level fields on that row: post link, created date/time, caption, saved comment count, likes.
3. Open a popup with the saved comment feed when the post hyperlink is clicked.

For this plan, the row columns are treated as `Post | Created | Caption | Comments Saved | Likes`. The old per-comment `User | Comment | Likes | Created` fields move into the popup feed, which matches the explicit field list in the request.

## File Structure

### Backend

| Path | Responsibility |
|---|---|
| `TRR-Backend/trr_backend/repositories/social_season_analytics.py` | Extend Instagram post rows with `saved_comments`, add `comments_only` filtering to the profile posts dataset, and add optional `post_source_id` filtering to the profile comments feed |
| `TRR-Backend/api/routers/socials.py` | Accept new query params on the posts/comments profile routes and keep cache keys correct |
| `TRR-Backend/tests/repositories/test_social_season_analytics.py` | Repository regressions for post-summary counts and popup-feed filtering |
| `TRR-Backend/tests/api/routers/test_socials_season_analytics.py` | Route-level regressions for query-param passthrough and filtered reads |

### App

| Path | Responsibility |
|---|---|
| `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts` | Shared TypeScript types for `saved_comments` on post rows |
| `TRR-APP/apps/web/src/components/admin/instagram/InstagramCommentsPanel.tsx` | Comments tab table, post-summary fetch, popup state, and filtered comment-feed fetch |
| `TRR-APP/apps/web/src/components/admin/instagram/InstagramCommentsPostModal.tsx` | Dedicated popup component for the selected post’s saved comment feed |
| `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx` | Runtime coverage for the new table shape and popup feed |

## Task 1: Add The Backend Contract For Post-Level Comments Rows

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/api/routers/socials.py`
- Test: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Test: `TRR-Backend/tests/api/routers/test_socials_season_analytics.py`

- [ ] **Step 1: Write the failing repository tests for `saved_comments`, `comments_only`, and `post_source_id` filtering**

```python
def test_get_social_account_profile_posts_instagram_supports_comments_only_and_saved_comment_counts(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(social_repo, "_assert_social_account_profile_exists", lambda *_args, **_kwargs: [{}])
    monkeypatch.setattr(
        social_repo,
        "_instagram_social_account_profile_dataset_rows",
        lambda account_handle, *, search=None, limit=None, posted_since=None, collaborator_posted_since=None, conn=None, comments_only=False: [
            {
                "id": "post-1",
                "source_id": "DVfQnTcjsCA",
                "shortcode": "DVfQnTcjsCA",
                "posted_at": datetime(2026, 4, 22, 15, 0, tzinfo=UTC),
                "caption": "The traitors caption",
                "likes": 187,
                "comments_count": 42,
                "saved_comments": 11,
                "_profile_match_mode": "owner",
                "_profile_source_surface": "materialized",
            }
        ],
    )

    payload = social_repo.get_social_account_profile_posts(
        "instagram",
        "thetraitorsus",
        page=1,
        page_size=25,
        comments_only=True,
    )

    assert payload["pagination"] == {"page": 1, "page_size": 25, "total": 1, "total_pages": 1}
    assert payload["items"][0]["source_id"] == "DVfQnTcjsCA"
    assert payload["items"][0]["saved_comments"] == 11
    assert payload["items"][0]["metrics"]["likes"] == 187


def test_get_social_account_profile_comments_filters_to_one_post_source_id(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    summary_conn = object()
    social_repo._relation_columns_cache.clear()
    social_repo._column_exists_cache.clear()

    monkeypatch.setattr(social_repo, "_social_account_profile_summary_connection", lambda _label: nullcontext(summary_conn))
    monkeypatch.setattr(social_repo, "_assert_social_account_profile_exists", lambda *_args, **_kwargs: [])
    monkeypatch.setattr(
        social_repo.pg,
        "db_cursor",
        lambda conn=None, label=None, **_kwargs: nullcontext(object()),
    )

    def _fake_fetch_one_with_cursor(_cur: Any, sql: str, params: list[Any]) -> dict[str, Any]:
        if "select count(*)::int as total" in sql:
            assert params == ["thetraitorsus", "DVfQnTcjsCA"]
            return {"total": 2}
        raise AssertionError(f"Unexpected SQL: {sql}")

    def _fake_fetch_all_with_cursor(_cur: Any, sql: str, params: list[Any]) -> list[dict[str, Any]]:
        if "from information_schema.columns" in sql:
            return [{"column_name": "is_missing"}]
        if "from social.instagram_comments c" in sql:
            assert params == ["thetraitorsus", "DVfQnTcjsCA", 100, 0]
            return [
                {
                    "id": "comment-1",
                    "comment_id": "17800000000000001",
                    "post_id": "post-1",
                    "post_source_id": "DVfQnTcjsCA",
                    "post_url": "https://www.instagram.com/p/DVfQnTcjsCA/",
                    "username": "user-one",
                    "text": "First saved comment",
                    "likes": 7,
                    "is_reply": False,
                    "created_at": datetime(2026, 4, 22, 15, 30, tzinfo=UTC),
                    "parent_comment_id": None,
                }
            ]
        raise AssertionError(f"Unexpected SQL: {sql}")

    monkeypatch.setattr(social_repo.pg, "fetch_one_with_cursor", _fake_fetch_one_with_cursor)
    monkeypatch.setattr(social_repo.pg, "fetch_all_with_cursor", _fake_fetch_all_with_cursor)

    payload = social_repo.get_social_account_profile_comments(
        "instagram",
        "thetraitorsus",
        page=1,
        page_size=100,
        post_source_id="DVfQnTcjsCA",
    )

    assert payload["pagination"] == {"page": 1, "page_size": 100, "total": 2, "total_pages": 1}
    assert payload["items"][0]["post_source_id"] == "DVfQnTcjsCA"
```

- [ ] **Step 2: Write the failing route tests for the new query params**

```python
def test_get_social_account_profile_posts_route_passes_comments_only_flag(
    client: TestClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret-32-bytes-minimum-abcdef")
    token = _make_admin_token("test-secret-32-bytes-minimum-abcdef")

    with patch(
        "trr_backend.repositories.social_season_analytics.get_social_account_profile_posts",
        return_value={
            "items": [{"id": "post-1", "source_id": "DVfQnTcjsCA", "saved_comments": 11}],
            "pagination": {"page": 1, "page_size": 25, "total": 1, "total_pages": 1},
        },
    ) as posts_mock:
        response = client.get(
            "/api/v1/admin/socials/profiles/instagram/thetraitorsus/posts?page=1&page_size=25&comments_only=true",
            headers={"Authorization": f"Bearer {token}"},
        )

    assert response.status_code == 200
    posts_mock.assert_called_once_with(
        platform="instagram",
        account_handle="thetraitorsus",
        page=1,
        page_size=25,
        search=None,
        comments_only=True,
    )


def test_get_social_account_profile_comments_route_passes_post_source_id(
    client: TestClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret-32-bytes-minimum-abcdef")
    token = _make_admin_token("test-secret-32-bytes-minimum-abcdef")

    with patch(
        "trr_backend.repositories.social_season_analytics.get_social_account_profile_comments",
        return_value={
            "items": [{"id": "comment-1", "post_source_id": "DVfQnTcjsCA"}],
            "pagination": {"page": 1, "page_size": 100, "total": 1, "total_pages": 1},
        },
    ) as comments_mock:
        response = client.get(
            "/api/v1/admin/socials/profiles/instagram/thetraitorsus/comments?page=1&page_size=100&post_source_id=DVfQnTcjsCA",
            headers={"Authorization": f"Bearer {token}"},
        )

    assert response.status_code == 200
    comments_mock.assert_called_once_with(
        platform="instagram",
        account_handle="thetraitorsus",
        page=1,
        page_size=100,
        post_source_id="DVfQnTcjsCA",
    )
```

- [ ] **Step 3: Implement the repository contract**

```python
def _instagram_social_account_profile_dataset_rows(
    account_handle: str,
    *,
    search: str | None = None,
    limit: int | None = None,
    posted_since: datetime | None = None,
    collaborator_posted_since: datetime | None = None,
    conn: Any | None = None,
    comments_only: bool = False,
) -> list[dict[str, Any]]:
    normalized_account = _normalize_social_account_profile_handle(account_handle)
    fetch_limit = max(1, int(limit)) if limit is not None else None
    materialized_rows = _fetch_social_account_profile_rows(
        "instagram",
        normalized_account,
        limit=fetch_limit,
        posted_since=posted_since,
        conn=conn,
    )
    owner_catalog_rows = _fetch_instagram_owner_catalog_rows(
        normalized_account,
        limit=fetch_limit,
        posted_since=posted_since,
        conn=conn,
    )

    dataset_rows = _dedupe_social_account_profile_dataset_rows(
        [
            *_annotate_instagram_social_account_profile_dataset_rows(materialized_rows, source_surface="materialized", match_mode="owner", priority=3),
            *_annotate_instagram_social_account_profile_dataset_rows(owner_catalog_rows, source_surface="catalog", match_mode="owner", priority=2),
        ]
    )

    post_ids = [str(row.get("id") or "").strip() for row in dataset_rows if str(row.get("id") or "").strip()]
    saved_comment_counts = _count_stored_comments(post_ids, "instagram", conn=conn) if post_ids else {}

    enriched_rows: list[dict[str, Any]] = []
    for row in dataset_rows:
        next_row = dict(row)
        row_id = str(next_row.get("id") or "").strip()
        next_row["saved_comments"] = saved_comment_counts.get(row_id, 0)
        if comments_only:
            reported_comments = _normalize_non_negative_int(next_row.get("comments_count"))
            if max(reported_comments, _normalize_non_negative_int(next_row.get("saved_comments"))) <= 0:
                continue
        enriched_rows.append(next_row)

    known_handle_identity_index = _build_social_account_profile_known_handle_identity_index("instagram", enriched_rows)
    filtered_rows = [
        row
        for row in enriched_rows
        if _social_account_profile_row_matches_search(
            "instagram",
            row,
            account_handle=normalized_account,
            search=search,
            known_handle_identity_index=known_handle_identity_index,
        )
    ]
    filtered_rows.sort(
        key=lambda row: (_social_account_profile_row_sort_value(row.get("posted_at")), str(row.get("id") or "")),
        reverse=True,
    )
    return filtered_rows[:fetch_limit] if fetch_limit is not None else filtered_rows


def _social_account_profile_post_item(
    platform: str,
    row: Mapping[str, Any],
    *,
    account_handle: str,
    known_handle_identity_index: Mapping[str, set[str]] | None = None,
) -> dict[str, Any]:
    return {
        "id": str(row.get("id") or ""),
        "source_id": str(row.get("source_id") or ""),
        "platform": _normalize_social_account_profile_platform(platform),
        "account_handle": account_handle,
        "title": _social_account_profile_title_text(platform, row),
        "content": _social_account_profile_content_text(platform, row),
        "excerpt": (_social_account_profile_content_text(platform, row)[:280].strip() or _social_account_profile_title_text(platform, row)),
        "url": _social_account_profile_post_url(platform, row, account_handle=account_handle),
        "profile_url": _platform_profile_url_for_handle(platform, account_handle),
        "posted_at": row.get("posted_at"),
        "show_id": str(row.get("show_id") or "") or None,
        "show_name": row.get("show_name"),
        "show_slug": row.get("show_slug"),
        "season_id": str(row.get("season_id") or "") or None,
        "season_number": _normalize_non_negative_int(row.get("season_number")) or None,
        "hashtags": _social_account_profile_hashtags_for_row(platform, row),
        "mentions": _social_account_profile_mentions_for_row(platform, row, known_handle_identity_index=known_handle_identity_index),
        "collaborators": _social_account_profile_collaborators_for_row(row),
        "tags": _social_account_profile_tags_for_row(platform, row),
        "saved_comments": _normalize_non_negative_int(row.get("saved_comments")),
        "metrics": _social_account_profile_metric_payload(platform, row),
    }


def get_social_account_profile_posts(
    platform: str,
    account_handle: str,
    *,
    page: int = 1,
    page_size: int = _SOCIAL_ACCOUNT_PROFILE_DEFAULT_PAGE_SIZE,
    search: str | None = None,
    comments_only: bool = False,
) -> dict[str, Any]:
    if normalized_platform == "instagram":
        matching_rows = _instagram_social_account_profile_dataset_rows(
            normalized_account,
            search=normalized_search,
            comments_only=comments_only,
        )
        ...


def get_social_account_profile_comments(
    platform: str,
    account_handle: str,
    *,
    page: int = 1,
    page_size: int = _SOCIAL_ACCOUNT_PROFILE_DEFAULT_PAGE_SIZE,
    post_source_id: str | None = None,
) -> dict[str, Any]:
    normalized_post_source_id = str(post_source_id or "").strip() or None
    post_filter_sql = "and p.shortcode = %s" if normalized_post_source_id else ""
    post_filter_params = [normalized_post_source_id] if normalized_post_source_id else []
    ...
    total_row = pg.fetch_one_with_cursor(
        cur,
        f\"\"\"
        select count(*)::int as total
        from social.instagram_comments c
        join social.instagram_posts p on p.id = c.post_id
        where {owner_match_clause}
          {active_filter}
          {post_filter_sql}
        \"\"\",
        [normalized_account, *post_filter_params],
    ) or {}
    ...
    rows = pg.fetch_all_with_cursor(
        cur,
        f\"\"\"
        select
          c.id::text as id,
          c.comment_id,
          c.post_id::text as post_id,
          p.shortcode as post_source_id,
          ...
        from social.instagram_comments c
        join social.instagram_posts p on p.id = c.post_id
        where {owner_match_clause}
          {active_filter}
          {post_filter_sql}
        order by c.created_at desc nulls last, c.id desc
        limit %s
        offset %s
        \"\"\",
        [normalized_account, *post_filter_params, safe_page_size, (safe_page - 1) * safe_page_size],
    )
```

- [ ] **Step 4: Implement the router query params and cache-key inputs**

```python
@router.get("/profiles/{platform}/{account_handle}/posts")
def get_social_account_profile_posts_route(
    platform: str,
    account_handle: str,
    page: int = Query(default=1, ge=1, le=10_000),
    page_size: int = Query(default=25, ge=1, le=100),
    search: str | None = Query(default=None),
    comments_only: bool = Query(default=False),
    _: InternalAdminUser = None,
) -> dict[str, Any]:
    cache_key = _account_profile_cache_key(
        surface="posts",
        platform=platform,
        account_handle=account_handle,
        page=page,
        page_size=page_size,
        search=search,
        comments_only=comments_only,
    )
    payload = get_social_account_profile_posts(
        platform=platform,
        account_handle=account_handle,
        page=page,
        page_size=page_size,
        search=search,
        comments_only=comments_only,
    )
    return payload


@router.get("/profiles/{platform}/{account_handle}/comments")
def get_social_account_profile_comments_route(
    platform: str,
    account_handle: str,
    page: int = Query(default=1, ge=1, le=10_000),
    page_size: int = Query(default=25, ge=1, le=100),
    post_source_id: str | None = Query(default=None),
    _: InternalAdminUser = None,
) -> dict[str, Any]:
    cache_key = _account_profile_cache_key(
        surface="comments",
        platform=platform,
        account_handle=account_handle,
        page=page,
        page_size=page_size,
        post_source_id=post_source_id,
    )
    payload = get_social_account_profile_comments(
        platform=platform,
        account_handle=account_handle,
        page=page,
        page_size=page_size,
        post_source_id=post_source_id,
    )
    return payload
```

- [ ] **Step 5: Run the targeted backend tests**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q tests/repositories/test_social_season_analytics.py -k "social_account_profile_posts_instagram_supports_comments_only or social_account_profile_comments_filters_to_one_post_source_id"
pytest -q tests/api/routers/test_socials_season_analytics.py -k "passes_comments_only_flag or passes_post_source_id"
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR
git add \
  TRR-Backend/trr_backend/repositories/social_season_analytics.py \
  TRR-Backend/api/routers/socials.py \
  TRR-Backend/tests/repositories/test_social_season_analytics.py \
  TRR-Backend/tests/api/routers/test_socials_season_analytics.py
git commit -m "feat(comments): add post-summary contract for social account comments page"
```

## Task 2: Refactor The App Comments Tab To Show Post Rows And A Popup Feed

**Files:**
- Modify: `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts`
- Modify: `TRR-APP/apps/web/src/components/admin/instagram/InstagramCommentsPanel.tsx`
- Create: `TRR-APP/apps/web/src/components/admin/instagram/InstagramCommentsPostModal.tsx`
- Test: `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`

- [ ] **Step 1: Write the failing runtime tests for the new table and popup behavior**

```tsx
it("renders one comments-page row per post with saved comment counts", async () => {
  mocks.fetchAdminWithAuth.mockImplementation(async (input: RequestInfo | URL) => {
    const url = String(input);
    if (url.includes("/summary")) {
      return jsonResponse(baseSummary);
    }
    if (url.includes("/posts?page=1&page_size=25&comments_only=true")) {
      return jsonResponse({
        items: [
          {
            id: "post-1",
            source_id: "DVfQnTcjsCA",
            platform: "instagram",
            account_handle: "thetraitorsus",
            content: "The caption for the selected post.",
            url: "https://www.instagram.com/p/DVfQnTcjsCA/",
            posted_at: "2026-04-22T15:00:00Z",
            saved_comments: 11,
            metrics: { likes: 187, comments_count: 42, engagement: 229, views: 0 },
          },
        ],
        pagination: { page: 1, page_size: 25, total: 1, total_pages: 1 },
      });
    }
    throw new Error(`Unhandled request: ${url}`);
  });

  render(<SocialAccountProfilePage platform="instagram" handle="thetraitorsus" activeTab="comments" />);

  expect(await screen.findByRole("columnheader", { name: "Comments Saved" })).toBeInTheDocument();
  expect(screen.getByRole("link", { name: "DVfQnTcjsCA" })).toBeInTheDocument();
  expect(screen.getByText("The caption for the selected post.")).toBeInTheDocument();
  expect(screen.getByText("11")).toBeInTheDocument();
  expect(screen.getByText("187")).toBeInTheDocument();
  expect(screen.queryByRole("columnheader", { name: "User" })).not.toBeInTheDocument();
});


it("opens the popup feed for the clicked post link", async () => {
  mocks.fetchAdminWithAuth.mockImplementation(async (input: RequestInfo | URL) => {
    const url = String(input);
    if (url.includes("/summary")) {
      return jsonResponse(baseSummary);
    }
    if (url.includes("/posts?page=1&page_size=25&comments_only=true")) {
      return jsonResponse({
        items: [
          {
            id: "post-1",
            source_id: "DVfQnTcjsCA",
            platform: "instagram",
            account_handle: "thetraitorsus",
            content: "The caption for the selected post.",
            url: "https://www.instagram.com/p/DVfQnTcjsCA/",
            posted_at: "2026-04-22T15:00:00Z",
            saved_comments: 11,
            metrics: { likes: 187, comments_count: 42, engagement: 229, views: 0 },
          },
        ],
        pagination: { page: 1, page_size: 25, total: 1, total_pages: 1 },
      });
    }
    if (url.includes("/comments?page=1&page_size=100&post_source_id=DVfQnTcjsCA")) {
      return jsonResponse({
        items: [
          {
            id: "comment-1",
            comment_id: "17800000000000001",
            post_source_id: "DVfQnTcjsCA",
            username: "traitorsfan",
            text: "This is the first saved comment.",
            likes: 7,
            created_at: "2026-04-22T15:30:00Z",
            is_reply: false,
          },
          {
            id: "comment-2",
            comment_id: "17800000000000002",
            post_source_id: "DVfQnTcjsCA",
            username: "traitorsreply",
            text: "Reply comment.",
            likes: 1,
            created_at: "2026-04-22T15:31:00Z",
            is_reply: true,
          },
        ],
        pagination: { page: 1, page_size: 100, total: 2, total_pages: 1 },
      });
    }
    throw new Error(`Unhandled request: ${url}`);
  });

  render(<SocialAccountProfilePage platform="instagram" handle="thetraitorsus" activeTab="comments" />);

  fireEvent.click(await screen.findByRole("link", { name: "DVfQnTcjsCA" }));

  expect(await screen.findByRole("heading", { name: "DVfQnTcjsCA" })).toBeInTheDocument();
  expect(screen.getByText("traitorsfan")).toBeInTheDocument();
  expect(screen.getByText("This is the first saved comment.")).toBeInTheDocument();
  expect(screen.getByText("Reply")).toBeInTheDocument();
});
```

- [ ] **Step 2: Add the shared type and the popup component**

```ts
export type SocialAccountProfilePost = {
  id: string;
  source_id: string;
  platform: SocialPlatformSlug;
  account_handle: string;
  title?: string | null;
  content?: string | null;
  excerpt?: string | null;
  url?: string | null;
  profile_url?: string | null;
  posted_at?: string | null;
  show_id?: string | null;
  show_name?: string | null;
  show_slug?: string | null;
  season_id?: string | null;
  season_number?: number | null;
  hashtags?: string[];
  mentions?: string[];
  collaborators?: string[];
  tags?: string[];
  match_mode?: "owner" | "collaborator";
  source_surface?: "materialized" | "catalog";
  saved_comments?: number | null;
  metrics: {
    likes?: number | null;
    comments_count?: number | null;
    views?: number | null;
    shares?: number | null;
    retweets?: number | null;
    replies_count?: number | null;
    quotes?: number | null;
    engagement?: number | null;
  };
};
```

```tsx
"use client";

import type { SocialAccountProfileComment } from "@/lib/admin/social-account-profile";

type Props = {
  open: boolean;
  postSourceId: string | null;
  postCaption?: string | null;
  comments: SocialAccountProfileComment[];
  loading: boolean;
  error: string | null;
  onClose: () => void;
};

export default function InstagramCommentsPostModal({
  open,
  postSourceId,
  postCaption,
  comments,
  loading,
  error,
  onClose,
}: Props) {
  if (!open || !postSourceId) return null;

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center bg-zinc-950/60 px-4 py-6">
      <div className="max-h-[90vh] w-full max-w-3xl overflow-hidden rounded-3xl border border-zinc-200 bg-white shadow-2xl">
        <div className="flex items-center justify-between gap-4 border-b border-zinc-200 px-6 py-4">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-zinc-500">Saved Comments Feed</p>
            <h2 className="mt-1 text-xl font-semibold text-zinc-900">{postSourceId}</h2>
            {postCaption ? <p className="mt-2 text-sm text-zinc-500">{postCaption}</p> : null}
          </div>
          <button
            type="button"
            onClick={onClose}
            className="rounded-full border border-zinc-200 px-3 py-2 text-sm font-semibold text-zinc-500 hover:bg-zinc-50 hover:text-zinc-700"
          >
            Close
          </button>
        </div>
        <div className="max-h-[calc(90vh-96px)] overflow-y-auto px-6 py-5">
          {loading ? <p className="text-sm text-zinc-500">Loading saved comments...</p> : null}
          {error ? <p className="text-sm text-red-700">{error}</p> : null}
          {!loading && !error && comments.length === 0 ? <p className="text-sm text-zinc-500">No saved comments for this post.</p> : null}
          {!loading && !error && comments.length > 0 ? (
            <div className="space-y-3">
              {comments.map((item) => (
                <div key={item.id} className="rounded-2xl border border-zinc-200 bg-zinc-50 px-4 py-3">
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <p className="font-semibold text-zinc-900">{item.username || "Unknown"}</p>
                      <p className="text-xs text-zinc-500">{item.created_at || "Unknown time"}</p>
                    </div>
                    <div className="text-xs font-semibold text-zinc-500">{item.likes ?? 0} likes</div>
                  </div>
                  <p className="mt-2 text-sm leading-6 text-zinc-700">{item.text || "No text"}</p>
                  {item.is_reply ? <p className="mt-2 text-xs text-zinc-500">Reply</p> : null}
                </div>
              ))}
            </div>
          ) : null}
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 3: Refactor the comments panel to fetch posts for the table and filtered comments for the popup**

```tsx
const [posts, setPosts] = useState<PostsResponse | null>(null);
const [postsLoading, setPostsLoading] = useState(false);
const [postsError, setPostsError] = useState<string | null>(null);
const [selectedPost, setSelectedPost] = useState<SocialAccountProfilePost | null>(null);
const [selectedPostComments, setSelectedPostComments] = useState<SocialAccountProfileCommentsResponse | null>(null);
const [selectedPostCommentsLoading, setSelectedPostCommentsLoading] = useState(false);
const [selectedPostCommentsError, setSelectedPostCommentsError] = useState<string | null>(null);

const refreshPosts = useCallback(async () => {
  if (checking || !user || !hasAccess) return;
  setPostsLoading(true);
  setPostsError(null);
  try {
    const response = await fetchAdminWithAuth(
      `/api/admin/trr-api/social/profiles/${encodeURIComponent(platform)}/${encodeURIComponent(handle)}/posts?page=${page}&page_size=25&comments_only=true`,
      undefined,
      { preferredUser: user },
    );
    const data = (await response.json().catch(() => ({}))) as PostsResponse & ProxyErrorPayload;
    if (!response.ok) {
      throw new Error(readInstagramCommentsErrorMessage(data, "Failed to load Instagram comment posts"));
    }
    setPosts(data);
  } catch (error) {
    setPostsError(error instanceof Error ? error.message : "Failed to load Instagram comment posts");
  } finally {
    setPostsLoading(false);
  }
}, [checking, fetchAdminWithAuth, handle, hasAccess, page, platform, user]);

const openPostModal = useCallback(async (post: SocialAccountProfilePost) => {
  if (!user) return;
  setSelectedPost(post);
  setSelectedPostComments(null);
  setSelectedPostCommentsError(null);
  setSelectedPostCommentsLoading(true);
  try {
    const response = await fetchAdminWithAuth(
      `/api/admin/trr-api/social/profiles/${encodeURIComponent(platform)}/${encodeURIComponent(handle)}/comments?page=1&page_size=100&post_source_id=${encodeURIComponent(post.source_id)}`,
      undefined,
      { preferredUser: user },
    );
    const data = (await response.json().catch(() => ({}))) as SocialAccountProfileCommentsResponse & ProxyErrorPayload;
    if (!response.ok) {
      throw new Error(readInstagramCommentsErrorMessage(data, "Failed to load Instagram post comments"));
    }
    setSelectedPostComments(data);
  } catch (error) {
    setSelectedPostCommentsError(error instanceof Error ? error.message : "Failed to load Instagram post comments");
  } finally {
    setSelectedPostCommentsLoading(false);
  }
}, [fetchAdminWithAuth, handle, platform, user]);

useEffect(() => {
  if (platform !== "instagram") return;
  void refreshPosts();
}, [platform, refreshPosts]);

...

<table className="min-w-full divide-y divide-zinc-200 text-sm">
  <thead>
    <tr className="text-left text-xs uppercase tracking-[0.14em] text-zinc-500">
      <th className="pb-3 pr-4">Post</th>
      <th className="pb-3 pr-4">Created</th>
      <th className="pb-3 pr-4">Caption</th>
      <th className="pb-3 pr-4">Comments Saved</th>
      <th className="pb-3">Likes</th>
    </tr>
  </thead>
  <tbody className="divide-y divide-zinc-100">
    {(posts?.items ?? []).map((item) => (
      <tr key={item.id}>
        <td className="py-4 pr-4 align-top">
          <button
            type="button"
            onClick={() => void openPostModal(item)}
            className="text-xs font-semibold text-blue-600 hover:text-blue-800 hover:underline"
          >
            {item.source_id}
          </button>
        </td>
        <td className="py-4 pr-4 align-top text-xs text-zinc-500">{formatDateTime(item.posted_at)}</td>
        <td className="py-4 pr-4 align-top text-zinc-700">
          <div className="max-w-xl whitespace-pre-wrap text-sm leading-6">{item.content || item.excerpt || "No caption saved."}</div>
        </td>
        <td className="py-4 pr-4 align-top text-zinc-700">{formatInteger(item.saved_comments)}</td>
        <td className="py-4 align-top text-zinc-700">{formatInteger(item.metrics.likes)}</td>
      </tr>
    ))}
  </tbody>
</table>

<InstagramCommentsPostModal
  open={Boolean(selectedPost)}
  postSourceId={selectedPost?.source_id ?? null}
  postCaption={selectedPost?.content ?? selectedPost?.excerpt ?? null}
  comments={selectedPostComments?.items ?? []}
  loading={selectedPostCommentsLoading}
  error={selectedPostCommentsError}
  onClose={() => {
    setSelectedPost(null);
    setSelectedPostComments(null);
    setSelectedPostCommentsError(null);
  }}
/>
```

- [ ] **Step 4: Run the targeted app test**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web run test:ci -- social-account-profile-page.runtime.test.tsx
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR
git add \
  TRR-APP/apps/web/src/lib/admin/social-account-profile.ts \
  TRR-APP/apps/web/src/components/admin/instagram/InstagramCommentsPanel.tsx \
  TRR-APP/apps/web/src/components/admin/instagram/InstagramCommentsPostModal.tsx \
  TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx
git commit -m "feat(app): show comment posts table with popup comment feed"
```

## Task 3: Validate Both Repos And Ship The Cross-Repo Change

**Files:**
- Modify only if validation fails: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify only if validation fails: `TRR-APP/apps/web/src/components/admin/instagram/InstagramCommentsPanel.tsx`
- Test: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Test: `TRR-Backend/tests/api/routers/test_socials_season_analytics.py`
- Test: `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`

- [ ] **Step 1: Run the touched backend fast checks**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
ruff check api/routers/socials.py trr_backend/repositories/social_season_analytics.py tests/repositories/test_social_season_analytics.py tests/api/routers/test_socials_season_analytics.py
ruff format --check api/routers/socials.py trr_backend/repositories/social_season_analytics.py tests/repositories/test_social_season_analytics.py tests/api/routers/test_socials_season_analytics.py
pytest -q tests/repositories/test_social_season_analytics.py -k "social_account_profile_posts_instagram_supports_comments_only or social_account_profile_comments_filters_to_one_post_source_id"
pytest -q tests/api/routers/test_socials_season_analytics.py -k "passes_comments_only_flag or passes_post_source_id"
```

Expected: PASS.

- [ ] **Step 2: Run the touched app fast checks**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web run lint
pnpm -C apps/web exec next build --webpack
pnpm -C apps/web run test:ci -- social-account-profile-page.runtime.test.tsx
```

Expected: PASS.

- [ ] **Step 3: If any targeted validation fails, patch only the specific contract mismatch**

```tsx
if (!response.ok) {
  throw new Error(readInstagramCommentsErrorMessage(data, "Failed to load Instagram post comments"));
}

setSelectedPostComments(data);

if (selectedPost?.source_id !== post.source_id) {
  return;
}
```

```python
normalized_post_source_id = str(post_source_id or "").strip() or None
cache_key = _account_profile_cache_key(
    surface="comments",
    platform=platform,
    account_handle=account_handle,
    page=page,
    page_size=page_size,
    post_source_id=normalized_post_source_id,
)
```

- [ ] **Step 4: Create the final integration commit**

```bash
cd /Users/thomashulihan/Projects/TRR
git add \
  TRR-Backend/trr_backend/repositories/social_season_analytics.py \
  TRR-Backend/api/routers/socials.py \
  TRR-Backend/tests/repositories/test_social_season_analytics.py \
  TRR-Backend/tests/api/routers/test_socials_season_analytics.py \
  TRR-APP/apps/web/src/lib/admin/social-account-profile.ts \
  TRR-APP/apps/web/src/components/admin/instagram/InstagramCommentsPanel.tsx \
  TRR-APP/apps/web/src/components/admin/instagram/InstagramCommentsPostModal.tsx \
  TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx
git commit -m "feat(instagram): convert comments page to post summary with popup feed"
```

## Self-Review

### Spec Coverage

- Row-per-post comments page: covered in Task 1 backend contract and Task 2 panel refactor.
- Required row fields (`post`, `date/time`, `caption`, `comments saved`, `likes`): covered in Task 2 runtime test and render step.
- Popup/feed on post hyperlink click: covered in Task 1 filtered `post_source_id` backend read and Task 2 modal test/render step.

### Placeholder Scan

- No `TODO`, `TBD`, or “handle appropriately” placeholders remain.
- Every code-edit step includes concrete code or commands.

### Type Consistency

- The post table uses `SocialAccountProfilePost.saved_comments`.
- The popup continues to use `SocialAccountProfileCommentsResponse.items`.
- The filtered backend query param is consistently named `post_source_id` in repo, router, app fetches, and tests.
