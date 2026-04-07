# TRR Workspace Architecture Map

Updated from workspace scan on 2026-04-07.

## High-Level Shape

The workspace is a multi-repo system with one domain model shared across three execution surfaces:

1. `TRR-Backend/` owns schema, API contracts, media ingestion, and most canonical reads/writes.
2. `screenalytics/` owns video/audio/vision processing plus operational data under the same broader TRR domain.
3. `TRR-APP/` owns public UI, admin UI, server-side adapters, and selected direct data access for app workflows.

The workspace `AGENTS.md` makes this ownership explicit and requires backend-first ordering for shared contract changes.

## Primary Entry Points

### Backend

- FastAPI app bootstrap: `TRR-Backend/api/main.py`
- Realtime broker lifecycle: `TRR-Backend/api/realtime/broker.py`
- Router surface: `TRR-Backend/api/routers/*.py`
- CLI entry: `TRR-Backend/trr_backend/cli/__main__.py`

### screenalytics

- FastAPI bootstrap: `screenalytics/apps/api/main.py`
- Streamlit bootstrap: `screenalytics/apps/workspace-ui/streamlit_app.py`
- Celery tasks and async jobs:
  - `screenalytics/apps/api/tasks.py`
  - `screenalytics/apps/api/tasks_cast_screentime.py`
  - `screenalytics/apps/api/tasks_v2.py`

### Frontend

- Next App Router surface: `TRR-APP/apps/web/src/app/`
- App-side server adapters: `TRR-APP/apps/web/src/lib/server/`
- API route surface: `TRR-APP/apps/web/src/app/api/`
- Secondary Vue app: `TRR-APP/apps/vue-wordle/`

## Layering Patterns

### TRR-Backend

Observed layering is relatively consistent:

- `api/routers/` handles HTTP endpoints and request/response shaping
- `trr_backend/repositories/` contains DB-backed domain reads/writes
- `trr_backend/services/` contains orchestration and background/runtime logic
- `trr_backend/integrations/` contains third-party adapters
- `trr_backend/media/` owns object-storage and asset transformation flows
- `trr_backend/security/` owns JWT and internal-admin verification
- `trr_backend/db/` owns connection rules, pool policy, and DB preflight

This is not a fully strict clean architecture, but the repository/service split is strong enough to use as a planning anchor.

### screenalytics

screenalytics uses an app-and-services architecture:

- `apps/api/routers/` defines endpoint surfaces
- `apps/api/services/` carries most business logic
- `apps/api/config/` centralizes runtime settings
- `packages/py-screenalytics/src/py_screenalytics/` contains reusable lower-level pipeline code
- `tools/` and config YAMLs drive CLI and batch workflows

The API and Streamlit UI both sit on top of the same Python codebase rather than calling out to separate services for every action.

### TRR-APP

TRR-APP uses the standard Next App Router split, plus a deliberate server-boundary layer:

- route tree in `src/app/`
- interactive UI in `src/components/`
- shared utilities in `src/lib/`
- server-only adapters in `src/lib/server/`
- app-owned DB/auth adapters in `src/lib/server/postgres.ts`, `src/lib/server/auth.ts`, and `src/lib/server/trr-api/*`

This keeps most network and privileged logic out of client components.

## Cross-Repo Data Flow

### Public/admin app reads

Common path:

1. request enters `TRR-APP/apps/web/src/app/`
2. server component or route handler calls a module in `TRR-APP/apps/web/src/lib/server/`
3. that module either:
   - calls `TRR-Backend` via normalized `TRR_API_URL`, or
   - performs app-local DB/admin reads via Supabase/Postgres
4. response is rendered by server components or passed to client components

### screenalytics operational flow

Common path:

1. API or Streamlit action enters screenalytics
2. service layer loads pipeline state from local manifests, object storage, Redis, or Postgres
3. ML/pipeline code in `packages/py-screenalytics` or `tools/` runs
4. operational state is written back to Postgres/object storage
5. for selected flows, backend is updated through authenticated HTTP callbacks using `SCREENALYTICS_SERVICE_TOKEN`

### Backend canonical write flow

Common path:

1. request enters `TRR-Backend/api/routers/*`
2. router validates auth/runtime assumptions
3. repository/service writes to Supabase/Postgres and optional object storage
4. downstream consumers in `screenalytics` and `TRR-APP` depend on the updated contract

## Database Ownership and Schema Model

- Canonical migrations live in `TRR-Backend/supabase/migrations/`
- Generated schema reference lives in `TRR-Backend/supabase/schema_docs/`
- screenalytics is intentionally coupled to the same TRR-compatible Postgres through `TRR_DB_URL`
- the app occasionally reads/writes directly for app-admin flows, but backend remains contract owner

This is a shared-database, multi-application architecture rather than separate service databases.

## Async and Background Work

- Backend startup wires background maintenance in `TRR-Backend/api/main.py`
- screenalytics exposes optional Celery-driven async work
- frontend schedules recurring HTTP work through Vercel cron endpoints in `TRR-APP/apps/web/vercel.json`
- operational pipelines also exist as Python CLI or tools-based flows in `screenalytics/tools/` and `TRR-Backend/scripts/`

## Caching and State Models

- Backend request/runtime metrics and trace binding live in `TRR-Backend/trr_backend/observability.py`
- screenalytics uses Redis, local artifact manifests, and object storage as runtime state layers
- app-side route caches and memoized proxy helpers exist under:
  - `TRR-APP/apps/web/src/lib/server/admin/route-response-cache.ts`
  - `TRR-APP/apps/web/src/lib/server/trr-api/*route-cache*.ts`

## Architectural Boundaries That Matter

- Backend schema/API changes must land before downstream repos
- App must not invent backend response shapes; this is restated in `TRR-APP/AGENTS.md`
- screenalytics must treat backend schema/API as upstream and adapt after backend changes
- internal admin auth is a separate trusted service-to-service path, not the same as public user auth

## Architectural Pressure Points

- Auth is dual-lane in TRR-APP: Firebase user flows and Supabase/admin-backed server flows coexist
- screenalytics mixes local artifact storage, Redis, Celery, object storage, and shared Postgres
- backend router count is large, and several admin routers are wide surfaces with substantial embedded logic
- the frontend route tree is broad, especially under `src/app/admin/`, increasing the cost of route rewrite and auth regressions
