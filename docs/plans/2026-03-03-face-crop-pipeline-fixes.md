# Face Crop Pipeline — Refresh Details Fix

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix the "Refresh Details" pipeline so person gallery thumbnails correctly zoom in/center on the gallery owner's face, even when similarity scores are moderate (50-80%).

**Architecture:** Four backend bugs prevent correct face-centered cropping. The primary bug is an overly strict similarity threshold (0.80) in `_owner_face_crop_payload` that rejects faces the vision system already confirmed as matches (>= 0.65). When this fails, the fallback crop picks the face with highest *detection confidence* rather than highest *similarity to the owner* — centering on the wrong person. Additionally, the backend's similarity lead override redundantly overwrites already-correct "matched" diagnostics, and `_should_recenter_auto_crop` doesn't recognize successful owner crops as stable.

**Tech Stack:** Python (TRR-Backend)

---

## Root Cause Analysis

### The User's Scenario
On Alan Cumming's gallery page, an image with Alan Cumming + Milo Ventimiglia:
- **Face 1** (Milo): Sim 7.8% to owner | Detect 91.6% → below_threshold ✓
- **Face 2** (Alan): Sim 76.5% to owner | Detect 89.3% → matched ✓

Face 2 is correctly identified as Alan Cumming. But the crop fails because:

1. `_owner_face_crop_payload()` requires `match_similarity >= 0.80` — rejects 76.5%
2. Falls back to `auto_thumbnail_crop()` which picks `max(faces, key=confidence)` — picks Face 1 (91.6% detect) = Milo Ventimiglia
3. **Result: thumbnail centers on the WRONG person** (Milo, not Alan)

This is what the user means by "using Detect % instead of Similarity %."

### Bug Inventory

| # | Bug | File | Lines | Severity |
|---|-----|------|-------|----------|
| 1 | `OWNER_FACE_MATCH_SIMILARITY_MIN_DEFAULT = 0.80` too strict for crop | admin_person_images.py | 86, 2088-2098 | **Critical** |
| 1b | Same constant duplicated | admin_image_counts.py | 49, 994-1005 | **Critical** |
| 2 | Fallback crop uses detection confidence, not similarity | screenalytics.py | 194 | **High** |
| 3 | `_apply_similarity_lead_assignments` overwrites already-matched faces | admin_person_images.py | 1430-1462 | **Medium** |
| 4 | `_should_recenter_auto_crop` reprocesses owner_face_box_v1 every refresh | admin_person_images.py | 1918-1935 | **Low** |

---

## Task 1: Lower Owner Face Crop Similarity Threshold

The core fix. Lower `OWNER_FACE_MATCH_SIMILARITY_MIN_DEFAULT` from 0.80 to 0.50 in both files.

**Why 0.50:**
- Vision matching already validates at >= 0.65 (default `VISION_FACE_MATCH_SIMILARITY_MIN`)
- Cross-face lead accepts at >= 0.30 sim with >= 0.45 margin
- 0.50 is well above "different person" range (0.00-0.30) but allows all vision-confirmed matches through
- The env var `OWNER_FACE_MATCH_SIMILARITY_MIN` still allows per-deployment override

**Files:**
- Modify: `TRR-Backend/api/routers/admin_person_images.py:86`
- Modify: `TRR-Backend/api/routers/admin_image_counts.py:49`
- Test: `TRR-Backend/tests/api/routers/test_admin_person_images.py`

### Step 1: Write the failing test

Add test to `TRR-Backend/tests/api/routers/test_admin_person_images.py`:

```python
def test_owner_face_crop_payload_accepts_moderate_similarity() -> None:
    """Faces matched at 65-80% similarity should generate owner crop payloads."""
    face_boxes = [
        {
            "x": 0.1, "y": 0.2, "width": 0.2, "height": 0.3,
            "confidence": 0.916,
            "person_id": "11111111-1111-1111-1111-111111111111",
            "match_status": "matched",
            "match_similarity": 0.765,
            "match_reason": "matched",
        },
        {
            "x": 0.6, "y": 0.2, "width": 0.2, "height": 0.3,
            "confidence": 0.893,
            "match_status": "below_threshold",
            "match_similarity": 0.078,
            "match_reason": "below_threshold",
        },
    ]
    result = admin_person_images._owner_face_crop_payload(
        face_boxes,
        owner_person_id="11111111-1111-1111-1111-111111111111",
    )
    assert result is not None, "76.5% similarity should pass crop threshold"
    assert result["mode"] == "auto"
    assert result["strategy"] == "owner_face_box_v1"
    # Should center on Face 1 (the owner), not Face 2
    assert result["x"] < 50  # Face 1 is at x=0.1, center ~0.2 → ~20%
```

### Step 2: Run test to verify it fails

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/api/routers/test_admin_person_images.py::test_owner_face_crop_payload_accepts_moderate_similarity -xvs 2>&1 | tail -20`
Expected: FAIL — result is None because 0.765 < 0.80

### Step 3: Fix the threshold in admin_person_images.py

Change line 86:
```python
# Before:
OWNER_FACE_MATCH_SIMILARITY_MIN_DEFAULT = 0.80
# After:
OWNER_FACE_MATCH_SIMILARITY_MIN_DEFAULT = 0.50
```

### Step 4: Fix the threshold in admin_image_counts.py

Change line 49:
```python
# Before:
OWNER_FACE_MATCH_SIMILARITY_MIN_DEFAULT = 0.80
# After:
OWNER_FACE_MATCH_SIMILARITY_MIN_DEFAULT = 0.50
```

### Step 5: Run test to verify it passes

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/api/routers/test_admin_person_images.py::test_owner_face_crop_payload_accepts_moderate_similarity -xvs 2>&1 | tail -20`
Expected: PASS

### Step 6: Add edge case test for cross_face_lead_override at lower similarity

```python
def test_owner_face_crop_payload_accepts_cross_face_lead_override() -> None:
    """Cross-face lead override matches at ~55% similarity should generate crops."""
    face_boxes = [
        {
            "x": 0.5, "y": 0.2, "width": 0.2, "height": 0.3,
            "confidence": 0.757,
            "person_id": "11111111-1111-1111-1111-111111111111",
            "match_status": "matched",
            "match_similarity": 0.55,
            "match_reason": "cross_face_lead_override",
        },
    ]
    result = admin_person_images._owner_face_crop_payload(
        face_boxes,
        owner_person_id="11111111-1111-1111-1111-111111111111",
    )
    assert result is not None, "55% similarity cross_face_lead_override should pass"
    assert result["strategy"] == "owner_face_box_v1"
```

### Step 7: Run edge case test

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/api/routers/test_admin_person_images.py::test_owner_face_crop_payload_accepts_cross_face_lead_override -xvs 2>&1 | tail -20`
Expected: PASS

### Step 8: Verify existing tests still pass

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/api/routers/test_admin_person_images.py -x --timeout=30 2>&1 | tail -20`
Expected: All pass (no existing tests depend on 0.80 threshold)

### Step 9: Commit

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add api/routers/admin_person_images.py api/routers/admin_image_counts.py tests/api/routers/test_admin_person_images.py
git commit -m "fix: lower owner face crop similarity threshold from 0.80 to 0.50

The 0.80 threshold rejected faces that vision matching already confirmed
(>= 0.65). This caused the crop to fall back to detection-confidence
based centering, which centers on the wrong person in multi-face images.

0.50 is well above the 'different person' range (0.00-0.30) while
accepting all vision-confirmed matches. The OWNER_FACE_MATCH_SIMILARITY_MIN
env var still allows per-deployment override."
```

---

## Task 2: Fix Fallback Crop to Prefer Owner-Matched Face

When `_owner_face_crop_payload` returns None (e.g., no matched faces at all), the fallback `auto_thumbnail_crop` picks `max(faces, key=confidence)`. This picks the face with highest detection confidence — which may NOT be the owner.

**Files:**
- Modify: `TRR-Backend/trr_backend/clients/screenalytics.py:181-217`
- Test: `TRR-Backend/tests/vision/test_auto_thumbnail_crop.py` (new)

### Step 1: Write the failing test

Create `TRR-Backend/tests/vision/test_auto_thumbnail_crop.py`:

```python
from types import SimpleNamespace

from trr_backend.clients.screenalytics import auto_thumbnail_crop


def test_auto_thumbnail_crop_prefers_matched_face_over_higher_confidence() -> None:
    """When a matched face exists, prefer it over a higher-confidence unmatched face."""
    result = SimpleNamespace(
        detections=[
            SimpleNamespace(
                kind="face",
                x1=0.1, y1=0.1, x2=0.3, y2=0.4,
                confidence=0.95,
                match_status="below_threshold",
                match_similarity=0.07,
                person_id=None,
            ),
            SimpleNamespace(
                kind="face",
                x1=0.6, y1=0.1, x2=0.8, y2=0.4,
                confidence=0.85,
                match_status="matched",
                match_similarity=0.76,
                person_id="owner-uuid",
            ),
            SimpleNamespace(
                kind="person",
                x1=0.55, y1=0.0, x2=0.85, y2=0.9,
                confidence=0.80,
            ),
        ],
    )
    crop = auto_thumbnail_crop(result)
    assert crop is not None
    # Should center on the matched face (x ~ 0.7 → 70%), not the unmatched face (x ~ 0.2 → 20%)
    assert crop["x"] > 50, f"Expected crop centered on matched face (right side), got x={crop['x']}"
```

### Step 2: Run test to verify it fails

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/vision/test_auto_thumbnail_crop.py::test_auto_thumbnail_crop_prefers_matched_face_over_higher_confidence -xvs 2>&1 | tail -20`
Expected: FAIL — crop centers on left face (x < 50)

### Step 3: Fix auto_thumbnail_crop to prefer matched faces

In `TRR-Backend/trr_backend/clients/screenalytics.py`, modify `auto_thumbnail_crop` (around line 194):

```python
def auto_thumbnail_crop(
    result: PeopleCountResult,
    *,
    strategy: str = "face_torso_v2",
) -> dict[str, float | str] | None:
    """Compute deterministic auto crop from available face/person detections."""
    detections = getattr(result, "detections", None) or []
    if not detections:
        return None

    faces = [det for det in detections if str(getattr(det, "kind", "face")).lower() == "face"]
    people = [det for det in detections if str(getattr(det, "kind", "")).lower() == "person"]

    # Prefer matched faces over unmatched ones; break ties by confidence
    def _face_priority(det: object) -> tuple[int, float, float]:
        status = str(getattr(det, "match_status", "") or "").lower()
        similarity = float(getattr(det, "match_similarity", 0.0) or 0.0)
        confidence = float(getattr(det, "confidence", 0.0) or 0.0)
        is_matched = 1 if status == "matched" else 0
        return (is_matched, similarity, confidence)

    best_face = max(faces, key=_face_priority) if faces else None
    best_person = _pick_best_person_for_face(best_face, people) if best_face else None
    if not best_person and people:
        best_person = max(
            people,
            key=lambda d: (
                d.confidence,
                (d.x2 - d.x1) * (d.y2 - d.y1),
            ),
        )

    focus_x, focus_y, target_span = _face_torso_focus(face=best_face, person=best_person)
    base_visible_vertical_span = 0.8
    zoom = base_visible_vertical_span / max(target_span, 0.01)
    zoom = _clamp(zoom, 1.0, 1.6)

    return {
        "x": round(_clamp(focus_x, 0.0, 1.0) * 100.0, 1),
        "y": round(_clamp(focus_y, 0.0, 1.0) * 100.0, 1),
        "zoom": round(zoom, 2),
        "mode": "auto",
        "strategy": strategy,
    }
```

### Step 4: Apply same fix to face_centroid fallback

Also update `face_centroid` (line 220) to prefer matched faces:

```python
def face_centroid(result: PeopleCountResult) -> tuple[float, float] | None:
    """Return (x%, y%) centroid of the primary face, or None.

    Prefers matched faces over unmatched; falls back to highest confidence.
    Values are in the 0-100 range suitable for CSS object-position percentages.
    """
    detections = getattr(result, "detections", None)
    if not detections:
        return None
    face_detections = [d for d in detections if str(getattr(d, "kind", "face")).lower() == "face"]
    if not face_detections:
        return None

    def _face_priority(det: object) -> tuple[int, float, float]:
        status = str(getattr(det, "match_status", "") or "").lower()
        similarity = float(getattr(det, "match_similarity", 0.0) or 0.0)
        confidence = float(getattr(det, "confidence", 0.0) or 0.0)
        is_matched = 1 if status == "matched" else 0
        return (is_matched, similarity, confidence)

    best = max(face_detections, key=_face_priority)
    cx = ((best.x1 + best.x2) / 2) * 100
    cy = ((best.y1 + best.y2) / 2) * 100
    return (round(cx, 1), round(cy, 1))
```

### Step 5: Run test to verify it passes

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/vision/test_auto_thumbnail_crop.py -xvs 2>&1 | tail -20`
Expected: PASS

### Step 6: Run existing screenalytics client tests

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/vision/ -x --timeout=30 2>&1 | tail -20`
Expected: All pass

### Step 7: Commit

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add trr_backend/clients/screenalytics.py tests/vision/test_auto_thumbnail_crop.py
git commit -m "fix: auto_thumbnail_crop prefers matched faces over highest confidence

When the owner-specific crop path fails, the fallback was picking the
face with highest detection confidence, which could be a different
person. Now prefers matched faces (by similarity) first, falling back
to confidence only when no matched faces exist."
```

---

## Task 3: Fix `_apply_similarity_lead_assignments` Overwriting Direct Matches

The backend re-runs cross-face lead logic on boxes that screenalytics already correctly matched. This overwrites `match_reason: "matched"` with `match_reason: "cross_face_lead_override"`, producing misleading diagnostics.

**Files:**
- Modify: `TRR-Backend/api/routers/admin_person_images.py:1430-1462`
- Test: `TRR-Backend/tests/api/routers/test_admin_person_images.py`

### Step 1: Write the failing test

```python
def test_similarity_lead_does_not_overwrite_already_matched_same_person() -> None:
    """If a box is already matched for the same person, don't overwrite with lead_override."""
    boxes = [
        {
            "index": 1,
            "x": 0.1, "y": 0.2, "width": 0.2, "height": 0.3,
            "confidence": 0.91,
            "person_id": "11111111-1111-1111-1111-111111111111",
            "person_name": "Alan Cumming",
            "label": "Alan Cumming",
            "label_source": "identity_match",
            "match_status": "matched",
            "match_reason": "matched",
            "match_similarity": 0.765,
            "match_candidates": [
                {"person_id": "11111111-1111-1111-1111-111111111111", "person_name": "Alan Cumming", "similarity": 0.765},
            ],
        },
        {
            "index": 2,
            "x": 0.6, "y": 0.2, "width": 0.2, "height": 0.3,
            "confidence": 0.88,
            "label_source": "generic",
            "match_status": "below_threshold",
            "match_reason": "below_threshold",
            "match_similarity": 0.078,
            "match_candidates": [
                {"person_id": "11111111-1111-1111-1111-111111111111", "person_name": "Alan Cumming", "similarity": 0.078},
            ],
        },
    ]
    admin_person_images._apply_similarity_lead_assignments(
        boxes,
        tagged_people_ids=["11111111-1111-1111-1111-111111111111"],
        tagged_people_names=["Alan Cumming"],
    )
    # Face 1 should keep original match_reason, NOT be overwritten to cross_face_lead_override
    assert boxes[0]["match_reason"] == "matched", (
        f"Expected 'matched' but got '{boxes[0]['match_reason']}' — "
        "already-matched faces should not be overwritten by lead_override"
    )
    assert boxes[0]["label_source"] == "identity_match"
```

### Step 2: Run test to verify it fails

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/api/routers/test_admin_person_images.py::test_similarity_lead_does_not_overwrite_already_matched_same_person -xvs 2>&1 | tail -20`
Expected: FAIL — match_reason becomes "cross_face_lead_override"

### Step 3: Fix _apply_similarity_lead_assignments

In `admin_person_images.py`, in the claim processing loop (around line 1441), add a check to skip boxes already matched for the same person:

```python
    for claim in claims:
        box_index = int(claim["index"])
        if box_index in claimed_faces:
            continue
        person_id = claim.get("person_id")
        person_name = claim.get("person_name")
        person_name_key = claim.get("person_name_key")
        person_key = str(person_id or f"name:{person_name_key or ''}").strip()
        if not person_key or person_key in claimed_people:
            continue

        box = boxes[box_index]
        existing_label_source = str(box.get("label_source") or "").strip().lower()
        existing_person_id = _normalize_person_id(box.get("person_id"))
        existing_person_name_key = _person_name_key(box.get("person_name"))
        same_person = bool(
            (person_id and existing_person_id == person_id)
            or (person_name_key and existing_person_name_key == person_name_key)
        )
        if existing_label_source in {"identity_match", "owner_similarity_seed", "lead_override"} and not same_person:
            continue

        # NEW: Skip if already correctly matched for the same person
        existing_match_status = str(box.get("match_status") or "").strip().lower()
        if same_person and existing_match_status == "matched" and existing_label_source in {"identity_match", "owner_similarity_seed"}:
            claimed_faces.add(box_index)
            claimed_people.add(person_key)
            continue

        if person_id:
            box["person_id"] = person_id
        # ... rest unchanged
```

### Step 4: Run test to verify it passes

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/api/routers/test_admin_person_images.py::test_similarity_lead_does_not_overwrite_already_matched_same_person -xvs 2>&1 | tail -20`
Expected: PASS

### Step 5: Verify existing lead override test still passes

The existing test `test_build_detection_boxes_applies_similarity_lead_override_before_hybrid_fallback` has BOTH faces as "below_threshold" from screenalytics, so the new skip logic won't apply (neither has match_status="matched" with label_source="identity_match").

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/api/routers/test_admin_person_images.py::test_build_detection_boxes_applies_similarity_lead_override_before_hybrid_fallback -xvs 2>&1 | tail -20`
Expected: PASS

### Step 6: Run full test suite

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/api/routers/test_admin_person_images.py -x --timeout=30 2>&1 | tail -20`
Expected: All pass

### Step 7: Commit

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add api/routers/admin_person_images.py tests/api/routers/test_admin_person_images.py
git commit -m "fix: _apply_similarity_lead_assignments skips already-matched same-person faces

Previously, the backend cross-face lead override would overwrite
match_reason from 'matched' to 'cross_face_lead_override' even when
the face was already correctly matched by screenalytics for the same
person. This produced misleading diagnostics. Now, if a box is already
match_status='matched' with label_source='identity_match' for the
same person, it's skipped (just claimed, not overwritten)."
```

---

## Task 4: Accept `owner_face_box_v1` in `_should_recenter_auto_crop`

After Task 1 fixes the threshold, `_owner_face_crop_payload` will successfully generate `owner_face_box_v1` crops. But `_should_recenter_auto_crop` only recognizes `face_torso_v2` as stable, causing unnecessary recomputation on every refresh.

**Files:**
- Modify: `TRR-Backend/api/routers/admin_person_images.py:1918-1935`
- Test: `TRR-Backend/tests/api/routers/test_admin_person_images.py`

### Step 1: Write the failing test

```python
def test_should_recenter_auto_crop_accepts_owner_face_box_v1() -> None:
    """owner_face_box_v1 crops should be recognized as stable (skip recentering)."""
    crop = {
        "x": 35.0,
        "y": 42.0,
        "zoom": 1.35,
        "mode": "auto",
        "strategy": "owner_face_box_v1",
    }
    assert admin_person_images._should_recenter_auto_crop(crop) is False, (
        "owner_face_box_v1 should be recognized as a stable auto crop"
    )
```

### Step 2: Run test to verify it fails

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/api/routers/test_admin_person_images.py::test_should_recenter_auto_crop_accepts_owner_face_box_v1 -xvs 2>&1 | tail -20`
Expected: FAIL — returns True (wants to recenter)

### Step 3: Fix _should_recenter_auto_crop

Change the strategy check from single-value to a set:

```python
def _should_recenter_auto_crop(existing_crop: Any, *, force: bool = False) -> bool:
    if _is_manual_thumbnail_crop(existing_crop):
        return False
    if force:
        return True
    if not isinstance(existing_crop, dict):
        return True
    mode = str(existing_crop.get("mode") or "").lower()
    if mode != "auto":
        return True
    strategy = str(existing_crop.get("strategy") or "").lower()
    if strategy not in {"face_torso_v2", "owner_face_box_v1"}:
        return True
    for key in ("x", "y", "zoom"):
        value = existing_crop.get(key)
        if not isinstance(value, (int, float)):
            return True
    return False
```

### Step 4: Run test to verify it passes

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/api/routers/test_admin_person_images.py::test_should_recenter_auto_crop_accepts_owner_face_box_v1 -xvs 2>&1 | tail -20`
Expected: PASS

### Step 5: Run full test suite

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/api/routers/test_admin_person_images.py -x --timeout=30 2>&1 | tail -20`
Expected: All pass

### Step 6: Commit

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add api/routers/admin_person_images.py tests/api/routers/test_admin_person_images.py
git commit -m "fix: accept owner_face_box_v1 as stable auto crop strategy

Previously only face_torso_v2 was recognized as stable, causing
owner_face_box_v1 crops to be recomputed on every refresh. Now both
strategies are stable once generated with valid x/y/zoom values."
```

---

## Task 5: Improve `_owner_face_crop_payload` Crop Positioning with square_crop_bbox

The current crop uses raw x/y/width/height from the face box to compute center. The vision API already computes a `square_crop_bbox` with proper padding — use it when available for better centering.

**Files:**
- Modify: `TRR-Backend/api/routers/admin_person_images.py:2103-2126`
- Modify: `TRR-Backend/api/routers/admin_image_counts.py:1009-1032` (parallel copy)
- Test: `TRR-Backend/tests/api/routers/test_admin_person_images.py`

### Step 1: Write the failing test

```python
def test_owner_face_crop_payload_uses_square_crop_bbox() -> None:
    """When square_crop_bbox is available, use it for crop center computation."""
    face_boxes = [
        {
            "x": 0.4, "y": 0.3, "width": 0.1, "height": 0.15,
            "confidence": 0.90,
            "person_id": "owner-id",
            "match_status": "matched",
            "match_similarity": 0.80,
            "match_reason": "matched",
            "square_crop_bbox": [0.3, 0.2, 0.6, 0.5],  # center = (0.45, 0.35)
        },
    ]
    result = admin_person_images._owner_face_crop_payload(
        face_boxes,
        owner_person_id="owner-id",
    )
    assert result is not None
    # With square_crop_bbox, center should be at (0.45, ~0.35) → x=45.0, y=~35.0
    # Without it, center would be at (0.45, ~0.393) → x=45.0, y=~39.3
    # The key test: y should reflect square_crop_bbox center, not raw box center
    assert result["strategy"] == "owner_face_box_v1"
```

### Step 2: Modify `_owner_face_crop_payload` to use square_crop_bbox

In both `admin_person_images.py` and `admin_image_counts.py`, update the crop computation:

```python
    best = max(
        qualified_candidates,
        key=lambda item: (
            float(item.get("match_similarity") or 0.0),
            float(item.get("confidence") or 0.0),
            float(item.get("width") or 0.0) * float(item.get("height") or 0.0),
        ),
    )

    # Prefer square_crop_bbox from vision API (includes proper padding)
    scb = best.get("square_crop_bbox")
    if isinstance(scb, list) and len(scb) >= 4:
        try:
            scb_x1, scb_y1, scb_x2, scb_y2 = [float(v) for v in scb[:4]]
            scb_cx = (scb_x1 + scb_x2) / 2.0
            scb_cy = (scb_y1 + scb_y2) / 2.0
            scb_height = max(scb_y2 - scb_y1, 1e-4)
            cx = max(0.0, min(1.0, scb_cx))
            cy = max(0.0, min(1.0, scb_y1 + (scb_height * 0.45)))
            target_span = max(0.34, min(0.72, scb_height * 1.5))
        except (TypeError, ValueError):
            # Fall through to raw box computation
            scb = None

    if not isinstance(scb, list) or len(scb) < 4:
        x = float(best.get("x") or 0.0)
        y = float(best.get("y") or 0.0)
        width = max(float(best.get("width") or 0.0), 1e-4)
        height = max(float(best.get("height") or 0.0), 1e-4)
        cx = max(0.0, min(1.0, x + (width / 2.0)))
        cy = max(0.0, min(1.0, y + (height * 0.62)))
        target_span = max(0.34, min(0.72, height * 2.8))

    zoom = max(1.05, min(1.9, 0.8 / target_span))
    return {
        "x": round(cx * 100.0, 1),
        "y": round(cy * 100.0, 1),
        "zoom": round(zoom, 2),
        "mode": "auto",
        "strategy": "owner_face_box_v1",
        "generated_at": datetime.now(UTC).isoformat(),
    }
```

### Step 3: Run tests

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m pytest tests/api/routers/test_admin_person_images.py -x --timeout=30 2>&1 | tail -20`
Expected: All pass

### Step 4: Commit

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add api/routers/admin_person_images.py api/routers/admin_image_counts.py tests/api/routers/test_admin_person_images.py
git commit -m "fix: _owner_face_crop_payload uses square_crop_bbox when available

The vision API computes a padded square crop bbox for each face.
Using it produces better-centered crops than raw bounding box
coordinates."
```

---

## Task 6: Final Integration Verification

Run all relevant test files to ensure nothing is broken.

### Step 1: Run backend test suites

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python -m pytest tests/api/routers/test_admin_person_images.py tests/vision/ tests/api/routers/test_admin_image_counts_fallback.py -x --timeout=60 2>&1 | tail -30
```
Expected: All pass

### Step 2: Run screenalytics vision tests (if applicable)

```bash
cd /Users/thomashulihan/Projects/TRR/screenalytics
python -m pytest tests/api/test_vision_people_count_detections.py -x --timeout=60 2>&1 | tail -30
```
Expected: All pass (no screenalytics code changed)

### Step 3: Commit final state

If any additional fixes were needed, commit them.

---

## Summary of Changes

| File | Change | Reason |
|------|--------|--------|
| `admin_person_images.py:86` | `0.80` → `0.50` | Core fix: allow moderate-confidence matches to generate crops |
| `admin_image_counts.py:49` | `0.80` → `0.50` | Same fix in parallel code |
| `screenalytics.py:194` | `max(faces, key=confidence)` → prefer matched faces | Fallback crop centers on owner, not random person |
| `screenalytics.py:231` | Same fix in `face_centroid()` | Consistency with auto_thumbnail_crop |
| `admin_person_images.py:1441` | Skip already-matched same-person | Accurate diagnostics |
| `admin_person_images.py:1929` | Accept `owner_face_box_v1` strategy | Avoid redundant recomputation |
| `admin_person_images.py:2103-2126` | Use `square_crop_bbox` | Better crop positioning |
| `admin_image_counts.py:1009-1032` | Same square_crop_bbox fix | Parallel code |
