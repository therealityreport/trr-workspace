# Instagram Catalog Gap-Fill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two targeted catalog sync actions — `sync_newer` and `resume_tail` — that efficiently fill missing posts without re-running a full backfill, reducing a 15+ minute full re-scan to ~2-3 minutes.

**Architecture:** Instagram GraphQL paginates newest→oldest only. The head gap (posts newer than stored) is naturally fast since the API starts from the newest post. The tail gap (oldest posts the previous backfill didn't reach) leverages the `shared_account_run_frontiers` table, which stores the exact pagination cursor where the last backfill stopped. A new run seeded with that cursor resumes from where it left off. Both actions use the existing upsert-based persistence, so duplicates are harmless.

**Tech Stack:** Python (FastAPI backend), TypeScript/React (Next.js admin frontend), PostgreSQL (Supabase)

---

## File Structure

### Backend (TRR-Backend)
| File | Action | Responsibility |
|------|--------|----------------|
| `trr_backend/repositories/social_season_analytics.py` | Modify | Add `sync_newer_social_account_catalog`, `resume_tail_social_account_catalog`, `_latest_account_frontier`, enhanced freshness response |
| `api/routers/socials.py` | Modify | Add `POST .../catalog/sync-newer` and `POST .../catalog/resume-tail` routes + request models |

### Frontend (TRR-APP)
| File | Action | Responsibility |
|------|--------|----------------|
| `apps/web/src/lib/admin/social-account-profile.ts` | Modify | Extend `SocialAccountCatalogFreshness` type with gap metadata |
| `apps/web/src/components/admin/SocialAccountProfilePage.tsx` | Modify | Add "Sync Newer" and "Resume Tail" buttons, extend `runCatalogAction` |
| `apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/catalog/sync-newer/route.ts` | Create | Proxy route for sync-newer |
| `apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/catalog/resume-tail/route.ts` | Create | Proxy route for resume-tail |

---

## Task 1: Add `_latest_account_frontier` helper (Backend)

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py` (near line 24212, after `_get_shared_account_run_frontier`)

This function queries the frontier table for the most recent non-exhausted frontier for a given account across ALL previous runs. This is the key to resuming from where the last backfill stopped.

- [ ] **Step 1: Add `_latest_account_frontier` function**

```python
def _latest_account_frontier(
    platform: str,
    account_handle: str,
) -> dict[str, Any]:
    """Return the most recent non-exhausted frontier for this account, across all runs."""
    if not _shared_account_run_frontiers_table_ready():
        return {}
    normalized_platform = _normalize_platform_name(platform)
    normalized_account = _normalize_account_handle(account_handle)
    row = pg.fetch_one(
        """
        select
          id::text as id,
          run_id::text as run_id,
          platform,
          account_handle,
          strategy,
          status,
          next_cursor,
          total_posts,
          posts_checked,
          posts_saved,
          pages_scanned,
          last_transport,
          retry_count,
          exhausted,
          metadata,
          created_at,
          updated_at
        from social.shared_account_run_frontiers
        where platform = %s
          and account_handle = %s
          and coalesce(exhausted, false) = false
          and next_cursor is not null
          and nullif(trim(next_cursor), '') is not null
        order by updated_at desc
        limit 1
        """,
        [normalized_platform, normalized_account],
    )
    return _shared_account_frontier_row_to_payload(row)
```

- [ ] **Step 2: Verify function works by checking the data**

Run (from TRR-Backend root):
```bash
python -c "
from trr_backend.repositories.social_season_analytics import _latest_account_frontier
result = _latest_account_frontier('instagram', 'bravotv')
print('frontier:', result.get('next_cursor', 'NONE')[:30] if result else 'NO FRONTIER')
print('pages_scanned:', result.get('pages_scanned'))
print('posts_checked:', result.get('posts_checked'))
print('exhausted:', result.get('exhausted'))
"
```

Expected: A frontier row with `next_cursor` set and `exhausted=False`, showing the progress of the last backfill.

- [ ] **Step 3: Commit**

```bash
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py
git commit -m "feat(catalog): add _latest_account_frontier helper for cursor recovery"
```

---

## Task 2: Add `sync_newer_social_account_catalog` function (Backend)

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py` (after `sync_recent_social_account_catalog` near line 46410)

This function detects the newest stored post date and runs a bounded_window backfill from there to now. It's the "head gap" filler.

- [ ] **Step 1: Add `_catalog_newest_stored_post_at` helper**

Add near the other `_shared_catalog_*` helpers (around line 23221):

```python
def _catalog_newest_stored_post_at(platform: str, account_handle: str) -> datetime | None:
    """Return the posted_at of the newest stored catalog post for this account."""
    table, _source_id_column, posted_at_column = _shared_catalog_base_query_parts(platform)
    normalized_account = _normalize_account_handle(account_handle)
    row = pg.fetch_one(
        f"""
        select max({posted_at_column}) as newest_at
        from social.{table}
        where lower(source_account) = %s
        """,
        [normalized_account],
    )
    return _coerce_dt((row or {}).get("newest_at"))
```

- [ ] **Step 2: Add `sync_newer_social_account_catalog` function**

Add after `sync_recent_social_account_catalog` (line ~46410):

```python
def sync_newer_social_account_catalog(
    platform: str,
    account_handle: str,
    *,
    source_scope: str = "bravo",
    initiated_by: str | None = None,
    inline_worker_id: str | None = None,
) -> dict[str, Any]:
    """Fill the head gap: fetch all posts newer than the newest stored post."""
    normalized_platform = _normalize_social_account_profile_platform(platform)
    normalized_account = _normalize_social_account_profile_handle(account_handle)
    newest_at = _catalog_newest_stored_post_at(normalized_platform, normalized_account)
    if newest_at is None:
        raise SocialIngestValidationError(
            "NO_STORED_POSTS",
            "No stored posts found for this account. Run a full backfill first.",
        )
    now_utc = _now_utc()
    if newest_at >= now_utc:
        raise SocialIngestValidationError(
            "ALREADY_CURRENT",
            "Newest stored post is already at or beyond the current time.",
        )
    return start_social_account_catalog_backfill(
        platform,
        account_handle,
        source_scope=source_scope,
        date_start=newest_at,
        date_end=now_utc,
        initiated_by=initiated_by,
        inline_worker_id=inline_worker_id,
    )
```

- [ ] **Step 3: Commit**

```bash
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py
git commit -m "feat(catalog): add sync_newer to fill head gap from newest stored post"
```

---

## Task 3: Add `resume_tail_social_account_catalog` function (Backend)

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py` (after `sync_newer_social_account_catalog`)

This function resumes an incomplete full_history backfill by seeding a new run's frontier with the cursor from the previous run. This is the "tail gap" filler.

- [ ] **Step 1: Add `resume_tail_social_account_catalog` function**

```python
def resume_tail_social_account_catalog(
    platform: str,
    account_handle: str,
    *,
    source_scope: str = "bravo",
    initiated_by: str | None = None,
    inline_worker_id: str | None = None,
) -> dict[str, Any]:
    """Fill the tail gap: resume from the last backfill's frontier cursor."""
    normalized_platform = _normalize_social_account_profile_platform(platform)
    normalized_account = _normalize_social_account_profile_handle(account_handle)
    frontier = _latest_account_frontier(normalized_platform, normalized_account)
    next_cursor = str(frontier.get("next_cursor") or "").strip() or None
    if not next_cursor:
        raise SocialIngestValidationError(
            "NO_RESUMABLE_FRONTIER",
            "No resumable frontier cursor found. The previous backfill either completed fully or has no saved progress.",
        )
    if frontier.get("exhausted"):
        raise SocialIngestValidationError(
            "FRONTIER_ALREADY_EXHAUSTED",
            "The previous backfill's frontier is already exhausted (all posts were reached).",
        )
    # Start a new full_history backfill — it will use the frontier strategy
    result = start_social_account_catalog_backfill(
        platform,
        account_handle,
        source_scope=source_scope,
        date_start=None,
        date_end=None,
        initiated_by=initiated_by,
        inline_worker_id=inline_worker_id,
    )
    # Seed the new run's frontier with the recovered cursor
    new_run_id = str(result.get("run_id") or "").strip()
    if new_run_id:
        _ensure_shared_account_run_frontier(
            run_id=new_run_id,
            platform=normalized_platform,
            account_handle=normalized_account,
            strategy=CATALOG_FULL_HISTORY_FRONTIER_STRATEGY,
            status="queued",
            next_cursor=next_cursor,
            total_posts=frontier.get("total_posts"),
            posts_checked=frontier.get("posts_checked") or 0,
            posts_saved=frontier.get("posts_saved") or 0,
            pages_scanned=frontier.get("pages_scanned") or 0,
            metadata={
                "resumed_from_run_id": frontier.get("run_id"),
                "resumed_from_frontier_id": frontier.get("id"),
                "resumed_cursor": next_cursor,
            },
        )
    return {
        **result,
        "resumed_from_cursor": True,
        "source_frontier_run_id": frontier.get("run_id"),
        "source_frontier_pages_scanned": frontier.get("pages_scanned"),
        "source_frontier_posts_checked": frontier.get("posts_checked"),
    }
```

- [ ] **Step 2: Commit**

```bash
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py
git commit -m "feat(catalog): add resume_tail to continue from previous backfill cursor"
```

---

## Task 4: Enhance freshness response with gap metadata (Backend)

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py:46174` (`get_social_account_catalog_freshness`)

Add `catalog_first_post_at`, `catalog_last_post_at`, and frontier status to help the admin UI show WHERE the gaps are and which actions are available.

- [ ] **Step 1: Add `_catalog_oldest_stored_post_at` helper**

Add near `_catalog_newest_stored_post_at` (created in Task 2):

```python
def _catalog_oldest_stored_post_at(platform: str, account_handle: str) -> datetime | None:
    """Return the posted_at of the oldest stored catalog post for this account."""
    table, _source_id_column, posted_at_column = _shared_catalog_base_query_parts(platform)
    normalized_account = _normalize_account_handle(account_handle)
    row = pg.fetch_one(
        f"""
        select min({posted_at_column}) as oldest_at
        from social.{table}
        where lower(source_account) = %s
        """,
        [normalized_account],
    )
    return _coerce_dt((row or {}).get("oldest_at"))
```

- [ ] **Step 2: Modify `get_social_account_catalog_freshness` to include gap metadata**

In the function body (after line 46185), add:

```python
catalog_newest_at = _catalog_newest_stored_post_at(normalized_platform, normalized_account)
catalog_oldest_at = _catalog_oldest_stored_post_at(normalized_platform, normalized_account)
frontier = _latest_account_frontier(normalized_platform, normalized_account)
has_resumable_frontier = bool(
    frontier.get("next_cursor")
    and not frontier.get("exhausted")
)
```

Then add these fields to ALL return dicts in the function (both the `eligible: False` cases and the `eligible: True` case):

```python
"catalog_newest_post_at": _iso(catalog_newest_at),
"catalog_oldest_post_at": _iso(catalog_oldest_at),
"has_resumable_frontier": has_resumable_frontier,
"frontier_pages_scanned": frontier.get("pages_scanned") if has_resumable_frontier else None,
"frontier_posts_checked": frontier.get("posts_checked") if has_resumable_frontier else None,
```

- [ ] **Step 3: Commit**

```bash
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py
git commit -m "feat(catalog): enhance freshness response with gap metadata and frontier status"
```

---

## Task 5: Add API routes for sync-newer and resume-tail (Backend)

**Files:**
- Modify: `TRR-Backend/api/routers/socials.py` (after `post_social_account_catalog_sync_recent_route`, near line 3905)

- [ ] **Step 1: Add request model for sync-newer**

Add near `CatalogSyncRecentRequest` (line ~2465):

```python
class CatalogSyncNewerRequest(BaseModel):
    source_scope: Literal["bravo", "creator", "community"] = Field(default="bravo")
    allow_inline_dev_fallback: bool = Field(default=False)


class CatalogResumeTailRequest(BaseModel):
    source_scope: Literal["bravo", "creator", "community"] = Field(default="bravo")
    allow_inline_dev_fallback: bool = Field(default=False)
```

- [ ] **Step 2: Add `sync-newer` route**

Add after the `sync-recent` route (after line ~3903). Follow the exact same pattern as the `sync-recent` route but call `sync_newer_social_account_catalog` instead:

```python
@router.post("/profiles/{platform}/{account_handle}/catalog/sync-newer")
async def post_social_account_catalog_sync_newer_route(
    platform: str,
    account_handle: str,
    payload: CatalogSyncNewerRequest,
    background_tasks: BackgroundTasks,
    user: AdminUser,
) -> dict[str, Any]:
    from trr_backend.repositories.social_season_analytics import (
        SocialIngestConflictError,
        SocialIngestValidationError,
        SocialWorkerUnavailableError,
        _shared_account_catalog_requires_modal_executor,
        assert_worker_available_when_queue_enabled,
        is_queue_enabled,
        sync_newer_social_account_catalog,
    )

    # --- Copy the EXACT same queue_enabled / remote_plane / inline_fallback
    # --- boilerplate from post_social_account_catalog_sync_recent_route
    # --- (lines 3923-3966), replacing the function call with:
    #
    #   result = sync_newer_social_account_catalog(
    #       platform=platform,
    #       account_handle=account_handle,
    #       source_scope=payload.source_scope,
    #       initiated_by=(user or {}).get("email"),
    #       inline_worker_id=None if queue_enabled else f"api-background:catalog:{platform}",
    #   )
    #
    # --- Then the same post-call logic (background task, execution mode, return).
    # --- This is identical to sync-recent except the called function.
    ...
```

The route body follows the identical pattern as `post_social_account_catalog_sync_recent_route` — the only difference is calling `sync_newer_social_account_catalog` instead of `sync_recent_social_account_catalog`.

- [ ] **Step 3: Add `resume-tail` route**

Add after the `sync-newer` route, same pattern:

```python
@router.post("/profiles/{platform}/{account_handle}/catalog/resume-tail")
async def post_social_account_catalog_resume_tail_route(
    platform: str,
    account_handle: str,
    payload: CatalogResumeTailRequest,
    background_tasks: BackgroundTasks,
    user: AdminUser,
) -> dict[str, Any]:
    from trr_backend.repositories.social_season_analytics import (
        SocialIngestConflictError,
        SocialIngestValidationError,
        SocialWorkerUnavailableError,
        _shared_account_catalog_requires_modal_executor,
        assert_worker_available_when_queue_enabled,
        is_queue_enabled,
        resume_tail_social_account_catalog,
    )

    # --- Same boilerplate, calling:
    #
    #   result = resume_tail_social_account_catalog(
    #       platform=platform,
    #       account_handle=account_handle,
    #       source_scope=payload.source_scope,
    #       initiated_by=(user or {}).get("email"),
    #       inline_worker_id=None if queue_enabled else f"api-background:catalog:{platform}",
    #   )
    ...
```

- [ ] **Step 4: Commit**

```bash
git add TRR-Backend/api/routers/socials.py
git commit -m "feat(catalog): add sync-newer and resume-tail API routes"
```

---

## Task 6: Add frontend proxy routes (TRR-APP)

**Files:**
- Create: `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/catalog/sync-newer/route.ts`
- Create: `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/catalog/resume-tail/route.ts`

Both routes follow the exact same pattern as the existing `sync-recent/route.ts`.

- [ ] **Step 1: Read the existing sync-recent proxy route for reference**

Read: `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/catalog/sync-recent/route.ts`

- [ ] **Step 2: Create sync-newer proxy route**

Copy the `sync-recent/route.ts` file to `sync-newer/route.ts`. Change:
- The proxy path segment from `sync-recent` to `sync-newer`
- The timeout to `210` seconds (same as backfill — this could take a moment for large head gaps)

- [ ] **Step 3: Create resume-tail proxy route**

Copy the same file to `resume-tail/route.ts`. Change:
- The proxy path segment from `sync-recent` to `resume-tail`
- The timeout to `210` seconds

- [ ] **Step 4: Commit**

```bash
git add TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/\[platform\]/\[handle\]/catalog/sync-newer/route.ts
git add TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/\[platform\]/\[handle\]/catalog/resume-tail/route.ts
git commit -m "feat(admin): add sync-newer and resume-tail proxy routes"
```

---

## Task 7: Extend frontend types (TRR-APP)

**Files:**
- Modify: `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts:204`

- [ ] **Step 1: Extend `SocialAccountCatalogFreshness` type**

Add these fields to the type (after `active_run_status`):

```typescript
export type SocialAccountCatalogFreshness = {
  platform: SocialPlatformSlug;
  account_handle: string;
  eligible: boolean;
  reason?: string | null;
  checked_at: string;
  stored_total_posts: number;
  live_total_posts_current?: number | null;
  delta_posts: number;
  needs_recent_sync: boolean;
  latest_catalog_run_status?: string | null;
  active_run_status?: string | null;
  // --- NEW: gap metadata ---
  catalog_newest_post_at?: string | null;
  catalog_oldest_post_at?: string | null;
  has_resumable_frontier?: boolean;
  frontier_pages_scanned?: number | null;
  frontier_posts_checked?: number | null;
};
```

- [ ] **Step 2: Extend the `runCatalogAction` union type**

In `SocialAccountProfilePage.tsx`, the `runCatalogAction` function and `runningCatalogAction` state use a union type. Extend it:

At line 580, change:
```typescript
const [runningCatalogAction, setRunningCatalogAction] = useState<"backfill" | "sync_recent" | "sync_newer" | "resume_tail" | null>(null);
```

- [ ] **Step 3: Commit**

```bash
git add TRR-APP/apps/web/src/lib/admin/social-account-profile.ts
git add TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx
git commit -m "feat(admin): extend catalog freshness types with gap metadata"
```

---

## Task 8: Add "Sync Newer" and "Resume Tail" buttons to admin UI (TRR-APP)

**Files:**
- Modify: `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx:1819-1875` (runCatalogAction function)
- Modify: `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx:2044-2067` (button group)

- [ ] **Step 1: Extend `runCatalogAction` to handle new action types**

At line 1819, modify the function signature and the URL path mapping:

```typescript
const runCatalogAction = async (
  action: "backfill" | "sync_recent" | "sync_newer" | "resume_tail",
  requestBody: CatalogBackfillRequest | CatalogSyncRecentRequest | Record<string, unknown>,
) => {
```

At line 1831, extend the URL segment mapping:

```typescript
const actionSlug =
  action === "backfill" ? "backfill"
  : action === "sync_newer" ? "sync-newer"
  : action === "resume_tail" ? "resume-tail"
  : "sync-recent";
```

Use `actionSlug` in the fetch URL.

Update the success/error messages to handle the new actions (lines 1860-1868).

- [ ] **Step 2: Add new buttons in the button group**

At the button group area (lines 2044-2067), add two new buttons between "Backfill Posts" and "Sync Recent":

```tsx
{/* Sync Newer — visible when delta_posts > 0 and catalog has posts */}
{catalogFreshness?.needs_recent_sync && catalogFreshness?.catalog_newest_post_at && (
  <button
    className="rounded bg-blue-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-blue-700 disabled:opacity-50"
    disabled={catalogActionsBlocked || !!runningCatalogAction}
    onClick={() =>
      void runCatalogAction("sync_newer", {
        source_scope: "bravo",
      })
    }
  >
    {runningCatalogAction === "sync_newer" ? "Queueing…" : "Sync Newer Posts"}
  </button>
)}

{/* Resume Tail — visible when frontier has a resumable cursor */}
{catalogFreshness?.has_resumable_frontier && (
  <button
    className="rounded bg-amber-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-amber-700 disabled:opacity-50"
    disabled={catalogActionsBlocked || !!runningCatalogAction}
    onClick={() =>
      void runCatalogAction("resume_tail", {
        source_scope: "bravo",
      })
    }
  >
    {runningCatalogAction === "resume_tail" ? "Queueing…" : "Resume Tail"}
  </button>
)}
```

- [ ] **Step 3: Update the help text**

At line 2098, update the help text to describe the new actions:

```tsx
Backfill Posts runs the full-history catalog job.
Sync Newer fetches only posts published after the latest stored post.
Resume Tail continues from where the last backfill stopped.
Sync Recent runs the same pipeline, limited to the last day.
```

- [ ] **Step 4: Commit**

```bash
git add TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx
git commit -m "feat(admin): add Sync Newer and Resume Tail buttons to catalog actions"
```

---

## Task 9: Integration test — verify the full flow

- [ ] **Step 1: Start the dev stack**

```bash
cd /Users/thomashulihan/Projects/TRR && make dev
```

- [ ] **Step 2: Navigate to admin page**

Open `http://admin.localhost:3000/social/instagram/bravotv`

- [ ] **Step 3: Click "Check Freshness" and verify new fields**

Expected: The freshness response now shows:
- `catalog_newest_post_at`: a date around 3/20/2026
- `catalog_oldest_post_at`: the oldest stored post date
- `has_resumable_frontier`: `true` (if previous backfill has a saved cursor)

- [ ] **Step 4: Verify "Sync Newer Posts" button appears**

Expected: A blue "Sync Newer Posts" button appears when `needs_recent_sync` is true and `catalog_newest_post_at` exists.

- [ ] **Step 5: Verify "Resume Tail" button appears**

Expected: An amber "Resume Tail" button appears when `has_resumable_frontier` is true.

- [ ] **Step 6: Test Sync Newer (fills head gap)**

Click "Sync Newer Posts". Expected:
- Backfill queues with a bounded_window from the latest stored post date to now
- Only pages through ~10-20 pages of the newest posts
- Completes in 1-3 minutes
- `delta_posts` decreases by the number of newer posts found

- [ ] **Step 7: Test Resume Tail (fills tail gap)**

Click "Resume Tail". Expected:
- Backfill queues using the frontier cursor from the previous run
- Only pages through ~2-5 pages of the oldest remaining posts
- Completes in under 1 minute
- `delta_posts` drops to 0 (or very close)

- [ ] **Step 8: Final verification**

Click "Check Freshness" again. Expected:
- `stored_total_posts` should be close to or equal to `live_total_posts_current`
- `delta_posts` should be 0 or very small (new posts published during the test)

- [ ] **Step 9: Commit any fixes**

```bash
git add -A
git commit -m "fix: integration test adjustments for catalog gap-fill"
```

---

## Design Notes

### Why two separate actions instead of one "Fill Gaps"?

1. **Different failure modes**: Sync Newer is simple bounded_window (very reliable). Resume Tail depends on having a usable frontier cursor (might not exist if the previous run had no frontier strategy, or if the run was a bounded_window). Keeping them separate lets the user take the guaranteed-to-work action (Sync Newer) even if Resume Tail isn't available.

2. **Visibility**: The admin sees exactly what each action does. "Sync Newer Posts" is self-explanatory. "Resume Tail" with the frontier metadata (pages scanned, posts checked) gives confidence that it will pick up where the last run left off.

3. **Can be combined later**: A "Fill All Gaps" button that runs both in sequence is a trivial follow-up once the primitives exist.

### Edge cases

| Scenario | sync_newer behavior | resume_tail behavior |
|----------|-------------------|---------------------|
| No stored posts at all | Error: "Run a full backfill first" | Error: "No resumable frontier" |
| Previous backfill fully exhausted | Works normally (catches newer posts) | Error: "Frontier already exhausted" |
| No frontier table | Works normally | Error: "No resumable frontier" |
| Active run in progress | Error: "Run already active" (existing check) | Error: "Run already active" |
| Multiple previous frontiers | N/A | Uses the most recently updated one |

### Performance expectations

| Action | Pages fetched | Estimated time | Gap addressed |
|--------|---------------|----------------|---------------|
| Sync Newer | ~10-20 pages | 1-3 min | Head gap (~560 posts) |
| Resume Tail | ~2-5 pages | 30-60 sec | Tail gap (~100 posts) |
| Full Backfill (existing) | ~330+ pages | 10-20 min | Everything (brute force) |
