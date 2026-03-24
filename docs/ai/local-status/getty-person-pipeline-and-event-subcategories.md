# Getty person pipeline and event subcategories

Last updated: 2026-03-22

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-22
  current_phase: "deterministic-getty-nbcumv-ingest"
  next_action: "Live-smoke the Brandi gallery path again and confirm Getty diagnostics explain zero-result runs when they occur"
  detail: self
```

- 2026-03-22 deterministic Getty/NBCUMV ingest follow-through:
  - `Get Images (Getty / NBCUMV)` now treats `nbcumv` as the shared Getty ingest path consistently in both refresh and reprocess flows.
  - `Run Person Pipeline` now carries the exact selected Get Images sources through to reprocess instead of widening from existing gallery rows.
  - reprocess source expansion for shared Getty/NBCUMV now stays deterministic:
    - refresh selection `nbcumv` expands to reprocess sources `getty`, `nbcumv`, and `bravotv`
    - direct `bravotv`, `imdb`, and `tmdb` selections remain source-specific
  - IMDb repair is now source-gated:
    - refresh skips IMDb repair when `IMDb` is not selected
    - reprocess skips IMDb repair when `IMDb` is not selected
  - the person-page reprocess path now switches from the initial kickoff stream to the admin-operations monitor the same way refresh already does, which avoids keeping long Modal jobs pinned to one long-lived local Next proxy stream
  - Getty diagnostics now include:
    - `getty_search_attempted`
    - primary/fallback/grouped Getty candidate counts
    - `getty_zero_result_reason`
    - `matched_via_image_search`
  - the Getty progress UI now surfaces `Via Image Search` in the completion breakdown
  - targeted validation:
    - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m py_compile api/routers/admin_person_images.py`
    - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ruff check api/routers/admin_person_images.py tests/api/routers/test_admin_person_images.py`
    - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/api/routers/test_admin_person_images.py -k 'source_aware or matched_via_image_search or zero_getty_results or refresh_runs_existing_imdb_repair_stage or refresh_skips_existing_imdb_repair_when_imdb_not_selected or reprocess_stream_runs_metadata_repair_when_enabled or reprocess_stream_skips_metadata_repair_when_imdb_is_not_selected or accepts_bravotv_source'`
    - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec eslint 'src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx' 'src/app/admin/trr-shows/people/[personId]/refresh-progress.ts' tests/person-refresh-progress.test.ts`
    - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/person-refresh-progress.test.ts`

- `TRR-Backend` Getty matching now prefers explicit `People:` overlay signals over noisy tags, infers `people_count` from Getty keywords like `One Person` / `Two People`, supports conservative one-letter typo tolerance for strong WWHL caption evidence, and blocks the known Brandi/Hilary Roberts false-positive event.
- The person Getty/NBCUMV import path now persists Getty person-match metadata, writes event subcategory metadata onto gallery bucket fields, and retries WWHL grouped-event discovery with a `Watch What Happens Live` custom date-range search using a +/- 2 day window around credited air dates when the normal grouped search comes up empty.
- `TRR-APP` person gallery now has a true `Run Person Pipeline` action that chains `Get Images` with the downstream reprocess stages and includes `Auto-Crop` by default, while preserving the single-stage worker buttons for targeted reruns.
- Person gallery tabs now put `All Media` first, route explicit event subcategories into the Events filter, move `other_shows` event rows out of generic Events, and expose `UNSORTED` as its own top-level filter.
- Crop-related copy is clearer in the UI and progress rail:
  - `Crop` means save framing/focus metadata.
  - `Auto-Crop` means generate cropped/resized variants.
- 2026-03-21 deploy follow-through:
  - committed the full dirty workspace as-is to `deploy/current-workspace-20260321` in both `TRR-APP` and `TRR-Backend`
  - pushed both branches to GitHub:
    - `TRR-APP` commit `675f3e6a9ed099a54ff38bd33b7cc7598b1f9aa3`
    - `TRR-Backend` commit `8d46a749c989bdeb1333b2189c99a59962af40b9`
  - redeployed Modal from the current backend workspace with faster admin-worker settings:
    - `TRR_MODAL_ADMIN_KEEP_WARM=2`
    - `TRR_MODAL_ADMIN_OPERATION_CONCURRENCY_LIMIT=12`
    - deploy command: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && TRR_MODAL_ADMIN_KEEP_WARM=2 TRR_MODAL_ADMIN_OPERATION_CONCURRENCY_LIMIT=12 .venv/bin/python -m modal deploy -m trr_backend.modal_jobs`
  - Modal deploy completed successfully:
    - app: `trr-backend-jobs`
    - API URL: [admin-56995--trr-backend-api.modal.run](https://admin-56995--trr-backend-api.modal.run)
    - deployment page: [Modal deployment](https://modal.com/apps/admin-56995/main/deployed/trr-backend-jobs)
  - post-deploy readiness check passed:
    - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && .venv/bin/python scripts/modal/verify_modal_readiness.py --json`
    - `ok=true`, API web endpoint resolved, all expected functions resolved including `run_admin_operation_v2` and `heartbeat_remote_executors`
  - tuned the person-gallery request profile so the app now asks the remote pipeline for more intra-job parallelism:
    - ingest: `sync=4`, `mirror=16`, `tagging=12`, `crop=12`
    - reprocess: `sync=4`, `mirror=16`, `tagging=12`, `crop=12`
    - larger batch sizes: `tagging=48`, `mirror=256`, `crop=96`
  - Vercel Git deploy triggered from the pushed app branch and was still `pending` at handoff time:
    - status context: `Vercel`
    - dashboard URL: [trr-app branch deployment](https://vercel.com/the-reality-reports-projects/trr-app/B4AJFtFr6eNnBVrLF8T5ehKaH4tG)
    - note: local Vercel CLI deploy remains blocked in this session because `vercel whoami` reports an invalid token, so the app deploy path used GitHub push + Vercel Git integration instead
- Validation:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ruff check trr_backend/integrations/getty.py api/routers/admin_person_images.py tests/integrations/test_getty.py tests/api/routers/test_admin_person_images.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ruff format --check trr_backend/integrations/getty.py api/routers/admin_person_images.py tests/integrations/test_getty.py tests/api/routers/test_admin_person_images.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/integrations/test_getty.py::test_infer_people_count_supports_one_person_keyword tests/integrations/test_getty.py::test_describe_asset_person_match_prefers_people_overlay_over_noisy_tags tests/integrations/test_getty.py::test_describe_asset_person_match_allows_single_letter_wwhl_caption_typo tests/integrations/test_getty.py::test_describe_asset_person_match_rejects_known_false_positive_event tests/api/routers/test_admin_person_images.py::test_resolve_gallery_bucket_metadata_includes_event_subcategories tests/api/routers/test_admin_person_images.py::test_import_nbcumv_person_media_uses_wwhl_date_range_fallback`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && .venv/bin/ruff check trr_backend/modal_jobs.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec eslint src/lib/admin/person-gallery-media-view.ts 'src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx' 'src/app/admin/trr-shows/people/[personId]/refresh-progress.ts' tests/person-gallery-media-view.test.ts tests/person-refresh-progress.test.ts`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/person-gallery-media-view.test.ts tests/person-refresh-progress.test.ts`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec eslint 'src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx'`
- 2026-03-21 live Brandi remote-worker validation:
  - workspace is now running non-reload backend mode with remote admin execution enabled by default:
    - `TRR_BACKEND_RELOAD=0`
    - `WORKSPACE_TRR_JOB_PLANE_MODE=remote`
    - `WORKSPACE_TRR_REMOTE_EXECUTOR=modal`
  - the stale Brandi reprocess op was force-cancelled before retest:
    - cancelled op: `6761acf8-9c8b-4094-86fd-a5a0226ff7de`
  - a fresh shared-source refresh run completed successfully on Modal:
    - refresh op: `2d49aad3-dedd-40ce-9ef0-6e4b9c41dd9d`
    - completed at: `2026-03-21 08:48:15+00`
    - result: NBCUMV direct caption search queued/imported `96` matches and the refresh stream finished cleanly
  - a fresh NBCUMV-filtered reprocess run also completed successfully on Modal:
    - reprocess op: `f30d31ff-799e-463f-bfef-2894971a9019`
    - completed at: `2026-03-21 09:05:34+00`
    - target scope: `129` NBCUMV-linked `media_links` for Brandi
    - confirmed stage behavior:
      - `Fixing IMDb Details complete (reviewed 13/13, changed 13, failed 13).`
      - `Deferring auto-count in fast-pass mode.`
      - `Deferring word detection in fast-pass mode.`
      - `Centered 95 thumbnails (19 failed, 0 manual skipped).`
      - `Variant generation complete (129/129 base, 129/129 crop).`
  - the end-to-end person pipeline now completes successfully on the live Brandi gallery path with Modal-backed refresh and reprocess execution
  - remaining follow-up worth doing, but not blocking this success criteria:
    - resize still finishes slowly because variant generation is serial and only emits heartbeat-style progress
    - IMDb repair still reports `changed 13, failed 13`, which looks like bad failure accounting rather than a hard pipeline blocker
- 2026-03-21 BravoTV source follow-up:
  - the person-gallery `Get Images` source selector is now true multi-select:
    - no source chips selected means `All Sources`
    - selectable sources are `Getty / NBCUMV`, `BravoTV`, `IMDb`, and `TMDb`
  - `TRR-Backend` person refresh now accepts `bravotv` as a first-class refresh source
  - Bravo JSON person-gallery images that are only discoverable via the Bravo JSON API now import directly into the main person-gallery flow as `media_assets`
  - BravoTV-only imports are quality-gated before upload/import:
    - default minimum long side: `1200`
    - default minimum short side: `600`
    - default minimum bytes: `150000`
    - env overrides:
      - `TRR_BRAVOTV_MIN_LONG_SIDE`
      - `TRR_BRAVOTV_MIN_SHORT_SIDE`
      - `TRR_BRAVOTV_MIN_BYTES`
  - targeted validation:
    - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/api/routers/test_admin_person_images.py -k 'bravotv or canonicalizes_getty_alias or preserves_bravotv_source'`
    - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ruff check api/routers/admin_person_images.py tests/api/routers/test_admin_person_images.py`
    - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m py_compile api/routers/admin_person_images.py`
    - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec eslint 'src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx' 'src/app/admin/trr-shows/people/[personId]/refresh-progress.ts'`
- 2026-03-21 SSE stream timeout hardening:
  - fixed long-running person refresh/reprocess/admin-operation stream proxies to stop tripping `UND_ERR_BODY_TIMEOUT` inside the Next server proxy layer
  - added a shared no-body-timeout streaming fetch helper in `TRR-APP/apps/web/src/lib/server/sse-proxy.ts`
  - applied that helper to:
    - `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/refresh-images/stream/route.ts`
    - `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/reprocess-images/stream/route.ts`
    - `TRR-APP/apps/web/src/app/api/admin/trr-api/operations/[operationId]/stream/route.ts`
  - added route-test assertions that the streaming proxy fetch includes the long-lived dispatcher configuration
  - app dependency follow-up:
    - added `undici` to `TRR-APP/apps/web/package.json`
  - targeted validation:
    - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/person-refresh-images-stream-route.test.ts tests/person-reprocess-images-stream-route.test.ts`
    - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec eslint 'src/lib/server/sse-proxy.ts' 'src/app/api/admin/trr-api/people/[personId]/refresh-images/stream/route.ts' 'src/app/api/admin/trr-api/people/[personId]/reprocess-images/stream/route.ts' 'src/app/api/admin/trr-api/operations/[operationId]/stream/route.ts' tests/person-refresh-images-stream-route.test.ts tests/person-reprocess-images-stream-route.test.ts`
- 2026-03-21 cancel-handling fix:
  - remote person reprocess workers now receive the actual admin `operation_id` via the internal raw-stream request shim
  - the reprocess stream now cooperatively checks `admin_operations.is_cancel_requested(...)` during long-running stage heartbeats and exits early when a cancel is requested
  - this closes the UI state where `Cancel Job` stayed on `Cancellation requested...` while the backend kept heartbeating forever
  - backend validation:
    - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ruff check api/routers/admin_person_images.py trr_backend/pipeline/admin_operations.py tests/api/routers/test_admin_person_images.py`
    - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m py_compile api/routers/admin_person_images.py trr_backend/pipeline/admin_operations.py tests/api/routers/test_admin_person_images.py`
