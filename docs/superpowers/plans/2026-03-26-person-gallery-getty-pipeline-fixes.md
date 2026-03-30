# Person Gallery Getty Image Scrape Pipeline — Bug Fixes & Optimization Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix bugs, eliminate double-pass searches, remove code duplication, and speed up the Person Gallery Getty Image Scrape Pipeline end-to-end.

**Architecture:** The pipeline spans three repos (TRR-Backend, TRR-APP, BRAVOTV) with a multi-phase flow: local Playwright Getty scrape → prefetch state via tmp JSON files → Next.js SSE proxy → FastAPI backend import/bridge/mirror. Fixes target each layer in dependency order: shared code first, then backend logic, then frontend plumbing.

**Tech Stack:** Python 3.11, FastAPI, BeautifulSoup4, Playwright, requests, TypeScript, Next.js App Router, SSE, Supabase, S3

---

## File Structure

Files that will be **modified** (no new files created):

| File | Responsibility | Tasks |
|------|---------------|-------|
| `TRR-Backend/trr_backend/integrations/getty.py` | Getty search + detail parsing | 1, 2 |
| `TRR-Backend/trr_backend/integrations/getty_local_prefetch.py` | Playwright bridge + cookie auth | 3 |
| `TRR-Backend/trr_backend/bravotv/get_images_pipeline.py` | NUP bridge + catalog builder | 4 |
| `TRR-Backend/api/routers/admin_person_images.py` | Import orchestrator + SSE progress | 5, 6, 7 |
| `TRR-APP/apps/web/src/lib/server/admin/getty-local-scrape.ts` | Prefetch job state + subprocess | 8, 9 |
| `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/refresh-images/route.ts` | Refresh proxy | 9 |
| `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/refresh-images/stream/route.ts` | SSE stream proxy | 9 |
| Test files (existing) | Regression coverage | Each task |

---

## Task 1: Eliminate the double Getty search in `_merge_grouped_event_metadata`

**The biggest single performance win.** `search_editorial_assets` (getty.py:241) calls `_search_asset_candidates_for_phrase` to find candidates, then immediately calls `_merge_grouped_event_metadata` (getty.py:458) which runs `_search_asset_candidates_for_phrase` **again** with `groupbyevent=true` — a full second search over the same Getty result space. This doubles HTTP requests and wall-clock time for every person search.

**Files:**
- Modify: `TRR-Backend/trr_backend/integrations/getty.py:241-340` (`search_editorial_assets`) and `TRR-Backend/trr_backend/integrations/getty.py:458-514` (`_merge_grouped_event_metadata`)
- Test: `TRR-Backend/tests/integrations/test_getty.py`

**Root cause:** `_merge_grouped_event_metadata` was added to enrich flat candidates with event-group metadata (event name, grouped image count). But it does this by running an independent grouped search and joining by detail_url/editorial_id/object_name. The event metadata could instead be captured during the initial search pass.

- [ ] **Step 1: Write the failing test**

Test `_merge_grouped_event_metadata` directly — it's the function that performs the redundant re-search. The test verifies that when called with candidates, it invokes `_search_asset_candidates_for_phrase` (the double-fetch). Note: testing via `search_editorial_assets` with `include_details=False` won't trigger the grouped merge because it returns early before that call. Testing via `include_details=True` requires realistic HTML. So we test the merge function in isolation.

```python
# tests/integrations/test_getty.py

def test_merge_grouped_event_metadata_does_not_re_search_when_grouped_candidates_provided():
    """_merge_grouped_event_metadata should use provided grouped_candidates, not re-search."""
    from trr_backend.integrations import getty

    candidates = [{"detail_url": "/detail/1234", "editorial_id": "1234", "title": "Test"}]
    grouped = [{"detail_url": "/detail/1234", "editorial_id": "1234", "grouped_image_count": 42}]

    fetcher_called = False
    def should_not_be_called(url):
        nonlocal fetcher_called
        fetcher_called = True
        return {"html": "", "response_url": url, "status_code": 200}

    result = getty._merge_grouped_event_metadata(
        "Test Person",
        candidates,
        grouped_candidates=grouped,
        search_page_fetcher=should_not_be_called,
        limit=10,
    )
    assert not fetcher_called, "Fetcher was called even though grouped_candidates were provided"
    assert len(result) == 1
    assert result[0].get("grouped_image_count") == 42
```

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/integrations/test_getty.py::test_merge_grouped_event_metadata_does_not_re_search_when_grouped_candidates_provided -v`
Expected: FAIL — current signature does not accept `grouped_candidates` param

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/integrations/test_getty.py::test_merge_grouped_event_metadata_does_not_re_search_when_grouped_candidates_provided -v`
Expected: FAIL — `TypeError: unexpected keyword argument 'grouped_candidates'`

- [ ] **Step 3: Refactor `_merge_grouped_event_metadata` to use a pre-fetched grouped index**

The fix: make `search_editorial_assets` accept an optional pre-built grouped candidates list, and when calling `_merge_grouped_event_metadata`, pass the grouped candidates that were already fetched by the caller (in `_import_nbcumv_person_media` or `fetch_person_getty_prefetch_payload`). When no pre-built list is available, skip the merge entirely instead of re-searching.

In `getty.py`, change `_merge_grouped_event_metadata` to accept candidates directly:

```python
def _merge_grouped_event_metadata(
    phrase: str,
    candidates: list[dict[str, Any]],
    *,
    grouped_candidates: list[dict[str, Any]] | None = None,  # NEW: accept pre-fetched
    session: Session | None = None,
    query_params: dict[str, str] | None = None,
    limit: int | None,
    max_search_pages: int | None = MAX_SEARCH_PAGES,
    diagnostics_out: GettyAccessDiagnostics | None = None,
    search_page_fetcher: GettySearchPageFetcher | None = None,
) -> list[dict[str, Any]]:
    if not candidates:
        return candidates

    # Use pre-fetched grouped candidates if available; skip re-search
    if grouped_candidates is None:
        return candidates  # No grouped data available — skip enrichment

    # ... rest of merge logic using grouped_candidates instead of re-searching
```

Then in `search_editorial_assets`, pass `grouped_candidates=None` to skip the redundant search:

```python
    candidates = _merge_grouped_event_metadata(
        cleaned,
        candidates,
        grouped_candidates=None,  # Caller provides grouped data separately
        # ... rest of params
    )
```

The callers that DO want grouped enrichment (`_import_nbcumv_person_media`) already run `search_grouped_events` separately — their results can be passed in via a new param.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/integrations/test_getty.py::test_search_editorial_assets_does_not_double_fetch -v`
Expected: PASS

- [ ] **Step 5: Run full Getty test suite for regressions**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/integrations/test_getty.py -v --tb=short`
Expected: All existing tests PASS

- [ ] **Step 6: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add trr_backend/integrations/getty.py tests/integrations/test_getty.py
git commit -m "perf(getty): eliminate double search in _merge_grouped_event_metadata

The grouped event metadata merge was running a full second Getty search
pass with groupbyevent=true. This doubled HTTP requests and wall-clock
time for every person search. Now accepts pre-fetched grouped candidates
and skips the re-search when none are available."
```

---

## Task 2: Deduplicate editorial IDs across multi-query Getty searches

The pipeline runs multiple search queries (primary person search, fallback person search, show search, additional search, bravo grouped events, broad grouped events, WWHL fallback). Each query can return overlapping editorial IDs, leading to duplicate detail fetches.

**Files:**
- Modify: `TRR-Backend/trr_backend/integrations/getty.py` — `_search_asset_candidates_for_phrase` and `search_editorial_assets`
- Modify: `TRR-Backend/api/routers/admin_person_images.py` — the multi-query orchestration in `_import_nbcumv_person_media`
- Test: `TRR-Backend/tests/integrations/test_getty.py`

- [ ] **Step 1: Write the failing test**

The parser expects `<script data-component="Search">` containing JSON with `{"search":{"gallery":{"assets":[...]}}}` structure. Each asset needs `landingUrl` and `editorialId`. We test `_search_asset_candidates_for_phrase` directly (lower level, easier to mock) to verify dedup within a single query.

```python
def test_search_asset_candidates_deduplicates_by_editorial_id():
    """Duplicate editorial IDs across pages should be deduplicated."""
    import json
    from trr_backend.integrations import getty

    def build_search_html(assets):
        payload = json.dumps({"search": {"gallery": {"assets": assets}}})
        return f'<html><script data-component="Search">{payload}</script></html>'

    asset = {"landingUrl": "/detail/photo/1234", "editorialId": "1234", "title": "Dup Photo"}
    page_html = build_search_html([asset])

    call_count = 0
    def counting_fetcher(url):
        nonlocal call_count
        call_count += 1
        return {"html": page_html, "response_url": url, "status_code": 200}

    # Feed the same asset on every page to simulate cross-page overlap
    results = getty._search_asset_candidates_for_phrase(
        "Test Person",
        limit=10,
        search_page_fetcher=counting_fetcher,
    )
    editorial_ids = [str(r.get("editorial_id") or r.get("editorialId") or "") for r in results]
    editorial_ids_nonempty = [eid for eid in editorial_ids if eid]
    assert len(editorial_ids_nonempty) == len(set(editorial_ids_nonempty)), (
        f"Duplicate editorial IDs in results: {editorial_ids_nonempty}"
    )
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/integrations/test_getty.py::test_search_editorial_assets_deduplicates_by_editorial_id -v`

- [ ] **Step 3: Add editorial ID deduplication to `_search_asset_candidates_for_phrase`**

In `_search_asset_candidates_for_phrase`, maintain a `seen_editorial_ids: set[str]` and skip candidates whose editorial_id is already in the set:

```python
    seen_editorial_ids: set[str] = set()
    # ... in the candidate collection loop:
    for candidate in page_candidates:
        eid = str(candidate.get("editorial_id") or candidate.get("editorialId") or "").strip()
        if eid and eid in seen_editorial_ids:
            continue
        if eid:
            seen_editorial_ids.add(eid)
        all_candidates.append(candidate)
```

Also accept an optional `exclude_editorial_ids: set[str] | None = None` param so the multi-query orchestrator can pass IDs already fetched by earlier queries.

- [ ] **Step 4: Run tests**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/integrations/test_getty.py -v --tb=short`

- [ ] **Step 5: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add trr_backend/integrations/getty.py tests/integrations/test_getty.py
git commit -m "perf(getty): deduplicate editorial IDs across search pages and queries

Adds a seen_editorial_ids set to _search_asset_candidates_for_phrase to
prevent the same asset from being fetched for details multiple times.
Also adds exclude_editorial_ids param for cross-query dedup."
```

---

## Task 3: Cache env-var reads and profile discovery in `getty_local_prefetch.py`

`_resolve_browser_search_page_concurrency()`, `_iter_profile_dirs()`, and `_iter_cookie_files()` all re-read environment variables and scan the filesystem on every call. These values don't change during a scrape job.

**Files:**
- Modify: `TRR-Backend/trr_backend/integrations/getty_local_prefetch.py:72-113,147-155`
- Test: `TRR-Backend/tests/integrations/test_getty_local_prefetch.py`

- [ ] **Step 1: Write the failing test**

**Important:** The test must call `cache_clear()` in setup to avoid cross-test pollution from `@lru_cache`. Also add a `finally` teardown to clear the cache after the test.

```python
def test_resolve_browser_search_page_concurrency_is_stable(monkeypatch):
    """Env var should be read once per process, not on every call."""
    from trr_backend.integrations import getty_local_prefetch

    fn = getty_local_prefetch._resolve_browser_search_page_concurrency
    # Clear any cached value from prior tests
    if hasattr(fn, "cache_clear"):
        fn.cache_clear()

    try:
        monkeypatch.setenv("TRR_GETTY_BROWSER_SEARCH_PAGE_CONCURRENCY", "5")
        result1 = fn()
        monkeypatch.setenv("TRR_GETTY_BROWSER_SEARCH_PAGE_CONCURRENCY", "99")
        result2 = fn()
        assert result1 == 5
        # With caching, result2 should still be 5 (cached)
        assert result2 == 5, "Concurrency value should be cached, not re-read every call"
    finally:
        if hasattr(fn, "cache_clear"):
            fn.cache_clear()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/integrations/test_getty_local_prefetch.py::test_resolve_browser_search_page_concurrency_is_stable -v`
Expected: FAIL — without `@lru_cache`, `result2` will be 99

- [ ] **Step 3: Add `@lru_cache` to `_resolve_browser_search_page_concurrency`**

**Note:** This caches for the entire process lifetime. This is safe because the function is only called during a single scrape job subprocess. Tests must call `.cache_clear()` in setup/teardown to avoid pollution.

```python
from functools import lru_cache

@lru_cache(maxsize=1)
def _resolve_browser_search_page_concurrency() -> int:
    raw_value = str(os.getenv("TRR_GETTY_BROWSER_SEARCH_PAGE_CONCURRENCY") or "").strip()
    if not raw_value:
        return _DEFAULT_BROWSER_SEARCH_PAGE_CONCURRENCY
    try:
        parsed = int(raw_value)
    except ValueError:
        return _DEFAULT_BROWSER_SEARCH_PAGE_CONCURRENCY
    return max(1, parsed)
```

- [ ] **Step 4: Run tests**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/integrations/test_getty_local_prefetch.py -v --tb=short`

- [ ] **Step 5: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add trr_backend/integrations/getty_local_prefetch.py tests/integrations/test_getty_local_prefetch.py
git commit -m "perf(getty-prefetch): cache env-var reads for browser concurrency"
```

---

## Task 4: Eliminate double `_collect_known_people_names` call in `get_images_pipeline.py`

`_collect_known_people_names(raw_payloads)` is called inside `_normalize_candidate_records` (line 466) and AGAIN inside `build_bridge_and_catalog` (line 567). Both iterate all getty/nbcumv/bravo rows extracting people names from captions. The first call's result is thrown away.

**Files:**
- Modify: `TRR-Backend/trr_backend/bravotv/get_images_pipeline.py:465-477,565-698`
- Test: `TRR-Backend/tests/integrations/test_getty.py` (or a new targeted test)

- [ ] **Step 1: Write the failing test**

```python
def test_build_bridge_and_catalog_collects_known_people_once():
    """_collect_known_people_names should be called once, not twice."""
    from unittest.mock import patch
    from trr_backend.bravotv.get_images_pipeline import build_bridge_and_catalog

    call_count = 0
    original_fn = None

    def counting_collect(raw_payloads):
        nonlocal call_count
        call_count += 1
        return original_fn(raw_payloads)

    import trr_backend.bravotv.get_images_pipeline as mod
    original_fn = mod._collect_known_people_names

    with patch.object(mod, "_collect_known_people_names", side_effect=counting_collect):
        build_bridge_and_catalog({"getty": [], "nbcumv": [], "bravo": []})

    assert call_count == 1, f"_collect_known_people_names called {call_count} times, expected 1"
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — currently called twice (line 466 and 567)

- [ ] **Step 3: Refactor to compute `known_people` once and pass it through**

Change `_normalize_candidate_records` to accept and return `known_people`:

```python
def _normalize_candidate_records(
    raw_payloads: Mapping[str, Any],
    known_people: list[str] | None = None,
) -> tuple[list[dict[str, Any]], list[str]]:
    if known_people is None:
        known_people = _collect_known_people_names(raw_payloads)
    normalized: list[dict[str, Any]] = []
    # ... same logic ...
    return normalized, known_people
```

Update `build_bridge_and_catalog`:

```python
def build_bridge_and_catalog(raw_payloads: Mapping[str, Any]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    records, known_people = _normalize_candidate_records(raw_payloads)
    # Use known_people directly instead of calling _collect_known_people_names again
    # ... rest of function uses known_people param
```

- [ ] **Step 4: Run tests**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/ -k "bridge" -v --tb=short`

- [ ] **Step 5: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add trr_backend/bravotv/get_images_pipeline.py
git commit -m "perf(pipeline): compute known_people once in bridge_and_catalog

_collect_known_people_names was called twice — once in
_normalize_candidate_records and again in build_bridge_and_catalog.
Now computed once and threaded through."
```

---

## Task 5: Fix duplicate fields in `RefreshImagesResponse`

`bravotv_attribution_skipped`, `bravotv_episode_routed`, and `bravotv_skip_gallery_count` are each declared **twice** in the Pydantic model (lines 548-550 and 551-553). Pydantic silently uses the last declaration, but this is a latent bug — the first declaration's default value is invisible.

**Files:**
- Modify: `TRR-Backend/api/routers/admin_person_images.py:548-553`
- Test: `TRR-Backend/tests/api/routers/test_admin_person_images.py`

- [ ] **Step 1: Write the failing test (AST-based source inspection)**

Pydantic v2 `model_fields` deduplicates keys silently, so a runtime test always passes. Instead, inspect the source code with `ast` to find duplicate class-level assignments:

```python
import ast
from pathlib import Path

def test_refresh_images_response_has_no_duplicate_source_fields():
    """RefreshImagesResponse source code should not have duplicate field assignments."""
    source_path = Path(__file__).resolve().parent.parent.parent / "api" / "routers" / "admin_person_images.py"
    source = source_path.read_text()
    tree = ast.parse(source)

    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef) and node.name == "RefreshImagesResponse":
            field_names = []
            for item in node.body:
                if isinstance(item, ast.AnnAssign) and isinstance(item.target, ast.Name):
                    field_names.append(item.target.id)
            duplicates = [name for name in field_names if field_names.count(name) > 1]
            assert not duplicates, (
                f"Duplicate field declarations in RefreshImagesResponse: {set(duplicates)}"
            )
            return
    raise AssertionError("RefreshImagesResponse class not found in source")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/api/routers/test_admin_person_images.py::test_refresh_images_response_has_no_duplicate_source_fields -v`
Expected: FAIL — finds `bravotv_attribution_skipped`, `bravotv_episode_routed`, `bravotv_skip_gallery_count` as duplicates

- [ ] **Step 3: Remove the duplicate declarations**

In `admin_person_images.py`, remove the second set of these three fields (lines ~551-553):

```python
    # DELETE these three duplicate lines:
    bravotv_attribution_skipped: int = 0
    bravotv_episode_routed: int = 0
    bravotv_skip_gallery_count: int = 0
```

Keep only the first declarations (lines ~548-550).

- [ ] **Step 4: Verify compile + lint**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m py_compile api/routers/admin_person_images.py && ruff check api/routers/admin_person_images.py`

- [ ] **Step 5: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add api/routers/admin_person_images.py
git commit -m "fix(admin): remove duplicate field declarations in RefreshImagesResponse

bravotv_attribution_skipped, bravotv_episode_routed, and
bravotv_skip_gallery_count were each declared twice in the Pydantic model."
```

---

## Task 6: Replace per-item ThreadPoolExecutor with shared executor for NBCUMV imports

`_run_nbcumv_item_import_with_timeout` (admin_person_images.py:~2198) creates a **new** `ThreadPoolExecutor(max_workers=1)` for every single NBCUMV import item, then immediately shuts it down. For a person with 100+ NBCUMV matches, this creates and destroys 100+ thread pools. Use a shared executor with per-future timeout instead.

**Files:**
- Modify: `TRR-Backend/api/routers/admin_person_images.py:2198-2217`
- Test: `TRR-Backend/tests/api/routers/test_admin_person_images.py`

- [ ] **Step 1: Write the test**

```python
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import patch

def test_nbcumv_import_does_not_create_executor_per_item():
    """NBCUMV imports should reuse a single ThreadPoolExecutor, not create one per item."""
    executor_init_count = 0
    OriginalTPE = ThreadPoolExecutor

    class CountingTPE(OriginalTPE):
        def __init__(self, *args, **kwargs):
            nonlocal executor_init_count
            executor_init_count += 1
            super().__init__(*args, **kwargs)

    # Patch ThreadPoolExecutor in the admin_person_images module
    with patch("api.routers.admin_person_images.ThreadPoolExecutor", CountingTPE):
        # Import and call _run_nbcumv_item_import_with_timeout 3 times
        # (exact invocation depends on test fixtures for db/items)
        # After refactor: executor_init_count should be 1 (shared), not 3 (per-item)
        pass

    # NOTE: This test skeleton must be wired to a test fixture that calls the
    # NBCUMV import path with 3+ items. The assertion is:
    assert executor_init_count <= 1, (
        f"ThreadPoolExecutor created {executor_init_count} times — should be 1 (shared)"
    )
```

**Note:** The exact test fixture wiring depends on the existing test harness for `_import_nbcumv_person_media`. The implementer should adapt this pattern to the existing Supabase mock fixtures in `test_admin_person_images.py`.

- [ ] **Step 2: Refactor to hoist executor outside the per-item loop**

Move the `ThreadPoolExecutor` creation to the scope of `_import_nbcumv_person_media` and pass it into the per-item helper:

```python
    # In _import_nbcumv_person_media, before the import loop:
    nbcumv_executor = ThreadPoolExecutor(
        max_workers=2,
        thread_name_prefix="person-nbcumv-import",
    )

    def _run_nbcumv_item_import_with_timeout(*, item: NbcumvImportItem) -> dict[str, Any]:
        future = nbcumv_executor.submit(
            _import_single_item,
            db=db,
            item=item,
            assign_people=True,
            people_index={},
        )
        try:
            return future.result(timeout=nbcumv_import_item_timeout_seconds)
        except FuturesTimeoutError as exc:
            future.cancel()
            raise TimeoutError(
                f"NBCUMV asset import timed out after {nbcumv_import_item_timeout_seconds:.2f}s"
            ) from exc

    # After the import loop:
    nbcumv_executor.shutdown(wait=True, cancel_futures=False)
```

- [ ] **Step 3: Run tests**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/api/routers/test_admin_person_images.py -v --tb=short -x`

- [ ] **Step 4: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add api/routers/admin_person_images.py tests/api/routers/test_admin_person_images.py
git commit -m "perf(admin): reuse ThreadPoolExecutor for NBCUMV imports

Was creating and destroying a new ThreadPoolExecutor(max_workers=1) for
every single NBCUMV import item. Now creates one shared executor for
the entire import loop."
```

---

## Task 7: Replace `limit(1000)` gallery count query with efficient `count="exact"` + `limit(1)`

`_count_existing_person_gallery_assets_for_source("nbcumv")` (admin_person_images.py:~2043) fetches up to 1000 full rows with an inner join just to compute `len(rows)`. The count is emitted into SSE progress payloads (line 2155: `result["existing_nbcumv_gallery_count"]`), so we must preserve the integer count. Use `count="exact"` with `limit(1)` to get the real count from Postgres without transferring 1000 rows.

**Files:**
- Modify: `TRR-Backend/api/routers/admin_person_images.py:2043-2068`
- Test: `TRR-Backend/tests/api/routers/test_admin_person_images.py`

- [ ] **Step 1: Verify existing usage**

Check that `existing_nbcumv_gallery_count` is emitted as an integer in SSE progress (line ~2155) and used as `> 0` boolean (line ~2151). The fix must preserve both the integer count for SSE and the boolean usage.

- [ ] **Step 2: Change to `count="exact"` with `limit(1)` and preserve the source join filter**

```python
    def _count_existing_person_gallery_assets_for_source(source: str) -> int:
        normalized_source = str(source or "").strip().lower()
        if not normalized_source:
            return 0
        try:
            response = (
                db.schema("core")
                .table("media_links")
                .select("id, media_assets!inner(source)", count="exact")
                .eq("entity_type", "person")
                .eq("entity_id", person_id)
                .eq("kind", "gallery")
                .eq("media_assets.source", normalized_source)
                .limit(1)
                .execute()
            )
            return int(response.count or 0)
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "Failed to count existing person gallery assets for source=%s person_id=%s: %s",
                normalized_source,
                person_id,
                exc,
            )
            return 0
```

**Key changes vs. original:** `count="exact"` asks Postgres to compute the real count server-side. `limit(1)` avoids transferring rows. The `media_assets!inner(source)` join and `.eq("media_assets.source", ...)` filter are preserved. Return type stays `int`.

- [ ] **Step 3: Run tests**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/api/routers/test_admin_person_images.py -v --tb=short -x`

- [ ] **Step 4: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add api/routers/admin_person_images.py tests/api/routers/test_admin_person_images.py
git commit -m "perf(admin): use limit(1) existence check for NBCUMV gallery count

Was fetching up to 1000 rows with a join just to check > 0. Now uses
limit(1) with count='exact' for a single-row existence check."
```

---

## Task 8: Add TTL cleanup for Getty prefetch tmp files

`GETTY_PREFETCH_TMP_DIR` (`/tmp/trr-getty-prefetch/`) accumulates JSON state files that are never cleaned up. `deleteGettyPrefetchPayload` is exported but never called. Over time this fills tmp with stale files.

**Files:**
- Modify: `TRR-APP/apps/web/src/lib/server/admin/getty-local-scrape.ts`
- Test: `TRR-APP/apps/web/tests/getty-local-scrape-route.test.ts`

- [ ] **Step 1: Write the test**

```typescript
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { cleanupStalePrefetchFiles } from "@/lib/server/admin/getty-local-scrape";
import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";

describe("cleanupStalePrefetchFiles", () => {
  const testDir = path.join(os.tmpdir(), "trr-getty-prefetch-test");

  beforeEach(async () => {
    await fs.mkdir(testDir, { recursive: true });
  });

  afterEach(async () => {
    await fs.rm(testDir, { recursive: true, force: true });
  });

  it("removes files older than maxAgeMs", async () => {
    const filePath = path.join(testDir, "old-token.json");
    await fs.writeFile(filePath, JSON.stringify({ status: "completed" }));
    // Touch the file to be old
    const oldTime = new Date(Date.now() - 3 * 60 * 60 * 1000);
    await fs.utimes(filePath, oldTime, oldTime);

    const removed = await cleanupStalePrefetchFiles(testDir, 2 * 60 * 60 * 1000);
    expect(removed).toBe(1);
  });
});
```

- [ ] **Step 2: Add `readdir` and `stat` to imports, then implement `cleanupStalePrefetchFiles`**

First, update the import at the top of `getty-local-scrape.ts` (line 3):

```typescript
// Change:
import { access, mkdir, readFile, rm, writeFile } from "node:fs/promises";
// To:
import { access, mkdir, readdir, readFile, rm, stat, writeFile } from "node:fs/promises";
```

Then add the exported function:

```typescript
export const cleanupStalePrefetchFiles = async (
  dir: string = GETTY_PREFETCH_TMP_DIR,
  maxAgeMs: number = 2 * 60 * 60 * 1000 // 2 hours
): Promise<number> => {
  const now = Date.now();
  let removed = 0;
  try {
    const entries = await readdir(dir);
    for (const entry of entries) {
      if (!entry.endsWith(".json")) continue;
      const filePath = path.join(dir, entry);
      try {
        const fileStat = await stat(filePath);
        if (now - fileStat.mtimeMs > maxAgeMs) {
          await rm(filePath, { force: true });
          removed += 1;
        }
      } catch { /* skip individual file errors */ }
    }
  } catch { /* dir doesn't exist — nothing to clean */ }
  return removed;
};
```

- [ ] **Step 3: Call cleanup at the start of `createGettyPrefetchJob`**

```typescript
export const createGettyPrefetchJob = async (...) => {
  await mkdir(GETTY_PREFETCH_TMP_DIR, { recursive: true });
  // Best-effort cleanup of stale files before creating new ones
  cleanupStalePrefetchFiles().catch(() => {});
  // ... rest of function
};
```

- [ ] **Step 4: Run tests**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/getty-local-scrape-route.test.ts`

- [ ] **Step 5: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
git add apps/web/src/lib/server/admin/getty-local-scrape.ts apps/web/tests/getty-local-scrape-route.test.ts
git commit -m "fix(getty-prefetch): add TTL cleanup for stale prefetch tmp files

Prefetch JSON state files were never cleaned up, accumulating in
/tmp/trr-getty-prefetch/. Now runs best-effort cleanup of files older
than 2 hours at the start of each new prefetch job."
```

---

## Task 9: Extract shared `hydrateGettyPrefetchPayload` from route files

`hydrateGettyPrefetchPayload` is copy-pasted identically (~40 lines) in both:
- `refresh-images/route.ts`
- `refresh-images/stream/route.ts`

Any bug fix to one must be manually applied to the other.

**Files:**
- Modify: `TRR-APP/apps/web/src/lib/server/admin/getty-local-scrape.ts` (add export)
- Modify: `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/refresh-images/route.ts` (import shared)
- Modify: `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/refresh-images/stream/route.ts` (import shared)
- Test: `TRR-APP/apps/web/tests/getty-local-scrape-payload-compact.test.ts`

- [ ] **Step 1: Write the test for the shared function**

```typescript
import { describe, it, expect } from "vitest";
import { hydrateGettyPrefetchPayload } from "@/lib/server/admin/getty-local-scrape";

describe("hydrateGettyPrefetchPayload (shared)", () => {
  it("returns body unchanged when no prefetch_token", async () => {
    const body = JSON.stringify({ sources: ["nbcumv"] });
    const result = await hydrateGettyPrefetchPayload(body);
    expect(JSON.parse(result)).toEqual({ sources: ["nbcumv"] });
  });

  it("returns body unchanged when assets already present", async () => {
    const body = JSON.stringify({
      getty_prefetch_token: "abc",
      getty_prefetched_assets: [{ id: "1" }],
    });
    const result = await hydrateGettyPrefetchPayload(body);
    const parsed = JSON.parse(result);
    expect(parsed.getty_prefetched_assets).toEqual([{ id: "1" }]);
  });
});
```

- [ ] **Step 2: Move `hydrateGettyPrefetchPayload` to `getty-local-scrape.ts` and export it**

Copy the function from `route.ts` to `getty-local-scrape.ts` as an exported function. It already uses `readGettyPrefetchPayload` from the same module.

- [ ] **Step 3: Replace both inline copies with imports**

In both `route.ts` and `stream/route.ts`:

```typescript
import {
  hydrateGettyPrefetchPayload,
  readGettyPrefetchPayload,
} from "@/lib/server/admin/getty-local-scrape";
```

Delete the local `hydrateGettyPrefetchPayload` function from both route files.

- [ ] **Step 4: Run tests**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/getty-local-scrape-payload-compact.test.ts tests/getty-local-scrape-route.test.ts tests/person-getty-enrichment-route.test.ts`

- [ ] **Step 5: Run ESLint on modified files**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec eslint src/lib/server/admin/getty-local-scrape.ts 'src/app/api/admin/trr-api/people/[personId]/refresh-images/route.ts' 'src/app/api/admin/trr-api/people/[personId]/refresh-images/stream/route.ts'`

- [ ] **Step 6: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
git add apps/web/src/lib/server/admin/getty-local-scrape.ts \
  'apps/web/src/app/api/admin/trr-api/people/[personId]/refresh-images/route.ts' \
  'apps/web/src/app/api/admin/trr-api/people/[personId]/refresh-images/stream/route.ts' \
  apps/web/tests/getty-local-scrape-payload-compact.test.ts
git commit -m "refactor(getty): extract shared hydrateGettyPrefetchPayload

Was copy-pasted identically in both the refresh-images route and the
stream route. Now lives in getty-local-scrape.ts and is imported by both."
```

---

## Summary of Expected Impact

| Task | Type | Impact |
|------|------|--------|
| 1. Eliminate double Getty search | **Perf** | ~2x faster Getty search phase (halves HTTP requests) |
| 2. Deduplicate editorial IDs | **Perf** | Eliminates redundant detail fetches across queries |
| 3. Cache env-var reads | **Perf** | Minor — removes repeated fs/env reads per scrape |
| 4. Single `_collect_known_people_names` | **Perf** | Eliminates redundant caption parsing pass |
| 5. Fix duplicate Pydantic fields | **Bug** | Prevents silent field shadowing |
| 6. Shared ThreadPoolExecutor | **Perf** | Eliminates 100+ executor create/destroy cycles per import |
| 7. Limit(1) existence check | **Perf** | Replaces 1000-row fetch with single-row existence check |
| 8. TTL cleanup for tmp files | **Bug** | Prevents unbounded disk usage in /tmp |
| 9. Extract shared hydrate function | **DRY** | Single source of truth, no divergence risk |

**Execution order:** Tasks 1-7 (Backend) can be done first as a batch. Tasks 8-9 (APP) form a second batch. No cross-repo dependencies between tasks.
