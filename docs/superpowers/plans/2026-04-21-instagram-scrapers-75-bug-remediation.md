# Instagram Scrapers 75-Bug Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the unresolved Instagram posts, media, and comments bugs from the 2026-04-21 inventory using the current `TRR-Backend` contracts, with safe schema sequencing, repo-accurate tests, and no stale-task drift.

**Architecture:** Land this in dependency order. First lock the database and queue contracts: global active media-mirror dedupe for any local Instagram account/run, and verification that the deployed Modal comments lane is actually running the repo's landed composite Instagram comment identity contract keyed by `(post_id, comment_id)`. Then harden shared primitives already used by multiple lanes. After that, fix media/download correctness, then posts/runtime correctness, then comments/runtime correctness, and finish with focused coverage plus operator-facing validation. Reuse existing writer paths such as `_update_platform_post_media_asset_meta(...)`; do not create duplicate contracts when the repo already has one.

**Tech Stack:** Python 3.11, FastAPI, Supabase/Postgres, requests, httpx, Playwright/Patchright, Scrapling, boto3/botocore, pytest, ruff

---

## Summary

This is the updated execution plan after auditing the original draft against the current repo.

The major corrections are:

1. Active Instagram media-mirror dedupe is **global across runs** for local execution. If any local Instagram account is added and run, only one active mirror job may exist per `(platform, post_id)`.
2. Instagram comment identity work is widened beyond upserts. Every lookup/update path that still keys by `comment_id` alone must be patched in the same phase.
3. Stale tasks were removed or rewritten. This plan does **not** re-fix already-fixed `csrftoken` behavior in posts Scrapling, and it does **not** keep the old unbound-`fetcher` cleanup task for comments Scrapling.
4. Existing repo contracts stay canonical. `asset_manifest` continues to flow through `_update_platform_post_media_asset_meta(...)`; the plan verifies and strengthens that path instead of inventing a second writer.
5. `hosted_tagged_profile_pics` shape upgrades are still included, but only after adding downgrade-safe readers across the current repo.
6. The 2026-04-21 `InvalidColumnReference` / `ON CONFLICT` failure in full-account Instagram comments syncs was **not** a missing database constraint. `social.instagram_comments` already has `instagram_comments_post_comment_unique` in the live schema and current repo code. The failing runs were executing stale deployed Modal code until `trr_backend.modal_jobs` was redeployed.
7. Comments-lane validation now has an explicit runtime sequence: `scripts/modal/verify_modal_readiness.py`, redeploy `trr_backend.modal_jobs`, run a one-shortcode remote comments diagnostic, then run the full-account comments sync. The old plan skipped the deploy-drift proof step.
8. The active remaining blocker in the comments lane is remote browser warmup instability, currently surfacing as `Page.goto: net::ERR_TIMED_OUT` against `https://www.instagram.com/`. Task 11 is rewritten to harden and classify that path instead of treating `ON CONFLICT` as the open issue.

## File Structure

### Migrations

| Path | Responsibility |
|---|---|
| `TRR-Backend/supabase/migrations/20260421130000_scrape_jobs_active_media_mirror_uniq.sql` | Global active media-mirror uniqueness for local runs |
| `TRR-Backend/supabase/migrations/20260421131000_instagram_comments_post_comment_unique.sql` | Composite Instagram comment uniqueness |
| `TRR-Backend/supabase/migrations/20260421132000_instagram_comments_nullable_text_deleted_at.sql` | Nullable deleted-comment text + `deleted_at` |
| `TRR-Backend/supabase/migrations/20260421133000_instagram_comments_parent_same_post_trigger.sql` | Same-post enforcement for comment parent/child links |
| `TRR-Backend/supabase/migrations/20260421134000_hosted_tagged_profile_pics_object_shape.sql` | Backfill metadata marker for richer hosted tagged-avatar objects |

### Core Backend

| Path | Responsibility |
|---|---|
| `TRR-Backend/trr_backend/repositories/social_season_analytics.py` | Queue dedupe, comment identity, media mirroring, posts/runtime fixes, shared helper contracts |
| `TRR-Backend/trr_backend/repositories/media_assets.py` | Hosted-field validation + retry-window query correctness |
| `TRR-Backend/trr_backend/media/s3_mirror.py` | S3 client config, MIME sniffing helpers, yt-dlp log redaction |
| `TRR-Backend/trr_backend/socials/instagram/scraper.py` | Concurrent fetch contract, comment pagination guards, cache locking, timestamp coercion |
| `TRR-Backend/trr_backend/socials/instagram/posts_scrapling/fetcher.py` | Async client rebuild, non-retryable GraphQL fallback stop conditions |
| `TRR-Backend/trr_backend/socials/instagram/posts_scrapling/persistence.py` | Atomic metadata merge |
| `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/fetcher.py` | Reply pagination, warmup retry/jitter, cursor echo, rate limiting, async client rebuild |
| `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/job_runner.py` | Complete-vs-partial tree contract |
| `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/persistence.py` | Composite upsert usage + reply-marking gate |
| `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/proxy.py` | Stable proxy fingerprint shape |
| `TRR-Backend/trr_backend/socials/instagram/apify_scraper.py` | Missing-count nullability + actor timeout |
| `TRR-Backend/trr_backend/socials/instagram/permalink_metadata.py` | Auth short-circuit on fallback chain |
| `TRR-Backend/trr_backend/socials/instagram/profile_shortcode_fallback.py` | Regex bound to IG shortcode length |
| `TRR-Backend/trr_backend/socials/crawlee_runtime/runtime.py` | Bounded thread join after explicit timeout plumbing |
| `TRR-Backend/scripts/socials/worker.py` | Stale-worker claim reclaim + queue-loop verification |
| `TRR-Backend/trr_backend/socials/control_plane/dispatch_runtime.py` | Claim-path reuse verification only if needed |
| `TRR-Backend/trr_backend/modal_jobs.py` | Deployed Modal job entrypoints and browser image bindings for social lanes |
| `TRR-Backend/trr_backend/modal_dispatch.py` | Stage-to-function resolution and operator-visible Modal dispatch metadata |

### Operational Scripts

| Path | Responsibility |
|---|---|
| `TRR-Backend/scripts/socials/backfill_instagram_metadata_and_media.py` | Batch commit boundaries |
| `TRR-Backend/scripts/socials/repair_instagram_single_media_urls.py` | Preserve legacy source URLs before repair |
| `TRR-Backend/scripts/socials/retire_stale_instagram_media_mirror_failures.py` | Retire obsolete, non-retryable failed mirror jobs |
| `TRR-Backend/scripts/socials/backfill_instagram_profile_avatars.py` | TTL semantics for `skipped_unsupported` + object-map reader compatibility |
| `TRR-Backend/scripts/socials/instagram/comments_scrape_cli.py` | Runtime metadata whitelist + env-backed defaults |
| `TRR-Backend/scripts/modal/verify_modal_readiness.py` | Verify deployed Modal app/functions before live Instagram comments validation |
| `TRR-Backend/scripts/modal/diagnose_instagram_comments_remote.py` | One-shortcode remote comments probe that distinguishes stale deploys from live browser failures |
| `TRR-Backend/scripts/modal/repair_instagram_auth.py` | Existing auth repair sequence reused when comments warmup points to remote session drift |
| `TRR-Backend/docs/observability/media_mirror_alerts.md` | Operator-facing failed-backlog alert recipe |

### Tests

| Path | Responsibility |
|---|---|
| `TRR-Backend/tests/repositories/test_enqueue_platform_media_mirror_job_dedupes.py` | Cross-run mirror dedupe regression |
| `TRR-Backend/tests/repositories/test_instagram_comment_identity_contract.py` | Live composite identity contract and downstream comment lookup/update identity |
| `TRR-Backend/tests/repositories/test_social_season_analytics.py` | Existing broad repository coverage extended where it already has seams |
| `TRR-Backend/tests/repositories/test_media_assets_mirroring.py` | Hosted-field validation + retry-window filtering |
| `TRR-Backend/tests/repositories/test_social_mirror_repairs.py` | Existing asset-manifest contract coverage |
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
| `TRR-Backend/tests/scripts/test_social_worker.py` | Claim/reclaim behavior |
| `TRR-Backend/tests/scripts/test_verify_modal_readiness.py` | Modal readiness output and comments-lane preflight guardrails |
| `TRR-Backend/tests/test_modal_dispatch.py` | Stage-specific Modal function routing and drift-visible dispatch metadata |
| `TRR-Backend/tests/test_modal_jobs.py` | Modal entrypoint/runtime wiring regression coverage |

## Deliberately Removed From the Older Draft

- The old "per-request `csrftoken` header" task is removed because the current posts Scrapling fetcher already reads `csrftoken` fresh per call.
- The old unbound-`fetcher` cleanup task is removed because the current comments Scrapling runner no longer has that shape.
- `asset_manifest` is not reimplemented from scratch; the current writer path is retained and strengthened.
- The old "missing Instagram comment unique constraint" explanation is removed. `instagram_comments_post_comment_unique` is already part of the repo/live contract; deploy drift and remote browser warmup are the real remaining comments blockers.

---

### Task 1: Global Active Media-Mirror Dedupe for Local Instagram Runs

Closes: Media #1, Media #23, Posts #7 (association), plus the audit follow-up that local Instagram runs must dedupe globally across runs.

**Files:**
- Create: `TRR-Backend/supabase/migrations/20260421130000_scrape_jobs_active_media_mirror_uniq.sql`
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Create: `TRR-Backend/tests/repositories/test_enqueue_platform_media_mirror_job_dedupes.py`

- [ ] **Step 1: Write the failing dedupe test for different runs targeting the same Instagram post**

```python
import threading

from trr_backend.repositories import social_season_analytics as social_repo


def test_enqueue_platform_media_mirror_job_is_global_across_runs_for_same_post(
    live_test_db,
    seeded_instagram_post,
) -> None:
    post_row = seeded_instagram_post
    created_ids: list[str | None] = []

    def _go(run_id: str) -> None:
        created_ids.append(
            social_repo._enqueue_platform_media_mirror_job(
                context=None,
                platform="instagram",
                run_id=run_id,
                source_scope="bravo",
                account="bravotv",
                post_row=post_row,
                week_index=None,
                parent_job_id=None,
            )
        )

    threads = [
        threading.Thread(target=_go, args=("run-a",)),
        threading.Thread(target=_go, args=("run-b",)),
        threading.Thread(target=_go, args=("run-c",)),
    ]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()

    non_null = [job_id for job_id in created_ids if job_id]
    assert len(set(non_null)) == 1
```

- [ ] **Step 2: Run the focused dedupe test and verify the current race/duplicate contract fails**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q tests/repositories/test_enqueue_platform_media_mirror_job_dedupes.py
```

Expected: FAIL because the current implementation still pre-reads by `run_id` and does not enforce global active dedupe.

- [ ] **Step 3: Add the active-job uniqueness migration**

```sql
begin;

create unique index if not exists scrape_jobs_active_media_mirror_uniq
  on social.scrape_jobs (platform, (config->>'post_id'))
  where status in ('queued', 'pending', 'retrying', 'running')
    and coalesce(config->>'stage', metadata->>'stage', job_type) = 'media_mirror';

comment on index social.scrape_jobs_active_media_mirror_uniq is
  'At most one active media_mirror scrape job per (platform, post_id) across local runs.';

commit;
```

- [ ] **Step 4: Rewrite `_enqueue_platform_media_mirror_job(...)` to insert first and infer the partial index**

```python
with pg.db_cursor(conn=conn) as cur:
    inserted = pg.fetch_one_with_cursor(
        cur,
        """
        insert into social.scrape_jobs (
          id,
          platform,
          job_type,
          status,
          config,
          run_id,
          parent_job_id
        )
        values (
          gen_random_uuid(),
          %s,
          %s,
          %s,
          %s::jsonb,
          %s::uuid,
          %s::uuid
        )
        on conflict (platform, (config->>'post_id'))
        where status in ('queued', 'pending', 'retrying', 'running')
          and coalesce(config->>'stage', metadata->>'stage', job_type) = 'media_mirror'
        do nothing
        returning id::text as id
        """,
        [normalized_platform, job_type, mirror_job_status, json.dumps(config), run_id, parent_job_id],
    )
    if inserted and inserted.get("id"):
        mirror_job_id = str(inserted["id"])
    else:
        existing = pg.fetch_one_with_cursor(
            cur,
            """
            select id::text as id
            from social.scrape_jobs
            where platform = %s
              and status in ('queued', 'pending', 'retrying', 'running')
              and coalesce(config->>'stage', metadata->>'stage', job_type) = 'media_mirror'
              and config->>'post_id' = %s
            order by created_at desc
            limit 1
            """,
            [normalized_platform, post_id],
        )
        mirror_job_id = str(existing["id"]) if existing and existing.get("id") else None
```

- [ ] **Step 5: Tighten the existing broad repo tests that currently lambda-pass mock `_enqueue_platform_media_mirror_job(...)`**

```python
enqueue_calls: list[dict[str, object]] = []

def _fake_enqueue(**kwargs):
    enqueue_calls.append(dict(kwargs))
    return "job-1"

monkeypatch.setattr(social_repo, "_enqueue_platform_media_mirror_job", _fake_enqueue)

# existing assertions...
assert len(enqueue_calls) == 1
assert enqueue_calls[0]["platform"] == "instagram"
```

- [ ] **Step 6: Apply migration, reload schema cache, rerun tests, and commit**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
supabase db push
./scripts/reload_postgrest_schema.sh
pytest -q \
  tests/repositories/test_enqueue_platform_media_mirror_job_dedupes.py \
  tests/repositories/test_social_season_analytics.py -k "enqueue_platform_media_mirror_job"
```

Expected: PASS.

```bash
cd /Users/thomashulihan/Projects/TRR
git add \
  TRR-Backend/supabase/migrations/20260421130000_scrape_jobs_active_media_mirror_uniq.sql \
  TRR-Backend/trr_backend/repositories/social_season_analytics.py \
  TRR-Backend/tests/repositories/test_enqueue_platform_media_mirror_job_dedupes.py \
  TRR-Backend/tests/repositories/test_social_season_analytics.py
git commit -m "fix(instagram): globally dedupe active media mirror jobs"
```

---

### Task 2: Lock the Deployed Instagram Comments Contract and Modal Drift Guardrails

Closes: Comments #5, Comments D1, Comments D2, Comments D3, plus the audit follow-up that the 2026-04-21 `InvalidColumnReference` failure was stale deployed Modal code, not a missing live constraint.

**Files:**
- Modify: `TRR-Backend/tests/repositories/test_instagram_comment_identity_contract.py`
- Modify: `TRR-Backend/trr_backend/modal_dispatch.py`
- Modify: `TRR-Backend/scripts/modal/verify_modal_readiness.py`
- Modify: `TRR-Backend/scripts/modal/diagnose_instagram_comments_remote.py`
- Modify: `TRR-Backend/tests/scripts/test_verify_modal_readiness.py`
- Modify: `TRR-Backend/tests/test_modal_dispatch.py`

- [ ] **Step 1: Extend repo and Modal-preflight regressions so the plan proves schema truth before another live comments run**

```python
from trr_backend.repositories import social_season_analytics as social_repo


def test_instagram_comment_identity_contract_keeps_live_post_comment_unique(live_test_db) -> None:
    rows = social_repo.pg.fetch_all(
        """
        select conname
        from pg_constraint
        where conrelid = 'social.instagram_comments'::regclass
          and conname = 'instagram_comments_post_comment_unique'
        """
    )

    assert rows == [{"conname": "instagram_comments_post_comment_unique"}]
```

```python
def test_verify_modal_readiness_requires_comments_function_when_social_jobs_are_enabled(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        cli,
        "get_app_function_handles",
        lambda *, app_name, modal_environment="": {
            "serve_backend_api": _StubFunctionHandle(web_url="https://workspace--trr-backend-api.modal.run"),
            "run_social_job": _StubFunctionHandle(),
        },
    )

    summary = cli.verify_modal_readiness(
        app_name="trr-backend-jobs",
        runtime_secret_name="trr-backend-runtime",
        social_secret_name="trr-social-auth",
        function_names=("serve_backend_api", "run_social_job", "run_social_comments_job"),
    )

    assert summary["ok"] is False
    assert summary["missing_functions"] == ["run_social_comments_job"]
```

- [ ] **Step 2: Run the focused local regressions and confirm the repo contract passes before touching Modal runtime code**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q \
  tests/repositories/test_instagram_comment_identity_contract.py \
  tests/scripts/test_verify_modal_readiness.py \
  tests/test_modal_dispatch.py -k "instagram_comment_identity_contract or comments_function or stage_specific_function"
```

Expected: PASS locally. This is the point of the task: current repo code and schema already know about `instagram_comments_post_comment_unique`, so any live `ON CONFLICT` failure after this step is deploy/runtime drift until proven otherwise.

- [ ] **Step 3: Surface the comments-lane Modal contract explicitly in readiness and dispatch output**

```python
summary["configured_social_functions"] = {
    "default": modal_social_job_function_name(),
    "posts": modal_social_posts_job_function_name(),
    "media": modal_social_media_job_function_name(),
    "comments": modal_social_comments_job_function_name(),
}
summary["required_social_functions"] = list(function_names)
```

```python
return {
    "resolved": resolved,
    "reason": reason,
    "function_name": function_name,
    "app_name": modal_app_name(),
    "modal_environment": modal_environment_name(),
}
```

- [ ] **Step 4: Make the one-shortcode remote comments diagnostic print enough context to distinguish stale deploys from live browser failures**

```python
payload["dispatch"] = {
    "app_name": str(os.getenv("TRR_MODAL_APP_NAME") or "trr-backend-jobs").strip() or "trr-backend-jobs",
    "function_name": str(os.getenv("TRR_MODAL_SOCIAL_COMMENTS_JOB_FUNCTION") or "run_social_comments_job").strip()
    or "run_social_comments_job",
}
```

```python
except Exception as exc:  # noqa: BLE001
    payload["error"] = {
        "class": type(exc).__name__,
        "message": str(exc),
        "runtime": dict(fetcher.runtime_metadata),
    }
```

- [ ] **Step 5: Re-run readiness, redeploy Modal, run the remote comments probe, and commit**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
source .venv/bin/activate
python scripts/modal/verify_modal_readiness.py --json
python -m modal deploy -m trr_backend.modal_jobs --env main
python scripts/modal/diagnose_instagram_comments_remote.py --account thetraitorsus --shortcode DXXAP-Ekb59
```

Expected:

- `verify_modal_readiness.py --json` returns `ok: true`
- Modal deploy succeeds and republishes `run_social_job` plus `run_social_comments_job`
- The remote comments diagnostic no longer reports `InvalidColumnReference` or an `ON CONFLICT` schema failure
- Any remaining failure is now classified as a live browser/runtime issue, for example `Page.goto: net::ERR_TIMED_OUT`

```bash
cd /Users/thomashulihan/Projects/TRR
git add \
  TRR-Backend/tests/repositories/test_instagram_comment_identity_contract.py \
  TRR-Backend/trr_backend/modal_dispatch.py \
  TRR-Backend/scripts/modal/verify_modal_readiness.py \
  TRR-Backend/scripts/modal/diagnose_instagram_comments_remote.py \
  TRR-Backend/tests/scripts/test_verify_modal_readiness.py \
  TRR-Backend/tests/test_modal_dispatch.py
git commit -m "fix(instagram): expose comments modal contract and runtime drift"
```

---

### Task 3: Structured Concurrent Comment Fetch Result and Cache Locking

Closes: Posts #2, Posts #4, Posts #5, Comments #1.

**Files:**
- Modify: `TRR-Backend/trr_backend/socials/instagram/scraper.py`
- Create: `TRR-Backend/tests/socials/test_instagram_scraper_concurrent_comments.py`
- Create: `TRR-Backend/tests/socials/test_instagram_profile_page_context_cache_threadsafety.py`

- [ ] **Step 1: Write the failing structured concurrent-result test**

```python
import pytest

from trr_backend.socials.instagram.scraper import InstagramScraper


class _BoomScraper(InstagramScraper):
    def fetch_comments(self, shortcode, **kwargs):
        if shortcode == "bad":
            raise RuntimeError("rate_limited")
        return []


def test_concurrent_fetch_returns_comments_and_errors() -> None:
    scraper = _BoomScraper.__new__(_BoomScraper)
    scraper._rate_limit = lambda *_args, **_kwargs: None

    result = scraper.fetch_comments_concurrent(
        ["ok", "bad"],
        max_comments=10,
        fetch_replies=False,
        delay=0,
        fast_mode=False,
        max_workers=2,
    )

    assert result.comments["ok"] == []
    assert result.errors["bad"] == "rate_limited"
    assert result.had_failures is True
```

- [ ] **Step 2: Write the failing cache-thread-safety test**

```python
import threading

from trr_backend.socials.instagram.scraper import InstagramScraper


def test_profile_page_context_cache_mutations_are_locked() -> None:
    scraper = InstagramScraper.__new__(InstagramScraper)
    scraper._profile_page_context_cache = {}
    scraper._context_cache_lock = threading.RLock()

    failures: list[Exception] = []

    def _hammer() -> None:
        try:
            for idx in range(200):
                scraper._set_profile_page_context("bravotv", {"cursor": str(idx)})
                scraper._get_profile_page_context("bravotv")
                if idx % 50 == 0:
                    scraper._clear_profile_page_context_cache()
        except Exception as exc:  # noqa: BLE001
            failures.append(exc)

    threads = [threading.Thread(target=_hammer) for _ in range(8)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()

    assert failures == []
```

- [ ] **Step 3: Run the two focused tests to confirm current failure**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q \
  tests/socials/test_instagram_scraper_concurrent_comments.py \
  tests/socials/test_instagram_profile_page_context_cache_threadsafety.py
```

Expected: FAIL because `fetch_comments_concurrent(...)` currently returns only a plain dict and the cache uses bare dict mutation sites.

- [ ] **Step 4: Introduce the structured result object, synchronized rate-limit injection, cache helpers, and pagination safety cap**

```python
@dataclass(slots=True)
class ConcurrentCommentFetchResult:
    comments: dict[str, list["InstagramComment"]] = field(default_factory=dict)
    errors: dict[str, str] = field(default_factory=dict)

    @property
    def had_failures(self) -> bool:
        return bool(self.errors)
```

```python
def _set_profile_page_context(self, username: str, ctx: dict[str, str]) -> None:
    with self._context_cache_lock:
        self._profile_page_context_cache[username] = dict(ctx)


def _get_profile_page_context(self, username: str) -> dict[str, str]:
    with self._context_cache_lock:
        return dict(self._profile_page_context_cache.get(username) or {})


def _clear_profile_page_context_cache(self) -> None:
    with self._context_cache_lock:
        self._profile_page_context_cache.clear()
```

```python
max_pages = 500
deadline = time.monotonic() + 300
pages_scanned = 0

while True:
    pages_scanned += 1
    if pages_scanned > max_pages or time.monotonic() > deadline:
        self.last_comment_fetch_reason = "pagination_safety_cap"
        logger.warning("instagram comment pagination stopped by safety cap")
        break
```

- [ ] **Step 5: Rerun the focused tests and the broader Instagram scraper suite, then commit**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q \
  tests/socials/test_instagram_scraper_concurrent_comments.py \
  tests/socials/test_instagram_profile_page_context_cache_threadsafety.py \
  tests/socials/test_instagram_bug_fixes.py
```

Expected: PASS.

```bash
cd /Users/thomashulihan/Projects/TRR
git add \
  TRR-Backend/trr_backend/socials/instagram/scraper.py \
  TRR-Backend/tests/socials/test_instagram_scraper_concurrent_comments.py \
  TRR-Backend/tests/socials/test_instagram_profile_page_context_cache_threadsafety.py
git commit -m "fix(instagram): structure concurrent comment fetch and lock profile cache"
```

---

### Task 4: Async HTTP Client Rebuild for Posts and Comments Scrapling Fetchers

Closes: Posts #3, Comments #13.

**Files:**
- Modify: `TRR-Backend/trr_backend/socials/instagram/posts_scrapling/fetcher.py`
- Modify: `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/fetcher.py`
- Modify: `TRR-Backend/tests/socials/instagram/posts_scrapling/test_fetcher_retry.py`
- Modify: `TRR-Backend/tests/socials/test_instagram_comments_scrapling_retry.py`

- [ ] **Step 1: Extend the existing retry suites with failing client-close tests**

```python
class _TrackingClient:
    def __init__(self) -> None:
        self.closed = False

    async def aclose(self) -> None:
        self.closed = True


def test_posts_rebuild_http_client_closes_previous_client(monkeypatch) -> None:
    fetcher = _make_fetcher()
    old = _TrackingClient()
    fetcher._http_client = old
    monkeypatch.setattr(
        "trr_backend.socials.instagram.posts_scrapling.fetcher.httpx.AsyncClient",
        lambda **_kwargs: _TrackingClient(),
    )

    asyncio.run(fetcher._rebuild_http_client())

    assert old.closed is True
```

```python
def test_comments_rebuild_http_client_closes_previous_client(monkeypatch) -> None:
    fetcher = _build_fetcher()
    old = _TrackingClient()
    fetcher._http_client = old
    monkeypatch.setattr(
        "trr_backend.socials.instagram.comments_scrapling.fetcher.httpx.AsyncClient",
        lambda **_kwargs: _TrackingClient(),
    )

    asyncio.run(fetcher._rebuild_http_client())

    assert old.closed is True
```

- [ ] **Step 2: Run the two focused retry suites and verify failure**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q \
  tests/socials/instagram/posts_scrapling/test_fetcher_retry.py \
  tests/socials/test_instagram_comments_scrapling_retry.py
```

Expected: FAIL because `_rebuild_http_client(...)` is synchronous and drops the old client without awaiting `aclose()`.

- [ ] **Step 3: Convert both `_rebuild_http_client(...)` helpers to async and await every call site**

```python
async def _rebuild_http_client(self) -> None:
    old = self._http_client
    self._http_client = httpx.AsyncClient(
        cookies=dict(self._raw_cookies),
        timeout=httpx.Timeout(self._timeout_ms / 1000),
        proxy=self._api_proxy_url,
        follow_redirects=False,
        trust_env=False,
    )
    if old is not None:
        try:
            await old.aclose()
        except Exception:  # noqa: BLE001
            logger.debug("old httpx client close failed", exc_info=True)
```

```python
await self._rebuild_http_client()
```

- [ ] **Step 4: Rerun the retry suites, grep for un-awaited call sites, and commit**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
rg "_rebuild_http_client\\(" trr_backend/socials/instagram
pytest -q \
  tests/socials/instagram/posts_scrapling/test_fetcher_retry.py \
  tests/socials/test_instagram_comments_scrapling_retry.py
```

Expected: `rg` shows only awaited call sites inside async functions, and tests PASS.

```bash
cd /Users/thomashulihan/Projects/TRR
git add \
  TRR-Backend/trr_backend/socials/instagram/posts_scrapling/fetcher.py \
  TRR-Backend/trr_backend/socials/instagram/comments_scrapling/fetcher.py \
  TRR-Backend/tests/socials/instagram/posts_scrapling/test_fetcher_retry.py \
  TRR-Backend/tests/socials/test_instagram_comments_scrapling_retry.py
git commit -m "fix(instagram): rebuild async clients without leaking old sessions"
```

---

### Task 5: Harden Media Downloading, S3 Keys, and Retry Semantics

Closes: Media #2, #3, #7, #8, #9, #12, #13, #15, #17, #18, #19, #28, #29.

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/trr_backend/media/s3_mirror.py`
- Modify: `TRR-Backend/tests/repositories/test_media_assets_mirroring.py`
- Modify: `TRR-Backend/tests/media/test_s3_mirror.py`
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`

- [ ] **Step 1: Add failing tests for Instagram CDN re-resolve, sniffing, and redaction**

```python
def test_download_and_upload_redacts_signed_instagram_cdn_urls() -> None:
    assert social_repo.redact_signed_url("https://cdn.test/file.jpg?oh=abc&oe=def") == "https://cdn.test/file.jpg"
```

```python
def test_is_retryable_mirror_reason_strips_nested_prefixes() -> None:
    assert social_repo._is_retryable_mirror_reason("download_failed:ytdlp_fallback_failed:http_503") is True
    assert social_repo._is_retryable_mirror_reason("invalid_source_url") is False
```

```python
def test_build_mirror_source_key_uses_post_uuid_in_unknown_instagram_fallback() -> None:
    first = social_repo._build_mirror_source_key(
        "instagram",
        type("P", (), {"id": "11111111-1111-1111-1111-111111111111", "shortcode": ""})(),
        source_urls=["https://cdn.test/a.jpg"],
    )
    second = social_repo._build_mirror_source_key(
        "instagram",
        type("P", (), {"id": "22222222-2222-2222-2222-222222222222", "shortcode": ""})(),
        source_urls=["https://cdn.test/a.jpg"],
    )
    assert first != second
```

- [ ] **Step 2: Run the focused media tests and verify current failures**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q \
  tests/repositories/test_media_assets_mirroring.py \
  tests/media/test_s3_mirror.py \
  tests/repositories/test_social_season_analytics.py -k "mirror or redact or asset_manifest"
```

Expected: FAIL at the newly added assertions and/or existing mirror regressions.

- [ ] **Step 3: Patch the mirror/download path without adding a second manifest writer**

```python
_KNOWN_RETRYABLE_PREFIXES = ("download_failed:", "upload_failed:", "ytdlp_fallback_failed:")


def _is_retryable_mirror_reason(reason: str | None) -> bool:
    normalized = str(reason or "").strip().lower()
    while any(normalized.startswith(prefix) for prefix in _KNOWN_RETRYABLE_PREFIXES):
        normalized = normalized.split(":", 1)[1]
    return normalized in {"request_timeout", "connection_error", "request_error", "http_429", "http_500", "http_502", "http_503", "http_504"}
```

```python
def redact_signed_url(url: str) -> str:
    parsed = urlparse(str(url or "").strip())
    return urlunparse(parsed._replace(query="")) if parsed.scheme and parsed.netloc else "<unparseable>"
```

```python
seed = "|".join([str(getattr(post, "id", "") or ""), *sorted(source_urls or [])]).encode("utf-8")
digest = hashlib.sha256(seed).hexdigest()[:24]
return f"unknown-{digest}"
```

```python
with tempfile.TemporaryDirectory(prefix=f"{normalized_platform}-mirror-") as temp_dir:
    # write temp files inside temp_dir
    # do not sleep inside retry loops; let outer job retry/backoff own scheduling
```

```python
if status_code in {401, 403} and normalized_platform == "instagram" and not metadata.get("cdn_reresolved"):
    refreshed = _enrich_instagram_post_from_permalink(post=post, scraper=scraper, now_utc=_now_utc())
    metadata["cdn_reresolved"] = True
```

```python
sniffed = _sniff_image_content_type(header_bytes)
if sniffed is None and inferred_ext in {".jpg", ".jpeg", ".png", ".webp"}:
    raise RuntimeError("asset_wrong_content_type")
```

- [ ] **Step 4: Add S3 client timeout/retry config and yt-dlp batch-file redaction**

```python
return session.client(
    "s3",
    **client_kwargs,
    config=Config(
        connect_timeout=10,
        read_timeout=90,
        retries={"max_attempts": 3, "mode": "standard"},
    ),
)
```

```python
with tempfile.NamedTemporaryFile("w", prefix="yt-dlp-", suffix=".txt", delete=False) as batch_file:
    batch_file.write(tweet_url + "\n")
    batch_path = batch_file.name

cmd = [
    os.getenv("SOCIAL_MEDIA_MIRROR_YTDLP_BIN", "yt-dlp"),
    "--batch-file",
    batch_path,
    "--dump-single-json",
]
```

- [ ] **Step 5: Verify the existing `asset_manifest` writer path instead of reimplementing it, rerun tests, and commit**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q \
  tests/repositories/test_media_assets_mirroring.py \
  tests/repositories/test_social_mirror_repairs.py \
  tests/media/test_s3_mirror.py \
  tests/repositories/test_social_season_analytics.py -k "mirror or asset_manifest or redact"
```

Expected: PASS, with manifest assertions still flowing through `_update_platform_post_media_asset_meta(...)`.

```bash
cd /Users/thomashulihan/Projects/TRR
git add \
  TRR-Backend/trr_backend/repositories/social_season_analytics.py \
  TRR-Backend/trr_backend/media/s3_mirror.py \
  TRR-Backend/tests/repositories/test_media_assets_mirroring.py \
  TRR-Backend/tests/repositories/test_social_mirror_repairs.py \
  TRR-Backend/tests/media/test_s3_mirror.py \
  TRR-Backend/tests/repositories/test_social_season_analytics.py
git commit -m "fix(media): harden mirroring downloads, keys, and retry behavior"
```

---

### Task 6: S3 Preflight, Avatar Streaming, Profile-Avatar TTL, and Mirror Ops Scripts

Closes: Media #4, #5, #6, #10, #11, #14, #21, #22, #24, #26, #27.

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/trr_backend/repositories/media_assets.py`
- Modify: `TRR-Backend/scripts/socials/backfill_instagram_metadata_and_media.py`
- Modify: `TRR-Backend/scripts/socials/repair_instagram_single_media_urls.py`
- Modify: `TRR-Backend/scripts/socials/backfill_instagram_profile_avatars.py`
- Create: `TRR-Backend/scripts/socials/retire_stale_instagram_media_mirror_failures.py`
- Create: `TRR-Backend/tests/scripts/test_retire_stale_instagram_media_mirror_failures.py`
- Modify: `TRR-Backend/tests/scripts/test_backfill_instagram_metadata_and_media.py`
- Modify: `TRR-Backend/tests/scripts/test_repair_instagram_single_media_urls.py`
- Modify: `TRR-Backend/tests/scripts/test_backfill_instagram_profile_avatars.py`
- Modify: `TRR-Backend/tests/repositories/test_media_assets_mirroring.py`
- Create: `TRR-Backend/docs/observability/media_mirror_alerts.md`

- [ ] **Step 1: Write failing tests for write-access preflight, hosted-field validation, commit batching, and legacy URL preservation**

```python
def test_ensure_media_mirror_s3_ready_requires_write_access(monkeypatch) -> None:
    client = MagicMock()
    client.head_bucket.side_effect = ClientError({"Error": {"Code": "AccessDenied"}}, "HeadBucket")
    monkeypatch.setattr("trr_backend.repositories.social_season_analytics.get_object_storage_client", lambda: client)

    with pytest.raises(Exception, match="head_bucket failed"):
        social_repo.ensure_media_mirror_s3_ready()
```

```python
def test_update_asset_with_hosted_fields_requires_hosted_triplet() -> None:
    db = MagicMock()
    with pytest.raises(ValueError, match="hosted_bucket"):
        media_assets.update_asset_with_hosted_fields(
            db,
            "asset-1",
            hosted_bucket="",
            hosted_key="key",
            hosted_url="https://cdn.test/x.jpg",
            hosted_bytes=12,
        )
```

```python
def test_repair_instagram_single_media_urls_archives_legacy_media_urls() -> None:
    row = {
        "id": "post-1",
        "shortcode": "abc123",
        "media_type": "image",
        "post_format": "post",
        "media_urls": ["https://cdn.test/one.jpg", "https://cdn.test/two.jpg"],
        "raw_data": {},
    }
    repaired = mod._repair_candidate_row(row)
    assert repaired["legacy_media_urls"] == ["https://cdn.test/one.jpg", "https://cdn.test/two.jpg"]
```

- [ ] **Step 2: Run the focused script/media tests and verify failure**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q \
  tests/repositories/test_media_assets_mirroring.py \
  tests/scripts/test_backfill_instagram_metadata_and_media.py \
  tests/scripts/test_repair_instagram_single_media_urls.py \
  tests/scripts/test_backfill_instagram_profile_avatars.py
```

Expected: FAIL at the new assertions.

- [ ] **Step 3: Patch preflight, hosted-field validation, avatar streaming, and profile-avatar TTL**

```python
def ensure_media_mirror_s3_ready() -> None:
    cfg = get_s3_config()
    client = get_object_storage_client()
    try:
        client.head_bucket(Bucket=cfg.bucket)
    except ClientError as exc:
        raise RuntimeError(f"head_bucket failed: {exc}") from exc
    probe_key = f"trr-health/{uuid.uuid4()}"
    try:
        client.put_object(Bucket=cfg.bucket, Key=probe_key, Body=b"")
        client.delete_object(Bucket=cfg.bucket, Key=probe_key)
    except ClientError as exc:
        raise RuntimeError(f"put_object failed: {exc}") from exc
```

```python
if not hosted_bucket or not hosted_key or not hosted_url:
    raise ValueError("update_asset_with_hosted_fields requires hosted_bucket, hosted_key, and hosted_url")
```

```python
status = "skipped_unsupported"
ttl_hours = max(1, int(os.getenv("SOCIAL_AVATAR_SKIP_TTL_HOURS", "168")))
```

```python
with requests.get(source_url, timeout=(10, 30), stream=True, headers=headers) as response:
    response.raise_for_status()
    written = 0
    sha = hashlib.sha256()
    for chunk in response.iter_content(chunk_size=65536):
        if not chunk:
            continue
        written += len(chunk)
        if written > max_bytes:
            raise RuntimeError("asset_too_large")
        sha.update(chunk)
        temp_file.write(chunk)
```

- [ ] **Step 4: Patch the ops scripts and add the Instagram stale-failure retirement script**

```python
with pg.db_connection(label="instagram-backfill-metadata-media") as conn:
    for index, row in enumerate(rows, start=1):
        # existing work...
        if index % commit_batch_size == 0:
            conn.commit()
    conn.commit()
```

```python
return {
    "id": str(row.get("id") or "").strip(),
    "shortcode": str(row.get("shortcode") or "").strip(),
    "old_media_urls": media_urls,
    "new_media_urls": [primary_url],
    "legacy_media_urls": media_urls,
}
```

```python
old_raw = dict(row.get("raw_data") or {})
old_raw["legacy_media_urls"] = media_urls
old_raw["repair_reason"] = "single_media_repair"
```

```python
NON_RETRYABLE_ERRORS = {
    "http_403_auth_or_expired",
    "http_404_not_found",
    "invalid_source_url",
    "asset_too_large",
    "asset_wrong_content_type",
}
```

- [ ] **Step 5: Add the alert recipe doc, rerun the focused tests, and commit**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q \
  tests/repositories/test_media_assets_mirroring.py \
  tests/scripts/test_backfill_instagram_metadata_and_media.py \
  tests/scripts/test_repair_instagram_single_media_urls.py \
  tests/scripts/test_backfill_instagram_profile_avatars.py \
  tests/scripts/test_retire_stale_instagram_media_mirror_failures.py
```

Expected: PASS.

```bash
cd /Users/thomashulihan/Projects/TRR
git add \
  TRR-Backend/trr_backend/repositories/social_season_analytics.py \
  TRR-Backend/trr_backend/repositories/media_assets.py \
  TRR-Backend/scripts/socials/backfill_instagram_metadata_and_media.py \
  TRR-Backend/scripts/socials/repair_instagram_single_media_urls.py \
  TRR-Backend/scripts/socials/backfill_instagram_profile_avatars.py \
  TRR-Backend/scripts/socials/retire_stale_instagram_media_mirror_failures.py \
  TRR-Backend/tests/repositories/test_media_assets_mirroring.py \
  TRR-Backend/tests/scripts/test_backfill_instagram_metadata_and_media.py \
  TRR-Backend/tests/scripts/test_repair_instagram_single_media_urls.py \
  TRR-Backend/tests/scripts/test_backfill_instagram_profile_avatars.py \
  TRR-Backend/tests/scripts/test_retire_stale_instagram_media_mirror_failures.py \
  TRR-Backend/docs/observability/media_mirror_alerts.md
git commit -m "fix(media): harden preflight, avatar mirroring, and mirror ops scripts"
```

---

### Task 7: Asset Manifest Verification and `hosted_tagged_profile_pics` Shape Migration

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

- [ ] **Step 1: Write the failing object-shape compatibility tests before changing the writer**

```python
def test_as_hosted_tagged_profile_pic_map_accepts_string_and_object_values() -> None:
    payload = social_repo._normalize_hosted_tagged_profile_pics(
        {
            "andy": "https://cdn.test/a.jpg",
            "cohen": {
                "hosted_url": "https://cdn.test/c.jpg",
                "sha256": "abc",
                "mirrored_at": "2026-04-21T00:00:00+00:00",
            },
        }
    )
    assert payload["andy"]["hosted_url"] == "https://cdn.test/a.jpg"
    assert payload["cohen"]["sha256"] == "abc"
```

- [ ] **Step 2: Run the focused hosted-avatar tests and verify failure**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q \
  tests/repositories/test_social_mirror_repairs.py \
  tests/scripts/test_backfill_instagram_profile_avatars.py \
  tests/scripts/test_repair_social_hosted_urls.py \
  tests/repositories/test_social_sync_orchestrator.py
```

Expected: FAIL because current readers assume `dict[str, str]`.

- [ ] **Step 3: Add the shared reader normalizer and patch every current reader before changing the writer**

```python
def _normalize_hosted_tagged_profile_pics(value: Any) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    if not isinstance(value, dict):
        return result
    for raw_key, raw_value in value.items():
        key = _normalize_account_handle(raw_key)
        if not key:
            continue
        if isinstance(raw_value, str) and raw_value.strip():
            result[key] = {"hosted_url": raw_value.strip(), "sha256": None, "mirrored_at": None}
        elif isinstance(raw_value, dict):
            hosted_url = str(raw_value.get("hosted_url") or "").strip()
            if hosted_url:
                result[key] = {
                    "hosted_url": hosted_url,
                    "sha256": str(raw_value.get("sha256") or "").strip() or None,
                    "mirrored_at": str(raw_value.get("mirrored_at") or "").strip() or None,
                }
    return result
```

- [ ] **Step 4: Switch the writer shape only after the readers pass**

```python
tagged_pics[username] = {
    "hosted_url": hosted_url,
    "sha256": sha256,
    "mirrored_at": _iso(_now_utc()),
}
```

```sql
begin;

comment on column social.instagram_posts.hosted_tagged_profile_pics is
  'Supports both legacy string values and object values with hosted_url, sha256, mirrored_at.';

commit;
```

- [ ] **Step 5: Rerun the focused compatibility tests and commit**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q \
  tests/repositories/test_social_mirror_repairs.py \
  tests/scripts/test_backfill_instagram_profile_avatars.py \
  tests/scripts/test_repair_social_hosted_urls.py \
  tests/repositories/test_social_sync_orchestrator.py
```

Expected: PASS, with legacy rows still readable and new rows richer.

```bash
cd /Users/thomashulihan/Projects/TRR
git add \
  TRR-Backend/supabase/migrations/20260421134000_hosted_tagged_profile_pics_object_shape.sql \
  TRR-Backend/trr_backend/repositories/social_season_analytics.py \
  TRR-Backend/scripts/socials/backfill_instagram_profile_avatars.py \
  TRR-Backend/scripts/socials/repair_social_hosted_urls.py \
  TRR-Backend/trr_backend/repositories/social_sync_orchestrator.py \
  TRR-Backend/tests/repositories/test_social_mirror_repairs.py \
  TRR-Backend/tests/scripts/test_backfill_instagram_profile_avatars.py \
  TRR-Backend/tests/scripts/test_repair_social_hosted_urls.py \
  TRR-Backend/tests/repositories/test_social_sync_orchestrator.py
git commit -m "feat(instagram): support richer hosted tagged avatar metadata safely"
```

---

### Task 8: Fix Stale-Job Backoff, Bounded Runtime Threads, and Run Loop Caps

Closes: Posts #1, Posts #7, Posts #8, Comments #11.

**Files:**
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/trr_backend/socials/crawlee_runtime/runtime.py`
- Modify: `TRR-Backend/scripts/socials/worker.py`
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Modify: `TRR-Backend/tests/scripts/test_social_worker.py`

- [ ] **Step 1: Write the failing stale-backoff and claim-reclaim tests**

```python
def test_recover_stale_running_jobs_uses_power_not_bitwise_xor(live_test_db) -> None:
    # insert a running job with attempt_count=3 and stale heartbeat
    # assert available_at lands ~20 seconds ahead after recovery
    ...
```

```python
def test_claim_next_jobs_reclaims_jobs_from_stale_worker_heartbeat(monkeypatch) -> None:
    rows = social_repo._claim_next_jobs(
        worker_id="worker-2",
        run_id=None,
        stage="comments_scrapling",
        platform="instagram",
        limit=1,
    )
    assert rows
```

- [ ] **Step 2: Run the focused tests and verify failure**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q \
  tests/repositories/test_social_season_analytics.py -k "stale_running_jobs or claim_next_jobs" \
  tests/scripts/test_social_worker.py -k "claim"
```

Expected: FAIL because the stale backoff still uses `2 ^ ...` and claim SQL does not yet reclaim work from stale worker ownership.

- [ ] **Step 3: Patch the SQL/runtime seams**

```sql
greatest(5, least(300, 5 * power(2, greatest(0, j.attempt_count - 1))))
```

```python
def _run_coroutine(coro: Any, *, join_timeout_seconds: float | None = None) -> Any:
    # existing fast path...
    thread = Thread(target=_thread_main, daemon=False)
    thread.start()
    thread.join(timeout=join_timeout_seconds)
    if thread.is_alive():
        raise CrawleeRuntimeError("crawlee_coroutine_timed_out", error_code="crawlee_coroutine_timed_out", retryable=False)
```

```python
execute_timeout = max_scrape_seconds + 30
return _run_coroutine(_execute_with_queue(), join_timeout_seconds=execute_timeout)
```

```python
max_jobs_per_invocation = max(1, int(os.getenv("SOCIAL_EXECUTE_RUN_MAX_JOBS", "1000")))
max_run_seconds = max(60, int(os.getenv("SOCIAL_EXECUTE_RUN_MAX_SECONDS", "1800")))
```

```sql
or (
  j.worker_id is not null
  and exists (
    select 1
    from social.scrape_workers w
    where w.worker_id = j.worker_id
      and w.last_seen_at < now() - make_interval(secs => %s)
  )
)
```

- [ ] **Step 4: Rerun the focused tests, then commit**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q \
  tests/repositories/test_social_season_analytics.py -k "stale_running_jobs or claim_next_jobs or execute_run" \
  tests/scripts/test_social_worker.py -k "claim"
```

Expected: PASS.

```bash
cd /Users/thomashulihan/Projects/TRR
git add \
  TRR-Backend/trr_backend/repositories/social_season_analytics.py \
  TRR-Backend/trr_backend/socials/crawlee_runtime/runtime.py \
  TRR-Backend/scripts/socials/worker.py \
  TRR-Backend/tests/repositories/test_social_season_analytics.py \
  TRR-Backend/tests/scripts/test_social_worker.py
git commit -m "fix(runtime): bound stale retries, thread joins, and run loops"
```

---

### Task 9: Posts Scraper Contract Corrections

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

- [ ] **Step 1: Add focused failing tests for the remaining posts-scraper issues**

```python
def test_profile_shortcode_fallback_stops_at_11_chars() -> None:
    assert extract_profile_shortcodes('/p/ABCDEFGHIJK123') == ['ABCDEFGHIJK']
```

```python
def test_apify_normalize_missing_counts_as_none() -> None:
    payload = normalize_apify_post({"id": "1", "shortCode": "abc", "timestamp": "2026-01-01T00:00:00Z"})
    assert payload["likes_count"] is None
    assert payload["comments_count"] is None
```

```python
def test_fetch_posts_page_breaks_on_first_non_retryable_failure(monkeypatch) -> None:
    fetcher = _make_fetcher()
    fetcher._fetch_json_response = AsyncMock(return_value={"failed": True, "auth_failed": False, "retryable": False, "reason": "http_500"})
    result = asyncio.run(fetcher.fetch_posts_page("bravotv"))
    assert result.fetch_reason == "http_500"
    assert fetcher._fetch_json_response.await_count == 1
```

- [ ] **Step 2: Run the focused tests to verify failure**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q \
  tests/socials/test_instagram_profile_shortcode_fallback.py \
  tests/socials/test_instagram_permalink_metadata.py \
  tests/socials/instagram/posts_scrapling/test_fetcher_retry.py \
  tests/repositories/test_social_season_analytics.py -k "persist_instagram_posts or execute_run or metadata"
```

Expected: FAIL at the new assertions.

- [ ] **Step 3: Patch the posts contracts**

```python
_PROFILE_SHORTCODE_RE = re.compile(r"/(?:p|reel|tv)/([A-Za-z0-9_-]{5,11})(?=[^A-Za-z0-9_-]|$)")
```

```python
run = client.actor(APIFY_ACTOR_ID).call(
    run_input=run_input,
    timeout_secs=int(os.getenv("INSTAGRAM_APIFY_TIMEOUT_SECS", "600")),
    wait_secs=30,
)
```

```python
"likes_count": raw.get("likesCount"),
"comments_count": raw.get("commentsCount"),
```

```python
if current_failed:
    auth_failed = auth_failed or current_auth
    retryable = retryable or current_retryable
    if current_reason and not fetch_reason:
        fetch_reason = current_reason
    if current_auth or not current_retryable:
        break
    continue
```

```python
logger.info("instagram session configured", extra={"sessionid_hash": hashlib.sha256(sessionid.encode()).hexdigest()[:12]})
```

```python
if any(status in {401, 403, 429} for status in attempted_statuses):
    raise AuthShortCircuit("instagram_permalink_auth_short_circuit")
```

```python
metadata["attempts"] = [*metadata.get("attempts", [])[-4:], new_attempt]
```

- [ ] **Step 4: Replace the non-atomic metadata merge in `persist_instagram_posts(...)`**

```python
update social.scrape_jobs
set metadata =
  coalesce(metadata, '{}'::jsonb)
  || %s::jsonb
where id = %s::uuid
```

- [ ] **Step 5: Rerun focused tests and commit**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q \
  tests/socials/test_instagram_profile_shortcode_fallback.py \
  tests/socials/test_instagram_permalink_metadata.py \
  tests/socials/instagram/posts_scrapling/test_fetcher_retry.py \
  tests/repositories/test_social_season_analytics.py -k "persist_instagram_posts or metadata or catalog"
```

Expected: PASS.

```bash
cd /Users/thomashulihan/Projects/TRR
git add \
  TRR-Backend/trr_backend/repositories/social_season_analytics.py \
  TRR-Backend/trr_backend/socials/instagram/posts_scrapling/persistence.py \
  TRR-Backend/trr_backend/socials/instagram/posts_scrapling/fetcher.py \
  TRR-Backend/trr_backend/socials/instagram/profile_shortcode_fallback.py \
  TRR-Backend/trr_backend/socials/instagram/apify_scraper.py \
  TRR-Backend/trr_backend/socials/instagram/permalink_metadata.py \
  TRR-Backend/trr_backend/socials/instagram/scraper.py \
  TRR-Backend/tests/repositories/test_social_season_analytics.py \
  TRR-Backend/tests/socials/instagram/posts_scrapling/test_fetcher_retry.py \
  TRR-Backend/tests/socials/test_instagram_permalink_metadata.py \
  TRR-Backend/tests/socials/test_instagram_profile_shortcode_fallback.py
git commit -m "fix(instagram): close remaining posts scraper contract gaps"
```

---

### Task 10: Comments Tree Completeness, Pagination, and Reply-Marking Semantics

Closes: Comments #2, #3, #7, #8, #9, #10, #15.

**Files:**
- Modify: `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/fetcher.py`
- Modify: `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/job_runner.py`
- Modify: `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/persistence.py`
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/tests/socials/test_instagram_comments_scrapling_retry.py`
- Modify: `TRR-Backend/tests/socials/test_instagram_comments_scrapling.py`
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`

- [ ] **Step 1: Add failing tests for partial reply trees, cursor echo, and reply marking**

```python
def test_comments_scrape_is_incomplete_when_reply_fetch_failed() -> None:
    result = InstagramCommentsFetchResult(
        comments=[],
        fetch_failed=False,
        auth_failed=False,
        fetch_reason=None,
        request_count=1,
        retryable=False,
        reply_fetch_failed=True,
    )
    assert _comments_scrape_is_complete(result=result, max_comments_per_post=200) is False
```

```python
def test_top_level_comment_pagination_reuses_cursor_field_name() -> None:
    # first payload returns next_max_id; second request must send max_id, not min_id
    ...
```

```python
def test_mark_missing_comments_for_anchor_skips_replies_when_requested(monkeypatch) -> None:
    captured: list[str] = []
    monkeypatch.setattr(social_repo.pg, "fetch_all_with_cursor", lambda _cur, sql, params: captured.append(sql) or [])
    social_repo._mark_missing_comments_for_anchor(
        platform="instagram",
        anchor_id="post-1",
        observed_comment_ids={"c1"},
        mark_replies=False,
    )
    assert "is_reply = false" in captured[0]
```

- [ ] **Step 2: Run the focused comments tests and verify failure**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q \
  tests/socials/test_instagram_comments_scrapling.py \
  tests/socials/test_instagram_comments_scrapling_retry.py \
  tests/repositories/test_social_season_analytics.py -k "mark_missing_comments_for_anchor"
```

Expected: FAIL at the new assertions.

- [ ] **Step 3: Patch the comments result and pagination contract**

```python
@dataclass(slots=True)
class InstagramCommentsFetchResult:
    comments: list[InstagramComment] = field(default_factory=list)
    fetch_failed: bool = False
    auth_failed: bool = False
    fetch_reason: str | None = None
    request_count: int = 0
    retryable: bool = False
    reply_fetch_failed: bool = False
```

```python
fetch_reason = response.get("reason") or fetch_reason
```

```python
cursor_field = "min_id"
next_cursor = payload.get("next_min_id")
if payload.get("next_max_id"):
    cursor_field = "max_id"
    next_cursor = payload.get("next_max_id")
```

```python
if not fetch_replies:
    comments_marked_missing = repo._mark_missing_comments_for_anchor(
        platform="instagram",
        anchor_id=post_id,
        observed_comment_ids=observed_comment_ids,
        mark_replies=False,
        conn=conn,
    )
```

- [ ] **Step 4: Add dual-direction reply pagination and safety caps**

```python
tail_cursor = payload.get("next_min_child_cursor")
head_cursor = payload.get("next_max_child_cursor")
```

```python
seen_reply_ids: set[str] = set()
for reply_data in reply_rows:
    # dedupe by comment_id before append
```

```python
if pages_scanned >= 500:
    fetch_reason = fetch_reason or "pagination_safety_cap"
    fetch_failed = True
    retryable = False
    break
```

- [ ] **Step 5: Rerun focused tests and commit**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q \
  tests/socials/test_instagram_comments_scrapling.py \
  tests/socials/test_instagram_comments_scrapling_retry.py \
  tests/repositories/test_social_season_analytics.py -k "mark_missing_comments_for_anchor or instagram_comments"
```

Expected: PASS.

```bash
cd /Users/thomashulihan/Projects/TRR
git add \
  TRR-Backend/trr_backend/socials/instagram/comments_scrapling/fetcher.py \
  TRR-Backend/trr_backend/socials/instagram/comments_scrapling/job_runner.py \
  TRR-Backend/trr_backend/socials/instagram/comments_scrapling/persistence.py \
  TRR-Backend/trr_backend/repositories/social_season_analytics.py \
  TRR-Backend/tests/socials/test_instagram_comments_scrapling.py \
  TRR-Backend/tests/socials/test_instagram_comments_scrapling_retry.py \
  TRR-Backend/tests/repositories/test_social_season_analytics.py
git commit -m "fix(instagram): make comments completeness and pagination honest"
```

---

### Task 11: Comments Remote Browser Warmup, Timeout Classification, and CLI Hardening

Closes: Comments #6, #12, #14, #16, #17, #18, #19, plus the active Modal comments blocker `Page.goto: net::ERR_TIMED_OUT`.

**Files:**
- Modify: `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/fetcher.py`
- Modify: `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/proxy.py`
- Modify: `TRR-Backend/scripts/socials/instagram/comments_scrape_cli.py`
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `TRR-Backend/scripts/modal/diagnose_instagram_comments_remote.py`
- Modify: `TRR-Backend/tests/socials/test_instagram_comments_scrapling.py`
- Modify: `TRR-Backend/tests/socials/test_instagram_comments_scrapling_retry.py`

- [ ] **Step 1: Add failing tests for browser warmup timeout classification, proxy fingerprint shape, env-backed CLI defaults, and safe CLI metadata**

```python
from playwright.async_api import TimeoutError as PlaywrightTimeoutError


@pytest.mark.asyncio
async def test_warmup_timeout_is_classified_and_recorded(monkeypatch: pytest.MonkeyPatch) -> None:
    fetcher = _build_fetcher_for_test()

    async def _boom(*_args, **_kwargs):
        raise PlaywrightTimeoutError("Page.goto: net::ERR_TIMED_OUT at https://www.instagram.com/")

    monkeypatch.setattr(fetcher, "_warm_browser_homepage", _boom)

    with pytest.raises(RuntimeError, match="warmup_failed"):
        await fetcher.warmup()

    assert fetcher.runtime_metadata["warmup_error_code"] == "page_goto_timeout"
    assert fetcher.runtime_metadata["warmup_error_phase"] == "instagram_home"
```

```python
def test_fingerprint_from_gateway_normalizes_host_port_provider() -> None:
    assert _fingerprint_from_gateway("gate.decodo.com:7000", "decodo") == "gate.decodo.com:7000:decodo"
```

```python
def test_comments_cli_max_comments_defaults_from_env(monkeypatch) -> None:
    monkeypatch.setenv("SOCIAL_INSTAGRAM_COMMENTS_MAX_COMMENTS_PER_POST", "42")
    args = parse_args()
    assert args.max_comments == 42
```

```python
def test_cli_runtime_metadata_is_whitelisted() -> None:
    fetcher_meta = {
        "warmup_cookie_names": ["csrftoken"],
        "warmup_cookie_count": 1,
        "selected_proxy_fingerprint": "gate.decodo.com:7000:decodo",
        "transport": "httpx_after_browser_warmup",
        "request_count": 3,
        "sessionid": "should-not-print",
    }
    safe = _safe_runtime_metadata(fetcher_meta)
    assert "sessionid" not in safe
```

- [ ] **Step 2: Run the focused transport/CLI tests and verify failure**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q \
  tests/socials/test_instagram_comments_scrapling.py \
  tests/socials/test_instagram_comments_scrapling_retry.py
```

Expected: FAIL at the new timeout-classification and metadata assertions.

- [ ] **Step 3: Patch browser warmup timeout classification, rate limiting, retry/jitter, proxy shape, and CLI output safety**

```python
except PlaywrightTimeoutError as exc:
    self.runtime_metadata["warmup_error_code"] = "page_goto_timeout"
    self.runtime_metadata["warmup_error_phase"] = "instagram_home"
    self.runtime_metadata["warmup_error_detail"] = str(exc)[:200]
    last_exc = exc
```

```python
self._min_request_interval_s = max(0.0, float(os.getenv("SOCIAL_INSTAGRAM_COMMENTS_MIN_REQUEST_INTERVAL_SECONDS", "0.5")))
self._request_gate = asyncio.Lock()
self._last_request_started_at = 0.0
```

```python
async with self._request_gate:
    now = asyncio.get_running_loop().time()
    sleep_for = max(0.0, self._min_request_interval_s - (now - self._last_request_started_at))
    if sleep_for > 0:
        await asyncio.sleep(sleep_for)
    self._last_request_started_at = asyncio.get_running_loop().time()
```

```python
for attempt in range(3):
    try:
        response = await self._fetch_page(...)
        break
    except Exception as exc:  # noqa: BLE001
        if attempt == 2:
            raise RuntimeError("warmup_failed") from exc
        await asyncio.sleep(random.uniform(0.5, 1.5) * (2**attempt))
```

```python
def _fingerprint_from_gateway(gateway: str, provider: str) -> str:
    host, port = gateway.rsplit(":", 1)
    return f"{host}:{int(port)}:{provider}"
```

```python
SAFE_RUNTIME_META_KEYS = {
    "warmup_cookie_names",
    "warmup_cookie_count",
    "warmup_error_code",
    "warmup_error_phase",
    "warmup_error_detail",
    "warmup_attempts",
    "selected_proxy_fingerprint",
    "transport",
    "request_count",
}
```

- [ ] **Step 4: Ensure comment media follow-up enqueue requires both schema columns and the remote diagnostic uses the safe runtime metadata**

```python
if media_urls and _column_exists("social", "instagram_comments", "media_mirror_status") and _column_exists("social", "instagram_comments", "media_mirror_error"):
    payload["media_mirror_status"] = "pending"
    payload["media_mirror_error"] = None
```

```python
payload["warmup"] = {
    "ok": True,
    "runtime": _safe_runtime_metadata(dict(fetcher.runtime_metadata)),
}
```

- [ ] **Step 5: Rerun focused tests, then verify the remote comments probe surfaces structured timeout data instead of an opaque crash**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q \
  tests/socials/test_instagram_comments_scrapling.py \
  tests/socials/test_instagram_comments_scrapling_retry.py
python scripts/modal/diagnose_instagram_comments_remote.py --account thetraitorsus --shortcode DXXAP-Ekb59
```

Expected:

- local tests PASS
- the remote diagnostic either succeeds or returns structured `warmup_error_code=page_goto_timeout` metadata instead of a generic crash with no warmup context

```bash
cd /Users/thomashulihan/Projects/TRR
git add \
  TRR-Backend/trr_backend/socials/instagram/comments_scrapling/fetcher.py \
  TRR-Backend/trr_backend/socials/instagram/comments_scrapling/proxy.py \
  TRR-Backend/scripts/socials/instagram/comments_scrape_cli.py \
  TRR-Backend/trr_backend/repositories/social_season_analytics.py \
  TRR-Backend/scripts/modal/diagnose_instagram_comments_remote.py \
  TRR-Backend/tests/socials/test_instagram_comments_scrapling.py \
  TRR-Backend/tests/socials/test_instagram_comments_scrapling_retry.py
git commit -m "fix(instagram): classify comments warmup timeouts and harden cli output"
```

---

### Task 12: Timestamp Nullability, Final Validation, and Closeout

Closes: Comments D4, test-gap closure, and operator-facing closeout.

**Files:**
- Modify: `TRR-Backend/trr_backend/socials/instagram/scraper.py`
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify tests only where current assertions still assume `0` instead of `None`

- [ ] **Step 1: Add the failing timestamp-nullability test**

```python
def test_instagram_timestamp_coercion_returns_none_for_unparseable_values() -> None:
    assert InstagramScraper._coerce_timestamp(None) is None
    assert InstagramScraper._coerce_timestamp("not-a-date") is None
    assert InstagramScraper._coerce_timestamp(0) == 0
```

- [ ] **Step 2: Run the focused timestamp test and verify failure**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
pytest -q tests/socials/test_instagram_bug_fixes.py -k "timestamp"
```

Expected: FAIL if the current helpers still collapse invalid values to `0`.

- [ ] **Step 3: Patch the timestamp helpers and audit the few known fallback sites**

```python
@staticmethod
def _coerce_timestamp(value: Any) -> int | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return int(value)
    if isinstance(value, str):
        raw = value.strip()
        if not raw:
            return None
        try:
            parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
        except ValueError:
            return None
        return int(parsed.timestamp())
    return None
```

```python
posted_at = _parse_platform_time(getattr(post, "posted_at", None)) or scraped_at
created_at = _parse_platform_time(getattr(comment, "created_at", None)) or scraped_at
```

- [ ] **Step 4: Run full backend validation plus the listed operator smoke commands**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
ruff check .
ruff format --check .
pytest -q
make schema-docs-check
source .venv/bin/activate
python scripts/modal/verify_modal_readiness.py --json
python -m modal deploy -m trr_backend.modal_jobs --env main
python scripts/modal/diagnose_instagram_comments_remote.py --account thetraitorsus --shortcode DXXAP-Ekb59
python -m scripts.socials.instagram.smoke_posts_scrapling --account bravotv --limit 10
python -m scripts.socials.instagram.comments_scrape_cli --account thetraitorsus --shortcode DXXAP-Ekb59 --max-comments 5
python -m scripts.socials.backfill_social_media_mirror_jobs --platform instagram --dry-run
python - <<'PY'
from trr_backend.repositories.social_season_analytics import start_social_account_comments_scrape

result = start_social_account_comments_scrape(
    "instagram",
    "thetraitorsus",
    mode="profile",
    refresh_policy="all_saved_posts",
    initiated_by="instagram-remediation-plan",
)
print(result)
PY
```

Expected:

- `ruff check .`: PASS
- `ruff format --check .`: PASS
- `pytest -q`: PASS
- `make schema-docs-check`: PASS or only intentional `supabase/schema_docs/*` drift that is committed in this task
- `verify_modal_readiness.py --json`: `ok: true`, with `run_social_job` and `run_social_comments_job` visible in the required/configured function set
- Modal deploy: succeeds and republishes the current repo code before the live comments run
- one-shortcode remote comments diagnostic: does not report `InvalidColumnReference`; if Instagram still blocks, the failure is classified as browser warmup timeout with safe runtime metadata
- profile comments sync kickoff for `@thetraitorsus`: returns a new `run_id` / `job_id` and no longer fails immediately on the old `ON CONFLICT` path

- [ ] **Step 5: Commit the final validation or schema-doc updates and run workspace closeout**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/supabase/schema_docs TRR-Backend
git commit -m "chore(instagram): close out scraper remediation validation"

./scripts/handoff-lifecycle.sh closeout
```

---

## Self-Review

### Spec coverage

- Global local Instagram mirror dedupe: covered by Task 1.
- Instagram comment composite identity plus deploy/runtime drift guardrails: covered by Task 2.
- Shared concurrency/cache/client primitives: covered by Tasks 3 and 4.
- Media downloader, S3, avatar, manifest, redaction, and ops scripts: covered by Tasks 5, 6, and 7.
- Posts/runtime correctness: covered by Tasks 8 and 9.
- Comments/runtime correctness, including remote browser warmup timeouts: covered by Tasks 10 and 11.
- Timestamp/nullability and full validation: covered by Task 12.

### Placeholder scan

- No `TBD`, `TODO`, or “similar to Task N” placeholders remain.
- Every task lists concrete files, concrete tests, concrete commands, and concrete code snippets.

### Type consistency

- Composite Instagram comment identity is treated as already-landed ground truth. Task 2 prevents deploy drift from masking that contract, and Tasks 10 and 11 keep runtime behavior aligned with it.
- `hosted_tagged_profile_pics` migration explicitly adds reader compatibility before writer-shape changes in Task 7.
- Async `_rebuild_http_client(...)` is treated consistently in both posts and comments fetchers in Task 4.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-21-instagram-scrapers-75-bug-remediation.md`.

Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
