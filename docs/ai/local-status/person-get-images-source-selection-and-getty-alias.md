# Person Get Images source selection and Getty alias

Last updated: 2026-03-20

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-20
  current_phase: "complete"
  next_action: "Use the new Gallery-tab source selector in person pages, then follow up later only if we want broader Show Run fan-out, richer Google reverse-search automation, or extra UI around Getty fallback metadata"
  detail: self
```

- `TRR-Backend` person image refresh now accepts `getty` as a request source alias and canonicalizes it to the existing fused Getty/NBCUMV/Bravo person-gallery pipeline instead of treating Getty as a separate raw-only fetch.
- Shared refresh progress now buckets both `getty` and `nbcumv` under the same Getty/NBCUMV progress lane, so the admin stream stays coherent when the UI requests the Getty-only run mode.
- Getty fallback rows that still do not find a public replacement now persist a Google reverse-image-search URL hint in metadata while keeping the existing object-storage mirroring path intact. No new local-file save path was introduced; hosted images still flow through the existing S3/R2-compatible mirror utilities.
- `TRR-APP` person Gallery now exposes `Run All`, `Getty`, `IMDb`, and `TMDb` options next to `Get Images`, and the selected mode is threaded into the existing refresh stream request without changing the separate `Sync` stage controls.
- Current `Run All` behavior preserves the existing all-sources ingestion path; the new single-source options only scope `Get Images` when the user explicitly selects one.
- Validation:
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ./.venv/bin/ruff check api/routers/admin_person_images.py tests/api/routers/test_admin_person_images.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ./.venv/bin/ruff format --check api/routers/admin_person_images.py tests/api/routers/test_admin_person_images.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ./.venv/bin/pytest -q tests/api/routers/test_admin_person_images.py -k 'resolve_refresh_sources_canonicalizes_getty_alias_to_nbcumv or normalize_source_progress_key_maps_getty_alias_to_shared_bucket or refresh_request_accepts_getty_source_alias or import_nbcumv_person_media_persists_getty_unmatched_urls_and_imports_only_overlaps or import_nbcumv_person_media_auto_replaces_bravocon_getty_asset'`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/person-refresh-request-id-wiring.test.ts tests/person-refresh-images-stream-route.test.ts`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec eslint 'src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx' tests/person-refresh-request-id-wiring.test.ts`
