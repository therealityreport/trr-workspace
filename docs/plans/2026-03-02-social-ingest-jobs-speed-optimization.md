# Social Ingest Jobs — Speed, Reliability & UX Optimization Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Speed up, harden, and improve the UX of the Social Ingest Jobs system shown on the `/rhoslc/s6/social` and `/rhoslc/s6/social/w8/details` admin pages — covering the multi-platform worker queue (Instagram, TikTok, YouTube, etc.) AND the Reddit refresh pipeline.

**Architecture:** The system spans three layers — TRR-APP (Next.js admin UI with polling), TRR-Backend (FastAPI orchestrator + worker queue + Reddit scraper), and PostgreSQL (Supabase). Optimizations target DB query performance, job lifecycle management, worker efficiency, frontend polling/UX, and error recovery.

**Tech Stack:** TypeScript/React (TRR-APP), Python/FastAPI (TRR-Backend), PostgreSQL/Supabase, `requests` HTTP client, `psycopg2`, `boto3`, `ThreadPoolExecutor`

---

## Task 1: Add Missing Database Indexes for Job Claiming Hot Path

The `_claim_next_jobs()` query in `social_season_analytics.py:15327` runs a CTE that scans `social.scrape_jobs` filtering by `status IN ('queued','pending','retrying')` and `available_at <= now()`. Without a partial index, this is a sequential scan on every claim cycle (every few seconds per worker).

**Files:**
- Create: `TRR-Backend/supabase/migrations/0XXX_social_ingest_job_claim_indexes.sql`

**Step 1: Write the migration**

```sql
-- Partial index for job claiming hot path: filters queued/pending/retrying jobs
-- that are available for pickup. Dramatically reduces claim query scan cost.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_scrape_jobs_claim_hotpath
  ON social.scrape_jobs (available_at, status, priority DESC, created_at)
  WHERE status IN ('queued', 'pending', 'retrying');

-- Index for run-in-flight CTE: counts running jobs per run_id
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_scrape_jobs_running_by_run
  ON social.scrape_jobs (run_id, status)
  WHERE status = 'running' AND run_id IS NOT NULL;

-- Index for worker heartbeat lookups during stale detection
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_scrape_jobs_heartbeat_stale
  ON social.scrape_jobs (heartbeat_at, status)
  WHERE status = 'running';
```

**Step 2: Run migration locally**

Run: `cd TRR-Backend && python -m supabase_migrations apply` (or equivalent Supabase CLI)
Expected: 3 indexes created

**Step 3: Verify with EXPLAIN ANALYZE**

```sql
EXPLAIN ANALYZE
SELECT id FROM social.scrape_jobs
WHERE status IN ('queued', 'pending', 'retrying')
  AND available_at <= now()
ORDER BY priority DESC, created_at
LIMIT 5;
```
Expected: Index Scan using `idx_scrape_jobs_claim_hotpath` (not Seq Scan)

**Step 4: Commit**

```bash
git add supabase/migrations/0XXX_social_ingest_job_claim_indexes.sql
git commit -m "perf: add partial indexes for scrape_jobs claim hot path"
```

---

## Task 2: Add Missing Indexes for Reddit Refresh Run Queries

`get_refresh_run()` aggregates ALL queued+running runs globally (no community/season filter) to compute queue position. The dedup check in `create_or_reuse_refresh_run()` also lacks a targeted index.

**Files:**
- Create: `TRR-Backend/supabase/migrations/0XXX_reddit_refresh_run_indexes.sql`

**Step 1: Write the migration**

```sql
-- Composite index for dedup/reuse check and cache lookups
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_reddit_refresh_runs_dedup
  ON social.reddit_refresh_runs (community_id, season_id, period_key, status, created_at DESC);

-- Partial index for queue position aggregation (only active runs matter)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_reddit_refresh_runs_active
  ON social.reddit_refresh_runs (status, created_at DESC)
  WHERE status IN ('queued', 'running');

-- Index for cache lookups (completed runs by community/season/period)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_reddit_refresh_runs_cache
  ON social.reddit_refresh_runs (community_id, season_id, period_key, created_at DESC)
  WHERE status = 'completed';
```

**Step 2: Run migration and verify**

Run: Apply migration, then `EXPLAIN ANALYZE` the dedup query.
Expected: Index Scan instead of Seq Scan.

**Step 3: Commit**

```bash
git add supabase/migrations/0XXX_reddit_refresh_run_indexes.sql
git commit -m "perf: add indexes for reddit refresh run dedup and queue position queries"
```

---

## Task 3: Cache Schema Introspection in `_column_exists()`

`_upsert_posts()` calls `_column_exists()` 9 times per batch, each querying `information_schema.columns`. There IS a `_column_exists_cache` dict defined at module level, but the cache is per-process and cold on every restart. The real issue is that it's called in the hot path on every batch insert.

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/reddit_refresh.py`

**Step 1: Verify the existing cache works correctly**

Read `_column_exists()` function (around line 568) and confirm the cache dict `_column_exists_cache` is populated on first call and reused. If it's already cached, this task becomes "no-op" — verify and move on.

**Step 2: If not cached, add session-level caching**

```python
# At module level (already exists):
_column_exists_cache: dict[tuple[str, str, str], bool] = {}

# In _column_exists(), ensure the cache is checked FIRST:
def _column_exists(schema: str, table: str, column: str) -> bool:
    key = (schema, table, column)
    if key in _column_exists_cache:
        return _column_exists_cache[key]
    # ... DB query ...
    _column_exists_cache[key] = result
    return result
```

**Step 3: Commit if changes were needed**

```bash
git add trr_backend/repositories/reddit_refresh.py
git commit -m "perf: verify column existence cache prevents repeated information_schema queries"
```

---

## Task 4: Add LIMIT to Dedup/Reuse Query

`create_or_reuse_refresh_run()` fetches ALL active runs matching (community, season, period) without a LIMIT. In practice there should be 0-2, but without a LIMIT the query is unbounded.

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/reddit_refresh.py`

**Step 1: Find the dedup query**

Search for the SQL in `create_or_reuse_refresh_run()` or `_find_or_create_refresh_run()` that selects active runs with `status IN ('queued', 'running')`.

**Step 2: Add LIMIT and ORDER BY**

Add `ORDER BY created_at DESC LIMIT 5` to the query. We only need the most recent few runs for dedup/recovery purposes.

**Step 3: Commit**

```bash
git add trr_backend/repositories/reddit_refresh.py
git commit -m "perf: add LIMIT to reddit refresh dedup query"
```

---

## Task 5: Scope Queue Position Query to Community

`get_refresh_run()` computes queue position by scanning ALL active runs globally. For a single-community check, this is wasteful.

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/reddit_refresh.py`

**Step 1: Find the queue position query in `get_refresh_run()`**

Look for the SQL that counts `running_total`, `queued_total`, `queued_ahead` from `social.reddit_refresh_runs WHERE status IN ('queued', 'running')`.

**Step 2: Add community_id filter**

```sql
SELECT
  count(*) FILTER (WHERE status = 'running') as running_total,
  count(*) FILTER (WHERE status = 'queued') as queued_total,
  count(*) FILTER (WHERE status = 'queued' AND created_at < %s::timestamptz) as queued_ahead
FROM social.reddit_refresh_runs
WHERE status IN ('queued', 'running')
  AND community_id = %s  -- ADD THIS
```

This still gives accurate queue position within the community and avoids scanning all communities.

**Step 3: Commit**

```bash
git add trr_backend/repositories/reddit_refresh.py
git commit -m "perf: scope queue position query to community_id"
```

---

## Task 6: Reduce Worker Stale Detection Overhead

`recover_stale_running_jobs()` runs every 30 seconds per worker. With N workers, that's N scans of running jobs. The scan uses `heartbeat_at` comparisons without a targeted index.

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`

**Step 1: Find `recover_stale_running_jobs()` (~line 5305)**

Read the current implementation.

**Step 2: Add early-exit when no stale jobs exist**

```python
def recover_stale_running_jobs(self, run_id=None, stage=None, platform=None, limit=10):
    stale_cutoff = datetime.now(tz=UTC) - timedelta(seconds=self.stale_after_seconds)

    # Quick check: any stale jobs at all? (uses the new partial index)
    with pg.db_connection() as conn:
        with pg.db_cursor(conn=conn) as cur:
            cur.execute("""
                SELECT EXISTS(
                    SELECT 1 FROM social.scrape_jobs
                    WHERE status = 'running'
                      AND heartbeat_at < %s
                    LIMIT 1
                )
            """, [stale_cutoff])
            has_stale = cur.fetchone()[0]
            if not has_stale:
                return []  # Fast path: nothing to recover
    # ... existing recovery logic ...
```

**Step 3: Commit**

```bash
git add trr_backend/repositories/social_season_analytics.py
git commit -m "perf: add early-exit to stale job recovery when no stale jobs exist"
```

---

## Task 7: Batch Worker Heartbeat Writes

Each worker writes its heartbeat every 15 seconds as a separate UPDATE. With multiple workers, this adds up.

**Files:**
- Modify: `TRR-Backend/scripts/socials/worker.py`

**Step 1: Read the `WorkerHeartbeat` class (~line 33)**

Understand the current heartbeat thread implementation.

**Step 2: Add conditional heartbeat skipping**

Only write heartbeat if status actually changed OR if the heartbeat interval has elapsed:

```python
class WorkerHeartbeat(threading.Thread):
    def __init__(self, ...):
        ...
        self._last_written_status: str | None = None
        self._last_written_at: float = 0.0

    def _tick(self):
        now = time.monotonic()
        # Skip write if status unchanged and interval not elapsed
        if (self._last_written_status == self.status
                and (now - self._last_written_at) < self.interval):
            return
        # ... existing write logic ...
        self._last_written_status = self.status
        self._last_written_at = now
```

**Step 3: Commit**

```bash
git add scripts/socials/worker.py
git commit -m "perf: skip redundant heartbeat writes when worker status unchanged"
```

---

## Task 8: Add AbortController to Frontend Polling Loops

The `WeekDetailPageView` and `SeasonSocialAnalyticsSection` polling loops do not use `AbortController`. If the user navigates away mid-poll, in-flight requests complete uselessly and can even update stale state.

**Files:**
- Modify: `TRR-APP/apps/web/src/components/admin/social-week/WeekDetailPageView.tsx`
- Modify: `TRR-APP/apps/web/src/components/admin/season-social-analytics-section.tsx`

**Step 1: Add AbortController to WeekDetailPageView sync polling**

Find the `fetchSyncProgress()` function and the polling loop that calls it. Add:

```typescript
const abortControllerRef = useRef<AbortController | null>(null);

// In the polling loop:
abortControllerRef.current?.abort();
abortControllerRef.current = new AbortController();
const signal = abortControllerRef.current.signal;

// Pass signal to fetch calls:
const response = await fetchWithTimeout(url, { headers, cache: "no-store", signal }, timeout, msg);
```

**Step 2: Abort on cleanup**

```typescript
useEffect(() => {
  return () => {
    abortControllerRef.current?.abort();
  };
}, []);
```

**Step 3: Apply same pattern to SeasonSocialAnalyticsSection**

**Step 4: Commit**

```bash
git add apps/web/src/components/admin/social-week/WeekDetailPageView.tsx
git add apps/web/src/components/admin/season-social-analytics-section.tsx
git commit -m "fix: add AbortController to social ingest polling loops to prevent stale updates"
```

---

## Task 9: Add Manual Retry Button After Polling Failures

When polling fails 3+ times, the UI stops polling silently. Users have no way to retry without reloading the page.

**Files:**
- Modify: `TRR-APP/apps/web/src/components/admin/social-week/WeekDetailPageView.tsx`

**Step 1: Find the polling error state**

Look for `syncPollError` state and `missingRunConsecutiveCountRef`.

**Step 2: Add retry button in error state**

```tsx
{syncPollError && (
  <div className="flex items-center gap-2 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
    <span>Polling stopped: {syncPollError}</span>
    <button
      type="button"
      onClick={() => {
        setSyncPollError(null);
        missingRunConsecutiveCountRef.current = 0;
        // Re-trigger polling
        void fetchSyncProgress();
      }}
      className="rounded border border-red-300 bg-white px-2 py-0.5 text-xs font-semibold text-red-600 hover:bg-red-50"
    >
      Retry
    </button>
  </div>
)}
```

**Step 3: Commit**

```bash
git add apps/web/src/components/admin/social-week/WeekDetailPageView.tsx
git commit -m "feat: add manual retry button when social ingest polling stops on errors"
```

---

## Task 10: Show Elapsed Time and ETA During Active Syncs

Sync operations can run 10-90+ minutes with no time feedback. Users have no idea how long to wait.

**Files:**
- Modify: `TRR-APP/apps/web/src/components/admin/social-week/WeekDetailPageView.tsx`

**Step 1: Track sync start time**

```typescript
const syncStartTimeRef = useRef<number | null>(null);

// When sync starts:
syncStartTimeRef.current = Date.now();
```

**Step 2: Show elapsed time in progress display**

```typescript
const elapsedMs = syncStartTimeRef.current ? Date.now() - syncStartTimeRef.current : 0;
const elapsedMin = Math.floor(elapsedMs / 60_000);
const elapsedSec = Math.floor((elapsedMs % 60_000) / 1000);

// In JSX:
<span className="text-xs text-zinc-400">
  {elapsedMin > 0 ? `${elapsedMin}m ${elapsedSec}s` : `${elapsedSec}s`} elapsed
</span>
```

**Step 3: Update elapsed display on each poll tick using a 1-second interval**

```typescript
const [elapsedDisplay, setElapsedDisplay] = useState("");

useEffect(() => {
  if (!syncStartTimeRef.current) return;
  const interval = setInterval(() => {
    const ms = Date.now() - (syncStartTimeRef.current ?? Date.now());
    const m = Math.floor(ms / 60_000);
    const s = Math.floor((ms % 60_000) / 1000);
    setElapsedDisplay(m > 0 ? `${m}m ${s}s` : `${s}s`);
  }, 1000);
  return () => clearInterval(interval);
}, [syncRunId]); // Reset when new sync starts
```

**Step 4: Commit**

```bash
git add apps/web/src/components/admin/social-week/WeekDetailPageView.tsx
git commit -m "feat: show elapsed time during active social ingest syncs"
```

---

## Task 11: Add Stale Data Indicator to Job Lists

When polling fails and falls back to cached data (`preserveLastGoodJobsIfEmpty`), users see stale data with no warning.

**Files:**
- Modify: `TRR-APP/apps/web/src/components/admin/social-week/WeekDetailPageView.tsx`

**Step 1: Track last successful fetch timestamp**

```typescript
const [lastJobsFetchedAt, setLastJobsFetchedAt] = useState<number | null>(null);

// On successful job fetch:
setLastJobsFetchedAt(Date.now());
```

**Step 2: Show stale data warning when data is old**

```tsx
{lastJobsFetchedAt && (Date.now() - lastJobsFetchedAt) > 30_000 && (
  <div className="text-xs text-amber-600">
    Data last refreshed {Math.floor((Date.now() - lastJobsFetchedAt) / 1000)}s ago
  </div>
)}
```

**Step 3: Commit**

```bash
git add apps/web/src/components/admin/social-week/WeekDetailPageView.tsx
git commit -m "feat: show stale data indicator when social ingest job list is outdated"
```

---

## Task 12: Add Inline Execution Timeout Guard

When the worker queue is unavailable and `allow_inline_dev_fallback=true`, the backend falls back to synchronous inline execution via `BackgroundTasks`. There's no timeout on this — it can block the API connection indefinitely.

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`

**Step 1: Find the inline execution fallback**

Search for `allow_inline_dev_fallback` or `BackgroundTasks.add_task` in the ingest flow.

**Step 2: Wrap inline execution with a timeout**

```python
import signal

def _execute_with_timeout(func, *args, timeout_seconds=600, **kwargs):
    """Execute a function with a hard timeout (10 minutes default)."""
    def _timeout_handler(signum, frame):
        raise TimeoutError(f"Inline execution exceeded {timeout_seconds}s timeout")

    old_handler = signal.signal(signal.SIGALRM, _timeout_handler)
    signal.alarm(timeout_seconds)
    try:
        return func(*args, **kwargs)
    finally:
        signal.alarm(0)
        signal.signal(signal.SIGALRM, old_handler)
```

Note: `signal.alarm` only works on the main thread. If inline execution runs in a background thread, use `threading.Timer` instead.

**Step 3: Commit**

```bash
git add trr_backend/repositories/social_season_analytics.py
git commit -m "fix: add timeout guard to inline execution fallback to prevent indefinite blocking"
```

---

## Task 13: Improve Run Finalization Race Condition Safety

`_finalize_run_status()` checks all jobs for a run and sets the run's final status. Two workers finishing their last jobs simultaneously could race on finalization.

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`

**Step 1: Find `_finalize_run_status()` (~line 5148)**

Read the current implementation.

**Step 2: Add advisory lock around finalization**

```python
def _finalize_run_status(self, run_id: str) -> str:
    with pg.db_connection() as conn:
        with pg.db_cursor(conn=conn) as cur:
            # Advisory lock keyed on run_id hash to prevent concurrent finalization
            lock_key = int(hashlib.md5(run_id.encode()).hexdigest()[:15], 16) % (2**31)
            cur.execute("SELECT pg_try_advisory_xact_lock(%s)", [lock_key])
            got_lock = cur.fetchone()[0]
            if not got_lock:
                return "running"  # Another worker is finalizing; skip
            # ... existing finalization logic ...
```

**Step 3: Commit**

```bash
git add trr_backend/repositories/social_season_analytics.py
git commit -m "fix: add advisory lock to run finalization to prevent race conditions"
```

---

## Task 14: Add Job Error Detail Expansion in UI

Job error messages are shown truncated in the UI with no way to see the full error or trace ID.

**Files:**
- Modify: `TRR-APP/apps/web/src/components/admin/season-social-analytics-section.tsx`

**Step 1: Find the job error display**

Look for where `error_message` is rendered in job rows/cards.

**Step 2: Add expandable error detail**

```tsx
const [expandedJobErrors, setExpandedJobErrors] = useState<Set<string>>(new Set());

// In job error display:
{job.error_message && (
  <div className="mt-1">
    <button
      type="button"
      onClick={() => setExpandedJobErrors((prev) => {
        const next = new Set(prev);
        next.has(job.id) ? next.delete(job.id) : next.add(job.id);
        return next;
      })}
      className="text-xs text-red-500 underline"
    >
      {expandedJobErrors.has(job.id) ? "Hide error" : "Show error"}
    </button>
    {expandedJobErrors.has(job.id) && (
      <pre className="mt-1 max-h-32 overflow-auto rounded bg-red-50 p-2 text-[10px] text-red-700">
        {job.error_message}
      </pre>
    )}
  </div>
)}
```

**Step 3: Commit**

```bash
git add apps/web/src/components/admin/season-social-analytics-section.tsx
git commit -m "feat: add expandable error details for social ingest jobs"
```

---

## Task 15: Add Cancel Sync Button for Long-Running Operations

Users cannot cancel a multi-pass comment sync or a long-running ingest. The only option is to wait for the 90-minute timeout.

**Files:**
- Modify: `TRR-APP/apps/web/src/components/admin/social-week/WeekDetailPageView.tsx`
- Modify: `TRR-Backend/api/routers/socials.py` (if cancel endpoint doesn't exist for reddit runs)

**Step 1: Add cancel button to active sync UI**

```tsx
{syncRun && ACTIVE_RUN_STATUSES.has(syncRun.status) && (
  <button
    type="button"
    onClick={() => void handleCancelSync()}
    className="rounded border border-red-300 bg-white px-2 py-1 text-xs font-semibold text-red-600 hover:bg-red-50"
  >
    Cancel Sync
  </button>
)}
```

**Step 2: Implement cancel handler**

```typescript
const handleCancelSync = async () => {
  if (!syncRunId) return;
  try {
    await fetchWithTimeout(
      `/api/admin/trr-api/social/ingest/stuck-jobs/cancel`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ run_id: syncRunId }),
      },
      15_000,
      "Cancel request timed out",
    );
    setSyncPollError("Sync cancelled by user.");
  } catch (err) {
    setSyncPollError(`Failed to cancel: ${toErrorMessage(err)}`);
  }
};
```

**Step 3: If needed, add a reddit-specific cancel endpoint in TRR-Backend**

Check if the existing stuck-jobs/cancel endpoint handles reddit refresh runs. If not, add:

```python
@router.post("/admin/socials/reddit/runs/{run_id}/cancel")
async def cancel_reddit_refresh_run(run_id: str):
    _update_run(run_id, status="cancelled", set_completed=True,
                error_message="Cancelled by user.")
    return {"status": "cancelled", "run_id": run_id}
```

**Step 4: Commit**

```bash
git add apps/web/src/components/admin/social-week/WeekDetailPageView.tsx
git add api/routers/socials.py  # if backend changes needed
git commit -m "feat: add cancel button for active social ingest syncs"
```

---

## Task 16: Parallelize sync_details Comment + Media Processing Per Post

In `sync_details` mode (`execute_refresh_run`), each post is processed sequentially: fetch comments → upsert → extract media → mirror media → update timestamp. Posts are independent and can be processed in parallel.

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/reddit_refresh.py`

**Step 1: Read the sync_details post loop (~line 2749)**

Currently iterates `for post_row in target_posts:` sequentially.

**Step 2: Wrap in ThreadPoolExecutor**

```python
def _process_single_detail_post(post_row, ...):
    """Process a single post for sync_details: comments + media."""
    # ... existing per-post logic extracted into a function ...
    return {
        "comments_upserted": n,
        "media_queued": q,
        "media_mirrored": m,
        "error": exc_or_none,
    }

detail_workers = min(4, len(target_posts)) if target_posts else 1
with ThreadPoolExecutor(max_workers=detail_workers, thread_name_prefix="detail") as pool:
    futures = {pool.submit(_process_single_detail_post, row): row for row in target_posts}
    for future in as_completed(futures):
        result = future.result()
        # Aggregate counters...
        detail_posts_done += 1
        apply_progress({...})
```

**Step 3: Commit**

```bash
git add trr_backend/repositories/reddit_refresh.py
git commit -m "perf: parallelize sync_details per-post processing (comments + media)"
```

---

## Task 17: Add Job Pagination Streaming to Frontend

`fetchJobsPages()` in WeekDetailPageView fetches up to 1000 jobs (4 pages of 250) before rendering anything. This blocks the UI.

**Files:**
- Modify: `TRR-APP/apps/web/src/components/admin/social-week/WeekDetailPageView.tsx`

**Step 1: Find `fetchJobsPages()` (~line 4558)**

**Step 2: Render incrementally after each page**

```typescript
const fetchJobsPages = async (): Promise<SocialJob[]> => {
  let offset = 0;
  let aggregated: SocialJob[] = [];
  while (aggregated.length < jobsHardCap) {
    const response = await fetchWithTimeout(...);
    const pageJobs = await response.json();
    aggregated = [...aggregated, ...pageJobs];
    // Render incrementally — show partial results immediately
    setSyncJobs([...aggregated]);
    if (pageJobs.length < jobsPageLimit) break;
    offset += jobsPageLimit;
  }
  return aggregated;
};
```

**Step 3: Commit**

```bash
git add apps/web/src/components/admin/social-week/WeekDetailPageView.tsx
git commit -m "perf: render job list incrementally as pages load instead of waiting for all"
```

---

## Task 18: Reduce Polling Aggressiveness on Season Social Page

`SeasonSocialAnalyticsSection` polls at 10-second intervals during active ingests, with each poll fetching runs + jobs + analytics. This creates 3+ API calls every 10 seconds.

**Files:**
- Modify: `TRR-APP/apps/web/src/components/admin/season-social-analytics-section.tsx`

**Step 1: Find polling interval constants (~line 906-921)**

```typescript
const ANALYTICS_POLL_REFRESH_ACTIVE_MS = 10_000; // 10 seconds
```

**Step 2: Increase active polling interval and add smart polling**

```typescript
const ANALYTICS_POLL_REFRESH_ACTIVE_MS = 20_000; // 20 seconds (was 10)

// Add: only poll runs/jobs during active ingest, skip analytics
// Analytics refresh can be manual or on longer interval (60s)
const ANALYTICS_POLL_REFRESH_IDLE_MS = 60_000; // 60 seconds (was 30)
```

**Step 3: Commit**

```bash
git add apps/web/src/components/admin/season-social-analytics-section.tsx
git commit -m "perf: reduce social analytics polling frequency to lower server load"
```

---

## Summary — Estimated Impact

| Task | Type | Impact | Effort |
|------|------|--------|--------|
| 1. Job claiming indexes | DB perf | HIGH — removes seq scans on every claim | Low |
| 2. Reddit run indexes | DB perf | HIGH — fixes dedup + queue position scans | Low |
| 3. Cache column introspection | Backend perf | MEDIUM — reduces info_schema queries | Low |
| 4. LIMIT dedup query | Backend perf | LOW — prevents unbounded scans | Low |
| 5. Scope queue position | Backend perf | MEDIUM — reduces aggregation scope | Low |
| 6. Stale detection early-exit | Backend perf | MEDIUM — skips work when nothing stale | Low |
| 7. Batch heartbeat writes | Backend perf | LOW — reduces DB write chatter | Low |
| 8. AbortController polling | Frontend fix | HIGH — prevents stale state + wasted requests | Medium |
| 9. Manual retry button | Frontend UX | HIGH — users can recover from failed polls | Low |
| 10. Elapsed time display | Frontend UX | MEDIUM — visibility into long operations | Low |
| 11. Stale data indicator | Frontend UX | MEDIUM — prevents user confusion on old data | Low |
| 12. Inline timeout guard | Backend fix | MEDIUM — prevents indefinite blocking | Low |
| 13. Run finalization lock | Backend fix | LOW — prevents rare race condition | Low |
| 14. Expandable error details | Frontend UX | MEDIUM — better debugging for admins | Low |
| 15. Cancel sync button | Frontend UX | HIGH — users can stop stuck syncs | Medium |
| 16. Parallel sync_details | Backend perf | HIGH — 3-4x faster detail scraping | Medium |
| 17. Incremental job render | Frontend perf | MEDIUM — faster perceived load time | Low |
| 18. Reduce polling frequency | Frontend perf | MEDIUM — lower server load, fewer stale races | Low |
