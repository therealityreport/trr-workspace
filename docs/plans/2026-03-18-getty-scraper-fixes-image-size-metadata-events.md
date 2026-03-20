# Getty Scraper Fixes: Image Size, Metadata, and Event Filtering

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix three Getty scraping deficiencies: images stored at preview resolution instead of largest available, object_name field polluted with page footer content, and non-Bravo events not filtering by people count.

**Architecture:** All fixes are in the shared Getty integration module (`trr_backend/integrations/getty.py`) and the pipeline orchestrator (`api/routers/admin_person_images.py`). The Getty scraper extracts image data from embedded JSON (`<script data-component="AssetDetail">`) and HTML detail sections. Both the person page and show page share the same `_import_nbcumv_person_media()` function, so all fixes apply everywhere.

**Tech Stack:** Python 3.11, BeautifulSoup4, requests, pytest

---

## Context: Getty Page Structure

Getty detail pages embed a `<script data-component="AssetDetail">` tag containing a JSON payload with the `asset` object. This has fields like `compUrl`, `thumbUrl`, `downloadableCompUrl`, etc. The HTML also has a "details section" with labeled fields (Credit, Collection, Object name, etc.) parsed by `_extract_detail_section_fields()`.

Getty search pages embed a `<script data-component="Search">` (or `id="Search_..."`) with search results as JSON containing `assets[]` with `landingUrl`, `eventName`, `eventId`, `collapsedImageCount`, etc.

---

### Task 1: Fix `object_name` parsing — stop capturing page footer/tag content

The `_extract_detail_section_fields()` function (getty.py:843-861) collects ALL `stripped_strings` from the soup after a field label until it hits another label or a stop marker. The stop markers only cover 3 strings. Everything else — tag text ("Brandi Glanville Photos", "2010-2019 Photos"), footer links, "CONTENT", "Royalty-free", etc. — gets concatenated into the field value.

**Files:**
- Modify: `trr_backend/integrations/getty.py:28-32` (stop markers), `trr_backend/integrations/getty.py:843-861` (`_extract_detail_section_fields`)
- Test: `tests/integrations/test_getty.py`

**Step 1: Write the failing test**

```python
def test_extract_detail_section_fields_stops_at_tag_cloud() -> None:
    """Object name should not include tag cloud text or footer content."""
    from bs4 import BeautifulSoup

    html = """
    <html><body>
    <div>Object name: NUP_162086_1491.jpg</div>
    <div>Brandi Glanville Photos</div>
    <div>2010-2019 Photos</div>
    <div>Arguing Photos</div>
    <div>CONTENT</div>
    <div>Royalty-free</div>
    <div>Creative Video</div>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    fields = getty._extract_detail_section_fields(soup)
    object_name = fields.get("object_name_display", "")
    assert object_name == "NUP_162086_1491.jpg", f"Got polluted object_name: {object_name!r}"
```

Run: `python -m pytest tests/integrations/test_getty.py::test_extract_detail_section_fields_stops_at_tag_cloud -v`
Expected: FAIL — currently captures everything after "Object name:"

**Step 2: Fix `_extract_detail_section_fields` to truncate after first value token for object_name**

The root issue: `object_name` is always a single filename (e.g., `NUP_162086_1491.jpg`). After the filename, everything else is tag/footer noise. Two fixes:

**Fix A — Add comprehensive stop markers** (getty.py:28-32):

```python
_DETAIL_SECTION_STOP_MARKERS = {
    "More images from this event",
    "Similar images",
    "Related searches",
    "CONTENT",
    "SOLUTIONS",
    "TOOLS & SERVICES",
    "COMPANY",
    "Royalty-free",
    "Creative Video",
    "Editorial",
    "Archive",
    "Custom Content",
    "Creative Collections",
    "Contributor support",
    "Apply to be a contributor",
}
```

**Fix B — For `object_name_display` specifically, only take the first token if it looks like a filename** (getty.py:858-860):

Replace:
```python
        cleaned = " ".join(part.strip() for part in collected if part.strip()).strip()
        if cleaned:
            results[field_name] = cleaned
```

With:
```python
        cleaned = " ".join(part.strip() for part in collected if part.strip()).strip()
        if cleaned:
            if field_name == "object_name_display" and " " in cleaned:
                # Object names are filenames — take only the first space-delimited token
                # to avoid capturing tag cloud text appended by Getty's page structure.
                first_token = cleaned.split()[0]
                if re.search(r"\.\w{2,4}$", first_token):
                    cleaned = first_token
            results[field_name] = cleaned
```

Note: `import re` is already at the top of the file.

**Step 3: Run test to verify it passes**

Run: `python -m pytest tests/integrations/test_getty.py -v`
Expected: ALL PASS

**Step 4: Commit**

```bash
git add trr_backend/integrations/getty.py tests/integrations/test_getty.py
git commit -m "fix(getty): stop capturing page footer/tag cloud in object_name_display

_extract_detail_section_fields() was collecting all stripped_strings after
a field label until a stop marker. With only 3 stop markers, tag cloud
text and footer content got concatenated into object_name. Added
comprehensive stop markers and filename-aware truncation for object_name."
```

---

### Task 2: Fix image size — prefer largest available Getty preview URL

The `preview_image_url` selection in `fetch_asset_detail()` (getty.py:762-771) checks `asset_json` for URL keys in priority order. But `_first_present()` only checks top-level keys. The issue is that Getty's JSON structure nests image URLs under `asset.displaySizes[]` or similar structures, and the top-level keys like `downloadableCompUrl` may not exist.

**Files:**
- Modify: `trr_backend/integrations/getty.py:760-771` (preview URL extraction)
- Test: `tests/integrations/test_getty.py`

**Step 1: Write the failing test**

```python
def test_fetch_asset_detail_prefers_largest_image_url(monkeypatch) -> None:
    """preview_image_url should prefer downloadableCompUrl over compUrl."""
    import json
    from unittest.mock import MagicMock

    asset_json = {
        "thumbUrl": "https://media.gettyimages.com/id/123/thumb.jpg?s=170x170",
        "compUrl": "https://media.gettyimages.com/id/123/comp.jpg?s=594x594",
        "downloadableCompUrl": "https://media.gettyimages.com/id/123/download.jpg?s=2048x2048",
        "title": "Test Image",
        "id": "123",
    }
    html = f'<html><script data-component="AssetDetail">{json.dumps({"asset": asset_json})}</script></html>'
    mock_response = MagicMock()
    mock_response.text = html
    mock_response.raise_for_status = MagicMock()

    def mock_get(url, **kwargs):
        return mock_response

    monkeypatch.setattr(getty, "_session", lambda s=None: MagicMock(get=mock_get))

    result = getty.fetch_asset_detail("https://www.gettyimages.com/detail/news-photo/test/123")
    assert result is not None
    assert "2048x2048" in result["preview_image_url"], (
        f"Expected largest URL, got: {result['preview_image_url']}"
    )
```

Run: `python -m pytest tests/integrations/test_getty.py::test_fetch_asset_detail_prefers_largest_image_url -v`

**Step 2: Extract display sizes from nested JSON**

Add a helper function after `_extract_asset_detail_json()` (after line 799):

```python
def _extract_best_image_urls(asset_json: dict[str, Any]) -> dict[str, str]:
    """Extract all available image URLs from asset JSON, including nested displaySizes."""
    urls: dict[str, str] = {}
    # Top-level keys
    for key in (
        "downloadableCompUrl",
        "galleryHighResCompUrl",
        "highResCompUrl",
        "galleryComp1024Url",
        "compUrl",
        "mainImageUrl",
        "thumbUrl",
    ):
        value = str(asset_json.get(key) or "").strip()
        if value:
            urls[key] = value

    # Nested displaySizes array — Getty sometimes puts URLs here
    display_sizes = asset_json.get("displaySizes")
    if isinstance(display_sizes, list):
        for entry in display_sizes:
            if not isinstance(entry, dict):
                continue
            name = str(entry.get("name") or "").strip().lower()
            uri = str(entry.get("uri") or entry.get("url") or "").strip()
            if uri:
                if name == "high_res_comp" and "highResCompUrl" not in urls:
                    urls["highResCompUrl"] = uri
                elif name == "comp" and "compUrl" not in urls:
                    urls["compUrl"] = uri
                elif name == "thumb" and "thumbUrl" not in urls:
                    urls["thumbUrl"] = uri
                elif name == "preview" and "downloadableCompUrl" not in urls:
                    urls["downloadableCompUrl"] = uri

    return urls
```

**Step 3: Update `fetch_asset_detail` to use the new helper**

Replace lines 760-771:

```python
    image_urls = _extract_best_image_urls(asset_json)
    result["thumb_url"] = image_urls.get("thumbUrl") or _first_present(asset_json, "thumbUrl")
    result["comp_url"] = image_urls.get("compUrl") or _first_present(asset_json, "compUrl")
    result["preview_image_url"] = (
        image_urls.get("downloadableCompUrl")
        or image_urls.get("galleryHighResCompUrl")
        or image_urls.get("highResCompUrl")
        or image_urls.get("galleryComp1024Url")
        or image_urls.get("compUrl")
        or image_urls.get("mainImageUrl")
        or image_urls.get("thumbUrl")
    )
```

**Step 4: Run tests**

Run: `python -m pytest tests/integrations/test_getty.py -v`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add trr_backend/integrations/getty.py tests/integrations/test_getty.py
git commit -m "fix(getty): prefer largest available image URL from asset JSON

fetch_asset_detail() now extracts URLs from both top-level keys and
nested displaySizes array, preferring downloadableCompUrl (highest res)
over compUrl (594px preview) and thumbUrl."
```

---

### Task 3: Add `numberofpeople` filter to broad (non-Bravo) grouped event search

The user wants non-Bravo events to filter for images with 1-2 people (solo/duo shots), using Getty's `numberofpeople` query parameter. The `query_params` dict already flows through to `_build_search_url()`, so this is a simple call-site change.

**Files:**
- Modify: `api/routers/admin_person_images.py:1409-1418` (broad grouped events call)
- Test: `tests/integrations/test_getty.py`

**Step 1: Write a test confirming numberofpeople flows through**

```python
def test_search_grouped_events_passes_numberofpeople_query_param(monkeypatch) -> None:
    """query_params like numberofpeople should flow through to the search URL."""
    captured_urls: list[str] = []

    def fake_search_candidates(phrase, *, limit, session=None, query_params=None):
        url = getty._build_search_url(phrase, query_params=query_params)
        captured_urls.append(url)
        return []

    monkeypatch.setattr(getty, "_search_asset_candidates_for_phrase", fake_search_candidates)

    getty.search_grouped_events(
        "Brandi Glanville",
        limit=10,
        query_params={"numberofpeople": "one", "sort": "best"},
        source_query_scope="broad",
    )

    assert len(captured_urls) == 1
    assert "numberofpeople=one" in captured_urls[0]
    assert "groupbyevent=true" in captured_urls[0]
```

Run: `python -m pytest tests/integrations/test_getty.py::test_search_grouped_events_passes_numberofpeople_query_param -v`
Expected: PASS (this should already work since query_params flows through)

**Step 2: Update the broad grouped events call site**

In `api/routers/admin_person_images.py`, find the broad grouped events call (around line 1409-1418) and add `numberofpeople` to `query_params`:

Current:
```python
    broad_grouped_events = getty_integration.search_grouped_events(
        normalized_person_name,
        limit=max(1, int(limit)),
        person_name=normalized_person_name,
        person_match_required=True,
        minimum_grouped_image_count=2,
        query_params={"sort": "best"},
        source_query_scope="broad",
    )
```

Replace with:
```python
    broad_grouped_events = getty_integration.search_grouped_events(
        normalized_person_name,
        limit=max(1, int(limit)),
        person_name=normalized_person_name,
        person_match_required=True,
        minimum_grouped_image_count=2,
        query_params={"sort": "best", "numberofpeople": "one,two"},
        source_query_scope="broad",
    )
```

Note: Getty accepts comma-separated values for `numberofpeople`. This filters for images showing 1 or 2 people, making the results more relevant (solo/duo shots of the person, not crowd scenes).

**Step 3: Run tests**

Run: `python -m pytest tests/integrations/test_getty.py tests/api/routers/test_admin_person_images.py -v`
Expected: ALL PASS

**Step 4: Commit**

```bash
git add trr_backend/integrations/getty.py tests/integrations/test_getty.py api/routers/admin_person_images.py
git commit -m "feat(getty): filter non-Bravo events to 1-2 person images

Broad (non-Bravo) grouped event search now passes numberofpeople=one,two
to Getty, filtering for solo/duo shots of the person instead of crowd
scenes. Bravo events are unaffected (full scan, no people filter)."
```

---

### Task 4: Fix event metadata mismatch — prefer image's own event data over parent search context

The metadata shows "tearful-times" (September 2015) for a February 2014 RHOBH Reunion image. This happens because `_merge_search_candidate_with_detail()` (getty.py:327-348) does `merged = dict(candidate); merged.update(detail)`. Since `detail` comes from `fetch_asset_detail()` which reads `eventName`/`eventId` from the individual asset's JSON, and `candidate` comes from the search results — the detail's event data should take priority for individual images. But when the detail page's asset JSON has *no* event data (fields are null/missing), the candidate's event data (from the parent grouped event search) leaks in via the fallback `if "event_name" not in merged` checks at lines 332-339.

In the grouped-event flow (`scan_event_page_for_person()`), each individual image is searched within an event page, so the candidate's event metadata comes from that specific event. The individual asset's detail page may have its own `eventName` that differs from the parent event context.

**Files:**
- Modify: `api/routers/admin_person_images.py:1254-1258` (getty event metadata in cast photo rows)
- Modify: `api/routers/admin_person_images.py:1240-1260` (metadata dict)

**Step 1: Add `date_created` cross-validation in metadata**

In `_build_getty_cast_photo_row()` around line 1254-1258, add a `getty_date_created` field and a cross-reference flag when event_date and date_created diverge significantly:

After line 1258 (`"getty_event_date"`), add:

```python
            "getty_date_created": str(asset.get("date_created") or "").strip() or None,
```

This preserves the image's own creation date alongside the event date so the frontend can display the correct date.

**Step 2: In the NBCUMV matched metadata path, also propagate `date_created`**

Find the `matched_bucket_metadata` block (search for `source_resolution.*nbcumv_preferred_shared`) and add:

```python
        matched_bucket_metadata["getty_date_created"] = str(asset.get("date_created") or "").strip() or None
```

**Step 3: Commit**

```bash
git add api/routers/admin_person_images.py
git commit -m "fix(getty): propagate date_created alongside event_date in metadata

Stores getty_date_created separately from getty_event_date so the
frontend can display the image's actual creation date rather than the
(sometimes mismatched) Getty event date."
```

---

### Task 5: Run full test suite and verify

**Step 1: Run all Getty tests**

```bash
python -m pytest tests/integrations/test_getty.py -v
```

Expected: ALL PASS (14+ tests)

**Step 2: Run all admin_person_images tests**

```bash
python -m pytest tests/api/routers/test_admin_person_images.py -v
```

Expected: ALL PASS (90+ tests)

**Step 3: Final commit (if any fixups needed)**

```bash
git add -A && git status
```
