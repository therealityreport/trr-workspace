# Screenalytics Retirement Migration Plan

Date: 2026-05-28

## Goal

Retire the adjacent `screenalytics/` repo from the TRR workspace. Anything still needed by supported Backend, App, or workspace operations should move into `TRR-Backend`, `TRR-APP`, or root workspace scripts/docs. Everything else should be archived or deleted.

## Current Conclusion

Current code evidence says the supported runtime no longer depends on importing, packaging, or launching code from `/Users/thomashulihan/Projects/TRR/screenalytics`.

There are still three kinds of Screenalytics references:

- Product/workflow labels in `TRR-APP`, especially `/screenalytics`; these are app-owned and can remain or be renamed.
- Backend compatibility names and DB legacy bridge fields; these are backend-owned and do not require the adjacent repo.
- Workspace scripts/docs/env manifests that still model `screenalytics/` as a live adjacent runtime; these should be migrated before the folder is removed.

## Already Migrated

### People Count And Image Analysis

Status: migrated to Backend.

Retained target:

- `TRR-Backend/trr_backend/vision/people_count_service.py`
- `TRR-Backend/trr_backend/vision/people_count_engine.py`
- `TRR-Backend/trr_backend/clients/screenalytics.py`
- `TRR-Backend/trr_backend/services/person_images/detection.py`

Notes:

- Backend tests explicitly prove people-count works without `SCREENALYTICS_API_URL`.
- `trr_backend.clients.screenalytics` is now a compatibility shim, not a remote Screenalytics client.
- No code needs to move from `screenalytics/apps/api/routers/vision.py` for current supported admin image flows.

Retirement action:

- Keep Backend implementation.
- Later rename compatibility symbols away from `Screenalytics*` after API callers/tests are updated.

### Cast Screen-Time Control Plane And Worker

Status: migrated to Backend/App.

Retained targets:

- `TRR-Backend/api/routers/admin_cast_screentime.py`
- `TRR-Backend/trr_backend/services/retained_cast_screentime_runtime.py`
- `TRR-Backend/trr_backend/services/retained_cast_screentime_dispatch.py`
- `TRR-Backend/trr_backend/services/retained_cast_screentime_review.py`
- `TRR-Backend/trr_backend/services/cast_screentime_artifacts.py`
- `TRR-Backend/trr_backend/repositories/cast_screentime.py`
- `TRR-APP/apps/web/src/app/admin/cast-screentime/`
- `TRR-APP/apps/web/src/app/api/admin/trr-api/cast-screentime/[...path]/route.ts`

Notes:

- `scripts/cast-screentime-gap-check.sh` already states no separate `screenalytics` repo checks are required.
- Backend starts runs through `retained_cast_screentime_runtime.enqueue_run`, not through `screenalytics/apps/api/services/cast_screentime_dispatch.py`.
- Backend still exposes `/internal/screenalytics/cast-screentime/*` callback endpoints, but those are retained compatibility endpoints in Backend.

Retirement action:

- Keep Backend/App retained runtime.
- Confirm no deployed external worker still calls `/internal/screenalytics/cast-screentime/*`.
- After that, rename internal callback route/auth names from `screenalytics` to `retained-screentime` or remove the callback endpoints entirely if the backend-only runtime no longer needs them.

### Screenalytics Picker Route

Status: migrated to App.

Retained targets:

- `TRR-APP/apps/web/src/app/screenalytics/page.tsx`
- `TRR-APP/apps/web/src/components/admin/ScreenalyticsPickerPage.tsx`
- `TRR-APP/apps/web/src/proxy.ts`

Notes:

- The visible `/screenalytics` route is app-owned.
- The component already says the picker is separate from the retired legacy `screenalytics` repo UI.
- `screenalytics/web/` is not used by TRR-APP.

Retirement action:

- Keep route as product label or rename it deliberately in TRR-APP.
- Do not keep `screenalytics/web/` for this route.

### Facebank Seed State

Status: migrated to Backend/App retained face-reference model.

Retained targets:

- `TRR-Backend/api/auth.py` facebank seed admin auth
- `TRR-Backend/trr_backend/repositories/face_references.py`
- `TRR-Backend/trr_backend/services/face_reference_contract.py`
- `TRR-Backend/trr_backend/services/face_reference_embeddings.py`
- `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/gallery/[linkId]/facebank-seed/route.ts`
- `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/facebank-seed-state.ts`

Notes:

- Backend retains legacy bridge fields like `legacy_screenalytics_face_bank_image_id`.
- Those fields do not require the adjacent repo; they support migration/history.
- Old `screenalytics/apps/api/routers/cast.py` sync endpoints should not be treated as supported source.

Retirement action:

- Keep Backend/App facebank seed flows.
- Do not migrate old Screenalytics facebank API unless a missing current workflow is proven.

## Still Needs Migration Before Repo Removal

### Workspace Env Governance

Problem:

- `docs/workspace/shared-env-manifest.json` still has a `screenalytics` owner alias.
- It still lists `screenalytics/.env.example`, `screenalytics/web/.env.local.example`, and `screenalytics/.env` as authority/local-secret surfaces.
- `scripts/env_contract_report.py` still renders `screenalytics` as a live owner alias.
- `scripts/workspace/env_hygiene.py` still has Screenalytics-specific key classification.

Target:

- Move surviving `SCREENALYTICS_*` keys into `backend-shared-schema` or `workspace-ops` only when the key is still consumed by supported Backend/workspace code.
- Mark old `screenalytics/.env*` surfaces as retired/ignored instead of authority surfaces.
- Remove `screenalytics` as a live owner alias once no supported env contract depends on it.

Suggested implementation slice:

1. Update `docs/workspace/shared-env-manifest.json`.
2. Update `scripts/env_contract_report.py` owner-alias projection.
3. Update `scripts/workspace/env_hygiene.py` so retired Screenalytics env files are cleanup/archive inputs, not current authority.
4. Regenerate env docs with the repo's env-contract command.

### Workspace Startup Flags

Problem:

- `scripts/dev-workspace.sh` still exposes `WORKSPACE_SCREENALYTICS_DB_ENABLED`.
- `scripts/workspace-env-contract.sh` still documents Screenalytics DB usage and `SCREENALYTICS_DB_APPLICATION_NAME`.
- `scripts/test_workspace_app_env_projection.py` expects Screenalytics DB projection text.

Target:

- Remove or rename these as retired compatibility flags.
- If a supported Backend path still needs a DB application name, move it to Backend-owned names such as `TRR_SCREENTIME_DB_APPLICATION_NAME` or keep the existing backend pool labels.

Suggested implementation slice:

1. Remove Screenalytics DB projection from `dev-workspace.sh` output.
2. Remove `WORKSPACE_SCREENALYTICS_DB_ENABLED` from generated env contract docs.
3. Update tests that currently expect the old projection.

### Workspace Cleanup/Hygiene Scripts

Problem:

- `scripts/workspace/hygiene_report.sh` reports `screenalytics` as an adjacent workspace.
- `scripts/workspace/hygiene_clean.sh` excludes `screenalytics` as a permanent adjacent repo.
- `scripts/cleanup-workspace-disk.py` has explicit legacy Screenalytics artifact cleanup logic.
- `docs/workspace/workspace-hygiene.md` documents `screenalytics/` as report-only.

Target:

- Replace recurring adjacent-repo support with a one-time retirement cleanup path.
- Keep secret/data safeguards for `screenalytics/.env` and `screenalytics/data`.
- After the folder is moved/deleted, hygiene scripts should not expect it.

Suggested implementation slice:

1. Add a one-time `scripts/retire-screenalytics-local.sh` or extend `cleanup-workspace-disk.py` with a guarded `--retire-screenalytics-local` mode.
2. Remove `screenalytics` from default hygiene status once the retirement script exists.
3. Update workspace hygiene docs.

### Root Compatibility No-Ops

Problem:

- `make down` and `scripts/down-screenalytics-infra.sh` are retained no-ops for retired local infra.

Target:

- Keep briefly during transition, then remove once no operator workflow uses them.

Suggested implementation slice:

1. Update help text to point to the retirement note.
2. Remove `scripts/down-screenalytics-infra.sh` after one release/cleanup pass.

## Retire Without Migration

These do not need migration for current Backend/App/workspace support:

- `screenalytics/web/` Next.js prototype
- `screenalytics/apps/workspace-ui/` Streamlit UI
- `screenalytics/infra/` Docker/nginx/systemd
- `screenalytics/mcps/`
- `screenalytics/agents/`
- `screenalytics/.claude/`, `.github/`, `.vscode/`
- `screenalytics/FEATURES/`
- old audio pipeline under `screenalytics/packages/py-screenalytics/src/py_screenalytics/audio/`
- old standalone CLI tools under `screenalytics/tools/`
- old standalone docs/PDFs under `screenalytics/docs/`, `PIPELINE/`, and root pipeline files
- generated/runtime state: `.venv`, `.venv-crawl4ai`, `web/node_modules`, `web/.next`, caches, logs, `.DS_Store`

## Do Not Delete Blindly

- `screenalytics/.env`: may contain secrets.
- `screenalytics/data/`: may contain local artifacts.
- `screenalytics/.git/`: nested repo history.
- Dirty nested repo state: `git -C screenalytics status --short` currently reports `60` entries.

## Recommended Execution Order

1. Land workspace governance cleanup so no root script treats `screenalytics/` as a live authority surface.
2. Run the existing cast-screentime gap check to prove Backend/App retained runtime is the supported path.
3. Remove generated Screenalytics local artifacts to reclaim disk without touching source/history/secrets.
4. Move or archive the entire `screenalytics/` checkout out of `/Users/thomashulihan/Projects/TRR`.
5. Clean up stale Backend compatibility names and routes only after no deployed external worker calls the retained callback endpoints.
6. Decide whether `/screenalytics` remains the product label in TRR-APP or becomes `/cast-screentime`.

## Acceptance Criteria

- `rg screenalytics` in root scripts/docs no longer identifies `screenalytics/` as a live adjacent runtime.
- `git check-ignore -v screenalytics` is no longer needed for normal workspace hygiene because the folder is absent.
- `make cast-screentime-gap-check` passes without any `screenalytics/` repo test.
- TRR-APP `/screenalytics` either remains as an app-owned product route or is renamed with route redirects/tests updated.
- Backend startup and admin image/cast-screentime flows do not require `SCREENALYTICS_API_URL`.
- Local secret handling has either archived or explicitly ignored `screenalytics/.env` without printing values.
