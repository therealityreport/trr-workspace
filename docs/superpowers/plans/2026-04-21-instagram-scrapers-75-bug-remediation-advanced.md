# Instagram Scrapers 75-Bug Remediation Implementation Plan (Advanced Copy)

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Source basis:** This document is the advanced copy of `2026-04-21-instagram-scrapers-75-bug-remediation.md`. It keeps Plan #1 as the execution base, folds in the rollout-safety improvements worth taking from Plan #2, and adds the missing repo-critical fixes required by the current `TRR-Backend` code.

**Goal:** Close the unresolved Instagram posts, media, comments, and queue/runtime defects from the 2026-04-21 inventory using the current `TRR-Backend` contracts, without inventing new job lanes or stale abstractions.

**Architecture:** Land this in dependency order. First fix the shared runtime and queue primitives that can corrupt every downstream phase. Next land the Instagram comment identity contract and update all comment and comment-media flows in the same wave. After that, run dry-run cleanup and only then enforce active-job uniqueness for post and comment media mirrors. Finish with media hardening, posts correctness, comments correctness, and a real validation/replay closeout.

**Non-goals:** Do not introduce `dedupe_key`, `parent_comment_external_id`, or a test-package reorganization. Do not create a second media metadata writer when `_update_platform_post_media_asset_meta(...)` already owns `asset_manifest`.

**Tech Stack:** Python 3.11, FastAPI, Supabase/Postgres, requests, httpx, Playwright/Patchright, Scrapling, boto3/botocore, pytest, ruff

---

## Summary

This is the approval-ready, execution-focused version of the Instagram remediation plan.

The major upgrades over the source plan are:

1. It keeps Plan #1's repo-accurate fixes, file targets, and tests as the base.
2. It adds Plan #2's strongest rollout protections: dry-run cleanup before uniqueness enforcement, explicit replay order, and apply-mode caution for repair scripts.
3. It closes one missing gap from both plans: `comment_media_mirror` still keys too much work by `comment_id` alone in the live repo, so the plan now upgrades that lane together with composite Instagram comment identity.
4. It replaces placeholder smoke verification with real local discovery of one saved Instagram account and one saved shortcode.

---

## Execution Rules

- [ ] Treat this as a backend-only remediation unless validation proves direct `TRR-APP` contract drift.
- [ ] Reuse the current stage and job-type contracts:
  - `media_mirror`
  - `comment_media_mirror`
  - `instagram_comment_media_mirror`
  - existing queue and worker claim helpers in `social_season_analytics.py`
- [ ] Keep `asset_manifest` canonical through `_update_platform_post_media_asset_meta(...)`.
- [ ] Keep `hosted_tagged_profile_pics` backward-compatible by landing tolerant readers before richer writers.
- [ ] Do not run any cleanup or replay script in apply mode before reviewing a dry-run preview.
- [ ] Do not leave the legacy global `instagram_comments.comment_id` unique constraint in place after code starts using composite identity. The schema and code switch must land in the same execution wave.

---

## File Structure

### Migrations

| Path | Responsibility |
|---|---|
| `TRR-Backend/supabase/migrations/20260421130000_scrape_jobs_active_media_mirror_uniq.sql` | Global active `media_mirror` uniqueness for Instagram posts across runs |
| `TRR-Backend/supabase/migrations/20260421130500_scrape_jobs_active_comment_media_mirror_uniq.sql` | Global active `comment_media_mirror` uniqueness for Instagram comments across runs |
| `TRR-Backend/supabase/migrations/20260421131000_instagram_comments_post_comment_unique.sql` | Composite Instagram comment uniqueness on `(post_id, comment_id)` |
| `TRR-Backend/supabase/migrations/20260421132000_instagram_comments_nullable_text_deleted_at.sql` | Nullable deleted-comment text + `deleted_at` |
| `TRR-Backend/supabase/migrations/20260421133000_instagram_comments_parent_same_post_trigger.sql` | Same-post enforcement for comment parent/child links |
| `TRR-Backend/supabase/migrations/20260421134000_hosted_tagged_profile_pics_object_shape.sql` | Metadata note and compatibility marker for richer hosted tagged-avatar objects |

### Core Backend

| Path | Responsibility |
|---|---|
| `TRR-Backend/trr_backend/repositories/social_season_analytics.py` | Queue dedupe, Instagram comment identity, media/comment-media mirroring, posts/runtime fixes, shared helper contracts |
| `TRR-Backend/trr_backend/repositories/media_assets.py` | Hosted-field validation + retry-window query correctness |
| `TRR-Backend/trr_backend/media/s3_mirror.py` | S3 client config, content sniffing helpers, temp-file safety, yt-dlp redaction |
| `TRR-Backend/trr_backend/socials/instagram/scraper.py` | Concurrent fetch contract, pagination guards, cache locking, timestamp coercion |
| `TRR-Backend/trr_backend/socials/instagram/posts_scrapling/fetcher.py` | Async client rebuild, retry stop conditions |
| `TRR-Backend/trr_backend/socials/instagram/posts_scrapling/persistence.py` | Atomic metadata merge |
| `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/fetcher.py` | Reply pagination, warmup retry/jitter, cursor semantics, rate limiting, async client rebuild |
| `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/job_runner.py` | Complete-vs-partial tree contract |
| `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/persistence.py` | Composite upsert usage + reply-marking gate |
| `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/proxy.py` | Stable proxy fingerprint shape |
| `TRR-Backend/trr_backend/socials/instagram/apify_scraper.py` | Missing-count nullability + actor timeout |
| `TRR-Backend/trr_backend/socials/instagram/permalink_metadata.py` | Auth short-circuit on fallback chain |
| `TRR-Backend/trr_backend/socials/instagram/profile_shortcode_fallback.py` | Regex bound to Instagram shortcode length |
| `TRR-Backend/trr_backend/socials/crawlee_runtime/runtime.py` | Bounded thread join and timeout propagation |
| `TRR-Backend/scripts/socials/worker.py` | Stale-worker claim reclaim + queue-loop caps |

### Operational Scripts

| Path | Responsibility |
|---|---|
| `TRR-Backend/scripts/socials/backfill_instagram_metadata_and_media.py` | Batch commit boundaries |
| `TRR-Backend/scripts/socials/repair_instagram_single_media_urls.py` | Preserve legacy source URLs before repair |
| `TRR-Backend/scripts/socials/retire_stale_instagram_media_mirror_failures.py` | Retire obsolete, non-retryable failed mirror jobs |
| `TRR-Backend/scripts/socials/retire_duplicate_instagram_media_mirror_jobs.py` | Dry-run and apply cleanup for duplicate active post-media jobs |
| `TRR-Backend/scripts/socials/retire_duplicate_instagram_comment_media_mirror_jobs.py` | Dry-run and apply cleanup for duplicate active comment-media jobs |
| `TRR-Backend/scripts/socials/backfill_instagram_profile_avatars.py` | TTL semantics for `skipped_unsupported` + object-map reader compatibility |
| `TRR-Backend/scripts/socials/instagram/comments_scrape_cli.py` | Runtime metadata whitelist + env-backed defaults |
| `TRR-Backend/docs/observability/media_mirror_alerts.md` | Operator-facing failed-backlog alert recipe |

### Tests

| Path | Responsibility |
|---|---|
| `TRR-Backend/tests/repositories/test_enqueue_platform_media_mirror_job_dedupes.py` | Cross-run post-media mirror dedupe regression |
| `TRR-Backend/tests/repositories/test_enqueue_platform_comment_media_mirror_job_dedupes.py` | Cross-run comment-media mirror dedupe regression |
| `TRR-Backend/tests/repositories/test_pg_upsert_many_composite_conflict.py` | Composite conflict clause support |
| `TRR-Backend/tests/repositories/test_instagram_comment_identity_contract.py` | Composite upsert + comment-media lookup/update identity |
| `TRR-Backend/tests/repositories/test_social_season_analytics.py` | Existing broad repository coverage extended where it already has seams |
| `TRR-Backend/tests/repositories/test_media_assets_mirroring.py` | Hosted-field validation + retry-window filtering |
| `TRR-Backend/tests/repositories/test_social_mirror_repairs.py` | Existing `asset_manifest` contract coverage |
| `TRR-Backend/tests/socials/test_instagram_scraper_concurrent_comments.py` | Structured concurrent fetch result |
| `TRR-Backend/tests/socials/test_instagram_profile_page_context_cache_threadsafety.py` | Cache lock correctness |
| `TRR-Backend/tests/socials/test_instagram_comments_scrapling.py` | Proxy, safe metadata, cursor semantics |
| `TRR-Backend/tests/socials/test_instagram_comments_scrapling_retry.py` | Async client rebuild, rate limiting, warmup retry, partial-tree behavior |
| `TRR-Backend/tests/socials/instagram/posts_scrapling/test_fetcher_retry.py` | Async client rebuild + non-retryable doc-id stop |
| `TRR-Backend/tests/socials/test_instagram_permalink_metadata.py` | Auth short-circuit |
| `TRR-Backend/tests/socials/test_instagram_profile_shortcode_fallback.py` | Regex bound |
| `TRR-Backend/tests/scripts/test_backfill_instagram_metadata_and_media.py` | Commit batch behavior |
| `TRR-Backend/tests/scripts/test_repair_instagram_single_media_urls.py` | Legacy URL preservation |
| `TRR-Backend/tests/scripts/test_backfill_instagram_profile_avatars.py` | TTL + object-shape reader compatibility |
| `TRR-Backend/tests/scripts/test_retire_stale_instagram_media_mirror_failures.py` | Stale mirror failure retirement |
| `TRR-Backend/tests/scripts/test_retire_duplicate_instagram_media_mirror_jobs.py` | Duplicate active post-media cleanup |
| `TRR-Backend/tests/scripts/test_retire_duplicate_instagram_comment_media_mirror_jobs.py` | Duplicate active comment-media cleanup |
| `TRR-Backend/tests/scripts/test_social_worker.py` | Claim/reclaim behavior |

---

## Deliberately Removed From Candidate Revisions

- The old "per-request `csrftoken` header" task stays removed because the current posts Scrapling fetcher already reads `csrftoken` fresh per call.
  Evidence: `TRR-Backend/trr_backend/socials/instagram/posts_scrapling/fetcher.py:363-370,468-473`
  Proof:

  ```python
  viewer_id = str(self._raw_cookies.get("ds_user_id") or "0")
  csrftoken = str(self._raw_cookies.get("csrftoken") or "")
  headers = _build_graphql_headers(
      referer=referer,
      csrftoken=csrftoken,
      lsd_token=self._page_tokens.get("lsd"),
      bloks_version=self._page_tokens.get("bloks_version"),
  )
  ```

  ```python
  def _merge_warmup_cookies(self, response: Any) -> None:
      new_cookies = _extract_response_cookies(response)
      self._warmup_cookie_delta = dict(new_cookies)
      for name, value in new_cookies.items():
          self._raw_cookies[name] = value
  ```
- The old unbound-`fetcher` cleanup task stays removed because the current comments Scrapling runner no longer has that shape.
  Evidence: `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/job_runner.py:95-113,193-195`
  Proof:

  ```python
  async def _run_job() -> tuple[dict[str, Any], dict[str, Any]]:
      ...
      fetcher = InstagramCommentsScraplingFetcher(
          cookies=session.cookies,
          raw_cookies=session.auth_session.cookies,
          browser_account_id=session.browser_account_id,
          proxy_config=proxy_config,
      )
      ...
      try:
          ...
      finally:
          fetcher_metadata = dict(fetcher.runtime_metadata)
          await fetcher.aclose()
  ```
- `dedupe_key` is not added; the current queue contract already has the right seam through stage-aware enqueue helpers and partial unique indexes.
- `parent_comment_external_id` is not introduced; the repo already models parent links with `parent_comment_id`, so the plan keeps that and enforces same-post integrity.
- Comments tests are not reorganized into a new package during remediation. Do not restructure existing test files unnecessarily, but add new focused test files when the concern is genuinely independent, such as reply pagination, cursor semantics, or proxy behavior.

---

## Task 1: Shared Runtime and Queue Primitive Corrections

Closes: Posts #1, Posts #2, Posts #3, Posts #4, Posts #5, Posts #8, Comments #1, Comments #11, Comments #13.

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/trr_backend/socials/crawlee_runtime/runtime.py`
- Modify: `TRR-Backend/trr_backend/socials/instagram/scraper.py`
- Modify: `TRR-Backend/trr_backend/socials/instagram/posts_scrapling/fetcher.py`
- Modify: `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/fetcher.py`
- Modify: `TRR-Backend/scripts/socials/worker.py`
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Create: `TRR-Backend/tests/socials/test_instagram_scraper_concurrent_comments.py`
- Create: `TRR-Backend/tests/socials/test_instagram_profile_page_context_cache_threadsafety.py`
- Modify: `TRR-Backend/tests/socials/instagram/posts_scrapling/test_fetcher_retry.py`
- Modify: `TRR-Backend/tests/socials/test_instagram_comments_scrapling_retry.py`
- Create when cleaner than extending existing files: `TRR-Backend/tests/socials/test_instagram_comments_scrapling_pagination.py`

**Repo evidence**
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py:10970-10976` still uses `2 ^ ...` in stale backoff.
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py:33486-33740` still claims jobs without reclaiming stale worker ownership.
- `TRR-Backend/trr_backend/socials/crawlee_runtime/runtime.py:113-128,141` still joins the worker thread without a timeout.
- `TRR-Backend/trr_backend/socials/instagram/posts_scrapling/fetcher.py:475-486` and `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/fetcher.py:390-399` still rebuild async clients synchronously.
- `TRR-Backend/trr_backend/socials/instagram/scraper.py:3064-3159` still patches `_rate_limit` and returns a plain dict from concurrent comment fetches.

### Task 1.1: Stale Retry Math

- [ ] Fix stale retry math in `recover_stale_running_jobs()` by replacing `2 ^ ...` with `power(2, ...)`.

### Task 1.2: Stale Worker Ownership Reclaim

- [ ] Update `_claim_next_jobs()` so stale worker ownership can be reclaimed when the owning worker heartbeat is old.

### Task 1.3: Bounded Crawlee Thread Join

- [ ] Bound `_run_coroutine()` with an explicit join timeout and propagate that timeout from the Crawlee runtime caller.

### Task 1.4: Queue Loop Max Jobs Cap

- [ ] Add a max-jobs cap to `scripts/socials/worker.py` queue loops.

### Task 1.5: Queue Loop Max Runtime Cap

- [ ] Add a max-runtime cap to `scripts/socials/worker.py` queue loops.

### Task 1.6: Async Client Rebuild Safety

- [ ] Convert both Instagram Scrapling `_rebuild_http_client()` helpers to async close-and-rebuild semantics and await all call sites.

### Task 1.7: Structured Concurrent Comment Fetch Result

- [ ] Replace the shared scraper's threaded `_rate_limit` monkey-patching with a structured concurrent result that reports both `comments` and `errors`.

### Task 1.8: Profile Context Cache Locking

- [ ] Lock every read/write/clear path touching `_profile_page_context_cache`.

### Task 1.9: Shared Pagination Safety Caps

- [ ] Add hard page caps, repeated-cursor guards, and wall-clock deadlines to shared comment/reply pagination.

**Acceptance criteria**
- Focused tests fail before the fix and pass after it.
- No live Instagram fetch path silently converts thread failures into empty success results.
- No queue worker can stay stuck forever inside an unbounded thread join or infinite loop.

**Verification**
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/repositories/test_social_season_analytics.py -k "stale_running_jobs or claim_next_jobs"`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/socials/instagram/posts_scrapling/test_fetcher_retry.py tests/socials/test_instagram_comments_scrapling_retry.py`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/socials/test_instagram_scraper_concurrent_comments.py tests/socials/test_instagram_profile_page_context_cache_threadsafety.py`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/socials/test_instagram_comments_scrapling_pagination.py`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && rg -n "power\\(2|join_timeout_seconds|max_jobs_per_invocation|max_run_seconds|ConcurrentCommentFetchResult|_context_cache_lock" trr_backend`

---

## Task 2: Composite Instagram Comment Identity on `(post_id, comment_id)`

Closes: Comments #5, Comments D1, Comments D2, Comments D3, plus the audit follow-up that identity fixes must include comment-media flows and not just upserts.

**Files:**
- Create: `TRR-Backend/supabase/migrations/20260421131000_instagram_comments_post_comment_unique.sql`
- Create: `TRR-Backend/supabase/migrations/20260421132000_instagram_comments_nullable_text_deleted_at.sql`
- Create: `TRR-Backend/supabase/migrations/20260421133000_instagram_comments_parent_same_post_trigger.sql`
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/persistence.py`
- Create: `TRR-Backend/tests/repositories/test_pg_upsert_many_composite_conflict.py`
- Create: `TRR-Backend/tests/repositories/test_instagram_comment_identity_contract.py`

- [ ] Extend `_pg_upsert()` and `_pg_upsert_many()` to accept either a single conflict column or a sequence of conflict columns.
- [ ] Drop the legacy `instagram_comments.comment_id` unique constraint and add a unique constraint on `(post_id, comment_id)` in the same execution wave as the code change.
- [ ] Make `text` nullable and add `deleted_at`.
- [ ] Add a DB trigger that rejects parent/child links spanning different `post_id` values.
- [ ] Patch `_upsert_instagram_comment_tree()`, `_batch_upsert_instagram_comments()`, and comments persistence helpers to upsert on `(post_id, comment_id)`.
- [ ] Patch every Instagram lookup/update path that still keys by `comment_id` alone.
- [ ] Keep parent linkage on `parent_comment_id`; do not add `parent_comment_external_id`.

**Acceptance criteria**
- The same external `comment_id` can exist on two different Instagram posts without collision.
- Parent/child mismatches across posts are rejected.
- Deleted-comment semantics can preserve row identity without a fake text placeholder.

**Verification**
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/repositories/test_pg_upsert_many_composite_conflict.py tests/repositories/test_instagram_comment_identity_contract.py`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/repositories/test_social_season_analytics.py -k "instagram_comments"`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && rg -n "conflict_col=.*post_id.*comment_id|instagram_comments_post_comment_unique|deleted_at|parent_same_post" trr_backend tests supabase/migrations`

---

## Task 3: Global Active Dedupe for `media_mirror` and `comment_media_mirror`

Closes: Media #1, Media #23, Posts #7, and the missing comment-media dedupe gap in the current repo.

**Files:**
- Create: `TRR-Backend/supabase/migrations/20260421130000_scrape_jobs_active_media_mirror_uniq.sql`
- Create: `TRR-Backend/supabase/migrations/20260421130500_scrape_jobs_active_comment_media_mirror_uniq.sql`
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Create: `TRR-Backend/tests/repositories/test_enqueue_platform_media_mirror_job_dedupes.py`
- Create: `TRR-Backend/tests/repositories/test_enqueue_platform_comment_media_mirror_job_dedupes.py`

- [ ] Rewrite `_enqueue_platform_media_mirror_job()` to use insert-first conflict handling and global active dedupe across runs for `(platform, post_id)`.
- [ ] Rewrite `_enqueue_platform_comment_media_mirror_job()` to use insert-first conflict handling and global active dedupe across runs for a stage-specific comment identity key.
- [ ] For comment-media jobs, encode the uniqueness identity as:
  - `comment_db_id` when present
  - otherwise the composite of `post_id` and `comment_id`
- [ ] Add focused concurrent tests that prove cross-run dedupe for both post and comment media mirrors.
- [ ] Keep the current stage and job-type names. Do not invent a new job lane.

**Acceptance criteria**
- Three concurrent enqueue attempts for the same active mirror target produce one active job ID.
- The dedupe works across runs, not just within a single `run_id`.

**Verification**
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/repositories/test_enqueue_platform_media_mirror_job_dedupes.py tests/repositories/test_enqueue_platform_comment_media_mirror_job_dedupes.py`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/repositories/test_social_season_analytics.py -k "enqueue_platform_media_mirror_job or enqueue_platform_comment_media_mirror_job"`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && rg -n "active_media_mirror_uniq|active_comment_media_mirror_uniq|comment_db_id|post_id" trr_backend supabase/migrations`

---

## Task 4: Preview-First Cleanup Before Uniqueness Enforcement

Closes: rollout safety gaps identified in the audit and prevents uniqueness migration failures on dirty queue data.

**Files:**
- Create: `TRR-Backend/scripts/socials/retire_duplicate_instagram_media_mirror_jobs.py`
- Create: `TRR-Backend/scripts/socials/retire_duplicate_instagram_comment_media_mirror_jobs.py`
- Create: `TRR-Backend/tests/scripts/test_retire_duplicate_instagram_media_mirror_jobs.py`
- Create: `TRR-Backend/tests/scripts/test_retire_duplicate_instagram_comment_media_mirror_jobs.py`
- Modify: `TRR-Backend/scripts/socials/retire_stale_instagram_media_mirror_failures.py`

- [ ] Add a dry-run script that reports duplicate active Instagram post-media jobs grouped by the future uniqueness key.
- [ ] Add a dry-run script that reports duplicate active Instagram comment-media jobs grouped by the future uniqueness key.
- [ ] Support apply mode only after the dry-run output is reviewed.
- [ ] Mark obsolete duplicate jobs terminal in the same way the current queue model expects, rather than deleting rows.
- [ ] Run both dry-run scripts before applying either active uniqueness migration.

**Acceptance criteria**
- Dry-run output lists the exact duplicate rows that would violate the new indexes.
- Apply mode retires duplicates without deleting queue history.

**Verification**
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/scripts/test_retire_duplicate_instagram_media_mirror_jobs.py tests/scripts/test_retire_duplicate_instagram_comment_media_mirror_jobs.py`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m scripts.socials.retire_duplicate_instagram_media_mirror_jobs --dry-run`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m scripts.socials.retire_duplicate_instagram_comment_media_mirror_jobs --dry-run`

---

## Task 5: Comment-Media Identity and Update Safety

Closes: the missing composite-identity fallout from Task 2 that the live repo still has in `_enqueue_platform_comment_media_mirror_job(...)`, `_update_platform_comment_media_mirror_fields(...)`, and `_run_generic_comment_media_mirror_stage(...)`.

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/tests/repositories/test_instagram_comment_identity_contract.py`
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`

**Prerequisite check**
- [ ] Verify `_enqueue_platform_comment_media_mirror_job(...)` still writes both `comment_db_id` and `post_id` into job config before changing downstream reload/update logic.
  Evidence today: `TRR-Backend/trr_backend/repositories/social_season_analytics.py:16694-16696,16734-16736`

- [ ] Update comment-media job config to always carry:
  - `comment_id`
  - `comment_db_id`
  - `post_id`
- [ ] Change `_update_platform_comment_media_mirror_fields(...)` so Instagram updates target:
  - `id = comment_db_id` when present
  - otherwise `comment_id = ... and post_id = ...`
- [ ] Change `_run_generic_comment_media_mirror_stage(...)` so Instagram reloads target:
  - `c.id = comment_db_id`
  - otherwise `c.comment_id = ... and c.post_id = ...`
- [ ] Preserve existing generic behavior for non-Instagram platforms unless the current schema already needs more.
- [ ] Add focused regressions that prove the correct row is updated when the same external `comment_id` exists on two different posts.

**Acceptance criteria**
- `comment_media_mirror` does not update or reload the wrong Instagram comment row after composite identity lands.
- Existing non-Instagram comment-media behavior stays intact.

**Verification**
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/repositories/test_instagram_comment_identity_contract.py tests/repositories/test_social_season_analytics.py -k "comment_media_mirror"`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && rg -n "comment_db_id|c\\.id =|c\\.comment_id = .*post_id|media_mirror_last_job_id" trr_backend/repositories/social_season_analytics.py`

---

## Task 6: Media Downloading, S3 Safety, and Repair-Script Hardening

Closes: Media #2, #3, #4, #5, #6, #7, #8, #9, #10, #11, #12, #13, #14, #15, #16, #17, #18, #19, #21, #22, #26, #27, #28, #29.

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/trr_backend/repositories/media_assets.py`
- Modify: `TRR-Backend/trr_backend/media/s3_mirror.py`
- Modify: `TRR-Backend/scripts/socials/backfill_instagram_metadata_and_media.py`
- Modify: `TRR-Backend/scripts/socials/repair_instagram_single_media_urls.py`
- Modify: `TRR-Backend/scripts/socials/backfill_instagram_profile_avatars.py`
- Modify: `TRR-Backend/tests/repositories/test_media_assets_mirroring.py`
- Modify: `TRR-Backend/tests/repositories/test_social_mirror_repairs.py`
- Modify: `TRR-Backend/tests/media/test_s3_mirror.py`
- Modify: `TRR-Backend/tests/scripts/test_backfill_instagram_metadata_and_media.py`
- Modify: `TRR-Backend/tests/scripts/test_repair_instagram_single_media_urls.py`
- Modify: `TRR-Backend/tests/scripts/test_backfill_instagram_profile_avatars.py`
- Modify: `TRR-Backend/docs/observability/media_mirror_alerts.md`
- Create when cleaner than extending existing files: `TRR-Backend/tests/repositories/test_instagram_media_mirror_pagination_and_keys.py`

**Repo evidence**
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py:12760-12784` still uses `unknown-...` fallback keys and needs the Media #16 collision fix.
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py:12744-12757` still strips only one retry prefix layer.
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py:12779-12784` still derives Instagram unknown keys from a short fallback that should be made content-addressed and post-specific.

### Task 6A: Canonical Manifest and Mirror-Key Safety

- [ ] Keep `_update_platform_post_media_asset_meta(...)` as the only canonical `asset_manifest` writer.
  TDD: extend `tests/repositories/test_social_mirror_repairs.py` so manifest assertions still flow through the existing writer path and fail if a second writer path is introduced.
- [ ] Fix Media #16 by making `_build_mirror_source_key(...)` use a collision-resistant fallback that incorporates the post UUID and normalized source URLs before returning the Instagram `unknown-...` key.
  TDD: add `tests/repositories/test_instagram_media_mirror_pagination_and_keys.py::test_build_mirror_source_key_uses_post_uuid_in_unknown_instagram_fallback` with two different post IDs sharing the same source URL and assert the fallback keys differ.

### Task 6B: Transport, Retry, and Redaction Hardening

- [ ] Add S3 write-access preflight, boto timeouts/retries, signed-URL redaction, content sniffing, and bounded temp-dir handling.
  TDD: extend `tests/repositories/test_media_assets_mirroring.py` and `tests/media/test_s3_mirror.py` to assert `head_bucket` plus a write/delete probe are required, signed query strings are stripped from logs/metadata, and wrong-content-type responses raise a hard failure.
- [ ] Re-resolve Instagram CDN 401/403/404 failures once through permalink metadata before final failure classification.
  TDD: extend `tests/repositories/test_media_assets_mirroring.py` with a case where the first CDN fetch fails `403`, permalink metadata returns refreshed media URLs, and the second download path succeeds exactly once.
- [ ] Normalize retry classification so nested prefixes such as `download_failed:ytdlp_fallback_failed:http_503` still resolve as retryable.
  TDD: add an assertion in `tests/repositories/test_media_assets_mirroring.py` that nested retry prefixes resolve to `True` for transient codes and `False` for permanent reasons.

### Task 6C: Repair Scripts and Source Preservation

- [ ] Preserve legacy media URLs before single-media repairs collapse to a primary URL.
  TDD: extend `tests/scripts/test_repair_instagram_single_media_urls.py` to assert the repaired payload carries `legacy_media_urls` and preserves them in `raw_data`.
- [ ] Commit metadata/media repair scripts in bounded batches.
  TDD: extend `tests/scripts/test_backfill_instagram_metadata_and_media.py` to assert explicit commit boundaries fire at the configured batch size and once at the end.

### Task 6D: Avatar and Failure-Retirement Hardening

- [ ] Stream avatar downloads with byte caps and TTL-aware skip semantics.
  TDD: extend `tests/scripts/test_backfill_instagram_profile_avatars.py` to assert streamed download accounting, `asset_too_large`, and TTL behavior for `skipped_unsupported`.
- [ ] Retire stale non-retryable mirror failures through the current queue semantics.
  TDD: extend `tests/scripts/test_retire_stale_instagram_media_mirror_failures.py` to assert non-retryable failures are retired and retryable failures are preserved.

**Acceptance criteria**
- `asset_manifest` still flows through the existing writer path.
- Repair scripts preserve enough source history to explain what changed.
- No signed CDN query params leak into logs or operator-facing metadata.

**Verification**
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/repositories/test_media_assets_mirroring.py tests/repositories/test_social_mirror_repairs.py tests/media/test_s3_mirror.py`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/repositories/test_instagram_media_mirror_pagination_and_keys.py`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/scripts/test_backfill_instagram_metadata_and_media.py tests/scripts/test_repair_instagram_single_media_urls.py tests/scripts/test_backfill_instagram_profile_avatars.py tests/scripts/test_retire_stale_instagram_media_mirror_failures.py`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && rg -n "_build_mirror_source_key|legacy_media_urls|head_bucket|put_object|delete_object|redact_signed_url" trr_backend scripts tests`

---

## Task 7: `hosted_tagged_profile_pics` Compatibility-Safe Shape Upgrade

Closes: Media #20, #24, #25.

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/scripts/socials/backfill_instagram_profile_avatars.py`
- Modify: `TRR-Backend/scripts/socials/repair_social_hosted_urls.py`
- Modify: `TRR-Backend/trr_backend/repositories/social_sync_orchestrator.py`
- Create: `TRR-Backend/supabase/migrations/20260421134000_hosted_tagged_profile_pics_object_shape.sql`
- Modify: `TRR-Backend/tests/repositories/test_social_mirror_repairs.py`
- Modify: `TRR-Backend/tests/scripts/test_backfill_instagram_profile_avatars.py`
- Modify: `TRR-Backend/tests/scripts/test_repair_social_hosted_urls.py`
- Modify: `TRR-Backend/tests/repositories/test_social_sync_orchestrator.py`

- [ ] Add one shared reader-normalizer that accepts both legacy string values and richer object values.
- [ ] Patch every current reader before changing any writer.
- [ ] Switch writers to object values with `hosted_url`, `sha256`, and `mirrored_at`.
- [ ] Keep legacy rows readable after the writer change.

**Acceptance criteria**
- Legacy and new rows are both readable across current repository consumers.
- No current reader assumes `dict[str, str]` after this phase lands.

**Verification**
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/repositories/test_social_mirror_repairs.py tests/scripts/test_backfill_instagram_profile_avatars.py tests/scripts/test_repair_social_hosted_urls.py tests/repositories/test_social_sync_orchestrator.py`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && rg -n "hosted_tagged_profile_pics|hosted_url|sha256|mirrored_at" trr_backend scripts tests`

---

## Task 8: Posts Contract Corrections

Closes: Posts #9, #10, #12, #13, #14, #15, #16, #17, #18, #19.

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/trr_backend/socials/instagram/posts_scrapling/persistence.py`
- Modify: `TRR-Backend/trr_backend/socials/instagram/posts_scrapling/fetcher.py`
- Modify: `TRR-Backend/trr_backend/socials/instagram/profile_shortcode_fallback.py`
- Modify: `TRR-Backend/trr_backend/socials/instagram/apify_scraper.py`
- Modify: `TRR-Backend/trr_backend/socials/instagram/permalink_metadata.py`
- Modify: `TRR-Backend/trr_backend/socials/instagram/scraper.py`
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Modify: `TRR-Backend/tests/socials/instagram/posts_scrapling/test_fetcher_retry.py`
- Modify: `TRR-Backend/tests/socials/test_instagram_permalink_metadata.py`
- Modify: `TRR-Backend/tests/socials/test_instagram_profile_shortcode_fallback.py`

- [ ] Bound shortcode parsing to the real Instagram shortcode length.
- [ ] Normalize missing Apify counts as `None`, not fake zeros.
- [ ] Stop retry loops on the first non-retryable GraphQL failure.
- [ ] Short-circuit permalink fallback on auth failures instead of walking the rest of the chain.
- [ ] Replace the non-atomic metadata merge in post persistence with a single SQL merge update.

**Acceptance criteria**
- Posts persistence and fetchers stop lying about retryability, shortcode extraction, and metric nullability.

**Verification**
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/socials/instagram/posts_scrapling/test_fetcher_retry.py tests/socials/test_instagram_permalink_metadata.py tests/socials/test_instagram_profile_shortcode_fallback.py`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/repositories/test_social_season_analytics.py -k "persist_instagram_posts or metadata or catalog"`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && rg -n "graphql_empty_connection|auth_short_circuit|post_comment_unique|metadata =\\s*coalesce\\(metadata" trr_backend`

---

## Task 9: Comments Completeness, Pagination, Transport, and CLI Hardening

Closes: Comments #2, #3, #6, #7, #8, #9, #10, #12, #14, #15, #16, #17, #18, #19.

**Files:**
- Modify: `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/fetcher.py`
- Modify: `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/job_runner.py`
- Modify: `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/persistence.py`
- Modify: `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/proxy.py`
- Modify: `TRR-Backend/scripts/socials/instagram/comments_scrape_cli.py`
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/tests/socials/test_instagram_comments_scrapling.py`
- Modify: `TRR-Backend/tests/socials/test_instagram_comments_scrapling_retry.py`
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Create when cleaner than extending existing files: `TRR-Backend/tests/socials/test_instagram_comments_scrapling_pagination.py`
- Create when cleaner than extending existing files: `TRR-Backend/tests/socials/test_instagram_comments_scrapling_proxy.py`

- [ ] Extend `InstagramCommentsFetchResult` with `reply_fetch_failed`.
- [ ] Preserve the first non-empty `fetch_reason` instead of overwriting it later.
- [ ] Support both `next_min_id` and `next_max_id` semantics for top-level pagination and dual-direction cursors for replies.
- [ ] Stop marking replies missing when `fetch_replies=false` or when reply fetches failed/incomplete.
- [ ] Add explicit request gating, warmup retry/jitter, stable proxy fingerprints, and safe runtime metadata filtering.
- [ ] Keep comment media follow-ups behind `comments_enable_media_followups` and only set pending mirror fields when both required schema columns exist.

**Acceptance criteria**
- Partial or reply-skipped runs do not claim comment-tree completeness they did not earn.
- CLI/runtime metadata stays cookie-safe.

**Verification**
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/socials/test_instagram_comments_scrapling.py tests/socials/test_instagram_comments_scrapling_retry.py tests/socials/test_instagram_comments_scrapling_pagination.py tests/socials/test_instagram_comments_scrapling_proxy.py`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/repositories/test_social_season_analytics.py -k "mark_missing_comments_for_anchor or instagram_comments"`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && rg -n "reply_fetch_failed|next_max_id|next_min_id|SAFE_RUNTIME_META_KEYS|_fingerprint_from_gateway" trr_backend scripts`

---

## Task 10: Timestamp Nullability, Final Validation, and Bounded Replay

Closes: Comments D4, test-gap closure, and operator-facing closeout.

**Files:**
- Modify: `TRR-Backend/trr_backend/socials/instagram/scraper.py`
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify tests only where current assertions incorrectly expect `0` instead of `None`

- [ ] Make timestamp coercion return `None` for unparseable values instead of collapsing them to zero.
- [ ] Run full backend validation:
  - `ruff check .`
  - `ruff format --check .`
  - `pytest -q`
  - `make schema-docs-check`
- [ ] Discover one real saved Instagram account and one real saved shortcode from the local DB or catalog before smoke validation. Do not use placeholder shortcodes.
- [ ] Run smoke commands with real discovered values:
  - posts Scrapling smoke against a real account
  - comments scrape CLI against a real saved shortcode
  - backfill dry-run for Instagram media mirror jobs
- [ ] Replay in this exact order after validation:
  1. posts materialization/detail repair
  2. post-media repair/backfill
  3. comments rescrape
  4. comment-media mirror replay
- [ ] Use `fetch_replies=true` for any replay scope where reply lifecycle truth matters.

**Acceptance criteria**
- Validation passes with committed intended drift only.
- Smoke commands use real local data and do not leak signed CDN params or cookie secrets.
- Replay order avoids reintroducing stale comment-media assumptions before comments are repaired.

**Verification**
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ruff check . && ruff format --check . && pytest -q && make schema-docs-check`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m scripts.socials.instagram.smoke_posts_scrapling --account <real_account> --limit 10`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m scripts.socials.instagram.comments_scrape_cli --account <real_account> --shortcode <real_saved_shortcode> --max-comments 5`
- `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m scripts.socials.backfill_social_media_mirror_jobs --platform instagram --dry-run`

---

## Closeout Checklist

- [ ] Apply migrations in order, with schema cache reloads after each migration wave.
- [ ] Review duplicate-job dry-runs before applying active uniqueness indexes.
- [ ] Keep cleanup and replay outputs in operator-readable form.
- [ ] Stage and commit each task wave separately with repo-accurate commit messages.
- [ ] Run `./scripts/handoff-lifecycle.sh closeout` after the final validation wave.

---

## Self-Review

**Spec coverage**

- Shared runtime and queue correctness: covered by Task 1.
- Composite Instagram comment identity and same-post parent guarantees: covered by Task 2.
- Cross-run active dedupe for both post and comment media mirrors: covered by Tasks 3 and 4.
- Media downloader, S3, avatar, manifest, redaction, and repair scripts: covered by Tasks 6 and 7.
- Posts/runtime correctness: covered by Task 8.
- Comments/runtime correctness: covered by Task 9.
- Timestamp/nullability, validation, and bounded replay: covered by Task 10.

**Placeholder scan**

- No placeholder shortcodes remain in the execution plan. Final smoke validation requires local discovery of a real saved account and shortcode before running.
- No "similar to Task N" placeholders remain.

**Type consistency**

- Instagram comment identity is consistently keyed by `(post_id, comment_id)`.
- `comment_media_mirror` is explicitly upgraded to prefer `comment_db_id`, then `(post_id, comment_id)`.
- `hosted_tagged_profile_pics` reader compatibility lands before richer writer output.
- Async `_rebuild_http_client()` behavior is treated consistently in both posts and comments fetchers.

**Execution handoff**

- This document is the advanced copy to implement from.
- Preserve the original file as historical reference; execute from this copy.
