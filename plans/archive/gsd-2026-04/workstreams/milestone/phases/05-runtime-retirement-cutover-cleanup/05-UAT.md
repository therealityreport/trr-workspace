---
status: complete
phase: 05-runtime-retirement-cutover-cleanup
source:
  - 05-01-SUMMARY.md
started: 2026-04-03T21:03:00Z
updated: 2026-04-04T02:42:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Cold Start Smoke Test
expected: Stop any running backend process that serves screentime admin routes. Start TRR-Backend fresh without relying on `SCREENALYTICS_API_URL` or `SCREENALYTICS_SERVICE_TOKEN` for screentime. The server should boot cleanly, and a basic screentime admin request or page load should work without startup or auth errors tied to Screenalytics runtime config.
result: pass

### 2. Screentime Admin Page Continuity
expected: Open the existing TRR-APP screentime admin flow and navigate to the screentime page. The page should load through the same proxy path as before, and the main screentime UI should render without Screenalytics-specific runtime errors or missing-contract failures.
result: pass
reported: "Using the local dev-admin bypass on `http://127.0.0.1:3000/admin/cast-screentime`, the page rendered the full Cast Screen-Time operator UI after waiting for the page heading rather than stalling on the initial shell. A browser screenshot confirmed the owner-scope form, upload/import controls, run controls, review panels, and rollup cards all rendered through the existing app route."
severity: none

### 3. Backend-only Run Inspection
expected: Open an existing screentime asset or run from the admin workflow and inspect run details, totals, segments, exclusions, evidence, or generated clips. The inspection flow should work against backend-owned contracts with no donor-runtime fallback behavior exposed to the operator.
result: pass
reported: "After applying the retained runtime migration and asset-bridge repair, show and season published-rollup routes returned 200 from backend-owned ml.* tables for RHOBH."
severity: none

### 4. Backend-only Run Execution
expected: Trigger a screentime run, or verify the trigger path in a live environment. The request should be accepted without requiring `SCREENALYTICS_*` runtime envs, and the operator flow should continue using the existing admin surface rather than redirecting to a separate Screenalytics runtime.
result: pass
reported: "With `SCREENALYTICS_API_URL` and `SCREENALYTICS_SERVICE_TOKEN` unset, the RHOBH Season 5 clip `/Volumes/SHOWS DB/THE-SCENE/THE-SCENE.mp4` uploaded successfully, the 972 MB `upload-sessions/{id}/complete` promotion returned `200` after about 37.68s, canonical asset `b272ddc3-eb9c-4fe2-a58b-3bb8ed1989f3` was created in `ml.analysis_media_assets`, and backend-owned run `780b062e-5224-48fb-9214-b89ae40f7bf6` finished `success` with `dispatch_status=success` and manifest `derived/runs/780b062e-5224-48fb-9214-b89ae40f7bf6/manifest.json`."
severity: none

## Summary

total: 4
passed: 4
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "Operators can inspect screentime runs, rollups, and related review artifacts through backend-owned retained routes."
  status: passed
  reason: "After applying the retained runtime migration and targeted schema repairs, retained rollup reads returned 200 for RHOBH show and season routes."
  severity: none
  test: 3
  root_cause: "Initial failure was caused by unapplied retained schema. That gap is now fixed in the connected database."
  artifacts:
    - path: "TRR-Backend/trr_backend/repositories/cast_screentime.py"
      issue: "Published rollup queries now resolve successfully against ml.screentime_publications."
    - path: "TRR-Backend/supabase/migrations/20260402183000_create_ml_retained_runtime_tables.sql"
      issue: "Applied to the connected database during verification."
    - path: "TRR-Backend/supabase/migrations/20260403222500_cast_screentime_phase1_followup_repairs.sql"
      issue: "Additive follow-up migration repairs the legacy bridge and upload-session lifecycle fields without mutating already-shipped migrations."
  missing:
    - "Run a local Docker-backed `supabase db reset --yes` once Docker is available to verify the historical migration chain end-to-end in a fresh environment."
  debug_session: ""
- truth: "Operators can trigger a screentime run through the backend-owned upload and run-creation path without SCREENALYTICS runtime env dependencies."
  status: passed
  reason: "The backend runtime now owns the full smoke path for the RHOBH clip in this environment: OpenCV is installed, large-file promotion is exempt from the generic 30s request timeout, run creation is also exempt, and the fresh retained run completed successfully."
  severity: none
  test: 4
  root_cause: "The earlier failures were resolved by installing `opencv-python`, adding targeted timeout exemptions for long-running screentime admin endpoints, and repairing retained schema gaps with additive migrations."
  artifacts:
    - path: "TRR-Backend/api/routers/admin_cast_screentime.py"
      issue: "The live smoke path now completes without Screenalytics runtime envs for upload, promotion, and run creation."
    - path: "TRR-Backend/trr_backend/middleware/request_timeout.py"
      issue: "Cast screentime upload-complete and run-create endpoints are explicitly exempt from the generic request timeout budget."
    - path: "TRR-Backend/requirements.in"
      issue: "The retained screentime runtime dependency set now includes `opencv-python`."
    - path: "TRR-Backend/supabase/migrations/20260403225500_cast_screentime_manifest_key_repair.sql"
      issue: "Adds the retained `manifest_key` field required by backend execution finalization."
  missing: []
  debug_session: ""
