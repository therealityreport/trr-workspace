# Bravo Event Deep Scraping & Other Events Gallery Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** When "Get Images" runs, scrape ALL person-matching images from Bravo events (with NBCUMV crosswalk), but only ONE cover image from non-Bravo events. Display non-Bravo events in a separate "Other Events" container with gallery covers that prompt the user to scrape more on click. Fix event counts to show person-specific image counts instead of total event counts.

**Architecture:** Three-layer change — (1) Backend `getty.py` gets a new `scan_event_page_for_person()` function that paginates a Getty event page and returns all person-matching assets. (2) Backend `admin_person_images.py` uses this for Bravo events (full scan + NBCUMV crosswalk) while keeping single-cover behavior for broad events, and stores a `person_image_count` alongside `grouped_image_count`. (3) Frontend adds an "Other Events" gallery section with cover cards and a "Scrape More" action, and reads `person_image_count` for display instead of `grouped_image_count`.

**Tech Stack:** Python (requests, BeautifulSoup), TypeScript/React (Next.js), Supabase (cast_photos table), existing NBCUMV integration

---

## Task 1: Add `scan_event_page_for_person()` to `getty.py`

**Context:** The existing `fetch_grouped_event_page()` (line 356-400 in `getty.py`) scans up to `detail_limit` (default 6) images on an event page and returns one `representative_asset` plus one `matched_asset`. We need a new function that paginates through ALL images on a Getty event page and returns every asset that matches the person.

The Getty event page URL looks like: `https://www.gettyimages.com/photos/event-name?eventid=12345` or the `event_url` from the grouped search. Each page returns up to 60 assets (same as `DEFAULT_SEARCH_PAGE_SIZE`). We reuse `_extract_search_asset_candidates()` to parse each page, then `fetch_asset_detail()` + `_asset_matches_person()` for filtering.

**Files:**
- Modify: `TRR-Backend/trr_backend/integrations/getty.py:356-400`
- Test: `TRR-Backend/tests/integrations/test_getty.py`

**Step 1: Write the failing test**

```python
# Add to tests/integrations/test_getty.py

def test_scan_event_page_for_person_returns_all_matching_assets(monkeypatch) -> None:
    """scan_event_page_for_person should paginate through event images
    and return only those matching the person name."""
    # Simulate an event page with 3 candidates, 2 of which match the person
    fake_candidates = [
        {
            "detail_url": "https://www.gettyimages.com/detail/news-photo/img-one/1",
            "event_name": "BravoCon 2023",
        },
        {
            "detail_url": "https://www.gettyimages.com/detail/news-photo/img-two/2",
            "event_name": "BravoCon 2023",
        },
        {
            "detail_url": "https://www.gettyimages.com/detail/news-photo/img-three/3",
            "event_name": "BravoCon 2023",
        },
    ]
    # _search_asset_candidates_for_phrase returns all 3, then empty on page 2
    call_count = {"n": 0}

    def fake_search_candidates(phrase, *, limit, session=None, query_params=None):
        call_count["n"] += 1
        if call_count["n"] == 1:
            return list(fake_candidates)
        return []

    monkeypatch.setattr(getty, "_search_asset_candidates_for_phrase", fake_search_candidates)

    def fake_fetch_detail(detail_url, *, session=None):
        asset_id = detail_url.rsplit("/", 1)[-1]
        base = {
            "detail_url": detail_url,
            "object_name": f"OBJ_{asset_id}",
            "editorial_id": asset_id,
        }
        # Assets 1 and 3 mention the person, asset 2 does not
        if asset_id in ("1", "3"):
            base["caption"] = "Brandi Glanville at BravoCon"
        else:
            base["caption"] = "Andy Cohen at BravoCon"
        return base

    monkeypatch.setattr(getty, "fetch_asset_detail", fake_fetch_detail)

    results = getty.scan_event_page_for_person(
        event_url="https://www.gettyimages.com/photos/bravocon-2023?eventid=99999",
        person_name="Brandi Glanville",
    )

    assert results is not None
    assert len(results["matched_assets"]) == 2
    assert results["person_image_count"] == 2
    assert results["total_scanned"] == 3
    assert results["matched_assets"][0]["editorial_id"] == "1"
    assert results["matched_assets"][1]["editorial_id"] == "3"


def test_scan_event_page_for_person_respects_limit(monkeypatch) -> None:
    """scan_event_page_for_person should stop after scanning scan_limit assets."""
    fake_candidates = [
        {"detail_url": f"https://www.gettyimages.com/detail/news-photo/img/{i}"}
        for i in range(1, 201)
    ]

    def fake_search_candidates(phrase, *, limit, session=None, query_params=None):
        return list(fake_candidates)

    monkeypatch.setattr(getty, "_search_asset_candidates_for_phrase", fake_search_candidates)

    fetched_count = {"n": 0}

    def fake_fetch_detail(detail_url, *, session=None):
        fetched_count["n"] += 1
        return {
            "detail_url": detail_url,
            "object_name": f"OBJ_{fetched_count['n']}",
            "editorial_id": str(fetched_count["n"]),
            "caption": "Brandi Glanville at event",
        }

    monkeypatch.setattr(getty, "fetch_asset_detail", fake_fetch_detail)

    results = getty.scan_event_page_for_person(
        event_url="https://www.gettyimages.com/photos/event?eventid=1",
        person_name="Brandi Glanville",
        scan_limit=50,
    )

    assert results["total_scanned"] == 50
```

**Step 2: Run test to verify it fails**

Run: `cd TRR-Backend && python -m pytest tests/integrations/test_getty.py::test_scan_event_page_for_person_returns_all_matching_assets tests/integrations/test_getty.py::test_scan_event_page_for_person_respects_limit -v`
Expected: FAIL with `AttributeError: module 'trr_backend.integrations.getty' has no attribute 'scan_event_page_for_person'`

**Step 3: Write minimal implementation**

Add to `getty.py` after `fetch_grouped_event_page()` (after line 400):

```python
DEFAULT_EVENT_SCAN_LIMIT = 200


def scan_event_page_for_person(
    event_url: str,
    *,
    person_name: str,
    session: Session | None = None,
    scan_limit: int = DEFAULT_EVENT_SCAN_LIMIT,
    progress_cb: GettyProgressCallback | None = None,
) -> dict[str, Any] | None:
    """Paginate through a Getty event page and return ALL assets matching the person.

    Unlike fetch_grouped_event_page() which returns one representative,
    this scans up to scan_limit assets and returns every person match.
    """
    cleaned_url = str(event_url or "").strip()
    normalized_person = _normalize_name(person_name)
    if not cleaned_url or not normalized_person:
        return None

    # Extract event phrase from URL for pagination via search
    # Getty event pages can be searched with eventid param
    client = _session(session)
    try:
        response = client.get(cleaned_url, headers=_DEFAULT_HEADERS, timeout=DEFAULT_TIMEOUT_SECONDS)
        response.raise_for_status()
    except RequestException as exc:
        logger.warning("Getty event page scan failed for %s: %s", cleaned_url, exc)
        return None

    all_candidates = _extract_search_asset_candidates(response.text)
    if not all_candidates:
        all_candidates = [{"detail_url": url} for url in _extract_detail_urls_from_html(response.text)]

    safe_limit = max(1, int(scan_limit))
    candidates_to_scan = all_candidates[:safe_limit]
    total = len(candidates_to_scan)

    matched_assets: list[dict[str, Any]] = []
    all_scanned: list[dict[str, Any]] = []

    for index, candidate in enumerate(candidates_to_scan, start=1):
        detail_url = str(candidate.get("detail_url") or "").strip()
        if not detail_url:
            continue
        if progress_cb:
            progress_cb(index - 1, total, f"Scanning event asset {index}/{total}: {detail_url}")
        detail = fetch_asset_detail(detail_url, session=client)
        if not detail:
            continue
        merged = _merge_search_candidate_with_detail(candidate, detail)
        all_scanned.append(merged)
        if _asset_matches_person(merged, person_name):
            matched_assets.append(merged)
        if progress_cb:
            progress_cb(index, total, f"Scanned {index}/{total}, {len(matched_assets)} matches so far")

    return {
        "event_url": cleaned_url,
        "total_scanned": len(all_scanned),
        "person_image_count": len(matched_assets),
        "matched_assets": matched_assets,
        "representative_asset": matched_assets[0] if matched_assets else (all_scanned[0] if all_scanned else None),
    }
```

**Step 4: Run test to verify it passes**

Run: `cd TRR-Backend && python -m pytest tests/integrations/test_getty.py::test_scan_event_page_for_person_returns_all_matching_assets tests/integrations/test_getty.py::test_scan_event_page_for_person_respects_limit -v`
Expected: PASS

**Step 5: Commit**

```bash
git add TRR-Backend/trr_backend/integrations/getty.py TRR-Backend/tests/integrations/test_getty.py
git commit -m "feat(getty): add scan_event_page_for_person for full event page scanning"
```

---

## Task 2: Update `search_grouped_events()` to support full-scan mode for Bravo events

**Context:** Currently `search_grouped_events()` (line 147-232) fetches ONE `representative_asset` per event. For Bravo events, we need it to call `scan_event_page_for_person()` to get ALL person-matching assets. We add a `full_scan_person_assets` boolean parameter. When `True`, each event result includes a `matched_assets` list (plural) instead of just one `matched_asset`.

**Files:**
- Modify: `TRR-Backend/trr_backend/integrations/getty.py:147-232`
- Test: `TRR-Backend/tests/integrations/test_getty.py`

**Step 1: Write the failing test**

```python
def test_search_grouped_events_full_scan_returns_multiple_matched_assets(monkeypatch) -> None:
    """When full_scan_person_assets=True, search_grouped_events should
    return all person-matching assets per event, not just one."""
    # Mock _search_asset_candidates_for_phrase to return one event candidate
    monkeypatch.setattr(
        getty,
        "_search_asset_candidates_for_phrase",
        lambda phrase, **kwargs: [
            {
                "detail_url": "https://www.gettyimages.com/photos/bravocon-2023?eventid=100",
                "event_name": "BravoCon 2023",
                "grouped_image_count": 50,
            }
        ],
    )

    # Mock fetch_asset_detail for the representative asset
    monkeypatch.setattr(
        getty,
        "fetch_asset_detail",
        lambda detail_url, **kwargs: {
            "detail_url": detail_url,
            "object_name": "OBJ_REP",
            "editorial_id": "rep",
            "caption": "Brandi Glanville at BravoCon",
        },
    )

    # Mock scan_event_page_for_person to return 5 matches
    monkeypatch.setattr(
        getty,
        "scan_event_page_for_person",
        lambda event_url, person_name, **kwargs: {
            "event_url": event_url,
            "total_scanned": 50,
            "person_image_count": 5,
            "matched_assets": [
                {"editorial_id": str(i), "object_name": f"OBJ_{i}", "caption": "Brandi Glanville"}
                for i in range(1, 6)
            ],
            "representative_asset": {"editorial_id": "1", "object_name": "OBJ_1"},
        },
    )

    results = getty.search_grouped_events(
        "Brandi Glanville Bravo",
        limit=10,
        person_name="Brandi Glanville",
        full_scan_person_assets=True,
        source_query_scope="bravo",
    )

    assert len(results) == 1
    event = results[0]
    assert event["person_image_count"] == 5
    assert len(event.get("matched_assets_list", [])) == 5
    assert event["source_query_scope"] == "bravo"
```

**Step 2: Run test to verify it fails**

Run: `cd TRR-Backend && python -m pytest tests/integrations/test_getty.py::test_search_grouped_events_full_scan_returns_multiple_matched_assets -v`
Expected: FAIL — `full_scan_person_assets` param not accepted or `matched_assets_list` not present

**Step 3: Modify `search_grouped_events()` implementation**

In `getty.py`, update the `search_grouped_events` signature to add the new parameter:

```python
def search_grouped_events(
    phrase: str,
    *,
    limit: int = 50,
    session: Session | None = None,
    progress_cb: GettyProgressCallback | None = None,
    query_params: dict[str, str] | None = None,
    person_name: str | None = None,
    person_match_required: bool = False,
    minimum_grouped_image_count: int | None = None,
    event_detail_sample_limit: int = DEFAULT_EVENT_DETAIL_SAMPLE_LIMIT,
    source_query_scope: str | None = None,
    full_scan_person_assets: bool = False,
) -> list[dict[str, Any]]:
```

Then inside the `for index, candidate in enumerate(candidates[:total], start=1):` loop, after the existing `_merge_grouped_event_candidate_with_page()` call (around line 199-203), add a branch:

```python
        # --- NEW: full event page scan for Bravo events ---
        if full_scan_person_assets and person_name:
            scan_result = scan_event_page_for_person(
                event_url,
                person_name=person_name,
                session=session,
                progress_cb=progress_cb,
            )
            if scan_result and scan_result.get("matched_assets"):
                merged["matched_assets_list"] = scan_result["matched_assets"]
                merged["person_image_count"] = scan_result["person_image_count"]
                merged["event_asset_count_scanned"] = scan_result["total_scanned"]
                merged["matched_asset"] = scan_result["matched_assets"][0]
                merged["representative_asset"] = scan_result["representative_asset"]
            elif scan_result:
                merged["matched_assets_list"] = []
                merged["person_image_count"] = 0
                merged["event_asset_count_scanned"] = scan_result["total_scanned"]
        # --- END NEW ---
```

**Step 4: Run test to verify it passes**

Run: `cd TRR-Backend && python -m pytest tests/integrations/test_getty.py::test_search_grouped_events_full_scan_returns_multiple_matched_assets -v`
Expected: PASS

**Step 5: Run full getty test suite**

Run: `cd TRR-Backend && python -m pytest tests/integrations/test_getty.py -v`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add TRR-Backend/trr_backend/integrations/getty.py TRR-Backend/tests/integrations/test_getty.py
git commit -m "feat(getty): add full_scan_person_assets mode to search_grouped_events"
```

---

## Task 3: Update backend pipeline to use full-scan for Bravo events

**Context:** In `admin_person_images.py`, the refresh pipeline (line 1382-1398) calls `search_grouped_events()` twice — once for Bravo (scope=`"bravo"`) and once for broad (scope=`"broad"`). Currently both return one asset per event, and both flow through `_capture_grouped_event_inventory()` (line 1732-1770) which extracts a single `event_asset` via `_build_event_asset_candidate()`.

Changes needed:
1. Pass `full_scan_person_assets=True` for the Bravo call
2. Update `_capture_grouped_event_inventory()` to expand `matched_assets_list` into multiple `broad_event_assets` entries for Bravo events
3. Store `person_image_count` in inventory entries alongside `grouped_image_count`

**Files:**
- Modify: `TRR-Backend/api/routers/admin_person_images.py:1382-1398` (search calls)
- Modify: `TRR-Backend/api/routers/admin_person_images.py:1138-1190` (inventory entry builder)
- Modify: `TRR-Backend/api/routers/admin_person_images.py:1732-1770` (capture grouped event inventory)

**Step 1: Enable `full_scan_person_assets=True` on Bravo search call**

At line 1384-1388, change:

```python
    bravo_grouped_events = getty_integration.search_grouped_events(
        bravo_grouped_phrase,
        limit=max(1, int(limit)),
        person_name=normalized_person_name,
        source_query_scope="bravo",
    )
```

to:

```python
    bravo_grouped_events = getty_integration.search_grouped_events(
        bravo_grouped_phrase,
        limit=max(1, int(limit)),
        person_name=normalized_person_name,
        source_query_scope="bravo",
        full_scan_person_assets=True,
    )
```

**Step 2: Add `person_image_count` to `_build_event_inventory_entry()`**

At line 1156-1190, in the returned dict, add after `"grouped_image_count"`:

```python
            "person_image_count": event.get("person_image_count"),
```

**Step 3: Update `_capture_grouped_event_inventory()` to expand Bravo event assets**

At line 1732-1770, the current function extracts one `event_asset` per event and appends it to `broad_event_assets`. For Bravo events with `matched_assets_list`, we need to expand each matched asset into a separate entry in the assets pipeline.

Replace the block inside the for-loop that builds `broad_event_assets` (lines 1755-1769). The key change: when the event has a `matched_assets_list` (from full scan), iterate over each matched asset and add it individually instead of just the single representative:

```python
            matched_assets_list = event.get("matched_assets_list")
            if isinstance(matched_assets_list, list) and matched_assets_list:
                # Bravo full-scan: add EACH person-matching asset
                for matched_asset in matched_assets_list:
                    if not isinstance(matched_asset, dict):
                        continue
                    m_editorial_id = str(matched_asset.get("editorial_id") or "").strip()
                    if not m_editorial_id or m_editorial_id in seen_editorial_ids:
                        continue
                    # Enrich matched asset with event-level metadata
                    enriched = dict(matched_asset)
                    enriched["event_name"] = str(event.get("event_name") or enriched.get("event_name") or "").strip() or None
                    enriched["event_id"] = str(event.get("event_id") or enriched.get("event_id") or "").strip() or None
                    enriched["event_url_slug"] = str(event.get("event_url_slug") or enriched.get("event_url_slug") or "").strip() or None
                    enriched["event_url"] = str(event.get("event_url") or "").strip() or None
                    enriched["event_date"] = str(event.get("event_date") or enriched.get("event_date") or "").strip() or None
                    enriched["grouped_image_count"] = event.get("grouped_image_count")
                    enriched["person_image_count"] = event.get("person_image_count")
                    enriched["source_query_scope"] = str(event.get("source_query_scope") or "").strip() or None
                    broad_event_assets.append(
                        (
                            enriched,
                            resolved_event_show,
                            resolved_event_show_title or None,
                            bucket_metadata,
                        )
                    )
                    seen_editorial_ids.add(m_editorial_id)
            elif (
                bucket_metadata.get("bucket_type") == "event"
                and isinstance(event_asset, dict)
                and editorial_id
                and editorial_id not in seen_editorial_ids
            ):
                # Original behavior: one representative asset (broad/non-Bravo events)
                broad_event_assets.append(
                    (
                        event_asset,
                        resolved_event_show,
                        resolved_event_show_title or None,
                        bucket_metadata,
                    )
                )
                seen_editorial_ids.add(editorial_id)
```

**Step 4: Propagate `person_image_count` into getty-only cast_photo rows**

In `_build_getty_cast_photo_row()` (line 1204-1294), add to the `metadata` dict (after the `"grouped_image_count"` line at 1242):

```python
            "person_image_count": asset.get("person_image_count"),
```

Also add it to the NBCUMV matched metadata path (around line 1882-1884), in the `matched_bucket_metadata`:

```python
        matched_bucket_metadata["person_image_count"] = asset.get("person_image_count")
```

**Step 5: Verify existing tests still pass**

Run: `cd TRR-Backend && python -m pytest tests/api/routers/test_admin_person_images.py -v`
Expected: All existing tests PASS

**Step 6: Commit**

```bash
git add TRR-Backend/api/routers/admin_person_images.py
git commit -m "feat(admin-images): full-scan Bravo events for all person-matching assets with NBCUMV crosswalk"
```

---

## Task 4: Store `source_query_scope` and `person_image_count` in cast_photo metadata for frontend consumption

**Context:** The frontend needs to distinguish Bravo events (fully scraped) from broad/non-Bravo events (cover only). The `source_query_scope` is already stored in metadata (line 1243), but `person_image_count` is new. The frontend also needs `source_query_scope` to render the "Other Events" section. We need to ensure both fields propagate through the NBCUMV-matched path as well.

**Files:**
- Modify: `TRR-Backend/api/routers/admin_person_images.py:1880-1886` (NBCUMV matched path)

**Step 1: Verify `source_query_scope` propagates on the NBCUMV matched path**

At line 1882-1884, the `matched_bucket_metadata` is built from `bucket_metadata`. Check that `source_query_scope` is carried through. Currently it's stored in the asset-level metadata via `_build_event_asset_candidate()` (line 1151) but may not flow into the NBCUMV matched metadata.

Add to the matched metadata block around line 1883:

```python
        matched_bucket_metadata["source_query_scope"] = str(asset.get("source_query_scope") or "").strip() or None
        matched_bucket_metadata["person_image_count"] = asset.get("person_image_count")
```

**Step 2: Commit**

```bash
git add TRR-Backend/api/routers/admin_person_images.py
git commit -m "feat(admin-images): propagate source_query_scope and person_image_count to matched metadata"
```

---

## Task 5: Frontend — Add `person_image_count` reading to gallery bucketing

**Context:** The frontend reads `grouped_image_count` from cast_photo metadata in `person-gallery-media-view.ts` (line 385-386) to determine `qualifiesAsEvent`. We need it to also read `person_image_count` for display purposes, and use `source_query_scope` to distinguish Bravo vs non-Bravo events.

**Files:**
- Modify: `TRR-APP/apps/web/src/lib/admin/person-gallery-media-view.ts:366-622`

**Step 1: Add `person_image_count` and `source_query_scope` readers**

Near line 385, after `const groupedImageCount = readGroupedImageCount(photo, metadata);`, add:

```typescript
  const personImageCount = readPersonImageCount(photo, metadata);
  const sourceQueryScope = readSourceQueryScope(photo, metadata);
```

Add these helper functions near the other `read*` helpers in the file:

```typescript
function readPersonImageCount(
  photo: TrrPersonPhoto,
  metadata: Record<string, unknown>
): number | null {
  const galleryBucket = metadata.gallery_bucket;
  if (typeof galleryBucket === "object" && galleryBucket !== null) {
    const bucketMeta = galleryBucket as Record<string, unknown>;
    if (typeof bucketMeta.person_image_count === "number") return bucketMeta.person_image_count;
  }
  if (typeof metadata.person_image_count === "number") return metadata.person_image_count;
  return null;
}

function readSourceQueryScope(
  photo: TrrPersonPhoto,
  metadata: Record<string, unknown>
): string | null {
  const galleryBucket = metadata.gallery_bucket;
  if (typeof galleryBucket === "object" && galleryBucket !== null) {
    const bucketMeta = galleryBucket as Record<string, unknown>;
    if (typeof bucketMeta.source_query_scope === "string") return bucketMeta.source_query_scope;
  }
  if (typeof metadata.source_query_scope === "string") return metadata.source_query_scope;
  return null;
}
```

**Step 2: Add `personImageCount` and `sourceQueryScope` to `PersonPhotoShowBuckets` return type**

Find the `PersonPhotoShowBuckets` type and add:

```typescript
  personImageCount: number | null;
  sourceQueryScope: string | null;
```

Then update every return statement in `computePersonPhotoShowBuckets()` to include these two fields:

```typescript
    personImageCount,
    sourceQueryScope,
```

**Step 3: Commit**

```bash
git add TRR-APP/apps/web/src/lib/admin/person-gallery-media-view.ts
git commit -m "feat(gallery): read person_image_count and source_query_scope from cast_photo metadata"
```

---

## Task 6: Frontend — Add "Other Events" container to PersonPageClient gallery

**Context:** Currently all events (Bravo and non-Bravo) render in the same grid. Non-Bravo events (where `source_query_scope === "broad"`) should appear in a separate "Other Events" section below the main gallery. Each non-Bravo event shows as a gallery cover card. Clicking a card should trigger a "Scrape More" prompt that will eventually call the backend to do a full scan of that specific event.

**Files:**
- Modify: `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`

**Step 1: Separate filtered photos into main gallery and other-events**

After the `filteredPhotos` useMemo (around line 3567), add a new memo to split photos:

```typescript
  const { mainGalleryPhotos, otherEventCovers } = useMemo(() => {
    const main: TrrPersonPhoto[] = [];
    const otherCovers: TrrPersonPhoto[] = [];
    const seenOtherEventKeys = new Set<string>();

    for (const photo of filteredPhotos) {
      const metadata = (photo.metadata ?? {}) as Record<string, unknown>;
      const scope = typeof metadata.source_query_scope === "string"
        ? metadata.source_query_scope
        : null;

      if (scope === "broad") {
        // Group by event — only show one cover per event
        const eventKey =
          (typeof metadata.getty_event_id === "string" ? metadata.getty_event_id : null) ??
          (typeof metadata.getty_event_title === "string" ? metadata.getty_event_title : null) ??
          photo.source_image_id ??
          photo.id;
        if (!seenOtherEventKeys.has(String(eventKey))) {
          seenOtherEventKeys.add(String(eventKey));
          otherCovers.push(photo);
        }
      } else {
        main.push(photo);
      }
    }

    return { mainGalleryPhotos: main, otherEventCovers: otherCovers };
  }, [filteredPhotos]);
```

**Step 2: Replace `filteredPhotos` with `mainGalleryPhotos` in the main gallery grid**

Find where `filteredPhotos` is used to render the gallery grid (the `.map()` call that renders photo cards). Replace with `mainGalleryPhotos`.

**Step 3: Add "Other Events" section below the main gallery**

After the main gallery grid, add:

```tsx
  {otherEventCovers.length > 0 && (
    <div className="mt-8">
      <h3 className="mb-4 text-sm font-semibold uppercase tracking-[0.3em] text-zinc-400">
        Other Events ({otherEventCovers.length})
      </h3>
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
        {otherEventCovers.map((photo) => {
          const metadata = (photo.metadata ?? {}) as Record<string, unknown>;
          const eventTitle =
            (typeof metadata.getty_event_title === "string" ? metadata.getty_event_title : null) ??
            photo.caption ??
            "Unknown Event";
          const personCount =
            typeof metadata.person_image_count === "number"
              ? metadata.person_image_count
              : typeof metadata.grouped_image_count === "number"
                ? metadata.grouped_image_count
                : null;

          return (
            <button
              key={photo.id}
              type="button"
              onClick={() => {
                // TODO: Task 7 will implement the scrape-more handler
                const confirmed = window.confirm(
                  `Scrape all images of ${personName ?? "this person"} from "${eventTitle}"?`
                );
                if (confirmed) {
                  // Will call backend scan endpoint — see Task 7
                }
              }}
              className="group relative overflow-hidden rounded-lg border border-zinc-200 bg-white shadow-sm transition hover:shadow-md"
            >
              <div className="aspect-[3/4] w-full overflow-hidden bg-zinc-100">
                <img
                  src={photo.thumb_url || photo.image_url || photo.url}
                  alt={eventTitle}
                  className="h-full w-full object-cover transition group-hover:scale-105"
                  loading="lazy"
                />
              </div>
              <div className="p-2">
                <p className="truncate text-xs font-medium text-zinc-800">{eventTitle}</p>
                {personCount !== null && (
                  <p className="text-xs text-zinc-500">{personCount} images</p>
                )}
                <p className="mt-1 text-xs font-medium text-blue-600">Click to scrape</p>
              </div>
            </button>
          );
        })}
      </div>
    </div>
  )}
```

**Step 4: Commit**

```bash
git add TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx
git commit -m "feat(gallery): add Other Events container with cover cards for non-Bravo events"
```

---

## Task 7: Frontend — Update event count display to use `person_image_count`

**Context:** When events show count badges (e.g., "BravoCon 2023 (64)"), the count currently uses `grouped_image_count` which is Getty's total for the event, not the person-specific count. We need to prefer `person_image_count` when available.

**Files:**
- Modify: `TRR-APP/apps/web/src/lib/admin/person-gallery-media-view.ts`

**Step 1: Update `readGroupedImageCount` or add display count helper**

Add a new export function:

```typescript
export function getPersonEventImageCount(
  photo: TrrPersonPhoto,
  metadata?: Record<string, unknown> | null
): number | null {
  const meta = metadata ?? (photo.metadata as Record<string, unknown> | null) ?? {};
  // Prefer person-specific count
  const personCount = readPersonImageCount(photo, meta);
  if (personCount !== null && personCount > 0) return personCount;
  // Fall back to grouped image count
  return readGroupedImageCount(photo, meta);
}
```

**Step 2: Update PersonPageClient to use `getPersonEventImageCount` where event counts are displayed**

Search for usage of `groupedImageCount` or `grouped_image_count` in the PersonPageClient event badge rendering and replace with the new helper.

**Step 3: Commit**

```bash
git add TRR-APP/apps/web/src/lib/admin/person-gallery-media-view.ts TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx
git commit -m "feat(gallery): display person-specific image count instead of total event count"
```

---

## Task 8: Backend — Add "scrape more" endpoint for individual event expansion

**Context:** When the user clicks a non-Bravo event cover in "Other Events", the frontend needs to call a backend endpoint that does a full scan of that specific Getty event for the person. This is a targeted scan — given an `event_url` and `person_name`, scan all images, run NBCUMV crosswalk, and persist the results.

**Files:**
- Modify: `TRR-Backend/api/routers/admin_person_images.py` (add new endpoint or extend existing)

**Step 1: Add helper that performs single-event full scan + persist**

Add a new internal function near `_capture_grouped_event_inventory()`:

```python
    def _expand_single_event(
        event_url: str,
        person_name: str,
        source_query_scope: str = "broad",
    ) -> dict[str, Any]:
        """Scan a single Getty event for all person-matching images,
        crosswalk to NBCUMV, and persist as cast_photos."""
        scan_result = getty_integration.scan_event_page_for_person(
            event_url,
            person_name=person_name,
            session=None,
            progress_cb=_emit_progress,
        )
        if not scan_result or not scan_result.get("matched_assets"):
            return {"expanded": 0, "matched": 0}

        expanded_count = 0
        for asset in scan_result["matched_assets"]:
            # Run the same NBCUMV crosswalk + getty fallback logic
            # as the main matching loop (lines 1791-1886)
            filename = str(asset.get("object_name") or "").strip()
            editorial_id = str(asset.get("editorial_id") or "").strip()
            if not editorial_id or editorial_id in seen_editorial_ids:
                continue
            seen_editorial_ids.add(editorial_id)

            synthetic = dict(asset)
            synthetic["source_query_scope"] = source_query_scope
            resolved_asset_show = _resolve_asset_show(synthetic)
            bucket_metadata = _resolve_gallery_bucket_metadata(
                asset=synthetic,
                resolved_asset_show=resolved_asset_show,
                show_lookup_by_alias=show_lookup_by_alias,
            )
            # ... same NBCUMV lookup + getty fallback as main loop ...
            expanded_count += 1

        return {
            "expanded": expanded_count,
            "total_scanned": scan_result["total_scanned"],
            "person_image_count": scan_result["person_image_count"],
        }
```

**Step 2: Expose via existing refresh endpoint or new sub-endpoint**

The cleanest approach is to add an optional `expand_event_url` parameter to the existing refresh endpoint body. When present, it skips the full pipeline and only expands that one event:

```python
    expand_event_url = body.get("expand_event_url")
    if expand_event_url:
        expansion_result = _expand_single_event(
            expand_event_url,
            normalized_person_name,
        )
        result["event_expansion"] = expansion_result
        # skip rest of pipeline
        return result
```

**Step 3: Commit**

```bash
git add TRR-Backend/api/routers/admin_person_images.py
git commit -m "feat(admin-images): add expand_event_url for on-demand single-event full scan"
```

---

## Task 9: Frontend — Wire up "Scrape More" click handler to call expand endpoint

**Context:** The "Other Events" cover cards from Task 6 have a placeholder `onClick`. Now we wire them to call the backend `expand_event_url` endpoint and refresh the gallery.

**Files:**
- Modify: `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`

**Step 1: Add `handleExpandEvent` callback**

```typescript
  const handleExpandEvent = useCallback(async (eventUrl: string, eventTitle: string) => {
    if (!personId) return;
    const confirmed = window.confirm(
      `Scrape all images of ${personName ?? "this person"} from "${eventTitle}"?\n\nThis may take a moment.`
    );
    if (!confirmed) return;

    try {
      const response = await fetch(`/api/admin/trr-api/people/${personId}/images/refresh`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          expand_event_url: eventUrl,
        }),
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      // Refresh gallery photos after expansion
      await fetchPhotos();
    } catch (err) {
      console.error("Event expansion failed:", err);
    }
  }, [personId, personName, fetchPhotos]);
```

**Step 2: Update the "Other Events" cover card onClick to use `handleExpandEvent`**

Replace the placeholder onClick from Task 6:

```tsx
  onClick={() => {
    const eventUrl = typeof metadata.getty_event_url === "string" ? metadata.getty_event_url : null;
    if (eventUrl) {
      handleExpandEvent(eventUrl, eventTitle);
    }
  }}
```

**Step 3: Commit**

```bash
git add TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx
git commit -m "feat(gallery): wire Other Events cover cards to expand_event_url backend endpoint"
```

---

## Task 10: Integration testing — End-to-end verification

**Step 1: Run all backend tests**

Run: `cd TRR-Backend && python -m pytest tests/ -v --timeout=60`
Expected: All PASS

**Step 2: Run frontend type checking**

Run: `cd TRR-APP && npx tsc --noEmit`
Expected: No errors

**Step 3: Manual smoke test**

1. Navigate to `http://admin.localhost:3000/people/brandi-glanville/gallery?showId=rhobh`
2. Click "Get Images"
3. Verify:
   - Bravo events (WWHL, RHOBH, BravoCon) now show multiple images per event, not just one cover
   - Event counts show person-specific numbers (e.g., "BravoCon 2023 (12)" not "(64)")
   - NBCUMV hi-res versions replace Getty watermarked images where available
   - Non-Bravo events appear in a separate "Other Events" section at the bottom
   - Each "Other Events" card shows one cover image with event name and count
   - Clicking an "Other Events" card prompts to scrape more and loads additional images

**Step 4: Final commit**

```bash
git commit --allow-empty -m "chore: bravo event deep scraping and other events gallery — integration verified"
```

---

## Architecture Notes for Implementer

### Data Flow (After Changes)

```
"Get Images" clicked
    │
    ├── Getty search: "{name} Bravo" (editorial assets) ──────────┐
    │                                                              │
    ├── Getty grouped events: "{name} Bravo"                       │
    │   └── full_scan_person_assets=True                           │
    │       └── For EACH Bravo event:                              │
    │           └── scan_event_page_for_person()                   │
    │               └── Returns ALL person-matching assets         │
    │                   └── Each gets NBCUMV crosswalk ───────────>├── combined_assets
    │                                                              │
    ├── Getty grouped events: "{name}" (broad)                     │
    │   └── full_scan_person_assets=False (default)                │
    │       └── Returns ONE cover per event ──────────────────────>│
    │                                                              │
    └── combined_assets loop ──────────────────────────────────────┘
        ├── NBCUMV match found → hi-res row (source_resolution: nbcumv_preferred_shared)
        └── No NBCUMV match   → getty watermark row (source_resolution: getty_watermark_fallback)

Frontend reads cast_photos:
    ├── source_query_scope === "bravo" → main gallery grid
    └── source_query_scope === "broad" → "Other Events" section (one cover per event)
```

### Key Fields in cast_photo.metadata

| Field | Source | Purpose |
|-------|--------|---------|
| `source_query_scope` | `"bravo"` or `"broad"` | Determines main grid vs Other Events |
| `grouped_image_count` | Getty `collapsedImageCount` | Total event photos (all people) |
| `person_image_count` | `scan_event_page_for_person()` | Photos of THIS person in event |
| `bucket_type` | `_resolve_gallery_bucket_metadata()` | `"bravocon"`, `"wwhl"`, `"show"`, `"event"`, `"unknown"` |
| `source_resolution` | crosswalk result | `"nbcumv_preferred_shared"` or `"getty_watermark_fallback"` |

### Risk: Getty Bot Detection

The `requests` library may get bot-detected by Getty (returning `isBot: true`). The existing scraping works from the backend server environment which may have different fingerprinting than WebFetch. If this becomes an issue during testing:
- The `_DEFAULT_HEADERS` (line 59-66) mimic Chrome but the TLS fingerprint of `requests` differs from a real browser
- Mitigation options: add `curl_cffi` for TLS fingerprinting, or use Playwright for the event page scan
- This is a known risk but separate from this plan's scope — the existing `search_grouped_events()` already uses `requests` successfully
