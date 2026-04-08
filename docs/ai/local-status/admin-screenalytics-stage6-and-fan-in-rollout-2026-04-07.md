# Admin Screenalytics Stage 6 And Fan-In Rollout

Last updated: 2026-04-07

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: active
  last_updated: 2026-04-07
  current_phase: "phase closeout completed; remaining remediation in progress"
  next_action: "finish auth cleanup, page decomposition, dependency hygiene, and env/backfill tooling"
  detail: self
```

## Completed In This Session
- `TRR-Backend`
  - Added additive Screenalytics v2 contract fields on run status updates.
  - Added `GET /api/v1/screenalytics/v2/runs/{run_id}/result-bundle`.
  - Added Stage 6 flag-gated result ingestion scaffolding in `sync_screenalytics`.
  - Added aggregated admin live status endpoints:
    - `GET /api/v1/admin/socials/live-status`
    - `GET /api/v1/admin/socials/live-status/stream`
  - Added auth fallback env gates and fallback usage logging.
- `screenalytics`
  - Added internal-admin JWT signing helper for service-to-service calls.
  - Made TRR ingest and cast screentime backend calls prefer JWT and fall back to service token.
  - Relaxed startup validation to allow either `TRR_INTERNAL_ADMIN_SHARED_SECRET` or `SCREENALYTICS_SERVICE_TOKEN`.
  - Replaced placeholder TRR cast sync with real candidate-driven cast upsert behavior and explicit `errors[]`.
- `TRR-APP`
  - Added a reusable cross-tab shared live-resource coordinator.
  - Added admin live-status polling/SSE adapters backed by the new backend live-status endpoints.
  - Migrated `SystemHealthModal` to the shared live-status fan-in path.
  - Migrated season/week social sync session streaming to the shared SSE coordinator.

## Verification Completed
- `TRR-Backend` targeted tests for auth, Stage 6, live-status, and Screenalytics v2 contract updates passed earlier in this session.
- `screenalytics`
  - `pytest -q screenalytics/tests/unit/test_trr_ingest.py screenalytics/tests/api/test_sync_cast_from_trr.py screenalytics/tests/unit/test_startup_config.py screenalytics/tests/api/test_cast_screentime_internal.py -q`
- `TRR-APP`
  - `pnpm -C TRR-APP/apps/web exec eslint src/components/admin/SystemHealthModal.tsx src/components/admin/season-social-analytics-section.tsx src/components/admin/social-week/WeekDetailPageView.tsx src/lib/admin/shared-live-resource.ts src/lib/admin/admin-live-status.ts src/app/api/admin/trr-api/social/ingest/live-status/route.ts src/app/api/admin/trr-api/social/ingest/live-status/stream/route.ts`
  - `pnpm -C TRR-APP/apps/web exec tsc --noEmit`

## Remaining Work
- Remove raw secret header sending from `TRR-APP` and adjust tests/contracts so JWT is the only client path.
- Decompose the remaining large admin hotspots:
  - show detail route/page
  - person detail route/page
- Remove deprecated transitive package owners from `TRR-APP` and regenerate `pnpm-lock.yaml`.
- Add workspace-owned shared env manifest and repo validation wiring.
- Add backfill/re-finalization tooling for representative Stage 6 historical runs before cutover.

## Notes
- The current workspace contains unrelated dirty changes in all three repos. Do not revert them while finishing the remaining remediation tasks.
- `screenalytics` is still on `main` in this workspace as of this snapshot; branch hygiene should be corrected before final integration/PR prep.
