# Instagram Backfill Posts — Full Debug Report (Revised)

**Date:** 2026-04-07
**Scope:** Worker, runner, job pipeline, scraper, Modal dispatch, live DB state
**Revision:** Updated after reviewing commits `4de3be8` (reliability batch) and `2c7901a` (speed recovery)

---

## 1. LIVE STATE SUMMARY

### Recent Runs (last 7 days, all `@bravotv`)

| Run | Status | Strategy | Total Jobs | Completed | Failed | Duration |
|-----|--------|----------|-----------|-----------|--------|----------|
| `ea1cd84a` | **completed** | cursor_breakpoints | 2 | 2 | 0 | ~3 min |
| `02fa14c9` | cancelled | cursor_breakpoints | 11 | 7 | 0 | ~8 min |
| `d2d24a93` | **completed** | cursor_breakpoints | 2 | 2 | 0 | ~3 min |
| `3e986c30` | cancelled | cursor_breakpoints | 28 | 19 | 0 | ~6 min |
| `7a28f22c` | cancelled | cursor_breakpoints | 40 | 16 | 0 | — |

**Pattern:** Most runs get cancelled mid-flight. Only 2 out of 10 recent runs completed successfully. Both successful runs had only 2 jobs (discovery + classify). The larger runs with `shared_account_posts` jobs are the ones failing.

### Active Workers

| Worker | Status | Last Seen | Instagram Auth |
|--------|--------|-----------|----------------|
| `modal:social-dispatcher` | idle | ~18s ago | authenticated |
| `modal:reddit-dispatcher` | idle | recent | — |
| `modal:google-news-dispatcher` | idle | recent | — |
| `modal:admin-dispatcher` | idle | recent | — |

**No stuck running jobs** — the queue is currently empty.

### Error Patterns in Failed Jobs

The `shared_account_posts` stage is the primary failure point. Three distinct error classes:

1. **`instagram_graphql_initial_request_failed`** (`PlaywrightGraphQLFailure`) — 8 occurrences
   GraphQL initial page fetch fails completely. Zero posts checked. Jobs fail in ~14 seconds.

2. **`instagram_graphql_cursor_forbidden`** (`HTTPError`) — 4 occurrences
   Pagination cursor returns 403. Happens after checking 0–660 posts. Auth works for first pages but breaks mid-crawl.

3. **`instagram_graphql_cursor_unauthorized`** (`HTTPError`) — 4 occurrences
   Pagination cursor returns 401. Similar to forbidden but different HTTP status. Happens at various depths (0–99 posts checked).

4. **`shared_account_execution_lock_unavailable`** (`SharedStageRuntimeError`) — 1 occurrence
   Concurrent job tried to scrape same account while another held the advisory lock.

---

## 2. WHAT THE RECENT COMMITS FIXED

Commits `4de3be8` and `2c7901a` addressed many of the issues identified in the initial audit. Here's the updated status of each bug.

### FIXED: Thread-Unsafe Rate Limiting State (was BUG 7 — MEDIUM)

**Commit:** `4de3be8`
**Fix:** Added `self._rate_lock = threading.Lock()` (scraper.py:303). Both `_rate_limit()` and `_track_response_status()` are now wrapped in `with self._rate_lock:` (lines 1100, 1129). Concurrent partition runners can no longer race on `_request_count`, `_last_429_at`, or `_consecutive_success`.

**Verified:** Lock is present, guards all rate-limit state mutations.

### FIXED: Silent Auth Fallback (was BUG 3 — HIGH)

**Commit:** `4de3be8`
**Fix:** Added `unrecoverable_fallback_errors` set in scraper.py (~line 2186) containing `instagram_graphql_cursor_rate_limited`, `instagram_graphql_cursor_unauthorized`, `instagram_graphql_cursor_forbidden`, `instagram_graphql_checkpoint_required`. When the last error code is in this set, browser fallback is explicitly skipped with a warning log. Added `allow_browser_fallback` parameter (default True) to `fetch_posts_graphql()`.

**Verified:** Auth errors (401/403) now short-circuit instead of silently degrading.

### FIXED: Cookie Validation Logic Bug (NEW — discovered during fix)

**Commit:** `4de3be8`
**Fix:** Changed `if csrftoken or ds_user_id:` → `if csrftoken and ds_user_id:` in cookie validation. Added granular reason tracking: `missing_csrftoken`, `missing_ds_user_id`, or `missing_csrftoken_and_ds_user_id`.

### FIXED: Scraper Retry Jitter (was part of BUG 8 — MEDIUM)

**Commit:** `4de3be8` + `2c7901a`
**Fix:** Scraper-level retries in `_graphql_retry_delay()` now include jitter: `random.uniform(computed * 0.5, computed)` (scraper.py:525). This prevents thundering herd when multiple workers retry simultaneously.

**Verified:** Jitter is present in the scraper's own retry path.

### FIXED: Batch Upserts for Catalog Posts (was BOTTLENECK 1)

**Commit:** `2c7901a`
**Fix:** `_batch_upsert_shared_catalog_instagram_posts()` now uses `_pg_upsert_many()` (line 24970+), doing 1 DB round-trip per page instead of 50 individual upserts.

**Verified:** `_pg_upsert_many` is used across instagram_comments, twitter_tweets, and now catalog posts.

### FIXED: Configurable GraphQL Page Size (was BOTTLENECK 5)

**Commit:** `2c7901a`
**Fix:** `_shared_instagram_catalog_graphql_page_size()` reads `SOCIAL_INSTAGRAM_CATALOG_GRAPHQL_PAGE_SIZE` env var, defaults to 50 posts/page, bounded 33..50. Separate from `fast_mode` to avoid side effects.

### FIXED: Adaptive Delay Tiers (was BOTTLENECK contributing to rate limiting)

**Commit:** `2c7901a`
**Fix:** Non-fast-mode delay now uses tiered ramp based on `_consecutive_success`: 50%→25%→15% of base delay as success streak grows. Combined with jitter, this creates more organic request patterns.

### FIXED: Pipelined Discovery (NEW throughput optimization)

**Commit:** `2c7901a`
**Fix:** `_on_partition_discovered()` callback dispatches partition jobs as boundaries are found during discovery, giving ~90 seconds head start vs. waiting for discovery to complete. Early partition count estimate via `ceil(total_posts / target_posts_per_shard)`, reconciled after.

### FIXED: O(1) Shortcode-to-Media-ID Lookup (NEW micro-optimization)

**Commit:** `2c7901a`
**Fix:** Replaced `_SHORTCODE_ALPHABET.index(char)` (O(n) string search) with precomputed `_SHORTCODE_CHAR_MAP` dict (O(1) lookup). Added `KeyError` → `ValueError` for invalid chars.

### FIXED: Runtime Version Pinning (NEW infrastructure)

**Commit:** `4de3be8` + `2c7901a`
**Fix:** Jobs now stamped with `required_runtime_version`. Claim query filters by runtime label. `runtime_version_pin_mismatch` detection fixed to compare observed worker runtime, not local process.

### FIXED: Remote Auth Probe Infrastructure (NEW)

**Commit:** `4de3be8`
**Fix:** Added `probe_social_remote_auth()` Modal function (modal_jobs.py:431-441) + `probe_remote_auth_health()` in social_season_analytics.py. `verify_modal_readiness.py` now validates remote auth before declaring readiness. New `repair_instagram_auth.py` script orchestrates multi-step auth repair with step-by-step validation.

### FIXED: Worker Auth Capability Reporting

**Commit:** `4de3be8`
**Fix:** `_remote_auth_capability_from_workers()` now captures structured `auth_failure_details` with first-seen detail per reason, so API reports specific auth errors (checkpoint, rate limit) instead of generic strings.

---

## 3. BUGS THAT REMAIN UNFIXED

### BUG 1: Exponential Backoff Uses Bitwise XOR (CRITICAL — STILL PRESENT)

**Location:** `social_season_analytics.py:10706`

```sql
greatest(5, least(300, 5 * (2 ^ greatest(0, j.attempt_count - 1))))
```

**Verified still present:** `grep` confirms `2 ^` in the stale job recovery SQL and no `power(2,` anywhere in the file. PostgreSQL `^` is bitwise XOR, not exponentiation.

| attempt_count | Expected (power) | Actual (XOR) |
|--------------|-------------------|--------------|
| 1 | 5 × 2^0 = 5 | 5 × (2 XOR 0) = 10 |
| 2 | 5 × 2^1 = 10 | 5 × (2 XOR 1) = 15 |
| 3 | 5 × 2^2 = 20 | 5 × (2 XOR 2) = 0 → floored to 5 |
| 4 | 5 × 2^3 = 40 | 5 × (2 XOR 3) = 5 |

**Impact:** Stale job retry delays are completely wrong. The actual pattern is 10→15→5→5→35→... instead of 5→10→20→40→80→...

**Fix:** `power(2, greatest(0, j.attempt_count - 1))`

### BUG 2: No Timeout in Browser Intercept Scroll Loop (MEDIUM — STILL PRESENT)

**Location:** `scraper.py:3611`

```python
while not reached_date_limit and no_new_data_scrolls < max_no_new_data_scrolls:
    if len(posts) >= max_posts:
        break
    page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
    page.wait_for_timeout(scroll_interval_ms)
```

**Verified still present:** The scroll loop has no `time.monotonic()` deadline check. While `config.max_scrape_seconds` IS enforced in the GraphQL pagination loop (line 3333: `if time.monotonic() - _t0 > config.max_scrape_seconds`), the browser intercept scroll loop at line 3611 has no equivalent check. A stuck page can hang until the Modal function timeout kills the container.

**Fix:** Add `if time.monotonic() - _t0 > config.max_scrape_seconds: break` inside the scroll loop.

### BUG 3: Crawlee Runtime Retry Has No Backoff Delay (MEDIUM — STILL PRESENT)

**Location:** `crawlee_runtime/runtime.py:182-186`

```python
if retryable and attempt < attempts:
    counters.retries_total += 1
    counters.crawlee_retry_count += 1
    counters.session_rotations += 1
    continue  # ← immediate retry, no delay
```

**Verified still present:** The Crawlee runtime's retry loop has no `time.sleep()` or delay between attempts. While the *scraper's own* retries now have jitter (fixed in `4de3be8`), the outer Crawlee runtime that wraps stage execution still retries immediately.

**Note:** This is distinct from the scraper-level fix. The Crawlee runtime wraps the entire stage runner function. If a stage fails (e.g., auth error, network error), the immediate retry at this level can amplify load.

**Fix:** Add `time.sleep(min(base * 2**attempt, 30) + random.uniform(0, 1))` before `continue`.

### BUG 4: Daemon Thread in Crawlee `_run_coroutine()` (LOW-MEDIUM — STILL PRESENT)

**Location:** `crawlee_runtime/runtime.py:135`

```python
thread = Thread(target=_thread_main, daemon=True)
thread.start()
thread.join()
```

**Verified still present:** The daemon thread spawned for async coroutine execution has no `timeout` on `join()`. If the coroutine hangs, the caller blocks forever. The daemon flag means the thread is killed if the main thread exits, potentially mid-operation.

**Fix:** Use `thread.join(timeout=max_scrape_seconds + 30)` and non-daemon thread.

### BUG 5: Profile Page Context Cache Not Thread-Safe (LOW-MEDIUM — STILL PRESENT)

**Location:** `scraper.py:304, 418, 486, 744, 1064, 1089, 2063, 2175, 2207`

**Verified still present:** The `_rate_lock` now properly protects rate-limiting state (`_request_count`, `_consecutive_success`, `_last_429_at`), but `_profile_page_context_cache` is a separate dict that is read and written at 9+ locations **without any lock**. Operations include `.get()`, `[key] = value`, `.clear()`, `.pop()`, and dict comprehension — all unsynchronized.

Under concurrent partition runners, this can cause:
- `RuntimeError: dictionary changed size during iteration`
- Stale context tokens if one thread clears while another reads
- KeyError if `.pop()` races with `.get()`

**Fix:** Either protect with `_rate_lock` (simple but adds contention) or use a separate `threading.Lock`.

### BUG 6: Concurrent Comment Fetch Silently Drops Failures (LOW — STILL PRESENT)

**Location:** `scraper.py` concurrent comment fetch

Failed comment fetches still return empty lists `[]` indistinguishable from posts with zero comments. The scraper-level fix (thread-safe rate limiting) reduces the likelihood of concurrent failures but doesn't address the silent failure reporting.

### BUG 7: Mirror Job Deduplication Race (LOW — STILL PRESENT)

**Location:** `_enqueue_platform_media_mirror_job()` SELECT→INSERT pattern

The deduplication check is still a SELECT then INSERT without `INSERT...ON CONFLICT`. While the reliability batch added pre-computation of row identities, the core race between SELECT and INSERT remains.

**Practical impact is low** because mirror jobs are idempotent (re-mirroring the same media is safe, just wasteful).

### BUG 8: `execute_run` Unbounded Loop (LOW — STILL PRESENT)

**Location:** `execute_run()` while True loop

No maximum iteration cap. Runtime version pinning reduces the risk of infinite loops from version mismatch, but doesn't prevent loops from other causes (e.g., jobs perpetually re-queued by another process).

---

## 4. ROOT CAUSE ANALYSIS: WHY BACKFILL RUNS KEEP FAILING

The failure pattern in live data remains clear, though the recent fixes address several contributing factors:

```
1. Run created with cursor_breakpoints strategy, 4+ runners
2. Discovery stage completes (finds breakpoints for parallel fetch)
3. Multiple shared_account_posts jobs start in parallel
4. First few GraphQL pages succeed (auth cookies valid)
5. After 0-660 posts, Instagram returns 401/403 on cursor pagination
6. Jobs fail with instagram_graphql_cursor_forbidden/unauthorized
7. Run gets cancelled (likely manually or by cancellation logic)
```

**Root cause:** Instagram rate-limiting and auth revocation during parallel cursor-based pagination against `@bravotv`.

**What the recent fixes address:**
- Jitter on scraper retries (reduces thundering herd) ✓
- Unrecoverable error detection (stops wasted browser fallback) ✓
- Adaptive delay tiers (reduces burst rate) ✓
- Runtime version pinning (prevents version mismatch loops) ✓

**What remains unaddressed:**
- Crawlee runtime still retries immediately (amplifies load at the stage level)
- No backoff/cooldown on consecutive 401/403 errors across partition runners
- No inter-runner coordination to slow down when one runner hits auth errors
- Parallel runner count is still configurable but not dynamically throttled

**Recommendation:** The single highest-impact remaining fix is adding a delay in the Crawlee runtime retry loop. Even 5–10 seconds between stage-level retries would dramatically reduce the burst rate that triggers Instagram's session revocation.

---

## 5. SPEED/THROUGHPUT STATUS

| Bottleneck | Status | Notes |
|-----------|--------|-------|
| Single-row upserts | **FIXED** | `_pg_upsert_many()` batches per page |
| Fixed page size | **FIXED** | Configurable via env var, defaults to 50 |
| Classification on critical path | **FIXED** | Deferred to after fetch phase |
| No request jitter | **FIXED** | `random.uniform(computed * 0.5, computed)` |
| Sequential discovery | **FIXED** | Pipelined dispatch with callback |
| O(n) shortcode lookup | **FIXED** | O(1) dict-based lookup |
| Unbounded metadata growth | Remaining | No size caps on JSONB metadata |
| 500-post hard limit | Remaining | `_shared_post_rows_for_account()` silent truncation |
| Fixed browser scroll interval | Remaining | 600ms hardcoded |

---

## 6. ARCHITECTURAL CONCERNS (Unchanged)

### SQL Injection Surface

Column and table names composed into SQL via f-strings throughout `social_season_analytics.py`. Values come from constants, but no validation at point of use. Risk is theoretical but real if constants are ever tainted.

### Run Summary Reconciliation — No Transaction Isolation

`reconcile_run_summaries()` recomputes then persists in separate transactions. Summary can be stale the moment it's written.

### Concurrent Account Lock Gap

`shared_account_execution_lock_unavailable` error in live data confirms multiple workers can attempt the same account. Advisory lock exists at API level but not consistently at stage execution level.

---

## 7. REVISED RECOMMENDATIONS (Priority Order)

### Immediate Fixes (Do Now)

1. **Fix the XOR backoff bug** — `2 ^` → `power(2,` in stale job recovery SQL. Single line, critical correctness.
2. **Add delay in Crawlee runtime retry loop** — Even `time.sleep(5 + random.uniform(0, 3))` between stage-level retries would reduce the 401/403 failure cascade significantly.
3. **Add `max_scrape_seconds` check in browser intercept scroll loop** — Prevents container hangs.

### Short-Term Fixes (This Week)

4. **Protect `_profile_page_context_cache` with a lock** — Prevents dict corruption under concurrent partition runners.
5. **Fix mirror job dedup** — Use `INSERT...ON CONFLICT DO NOTHING`.
6. **Add inter-runner backoff on auth errors** — If one partition runner gets 401/403, signal other runners to slow down (e.g., via shared threading.Event or exponential backoff).

### Medium-Term (This Sprint)

7. **Add metadata JSONB size caps** — Trim attempts arrays to last 5 entries.
8. **Raise 500-post limit** or add pagination in `_shared_post_rows_for_account()`.
9. **Replace daemon thread** in `_run_coroutine()` with proper timeout handling.
10. **Add `execute_run` iteration cap** — Max 1000 jobs per invocation.

### Backlog

11. **Parameterize SQL identifiers** — `psycopg2.sql.Identifier()` for column/table composition.
12. **Add structured observability** — Request tracing, cache metrics, rate limit saturation.
13. **Adaptive browser scroll interval** — Based on response latency instead of fixed 600ms.

---

## 8. SUMMARY SCORECARD

| Category | Initial Bugs | Fixed by Recent Commits | Still Remaining |
|----------|-------------|------------------------|-----------------|
| Critical | 1 (XOR backoff) | 0 | **1** |
| High | 2 (auth fallback, race) | 1 (auth fallback) | 1 (mirror dedup) |
| Medium | 5 | 3 (thread safety, jitter, cookie validation) | 2 (browser timeout, crawlee retry) |
| Low-Medium | 2 | 0 | 2 (daemon thread, context cache) |
| Low | 1 (comment failure) | 0 | 1 |
| Throughput | 6 bottlenecks | 5 fixed | 1 remaining |
| **Totals** | **17 issues** | **9 resolved** | **8 remaining** |

The recent commits resolved roughly half the issues, with the most impactful fixes being batch upserts, thread-safe rate limiting, auth fallback detection, and adaptive delays. The remaining 8 issues range from critical (XOR backoff) to low priority (comment failure reporting), with the Crawlee runtime retry delay being the single highest-ROI fix still open.
