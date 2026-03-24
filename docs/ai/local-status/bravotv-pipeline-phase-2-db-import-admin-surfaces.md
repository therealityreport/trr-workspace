# BRAVOTV Pipeline Phase 2: DB Import and Admin Surfaces

Last updated: 2026-03-20

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-20
  current_phase: "Phase 2 shipped across backend and app, then the person-source contract was expanded so BRAVOTV Run All now includes Fandom gallery cards alongside Getty, IMDb, and TMDb with richer supplemental import metadata"
  next_action: "Run managed Chrome validation on the person admin page to confirm the Fandom-aware BRAVOTV source selector reads clearly, then decide whether to remove the lower legacy Get Images source buttons or keep them as separate maintenance tooling"
  detail: self
```

## Scope
- Approved plan: BRAVOTV Pipeline Phase 2
- Delivery focus:
  - durable BRAVOTV run persistence
  - object-storage-backed artifacts
  - auto-import into `core.media_assets` and `core.media_links`
  - shared backend run APIs
  - shared show/person admin UI controls
  - smarter Getty replacement metadata and previews

## What Shipped
- Backend:
  - Added `core.bravotv_image_runs` migration in `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/0202_bravotv_image_runs.sql`
  - Added run persistence repository in `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/bravotv_image_runs.py`
  - Added shared BRAVOTV run service in `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/bravotv/run_service.py`
    - uploads run artifacts to object storage under `bravotv-image-runs/{run_id}/...`
    - auto-imports deterministic results into unified media tables
    - keeps ambiguous person assignments in review artifacts
    - preserves replacement-needed metadata and Google reverse-image-search URLs
    - now preserves supplemental source context like Fandom section labels/content types during media import and generates variants for supplemental imports too
  - Expanded person supplemental source collection in `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/bravotv/get_images_pipeline.py`
    - `Run All` now includes `fandom` in person mode
    - Fandom gallery intake uses the existing Real Housewives gallery filter and keeps only confessional, intro, and title-card style assets
  - Tightened Fandom gallery normalization in `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/ingestion/cast_photo_sources.py`
    - treats `Title Cards` as intro-style assets
    - persists `fandom_section_label` and `fandom_section_tag` metadata for downstream gallery views
  - Added shared admin router in `/Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/admin_bravotv_images.py`
  - Registered the router in `/Users/thomashulihan/Projects/TRR/TRR-Backend/api/main.py`
  - Extended remote admin operation producer resolution in `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/pipeline/admin_operations.py`
- App:
  - Added shared run helper types in `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/admin/bravotv-image-runs.ts`
    - person-mode BRAVOTV source options now include `Fandom`
    - `Run All` is now described as Getty + Fandom + IMDb + TMDb
  - Added shared admin panel in `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/components/admin/BravotvImageRunPanel.tsx`
  - Added app proxy routes for show/person latest runs, stream starts, and artifact previews
  - Wired the shared panel into:
    - `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`
    - `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`

## Validation
- Backend:
  - `ruff check` passed for all touched backend files and new tests
  - `ruff format` applied
  - `pytest -q tests/api/routers/test_admin_bravotv_images.py tests/bravotv/test_run_service.py tests/bravotv/test_get_images_pipeline.py`
  - result: `12 passed`
  - `pytest -q tests/ingestion/test_cast_photo_sources_fandom.py tests/bravotv/test_get_images_pipeline.py tests/bravotv/test_run_service.py`
  - result: `12 passed`
- App:
  - `eslint` passed for all touched app files and new tests
  - `vitest run tests/bravotv-image-runs.test.ts tests/bravotv-image-routes.test.ts tests/bravotv-image-run-panel-wiring.test.ts tests/person-refresh-request-id-wiring.test.ts tests/person-refresh-images-stream-route.test.ts`
  - result: `25 passed`
  - `vitest run tests/bravotv-image-runs.test.ts`
  - result: `4 passed`
  - `pnpm exec next build --webpack` passed

## Schema Docs Note
- Added tracked docs for `core.bravotv_image_runs` manually under `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/schema_docs/`.
- `make schema-docs-check` was run, but it exposed unrelated local DB/schema drift in existing tables and therefore could not be used as a clean sync signal for this session.
- I restored the unrelated generated drift and kept only the new BRAVOTV run-table docs in the repo.
- Follow-up hardening: BRAVOTV run reads now fail soft when the migration has not yet been applied, so the admin panels render `no runs yet` instead of throwing a backend 500 on page load.

## Remaining Gaps
- Managed Chrome validation was not completed in this session.
- Photo Bank enrichment remains deferred.
- Google reverse-image-search URLs are surfaced, but Google result scraping is still out of scope.
- A richer manual-review queue UI is still a follow-up.

## Next Best Steps
1. Run managed Chrome validation for the new show and person admin panels against live admin pages.
2. Decide whether unresolved-review actions should land as a dedicated queue or stay artifact-preview-only for now.
3. Choose whether the next backend slice is Photo Bank metadata enrichment or deeper import dedupe/reconciliation.
