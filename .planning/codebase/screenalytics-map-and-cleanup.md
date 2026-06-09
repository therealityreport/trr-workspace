# Screenalytics Map And Cleanup Inventory

Date: 2026-05-28

## Practical Result

`screenalytics/` is an adjacent, ignored checkout/runtime folder inside the TRR workspace. It is not tracked by the TRR root repo and is not packaged by `TRR-Backend` or `TRR-APP`.

The supported runtime has moved into:

- Backend: `TRR-Backend/api`, `TRR-Backend/trr_backend`, `TRR-Backend/supabase/migrations`
- Frontend: `TRR-APP/apps/web/src`

The app still uses the visible `Screenalytics` label and `/screenalytics` picker route, but that route is implemented in `TRR-APP`, not in `screenalytics/web`.

## Evidence Commands

- `git check-ignore -v screenalytics screenalytics/.venv screenalytics/web/node_modules screenalytics/data screenalytics/.git`
- `git ls-files screenalytics`
- `git -C screenalytics status --short`
- `find screenalytics ... -prune ... -type f | wc -l`
- `rg -n --glob '!**/docs/**' 'SCREENALYTICS_API_URL|SCREENALYTICS_SERVICE_TOKEN|TRR_STAGE6_SYNC_ENABLED' TRR-Backend TRR-APP scripts Makefile`
- `rg -n --glob '!**/docs/**' 'Screenalytics|screenalytics|SCREENALYTICS' TRR-APP/apps/web/src TRR-APP/apps/web/tests`
- `rg -n 'internal/cast-screentime|cast-screentime/runs|SCREENALYTICS_SERVICE_TOKEN' TRR-Backend/api TRR-Backend/trr_backend TRR-Backend/tests TRR-Backend/scripts`

## Current Shape

- Total files under `screenalytics/`: `106560`
- Files after pruning `.git`, venvs, `node_modules`, `.next`, caches, logs, data, and worktrees: `1232`
- Nested `screenalytics` git-tracked files: `1252`
- Nested `screenalytics` dirty/deleted status entries: `60`
- TRR root tracking: none; `.gitignore` ignores `/screenalytics/`

Largest local runtime artifacts:

- `screenalytics/.venv`: `2.2G`
- `screenalytics/.venv-crawl4ai`: `630M`
- `screenalytics/web/node_modules`: `513M`
- `screenalytics/.git`: `104M`
- `screenalytics/data`: `46M`
- Entire `screenalytics/`: `3.5G`

## Source Map

### Runtime And API

- `screenalytics/apps/api/main.py` wires the legacy FastAPI app and includes the old broad API surface.
- `screenalytics/apps/api/routers/cast_screentime.py` exposes old internal worker start and clip endpoints under `/internal/cast-screentime/*`.
- `screenalytics/apps/api/services/cast_screentime.py` contains the old Screenalytics-side cast screentime worker implementation and callbacks to TRR-Backend `/internal/screenalytics/cast-screentime/*`.
- `screenalytics/apps/api/services/cast_screentime_dispatch.py` queues the old Celery worker lane.
- `screenalytics/apps/api/tasks_cast_screentime.py` defines the old Celery task.
- `screenalytics/apps/api/services/internal_admin_auth.py` creates internal-admin JWTs for outbound backend calls, with transitional `SCREENALYTICS_SERVICE_TOKEN` fallback.
- `screenalytics/apps/api/services/supabase_db.py` and `screenalytics/apps/api/services/storage.py` are supporting DB/object-storage helpers for the old API/worker.

### Python Package And Tools

- `screenalytics/packages/py-screenalytics/src/py_screenalytics/` holds reusable pipeline/audio/artifact modules for the old standalone repo.
- `screenalytics/tools/` holds old CLI and maintenance scripts.
- `screenalytics/FEATURES/` holds feature experiments and tests.
- `screenalytics/tests/` holds tests for the old repo.

### Frontend Prototype

- `screenalytics/web/` is a separate Next.js prototype with its own `package.json`, `node_modules`, `.next`, route tree, and generated OpenAPI client.
- Current `TRR-APP` does not import from `screenalytics/web`.

### Agent, Infra, Docs, Data

- `.claude/`, `.github/`, `.vscode/`, `mcps/`, and `agents/` are old repo tooling.
- `infra/` holds old Docker/nginx/systemd deployment material.
- `docs/`, `PIPELINE/`, and root pipeline PDFs are old repo documentation.
- `data/`, caches, logs, venvs, `.next`, and `node_modules` are local runtime/generated state.

## Backend Coupling

### Still Active In Backend

Backend keeps Screenalytics-named compatibility surfaces, but they are now backend-owned:

- `TRR-Backend/trr_backend/clients/screenalytics.py` is a compatibility shim over `trr_backend.vision.people_count_service`.
- `TRR-Backend/trr_backend/vision/people_count_service.py` runs local or Modal-backed people-count without `SCREENALYTICS_API_URL`.
- `TRR-Backend/api/screenalytics_auth.py` accepts internal-admin JWTs for retained worker endpoints.
- `TRR-Backend/api/routers/admin_cast_screentime.py` exposes `/internal/screenalytics/cast-screentime/*` callback endpoints.
- `TRR-Backend/trr_backend/services/retained_cast_screentime_runtime.py` now queues and executes retained cast-screentime runs inside backend code.
- `TRR-Backend/trr_backend/pipeline/stages/sync_screenalytics.py` is a disabled-by-default Stage 6 sync over backend-owned `ml.screentime_*` tables.

### Important Finding

I found no backend dependency manifest entry or Python import that requires files from `/Users/thomashulihan/Projects/TRR/screenalytics`.

The old Screenalytics worker code can still call backend compatibility endpoints if manually deployed or launched, but the current backend dispatch path does not need that folder to start runs.

## App/Frontend Coupling

### Still Active In App

TRR-APP owns the visible user-facing workflow:

- `TRR-APP/apps/web/src/app/screenalytics/page.tsx` renders the picker.
- `TRR-APP/apps/web/src/components/admin/ScreenalyticsPickerPage.tsx` implements the picker and explicitly says it is separate from the retired legacy repo UI.
- `TRR-APP/apps/web/src/proxy.ts` redirects legacy Screenalytics aliases to the backend-owned Cast Screen-Time admin path.
- Tests cover `/screenalytics`, `/screenlaytics`, and retired alias redirects.

### Important Finding

I found no TRR-APP dependency manifest entry or TS/TSX import that requires files from `screenalytics/web` or any other file under the adjacent `screenalytics/` checkout.

## Cleanup Classification

### Can Delete From TRR Root Perspective

These are generated/local artifacts and are not needed by Backend or App:

- `screenalytics/.venv/`
- `screenalytics/.venv-crawl4ai/`
- `screenalytics/web/node_modules/`
- `screenalytics/web/.next/`
- `screenalytics/.pytest_cache/`
- `screenalytics/.ruff_cache/`
- `screenalytics/.logs/`
- `screenalytics/.DS_Store` and nested `.DS_Store` files
- `screenalytics/.tmp_attempt5_report.txt`

These deletions only affect the adjacent checkout's local developer state.

### Retire Or Archive As A Batch

These are not used by supported TRR Backend or App code, but should be archived as source/history rather than deleted piecemeal if the adjacent Screenalytics repo is still being preserved:

- `screenalytics/web/`
- `screenalytics/apps/workspace-ui/`
- `screenalytics/infra/`
- `screenalytics/mcps/`
- `screenalytics/agents/`
- `screenalytics/.claude/`
- `screenalytics/.github/`
- `screenalytics/.vscode/`
- `screenalytics/FEATURES/`
- `screenalytics/docs/`
- `screenalytics/PIPELINE/`
- duplicate root pipeline PDFs/MDs
- old root setup/docs such as `ARCHITECTURE.md`, `SETUP.md`, `ACCEPTANCE_MATRIX.md`

### Keep Until Final Worker-Retirement Decision

These are only needed if an external Screenalytics worker/API can still be launched during transition:

- `screenalytics/apps/api/main.py`
- `screenalytics/apps/api/routers/cast_screentime.py`
- `screenalytics/apps/api/services/cast_screentime.py`
- `screenalytics/apps/api/services/cast_screentime_dispatch.py`
- `screenalytics/apps/api/tasks_cast_screentime.py`
- `screenalytics/apps/api/services/internal_admin_auth.py`
- `screenalytics/apps/api/services/supabase_db.py`
- `screenalytics/apps/api/services/storage.py`
- supporting runtime config under `screenalytics/config/`
- supporting tests under `screenalytics/tests/api/test_cast_screentime_internal.py`, `screenalytics/tests/unit/test_internal_admin_auth.py`, `screenalytics/tests/unit/test_runtime_startup_and_readiness.py`, and related cast-screentime tests

Current code evidence suggests these are no longer required for Backend or App execution, because Backend now owns retained cast-screentime dispatch and analysis.

### Do Not Delete As Part Of A Blind Cleanup

- `screenalytics/.git/`: nested repo history/control directory.
- `screenalytics/.env`: may contain local secrets. Do not print, archive, or delete without an explicit secret-handling decision.
- `screenalytics/data/`: runtime data; not needed by supported TRR startup, but it may contain local artifacts worth archiving first.
- Dirty/deleted nested repo files: `git -C screenalytics status --short` currently reports `60` entries, so cleanup should not assume a clean donor checkout.

## Priority Cleanup Sequence

1. Remove generated local weight first: venvs, `node_modules`, `.next`, caches, logs, and `.DS_Store`.
2. Decide whether the entire adjacent checkout is still needed locally. From supported TRR evidence, Backend and App do not need it.
3. If preserving history, archive or move the whole `screenalytics/` checkout outside the active TRR workspace rather than deleting source subtrees one by one.
4. If removing the old external worker, remove or rename the remaining Screenalytics compatibility wording in Backend only after verifying no deployed worker calls `/internal/screenalytics/cast-screentime/*`.
5. Leave TRR-APP `/screenalytics` route alone unless the product wants to rename the visible workflow; it is app-owned and not tied to the old repo folder.
