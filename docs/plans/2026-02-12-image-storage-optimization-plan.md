# Image Storage + Routing Optimization Plan (TRR)

Date: 2026-02-12  
Owner: TRR-Backend (with TRR-APP consumer updates)

## Implementation Status (Completed)
1. Completed: `core.media_asset_variants` schema + migration in `TRR-Backend/supabase/migrations/0119_create_media_asset_variants.sql`.
2. Completed: variant generator for base + crop outputs in `TRR-Backend/trr_backend/media/image_variants.py`.
3. Completed: generation wired into scrape import and auto-crop flows in:
   - `TRR-Backend/api/routers/admin_scrape.py`
   - `TRR-Backend/api/routers/admin_image_counts.py`
4. Completed: admin reprocess endpoint and backfill scripts:
   - `TRR-Backend/api/routers/admin_media_assets.py`
   - `TRR-Backend/scripts/media/backfill_media_asset_variants.py`
   - `TRR-Backend/scripts/backfill_media_asset_variants.py`
5. Completed: variant URL fields consumed by show, season, and person admin galleries in TRR-APP.
6. Completed: cropped variant URLs are now used for card/detail rendering where available, with original fallback.
7. Completed: readable admin slug/breadcrumb routes:
   - `/admin/trr-shows/{show-slug}`
   - `/admin/trr-shows/{show-slug}/media-gallery|media-videos|media-brand`
   - `/admin/trr-shows/{show-slug}/season-{n}/{tab}`
8. Completed: slug resolution proxy route and UUID compatibility maintained.

## Context
TRR mirrors scraped/imported images to S3/CloudFront, but many assets are stored as original-resolution files (including very large JPEGs). This causes slow gallery load times. Also, admin URLs are UUID-heavy and not breadcrumb-friendly for navigation/share.

## Goals
1. Keep original assets for archival quality and dedupe integrity.
2. Serve optimized display variants by default (fast first paint, lower bandwidth).
3. Persist cropped image outputs (auto-crop and manual crop) as real files in S3.
4. Avoid breaking existing media links, tags, gallery workflows, and crop metadata.
5. Introduce readable slug/breadcrumb admin URLs (show/season/tab) with UUID-route compatibility.
6. Support safe incremental rollout and backfill.

## Non-Goals
1. Replacing existing media schema with a completely new asset model.
2. Lossy re-encoding of originals in place (originals remain intact).
3. Introducing live, on-request expensive transforms in app runtime.

## Target Architecture
1. Keep current canonical/original object in S3 (`media_assets.hosted_url`).
2. Add generated derivatives per asset (`thumb`, `card`, `detail`) stored in S3.
3. Add generated crop derivatives per crop profile/signature (auto/manual).
4. Persist derivative metadata (URL, width, height, bytes, format, crop metadata) in DB.
5. Update TRR-APP rendering to choose best-fit non-crop/crop derivative for cards/lightbox.

## Proposed Variant Sets

### Base Variants
1. `thumb` (320w, JPEG/WebP quality ~70)
2. `card` (720w, quality ~75)
3. `detail` (1440w, quality ~80)

### Crop Variants (Persisted)
1. `crop_card` (e.g., 720x900 equivalent display target)
2. `crop_detail` (e.g., 1440x1800 equivalent display target)

Crop notes:
- Auto-crop output should be persisted once auto-crop is computed.
- Manual crop updates should generate a new crop signature and corresponding persisted variants.
- Crop variants should be selected in UI when crop mode is active, avoiding CSS-only transform for primary display path.

General notes:
- Preserve aspect ratio for base variants.
- Do not upscale if original is smaller.
- Keep original format where needed for transparency (PNG), otherwise generate WebP + JPEG fallback.

## Data Model Changes (Backend)
1. Add `core.media_asset_variants` table:
   - `id`, `media_asset_id`, `variant_key`, `format`, `width`, `height`, `bytes`, `hosted_bucket`, `hosted_key`, `hosted_url`, `created_at`.
   - Optional crop fields: `crop_mode`, `crop_x`, `crop_y`, `crop_zoom`, `crop_signature`.
   - Unique index: `(media_asset_id, variant_key, format, crop_signature)`.
2. Optionally mirror convenience JSON into `core.media_assets.metadata.variants` (read-only cache).

## Crop Variant Lifecycle
1. Trigger crop variant generation when:
   - auto-crop is first produced, or
   - manual crop values are updated.
2. Build deterministic `crop_signature` from `mode+x+y+zoom+source_asset_version`.
3. If matching signature exists, skip regeneration.
4. If signature changes, generate and upsert new crop variants; keep previous entries for audit/rollback (or mark superseded).

## Processing Pipeline
1. On scrape import and duplicate-link flows:
   - Ensure original is mirrored.
   - Enqueue/execute base variant generation once per asset ID.
2. On crop compute/update flows:
   - Enqueue crop-variant generation for active crop signature.
3. Variant generator:
   - Download original once.
   - Decode safely with Pillow.
   - Generate configured base/crop outputs.
   - Upload to S3 with long cache headers.
   - Upsert `media_asset_variants` rows.
4. Retry strategy:
   - Track generation state (`pending`, `complete`, `failed`) in metadata.
   - Allow manual reprocess endpoint/script for failed variants.

## API Contract Updates
1. Extend show/season/person asset payloads with preferred URLs:
   - `display_url` (best base card-size)
   - `detail_url` (best base detail-size)
   - `crop_display_url` (best crop card-size if crop active)
   - `crop_detail_url` (best crop detail-size if crop active)
   - `original_url` (existing `hosted_url`)
2. Keep existing fields stable for backward compatibility.

## TRR-APP Changes
1. Gallery cards use `crop_display_url` when crop mode active, else `display_url`; fallback `hosted_url`.
2. Lightbox uses `crop_detail_url` when active, else `detail_url`; explicit “view original” remains.
3. Keep existing tag/filter logic untouched.

## Breadcrumb/Slug URL Plan (TRR-APP)
Introduce readable admin route format in parallel with existing UUID paths.

### New URL Pattern Examples
1. `/admin/trr-shows/the-valley-persian-style`
2. `/admin/trr-shows/the-valley-persian-style/season-1/social`
3. `/admin/trr-shows/the-valley-persian-style/media-gallery`
4. `/admin/trr-shows/the-valley-persian-style/media-brand`
5. `/admin/trr-shows/the-valley-persian-style/media-videos`
6. `/admin/trr-shows/the-valley-persian-style/news`

### Routing Strategy
1. Add slug resolution layer (`slug -> show_id`) using deterministic slug (with collision suffix strategy).
2. Keep UUID routes functional and canonical for API calls.
3. Add redirects:
   - UUID page routes -> slug routes (UI-level)
   - invalid slug -> 404 or slug-correct redirect.
4. Maintain tabs/query compatibility during migration.

## Backfill Plan
1. Add script in `TRR-Backend/scripts/media/` to backfill base + crop variants for existing assets.
2. Prioritize by recency + frequently-linked assets (show/season/person galleries first).
3. Run in batches with concurrency and resumable cursor.
4. Skip assets that already have complete variant set for current signature.
5. Add optional job to pre-generate crop variants for top N most-viewed galleries.

## Observability
1. Metrics:
   - base/crop variant generation success/failure counts
   - average bytes reduction per delivered image
   - p50/p95 image payload size (card/detail/crop-card)
2. Dashboards/logging:
   - per-source failure rates (deadline, bravo, etc.)
   - queue lag / batch runtime
   - crop signature churn (manual edits frequency)

## Rollout Strategy
1. Phase 1: schema + generator + API additive fields.
2. Phase 2: TRR-APP reads `display_url/detail_url` with fallback.
3. Phase 3: TRR-APP reads `crop_display_url/crop_detail_url` when crop active.
4. Phase 4: slug route support + UUID->slug redirects.
5. Phase 5: backfill hot assets.
6. Phase 6: full backfill.
7. Phase 7: optional stricter import guardrails (max original bytes/dimensions warnings).

## Acceptance Criteria
1. New imports produce base variants automatically.
2. Auto/manual crop updates produce persisted crop variants automatically.
3. Existing galleries render derivative URLs when available.
4. No broken image links in show/season/person pages.
5. Slug/breadcrumb URLs resolve correctly and remain shareable.
6. Legacy UUID page URLs still work (redirect or compatible rendering).
7. At least 70% reduction in median bytes transferred for gallery grid views.
8. p95 image render time improves materially in production.

## Risks and Mitigations
1. Storage growth from variants.
   - Mitigation: fixed small variant set + lifecycle review + optional retention policy for superseded crop signatures.
2. Processing load spikes during backfill.
   - Mitigation: controlled concurrency + off-peak runs.
3. Compatibility drift between backend and app.
   - Mitigation: additive fields and phased client fallback.
4. Slug collisions/renames.
   - Mitigation: collision-safe slug registry and permanent redirect table.

## Repo Execution Order
1. TRR-Backend: schema + generator + APIs + backfill script.
2. TRR-APP: consume new image fields + slug route layer.
3. screenalytics: no changes expected unless consuming image payload contracts.

## Fast Validation Checklist
1. Backend unit tests for base/crop variant generation and idempotent upserts.
2. API tests for payload backward compatibility.
3. Route tests for slug resolution and UUID redirect compatibility.
4. App smoke tests for gallery grids/lightbox and breadcrumb navigation.
5. Load test sample page with 50+ assets before/after.
