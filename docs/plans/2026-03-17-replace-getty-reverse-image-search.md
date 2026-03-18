# Replace Getty — Reverse Image Search Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a "Replace Getty" button to the image lightbox that uses PicDetective's reverse image search API to find larger, unwatermarked versions of Getty-only images from editorial syndication sites (Glamour, Yahoo, Vogue, etc.), then replaces the watermarked Getty image with the selected alternative.

**Architecture:** Backend gets a new PicDetective integration module (`picdetective.py`) and two new endpoints on the existing admin media-assets router: one for searching and one for replacing. Frontend adds a "Replace Getty" button to the lightbox management actions that opens a candidate drawer. The button only appears when `source === "getty"`. On replacement, the `source` field updates to the new domain, but all Getty editorial metadata (people, event, caption, editorial_id) is preserved in `metadata.getty`.

**Tech Stack:** Python `requests` + `dataclasses` (backend integration), FastAPI (endpoints), Next.js API route (proxy), React + Tailwind (drawer component)

---

### Task 1: PicDetective Integration Module — Tests

**Files:**
- Create: `TRR-Backend/tests/integrations/test_picdetective.py`

**Step 1: Write the failing tests**

```python
from __future__ import annotations

import json
from unittest.mock import MagicMock, patch

from trr_backend.integrations.picdetective import (
    ReverseImageCandidate,
    parse_search_response,
    search_by_image_url,
)


SAMPLE_RESPONSE = {
    "exact_matches": [
        {
            "title": "Kim Richards Arrested",
            "link": "https://www.glamour.com/story/kim-richards",
            "url": "https://www.glamour.com/story/kim-richards",
            "source": "Glamour",
            "thumbnail": "data:image/jpeg;base64,abc123",
            "image": {"src": "https://glamour.com/img.jpg", "width": 1500, "height": 1000},
        },
        {
            "title": "RHOBH Season 5",
            "link": "https://www.gettyimages.com/detail/photo/1234",
            "url": "https://www.gettyimages.com/detail/photo/1234",
            "source": "Getty Images",
            "thumbnail": "data:image/jpeg;base64,def456",
            "image": {"src": "https://getty.com/img.jpg", "width": 612, "height": 408},
        },
        {
            "title": "Ask Her Anything",
            "link": "https://www.menshealth.com/article",
            "url": "https://www.menshealth.com/article",
            "source": "Men's Health",
            "thumbnail": "data:image/jpeg;base64,ghi789",
            "image": {"src": "https://menshealth.com/img.jpg", "width": 2004, "height": 2000},
        },
        {
            "title": "Small blog post",
            "link": "https://blog.example.com/post",
            "url": "https://blog.example.com/post",
            "source": "Example Blog",
            "thumbnail": "",
            "image": {"src": "", "width": 400, "height": 300},
        },
        {
            "title": "No dimensions",
            "link": "https://nodims.example.com/post",
            "url": "https://nodims.example.com/post",
            "source": "NoDims",
            "thumbnail": "",
            "image": {},
        },
    ],
}


def test_parse_search_response_filters_by_min_width() -> None:
    candidates = parse_search_response(SAMPLE_RESPONSE, min_width=1080)
    assert len(candidates) == 2
    assert candidates[0].source_domain == "menshealth.com"
    assert candidates[0].width == 2004
    assert candidates[1].source_domain == "glamour.com"
    assert candidates[1].width == 1500


def test_parse_search_response_excludes_getty_domains() -> None:
    candidates = parse_search_response(SAMPLE_RESPONSE, min_width=0)
    domains = [c.source_domain for c in candidates]
    assert "gettyimages.com" not in domains


def test_parse_search_response_sorts_by_resolution_descending() -> None:
    candidates = parse_search_response(SAMPLE_RESPONSE, min_width=0)
    areas = [(c.width or 0) * (c.height or 0) for c in candidates]
    assert areas == sorted(areas, reverse=True)


def test_parse_search_response_limits_results() -> None:
    candidates = parse_search_response(SAMPLE_RESPONSE, min_width=0, limit=2)
    assert len(candidates) == 2


def test_parse_search_response_extracts_domain_from_url() -> None:
    candidates = parse_search_response(SAMPLE_RESPONSE, min_width=0)
    glamour = next(c for c in candidates if "glamour" in c.source_domain)
    assert glamour.source_domain == "glamour.com"
    assert glamour.page_url == "https://www.glamour.com/story/kim-richards"


def test_parse_search_response_handles_missing_image_fields() -> None:
    candidates = parse_search_response(SAMPLE_RESPONSE, min_width=0)
    nodims = next((c for c in candidates if "nodims" in c.source_domain), None)
    assert nodims is not None
    assert nodims.width is None
    assert nodims.height is None


def test_search_by_image_url_calls_api(monkeypatch) -> None:
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = SAMPLE_RESPONSE
    mock_response.raise_for_status = MagicMock()

    mock_get = MagicMock(return_value=mock_response)
    monkeypatch.setattr("trr_backend.integrations.picdetective.requests.get", mock_get)

    candidates = search_by_image_url("https://media.gettyimages.com/id/467051416/photo/test.jpg?s=2048x2048&w=gi&k=20&c=abc")

    mock_get.assert_called_once()
    call_args = mock_get.call_args
    assert "picdetective.com/api/search" in call_args[0][0] or "picdetective.com/api/search" in str(call_args)
    assert len(candidates) <= 5


def test_search_by_image_url_returns_empty_on_api_error(monkeypatch) -> None:
    mock_get = MagicMock(side_effect=Exception("Connection refused"))
    monkeypatch.setattr("trr_backend.integrations.picdetective.requests.get", mock_get)

    candidates = search_by_image_url("https://example.com/image.jpg")
    assert candidates == []
```

**Step 2: Run tests to verify they fail**

Run: `cd TRR-Backend && python -m pytest tests/integrations/test_picdetective.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'trr_backend.integrations.picdetective'`

**Step 3: Commit test file**

```bash
cd TRR-Backend
git add tests/integrations/test_picdetective.py
git commit -m "test: add picdetective reverse image search integration tests"
```

---

### Task 2: PicDetective Integration Module — Implementation

**Files:**
- Create: `TRR-Backend/trr_backend/integrations/picdetective.py`

**Step 1: Implement the module**

```python
"""PicDetective reverse image search integration.

Calls the PicDetective API to find visually matching images across the web.
Used to find larger, unwatermarked versions of Getty editorial images on
syndication sites (Glamour, Yahoo, Vogue, Daily Mail, etc.).

API: GET https://picdetective.com/api/search?url=<encoded>&search_type=exact_matches
Returns JSON with exact_matches[] containing title, link, source, thumbnail, image{src,width,height}.
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass
from typing import Any
from urllib.parse import quote, urlparse

import requests

logger = logging.getLogger(__name__)

PICDETECTIVE_API_BASE = "https://picdetective.com/api"
DEFAULT_MIN_WIDTH = 1080
DEFAULT_LIMIT = 5
DEFAULT_TIMEOUT_SECONDS = 30
EXCLUDED_DOMAINS = frozenset({"gettyimages.com", "gettyimages.co.uk"})

_DEFAULT_HEADERS = {
    "accept": "application/json",
    "user-agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    ),
}


@dataclass(frozen=True)
class ReverseImageCandidate:
    """A candidate image found via reverse image search."""

    title: str
    source_domain: str
    page_url: str
    thumbnail_b64: str | None
    width: int | None
    height: int | None


def _extract_domain(url: str) -> str:
    """Extract clean domain from a URL, stripping www. prefix."""
    try:
        hostname = urlparse(url).hostname or ""
        return re.sub(r"^www\.", "", hostname.lower())
    except Exception:
        return ""


def _is_excluded_domain(domain: str) -> bool:
    """Check if domain is in the exclusion list (e.g., gettyimages.com)."""
    return any(domain.endswith(excluded) for excluded in EXCLUDED_DOMAINS)


def _parse_int(value: Any) -> int | None:
    """Safely parse a value to int, handling strings with commas like '2,560'."""
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if isinstance(value, str):
        cleaned = value.replace(",", "").strip()
        if cleaned.isdigit():
            return int(cleaned)
    return None


def parse_search_response(
    data: dict[str, Any],
    *,
    min_width: int = DEFAULT_MIN_WIDTH,
    limit: int = DEFAULT_LIMIT,
    exclude_domains: frozenset[str] = EXCLUDED_DOMAINS,
) -> list[ReverseImageCandidate]:
    """Parse PicDetective API response into filtered, sorted candidates."""
    matches = data.get("exact_matches")
    if not isinstance(matches, list):
        return []

    candidates: list[ReverseImageCandidate] = []
    for match in matches:
        if not isinstance(match, dict):
            continue

        page_url = str(match.get("link") or match.get("url") or "").strip()
        if not page_url:
            continue

        domain = _extract_domain(page_url)
        if not domain or _is_excluded_domain(domain):
            continue

        image = match.get("image") if isinstance(match.get("image"), dict) else {}
        width = _parse_int(image.get("width"))
        height = _parse_int(image.get("height"))

        if min_width and width is not None and width < min_width:
            continue

        candidates.append(
            ReverseImageCandidate(
                title=str(match.get("title") or "").strip(),
                source_domain=domain,
                page_url=page_url,
                thumbnail_b64=str(match.get("thumbnail") or "").strip() or None,
                width=width,
                height=height,
            )
        )

    candidates.sort(
        key=lambda c: (c.width or 0) * (c.height or 0),
        reverse=True,
    )
    return candidates[:limit]


def search_by_image_url(
    image_url: str,
    *,
    min_width: int = DEFAULT_MIN_WIDTH,
    limit: int = DEFAULT_LIMIT,
) -> list[ReverseImageCandidate]:
    """Search PicDetective for visually matching images.

    Args:
        image_url: The source image URL (typically a Getty preview URL with auth params).
        min_width: Minimum width in pixels to include in results.
        limit: Maximum number of candidates to return.

    Returns:
        List of ReverseImageCandidate sorted by resolution descending.
    """
    cleaned_url = str(image_url or "").strip()
    if not cleaned_url:
        return []

    api_url = f"{PICDETECTIVE_API_BASE}/search"
    try:
        response = requests.get(
            api_url,
            params={"url": cleaned_url, "search_type": "exact_matches"},
            headers=_DEFAULT_HEADERS,
            timeout=DEFAULT_TIMEOUT_SECONDS,
        )
        response.raise_for_status()
        data = response.json()
    except Exception as exc:
        logger.warning("PicDetective search failed for %s: %s", cleaned_url[:80], exc)
        return []

    return parse_search_response(data, min_width=min_width, limit=limit)
```

**Step 2: Run tests to verify they pass**

Run: `cd TRR-Backend && python -m pytest tests/integrations/test_picdetective.py -v`
Expected: All 8 tests PASS

**Step 3: Commit**

```bash
cd TRR-Backend
git add trr_backend/integrations/picdetective.py
git commit -m "feat: add PicDetective reverse image search integration"
```

---

### Task 3: Backend Endpoints — Reverse Image Search + Replace

**Files:**
- Modify: `TRR-Backend/api/routers/admin_media_assets.py`

**Step 1: Add the reverse-image-search endpoint**

Add these imports at the top of `admin_media_assets.py`:

```python
from trr_backend.integrations.picdetective import (
    ReverseImageCandidate,
    search_by_image_url,
)
from trr_backend.scraping.url_image_scraper import (
    download_and_hash_image,
    scrape_url_for_images,
)
```

Add these Pydantic models after the existing models:

```python
class ReverseImageSearchResponse(BaseModel):
    asset_id: str
    candidates: list[dict]
    search_url: str


class ReplaceFromUrlRequest(BaseModel):
    page_url: str
    source_domain: str
    expected_width: int | None = None
    expected_height: int | None = None


class ReplaceFromUrlResponse(BaseModel):
    asset_id: str
    status: str
    new_source: str
    new_source_url: str
    new_hosted_url: str | None = None
    width: int | None = None
    height: int | None = None
```

Add the search endpoint:

```python
@router.post(
    "/media-assets/{asset_id}/reverse-image-search",
    response_model=ReverseImageSearchResponse,
)
def reverse_image_search(
    asset_id: UUID,
    db: SupabaseAdminClient = None,
    _: AdminUser = None,
) -> ReverseImageSearchResponse:
    asset_id_str = str(asset_id)
    response = (
        db.schema("core")
        .table("media_assets")
        .select("id, source, source_url, metadata")
        .eq("id", asset_id_str)
        .limit(1)
        .execute()
    )
    if not response.data:
        raise HTTPException(status_code=404, detail="Media asset not found")

    row = response.data[0]
    if str(row.get("source") or "").strip().lower() != "getty":
        raise HTTPException(status_code=400, detail="Only Getty assets support reverse image search")

    source_url = str(row.get("source_url") or "").strip()
    if not source_url:
        raise HTTPException(status_code=409, detail="Media asset has no source_url")

    candidates = search_by_image_url(source_url, min_width=1080, limit=5)
    return ReverseImageSearchResponse(
        asset_id=asset_id_str,
        candidates=[
            {
                "title": c.title,
                "source_domain": c.source_domain,
                "page_url": c.page_url,
                "thumbnail_b64": c.thumbnail_b64,
                "width": c.width,
                "height": c.height,
            }
            for c in candidates
        ],
        search_url=source_url,
    )
```

Add the replace endpoint:

```python
@router.post(
    "/media-assets/{asset_id}/replace-from-url",
    response_model=ReplaceFromUrlResponse,
)
def replace_from_url(
    asset_id: UUID,
    payload: ReplaceFromUrlRequest,
    db: SupabaseAdminClient = None,
    _: AdminUser = None,
) -> ReplaceFromUrlResponse:
    asset_id_str = str(asset_id)
    response = (
        db.schema("core")
        .table("media_assets")
        .select("id, source, source_url, hosted_url, hosted_key, metadata")
        .eq("id", asset_id_str)
        .limit(1)
        .execute()
    )
    if not response.data:
        raise HTTPException(status_code=404, detail="Media asset not found")

    row = response.data[0]
    if str(row.get("source") or "").strip().lower() != "getty":
        raise HTTPException(status_code=400, detail="Only Getty assets can be replaced via reverse search")

    # Scrape the page for the largest image
    try:
        scraped = scrape_url_for_images(payload.page_url, min_width=800)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to scrape page: {exc}") from exc

    if not scraped:
        raise HTTPException(status_code=422, detail="No suitable images found on the page")

    best = max(scraped, key=lambda img: (img.width or 0) * (img.height or 0))
    if best.width and best.width < 1080:
        raise HTTPException(
            status_code=422,
            detail=f"Best image found is only {best.width}x{best.height}, below 1080px minimum",
        )

    # Download and hash
    try:
        download_result = download_and_hash_image(best.best_url, referer=payload.page_url)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to download image: {exc}") from exc

    if not download_result or not download_result.get("data"):
        raise HTTPException(status_code=502, detail="Downloaded image was empty")

    # Upload to S3
    s3_client = get_s3_client()
    bucket = get_s3_bucket()
    s3_key = f"media-assets/{asset_id_str}/replaced.jpg"
    content_type = download_result.get("content_type", "image/jpeg")

    try:
        s3_client.put_object(
            Bucket=bucket,
            Key=s3_key,
            Body=download_result["data"],
            ContentType=content_type,
        )
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to upload to S3: {exc}") from exc

    from trr_backend.media.s3_mirror import build_hosted_url

    hosted_url = build_hosted_url(s3_key)

    # Preserve Getty metadata, update source
    existing_metadata = row.get("metadata") if isinstance(row.get("metadata"), dict) else {}
    getty_metadata = {
        k: v for k, v in existing_metadata.items()
        if k in (
            "getty", "getty_details", "getty_tags", "getty_event_title", "getty_event_url",
            "object_name", "editorial_number", "people", "resolved_people", "unmatched_people",
            "tagged_people", "people_count", "people_names", "published_at", "show_name",
            "season_number", "episode_number", "episode_title", "content_type",
        )
    }
    new_metadata = {
        **getty_metadata,
        "original_source": "getty",
        "original_source_url": str(row.get("source_url") or ""),
        "replaced_from": {
            "url": payload.page_url,
            "domain": payload.source_domain,
            "width": best.width,
            "height": best.height,
            "replaced_at": datetime.now(UTC).isoformat(),
        },
    }

    # Update the media asset record
    update_payload = {
        "source": payload.source_domain,
        "source_url": payload.page_url,
        "hosted_url": hosted_url,
        "hosted_key": s3_key,
        "hosted_bucket": bucket,
        "hosted_sha256": download_result.get("sha256"),
        "hosted_bytes": len(download_result.get("data", b"")),
        "hosted_content_type": content_type,
        "width": best.width,
        "height": best.height,
        "sha256": download_result.get("sha256"),
        "metadata": new_metadata,
        "updated_at": datetime.now(UTC).isoformat(),
    }

    db.schema("core").table("media_assets").update(update_payload).eq("id", asset_id_str).execute()

    # Regenerate variants
    try:
        generate_media_asset_variants(db, asset_id_str)
    except Exception as exc:
        logger.warning("Variant generation failed after replace for %s: %s", asset_id_str, exc)

    return ReplaceFromUrlResponse(
        asset_id=asset_id_str,
        status="replaced",
        new_source=payload.source_domain,
        new_source_url=payload.page_url,
        new_hosted_url=hosted_url,
        width=best.width,
        height=best.height,
    )
```

Add `logger` near the top of the file if not already present:

```python
import logging
logger = logging.getLogger(__name__)
```

**Step 2: Run existing tests to verify nothing is broken**

Run: `cd TRR-Backend && python -m pytest tests/ -x -q --timeout=30`
Expected: All existing tests pass

**Step 3: Commit**

```bash
cd TRR-Backend
git add api/routers/admin_media_assets.py
git commit -m "feat: add reverse-image-search and replace-from-url endpoints"
```

---

### Task 4: Next.js API Proxy Routes

**Files:**
- Create: `TRR-APP/apps/web/src/app/api/admin/trr-api/media-assets/[assetId]/reverse-image-search/route.ts`
- Create: `TRR-APP/apps/web/src/app/api/admin/trr-api/media-assets/[assetId]/replace-from-url/route.ts`

Follow the exact pattern from the existing mirror route at `TRR-APP/apps/web/src/app/api/admin/trr-api/media-assets/[assetId]/mirror/route.ts`.

**Step 1: Create the reverse-image-search proxy**

```typescript
import { NextRequest, NextResponse } from "next/server";
import { requireAdmin } from "@/lib/server/auth";
import { getBackendApiUrl } from "@/lib/server/trr-api/backend";

export const dynamic = "force-dynamic";
const SEARCH_TIMEOUT_MS = 45_000; // PicDetective can be slow

interface RouteParams {
  params: Promise<{ assetId: string }>;
}

export async function POST(request: NextRequest, { params }: RouteParams) {
  try {
    await requireAdmin(request);
    const { assetId } = await params;

    if (!assetId) {
      return NextResponse.json({ error: "assetId is required" }, { status: 400 });
    }

    const backendUrl = getBackendApiUrl(`/admin/media-assets/${assetId}/reverse-image-search`);
    if (!backendUrl) {
      return NextResponse.json({ error: "Backend API not configured" }, { status: 500 });
    }

    const serviceRoleKey = process.env.TRR_CORE_SUPABASE_SERVICE_ROLE_KEY;
    if (!serviceRoleKey) {
      return NextResponse.json({ error: "Backend auth not configured" }, { status: 500 });
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), SEARCH_TIMEOUT_MS);

    try {
      const backendResponse = await fetch(backendUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${serviceRoleKey}`,
        },
        body: "{}",
        signal: controller.signal,
      });
      clearTimeout(timer);

      const data = await backendResponse.json().catch(() => ({}));
      if (!backendResponse.ok) {
        return NextResponse.json(
          { error: data.error ?? "Search failed", detail: data.detail },
          { status: backendResponse.status }
        );
      }
      return NextResponse.json(data);
    } catch (error) {
      clearTimeout(timer);
      if (error instanceof Error && error.name === "AbortError") {
        return NextResponse.json(
          { error: "Search timed out", detail: `Timed out after ${SEARCH_TIMEOUT_MS / 1000}s` },
          { status: 504 }
        );
      }
      throw error;
    }
  } catch (error) {
    console.error("[api] reverse-image-search failed", error);
    const message = error instanceof Error ? error.message : "failed";
    const status = message === "unauthorized" ? 401 : message === "forbidden" ? 403 : 500;
    return NextResponse.json({ error: message }, { status });
  }
}
```

**Step 2: Create the replace-from-url proxy**

```typescript
import { NextRequest, NextResponse } from "next/server";
import { requireAdmin } from "@/lib/server/auth";
import { getBackendApiUrl } from "@/lib/server/trr-api/backend";

export const dynamic = "force-dynamic";
const REPLACE_TIMEOUT_MS = 120_000; // Download + S3 upload + variant gen

interface RouteParams {
  params: Promise<{ assetId: string }>;
}

export async function POST(request: NextRequest, { params }: RouteParams) {
  try {
    await requireAdmin(request);
    const { assetId } = await params;

    if (!assetId) {
      return NextResponse.json({ error: "assetId is required" }, { status: 400 });
    }

    const backendUrl = getBackendApiUrl(`/admin/media-assets/${assetId}/replace-from-url`);
    if (!backendUrl) {
      return NextResponse.json({ error: "Backend API not configured" }, { status: 500 });
    }

    const serviceRoleKey = process.env.TRR_CORE_SUPABASE_SERVICE_ROLE_KEY;
    if (!serviceRoleKey) {
      return NextResponse.json({ error: "Backend auth not configured" }, { status: 500 });
    }

    const body = await request.json().catch(() => ({}));
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), REPLACE_TIMEOUT_MS);

    try {
      const backendResponse = await fetch(backendUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${serviceRoleKey}`,
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      });
      clearTimeout(timer);

      const data = await backendResponse.json().catch(() => ({}));
      if (!backendResponse.ok) {
        return NextResponse.json(
          { error: data.error ?? "Replace failed", detail: data.detail },
          { status: backendResponse.status }
        );
      }
      return NextResponse.json(data);
    } catch (error) {
      clearTimeout(timer);
      if (error instanceof Error && error.name === "AbortError") {
        return NextResponse.json(
          { error: "Replace timed out", detail: `Timed out after ${REPLACE_TIMEOUT_MS / 1000}s` },
          { status: 504 }
        );
      }
      throw error;
    }
  } catch (error) {
    console.error("[api] replace-from-url failed", error);
    const message = error instanceof Error ? error.message : "failed";
    const status = message === "unauthorized" ? 401 : message === "forbidden" ? 403 : 500;
    return NextResponse.json({ error: message }, { status });
  }
}
```

**Step 3: Commit**

```bash
cd TRR-APP
git add apps/web/src/app/api/admin/trr-api/media-assets/\[assetId\]/reverse-image-search/route.ts
git add apps/web/src/app/api/admin/trr-api/media-assets/\[assetId\]/replace-from-url/route.ts
git commit -m "feat: add Next.js proxy routes for reverse-image-search and replace-from-url"
```

---

### Task 5: ReplaceGettyDrawer Component

**Files:**
- Create: `TRR-APP/apps/web/src/components/admin/image-lightbox/ReplaceGettyDrawer.tsx`

**Step 1: Create the drawer component**

This component shows PicDetective candidates in a slide-out panel. It handles three states: loading, results, and replacing.

```tsx
"use client";

import { useState, useCallback } from "react";

interface ReverseImageCandidate {
  title: string;
  source_domain: string;
  page_url: string;
  thumbnail_b64: string | null;
  width: number | null;
  height: number | null;
}

interface ReplaceGettyDrawerProps {
  assetId: string;
  onClose: () => void;
  onReplaced: () => void;
}

export function ReplaceGettyDrawer({ assetId, onClose, onReplaced }: ReplaceGettyDrawerProps) {
  const [candidates, setCandidates] = useState<ReverseImageCandidate[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [replacing, setReplacing] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Fetch candidates on mount
  const fetchCandidates = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`/api/admin/trr-api/media-assets/${assetId}/reverse-image-search`, {
        method: "POST",
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? "Search failed");
        setCandidates([]);
        return;
      }
      setCandidates(data.candidates ?? []);
    } catch {
      setError("Failed to connect to search service");
      setCandidates([]);
    } finally {
      setLoading(false);
    }
  }, [assetId]);

  // Trigger fetch on first render
  useState(() => { fetchCandidates(); });

  const handleReplace = async (candidate: ReverseImageCandidate) => {
    setReplacing(candidate.page_url);
    try {
      const res = await fetch(`/api/admin/trr-api/media-assets/${assetId}/replace-from-url`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          page_url: candidate.page_url,
          source_domain: candidate.source_domain,
          expected_width: candidate.width,
          expected_height: candidate.height,
        }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.detail ?? data.error ?? "Replace failed");
        setReplacing(null);
        return;
      }
      onReplaced();
    } catch {
      setError("Failed to replace image");
      setReplacing(null);
    }
  };

  const MIN_WIDTH = 1080;

  return (
    <div className="mt-4 rounded-lg border border-white/10 bg-white/5 p-4">
      <div className="flex items-center justify-between">
        <span className="text-sm font-medium text-white">Replace Getty Image</span>
        <button
          onClick={onClose}
          className="text-white/50 hover:text-white"
          aria-label="Close"
        >
          ✕
        </button>
      </div>

      {loading && (
        <div className="mt-3 space-y-2">
          <p className="text-xs text-white/50">Searching for alternatives...</p>
          {[1, 2, 3].map((i) => (
            <div key={i} className="h-16 animate-pulse rounded bg-white/10" />
          ))}
        </div>
      )}

      {error && (
        <p className="mt-3 text-xs text-red-400">{error}</p>
      )}

      {!loading && candidates && candidates.length === 0 && !error && (
        <p className="mt-3 text-xs text-white/50">
          No alternative sources found above {MIN_WIDTH}px for this image.
        </p>
      )}

      {!loading && candidates && candidates.length > 0 && (
        <div className="mt-3 space-y-2">
          {candidates.map((candidate) => {
            const meetsMin = candidate.width != null && candidate.width >= MIN_WIDTH;
            const isReplacing = replacing === candidate.page_url;
            const area = (candidate.width ?? 0) * (candidate.height ?? 0);

            return (
              <div
                key={candidate.page_url}
                className={`flex items-start gap-3 rounded p-2 ${
                  meetsMin ? "bg-white/10" : "bg-white/5 opacity-50"
                }`}
              >
                {candidate.thumbnail_b64 ? (
                  <img
                    src={candidate.thumbnail_b64}
                    alt=""
                    className="h-12 w-16 flex-shrink-0 rounded object-cover"
                  />
                ) : (
                  <div className="flex h-12 w-16 flex-shrink-0 items-center justify-center rounded bg-white/10 text-[10px] text-white/30">
                    No preview
                  </div>
                )}
                <div className="min-w-0 flex-1">
                  <p className="truncate text-xs font-medium text-white">
                    {candidate.source_domain}
                  </p>
                  <p className="truncate text-[10px] text-white/50">
                    {candidate.title || "Untitled"}
                  </p>
                  <p className="text-[10px] text-white/40">
                    {candidate.width && candidate.height
                      ? `${candidate.width} × ${candidate.height}`
                      : "Unknown size"}
                  </p>
                </div>
                {meetsMin && (
                  <button
                    onClick={() => handleReplace(candidate)}
                    disabled={replacing !== null}
                    className="flex-shrink-0 rounded bg-blue-500/80 px-2 py-1 text-[10px] font-medium text-white hover:bg-blue-500 disabled:opacity-50"
                  >
                    {isReplacing ? "Replacing..." : "Use This"}
                  </button>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
```

**Step 2: Commit**

```bash
cd TRR-APP
git add apps/web/src/components/admin/image-lightbox/ReplaceGettyDrawer.tsx
git commit -m "feat: add ReplaceGettyDrawer component for reverse image search candidates"
```

---

### Task 6: Add "Replace Getty" Button to Lightbox

**Files:**
- Modify: `TRR-APP/apps/web/src/components/admin/ImageLightbox.tsx`

**Step 1: Add import for ReplaceGettyDrawer**

Near the other lightbox imports (around line 26), add:

```typescript
import { ReplaceGettyDrawer } from "@/components/admin/image-lightbox/ReplaceGettyDrawer";
```

**Step 2: Add state and button**

Find the inner component that renders the management actions section (around line 1543-1727). You need to:

1. Add state: `const [showReplaceGetty, setShowReplaceGetty] = useState(false);`
   Place this near the other `useState` calls in the same component scope.

2. Add the "Replace Getty" button and drawer inside `<LightboxManagementActions>`, right before the "Re-assign" button (around line 1701). Insert:

```tsx
{metadata.source?.toLowerCase() === "getty" && (
  <>
    <button
      onClick={() => setShowReplaceGetty((prev) => !prev)}
      disabled={actionLoading !== null || showReplaceGetty}
      className="w-full rounded bg-amber-500/20 px-3 py-2 text-left text-sm text-amber-300 hover:bg-amber-500/30 disabled:opacity-50"
    >
      {showReplaceGetty ? "Cancel Replace" : "Replace Getty"}
    </button>
    {showReplaceGetty && (
      <ReplaceGettyDrawer
        assetId={metadata.assetId ?? metadata.id ?? ""}
        onClose={() => setShowReplaceGetty(false)}
        onReplaced={() => {
          setShowReplaceGetty(false);
          management?.onRefresh?.();
        }}
      />
    )}
  </>
)}
```

**Important:** Check what property holds the asset ID on the `metadata` object. It is likely `metadata.assetId` or `metadata.id` — check the `PhotoMetadata` type in `@/lib/photo-metadata.ts`. Also verify `metadata.source` is available (the `formatSourceBadgeLabel` function at line 111 receives it, so it should be on the metadata object).

**Step 3: Verify the button only appears for Getty-sourced images**

Run the dev server: `cd TRR-APP && pnpm dev`
Navigate to an admin gallery, open the lightbox on a Getty image — the amber "Replace Getty" button should appear.
Open a non-Getty image — no button.

**Step 4: Commit**

```bash
cd TRR-APP
git add apps/web/src/components/admin/ImageLightbox.tsx
git commit -m "feat: add Replace Getty button to lightbox management actions"
```

---

### Task 7: End-to-End Smoke Test

**Step 1: Start both servers**

```bash
# Terminal 1 — Backend
cd TRR-Backend && uvicorn api.main:app --reload --port 8000

# Terminal 2 — Frontend
cd TRR-APP && pnpm dev
```

**Step 2: Test the full flow**

1. Navigate to an admin gallery page with Getty images
2. Open a Getty image in the lightbox
3. Verify the amber "Replace Getty" button appears
4. Click it — verify the drawer shows "Searching for alternatives..."
5. Verify candidates appear with thumbnails, source domains, and resolutions
6. Candidates below 1080px should be grayed out without "Use This" button
7. Click "Use This" on a candidate
8. Verify "Replacing..." state shows
9. Verify the lightbox refreshes with the new unwatermarked image
10. Verify the source badge changed from "Getty" to the new domain
11. Verify the metadata panel still shows Getty editorial details (people, event, caption)

**Step 3: Test edge cases**

- Open a non-Getty image → no "Replace Getty" button
- Open a Getty image with no PicDetective results → "No alternative sources found" message
- Check that the original Getty metadata is preserved in the database (`metadata.getty`, `metadata.original_source`)

**Step 4: Final commit**

```bash
cd TRR-Backend && git add -A && git status  # Verify only expected files
cd TRR-APP && git add -A && git status      # Verify only expected files
```
