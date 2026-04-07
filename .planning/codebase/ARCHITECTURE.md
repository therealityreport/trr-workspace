# Architecture

**Analysis Date:** 2026-04-04

## Pattern Overview

**Overall:** Brownfield multi-repo workspace with a root orchestration layer, a Next.js App Router frontend/BFF in `TRR-APP`, a FastAPI + shared-library backend in `TRR-Backend`, and a separate Screenalytics system that combines FastAPI, Streamlit, a reusable Python pipeline package, and an optional Next.js surface.

**Key Characteristics:**
- Use the workspace root as the coordination layer only. Startup, environment validation, handoff sync, and browser/MCP wrappers live in `Makefile`, `scripts/dev-workspace.sh`, `scripts/preflight.sh`, `scripts/status-workspace.sh`, `docs/workspace/dev-commands.md`, and `docs/cross-collab/WORKFLOW.md`.
- Treat `TRR-Backend` as the contract owner. Shared schema, API, auth, and database-lane decisions are implemented first in `TRR-Backend/api/`, `TRR-Backend/trr_backend/`, and `TRR-Backend/supabase/`, then consumed by `screenalytics`, then by `TRR-APP`.
- Treat `TRR-APP` as presentation plus backend-for-frontend. Browser routes live in `TRR-APP/apps/web/src/app/`, but many admin reads and writes are mediated through server-only modules in `TRR-APP/apps/web/src/lib/server/`.
- Treat `screenalytics` as a subsystem, not a shared contract source. Its API in `screenalytics/apps/api/` consumes TRR-owned metadata and shared DB contracts through `screenalytics/apps/api/services/supabase_db.py`, `screenalytics/apps/api/services/trr_metadata_db.py`, and `screenalytics/apps/api/services/trr_ingest.py`.
- Keep processing logic out of HTTP/UI layers. Reusable Screenalytics runtime code is concentrated under `screenalytics/packages/py-screenalytics/src/py_screenalytics/`, and reusable backend domain code is concentrated under `TRR-Backend/trr_backend/`.

## Cross-Repo Boundaries

**Workspace Coordination Boundary:**
- Root files coordinate repos but do not own product-domain logic.
- Use `Makefile` and `scripts/dev-workspace.sh` to start repos together.
- Use `docs/workspace/env-contract.md` and `scripts/workspace-env-contract.sh` as the cross-repo env contract reference.

**Backend Ownership Boundary:**
- `TRR-Backend` owns the canonical API entrypoint in `TRR-Backend/api/main.py`.
- `TRR-Backend` owns schema/migration state in `TRR-Backend/supabase/migrations/`.
- `screenalytics` and `TRR-APP` should consume backend contracts rather than redefine them.

**Frontend Boundary:**
- `TRR-APP` owns public/admin UI and request normalization, not the underlying domain contracts.
- Backend URLs are derived from `TRR_API_URL` in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.
- Internal admin hops are wrapped in `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts` and `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts`.

**Screenalytics Boundary:**
- `screenalytics` owns video-analysis pipelines, run/job orchestration, operator review flows, and artifact conventions.
- `screenalytics` reads TRR-owned metadata from `core.*` via `screenalytics/apps/api/services/trr_metadata_db.py` and imports TRR data through `screenalytics/apps/api/services/trr_ingest.py`.
- `screenalytics` does not own the shared TRR schema contract; it adapts after backend changes.

## Layers

**Workspace Orchestration Layer:**
- Purpose: Start, stop, validate, and coordinate all repos in one developer workflow.
- Location: `Makefile`, `scripts/`, `profiles/`, `docs/workspace/`, `docs/cross-collab/`.
- Contains: startup profiles, cloud-first vs local-docker modes, handoff sync, policy checks, browser tooling, and env-contract generation.
- Depends on: repo-local runtimes in `TRR-APP/`, `TRR-Backend/`, and `screenalytics/`.
- Used by: every multi-repo task, verification run, and local workspace session.

**TRR-APP Presentation + BFF Layer:**
- Purpose: Render public/admin UI and expose App Router handlers that proxy or compose server-side data access.
- Location: `TRR-APP/apps/web/src/app/`, `TRR-APP/apps/web/src/components/`, `TRR-APP/apps/web/src/lib/server/`.
- Contains: layouts/pages, route handlers, client components, auth/session routes, admin navigation, and proxy helpers.
- Depends on: `TRR-Backend` through `TRR_API_URL`, Firebase in `TRR-APP/apps/web/src/lib/firebase*.ts`, and direct DB/Supabase helpers in `TRR-APP/apps/web/src/lib/server/postgres.ts` and `TRR-APP/apps/web/src/lib/server/supabase-trr-admin.ts`.
- Used by: browser users, admins, cron routes, and internal server-side fetches.

**TRR-Backend API Layer:**
- Purpose: Publish the canonical TRR HTTP surface, realtime surface, auth checks, and service-to-service endpoints.
- Location: `TRR-Backend/api/main.py`, `TRR-Backend/api/routers/`, `TRR-Backend/api/auth.py`, `TRR-Backend/api/screenalytics_auth.py`, `TRR-Backend/api/realtime/`.
- Contains: FastAPI app setup, startup validation, observability middleware, router registration, request timeout middleware, and realtime broker lifecycle.
- Depends on: `TRR-Backend/trr_backend/` modules and runtime DB resolution in `TRR-Backend/trr_backend/db/connection.py`.
- Used by: `TRR-APP`, `screenalytics`, scripts, and ops tooling.

**TRR-Backend Domain + Persistence Layer:**
- Purpose: Centralize data access, domain services, external integrations, and backend-internal clients behind stable modules.
- Location: `TRR-Backend/trr_backend/db/`, `TRR-Backend/trr_backend/repositories/`, `TRR-Backend/trr_backend/services/`, `TRR-Backend/trr_backend/clients/`, `TRR-Backend/trr_backend/security/`, `TRR-Backend/trr_backend/integrations/`.
- Contains: pooled DB access, typed security helpers, repository modules per domain, media/social services, Screenalytics client code, and pipeline support.
- Depends on: Postgres/Supabase, external providers, and object-storage/runtime configuration.
- Used by: FastAPI routers, CLI entrypoints, and repo-local scripts.

**TRR-Backend Pipeline/CLI Layer:**
- Purpose: Execute resumable ingestion and synchronization flows outside the HTTP request path.
- Location: `TRR-Backend/trr_backend/cli/`, `TRR-Backend/trr_backend/pipeline/`, `TRR-Backend/scripts/`.
- Contains: Typer CLI entrypoints, sequential stage orchestration, run metadata persistence, manifest writing, and many sync/backfill scripts.
- Depends on: domain/persistence modules and schema objects in `pipeline.*` and `core.*`.
- Used by: local operators, batch jobs, and recovery flows.

**Screenalytics API + Jobs Layer:**
- Purpose: Expose processing endpoints, orchestrate setup and analysis runs, and persist Screenalytics run state.
- Location: `screenalytics/apps/api/main.py`, `screenalytics/apps/api/routers/`, `screenalytics/apps/api/services/`, `screenalytics/apps/api/tasks*.py`.
- Contains: FastAPI app setup, router registration, optional Celery integration, pipeline orchestration services, storage helpers, TRR ingest adapters, and V2 video-asset routes.
- Depends on: DB lane resolution in `screenalytics/apps/api/services/supabase_db.py`, reusable runtime code in `screenalytics/packages/py-screenalytics/src/py_screenalytics/`, and TRR-owned metadata.
- Used by: Streamlit workspace UI, the optional Next.js `screenalytics/web/` app, background workers, and local tooling.

**Screenalytics Operator UI Layer:**
- Purpose: Provide internal review and operational workflows for upload, runs, faces, cast, screentime, health, and docs.
- Location: `screenalytics/apps/workspace-ui/streamlit_app.py`, `screenalytics/apps/workspace-ui/pages/`, `screenalytics/apps/workspace-ui/components/`.
- Contains: a single Streamlit entrypoint, numbered multipage screens, workspace helpers, and review widgets.
- Depends on: `screenalytics/apps/api/` and helper logic in `py_screenalytics.workspace_ui`.
- Used by: operators, reviewers, and local development workflows.

**Screenalytics Reusable Pipeline Library Layer:**
- Purpose: Isolate artifact contracts, stage plans, runtime helpers, and ML/pipeline logic from the API/UI surfaces.
- Location: `screenalytics/packages/py-screenalytics/src/py_screenalytics/`.
- Contains: pipeline stages, run layout, run manifests, audio modules, reporting modules, config resolution, and workspace-ui helper logic.
- Depends on: configuration under `screenalytics/config/pipeline/` and artifact roots under `SCREENALYTICS_DATA_ROOT`.
- Used by: `screenalytics/apps/api/`, `screenalytics/tools/episode_run.py`, tests, and Streamlit pages.

**Screenalytics Web Prototype Layer:**
- Purpose: Provide a Next.js-based Screenalytics UI separate from the Streamlit workspace.
- Location: `screenalytics/web/app/`, `screenalytics/web/components/`, `screenalytics/web/api/`, `screenalytics/web/lib/`.
- Contains: app routes, React Query providers, generated API client helpers, and UI components.
- Depends on: `screenalytics/apps/api/` through local `/api` routes and generated schema/types in `screenalytics/web/api/`.
- Used by: optional local/operator workflows. It is not the primary pipeline entry surface.

## Data Flow

**Public/Admin Request Flow (`TRR-APP` -> `TRR-Backend`):**

1. A route under `TRR-APP/apps/web/src/app/` renders a page or handles a request.
2. Server-only code under `TRR-APP/apps/web/src/lib/server/` or `TRR-APP/apps/web/src/app/api/**/route.ts` prepares an upstream request.
3. Backend URLs are normalized through `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, which forces a `/api/v1` base.
4. Admin requests pass through helpers such as `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts`, which adds internal auth headers from `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`.
5. `TRR-Backend/api/main.py` dispatches to a router in `TRR-Backend/api/routers/`.
6. Router modules call repositories/services in `TRR-Backend/trr_backend/`.
7. Repositories hit the shared database through `TRR-Backend/trr_backend/db/`.
8. JSON responses are returned to the page, route handler, or client component for rendering.

**Backend Ingestion/Batch Flow (`TRR-Backend` scripts/CLI -> DB):**

1. An operator invokes `TRR-Backend/scripts/**` or `python -m trr_backend.cli pipeline ...`.
2. CLI code in `TRR-Backend/trr_backend/cli/` constructs a run config.
3. `TRR-Backend/trr_backend/pipeline/orchestrator.py` records run/stage state and executes stage functions sequentially.
4. Domain modules in `TRR-Backend/trr_backend/repositories/`, `services/`, and `integrations/` fetch external data and write to `core.*` or `pipeline.*`.
5. Manifest files are written via `TRR-Backend/trr_backend/pipeline/manifests.py`.

**Screenalytics Run Flow (`screenalytics` UI/API -> pipeline package -> DB/artifacts):**

1. A Streamlit page in `screenalytics/apps/workspace-ui/pages/` or a Next.js page in `screenalytics/web/app/` triggers an API call.
2. `screenalytics/apps/api/main.py` routes the request to a module under `screenalytics/apps/api/routers/`.
3. Router modules delegate to services such as `screenalytics/apps/api/services/pipeline_orchestration.py`, `run_state.py`, `runs_v2.py`, or `storage.py`.
4. Reusable stage plans and artifact contracts are resolved from `screenalytics/packages/py-screenalytics/src/py_screenalytics/`.
5. Operational state is stored in the shared database through `screenalytics/apps/api/services/supabase_db.py` and related services.
6. Artifacts and manifests are written under `SCREENALYTICS_DATA_ROOT` using layout helpers from `py_screenalytics.run_layout` and `py_screenalytics.artifacts`.

**TRR Metadata Consumption Flow (`screenalytics` -> TRR data):**

1. `screenalytics/apps/api/services/trr_metadata_db.py` reads canonical metadata from `core.shows`, `core.seasons`, `core.episodes`, and `core.people`.
2. `screenalytics/apps/api/services/trr_ingest.py` imports cast/photo data either directly from the DB or, for legacy paths, over HTTP using `TRR_API_URL` plus `SCREENALYTICS_SERVICE_TOKEN`.
3. Imported TRR metadata is converted into Screenalytics-specific operational records such as facebank seeds, candidate-cast snapshots, and run-scoped assignments.

**State Management:**
- `TRR-APP` uses App Router server rendering for most data-fetching, with client state added selectively in client-marked components such as `TRR-APP/apps/web/src/app/page.tsx` and provider wrappers like `TRR-APP/apps/web/src/components/SideMenuProvider.tsx`.
- `TRR-Backend` keeps request state mostly stateless per request, with shared runtime state limited to observability, DB pools, and realtime broker lifecycle in `TRR-Backend/api/realtime/`.
- `screenalytics` persists long-running run state in services such as `screenalytics/apps/api/services/run_state.py` and complements it with filesystem/object-storage artifacts managed by `py_screenalytics`.

## Key Abstractions

**Backend Base Normalization:**
- Purpose: Guarantee that app-side server fetches always target the canonical backend base path.
- Examples: `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.
- Pattern: small server-only URL normalizer used by many route handlers and repositories.

**Internal Admin Proxy:**
- Purpose: Centralize admin request timeouts, retries, error normalization, and internal-auth header generation.
- Examples: `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts`, `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`.
- Pattern: BFF proxy wrapper around backend requests with typed proxy errors.

**Runtime DB Lane Resolution:**
- Purpose: Keep every repo on the same `TRR_DB_URL` / `TRR_DB_FALLBACK_URL` contract and reject unsupported database lanes.
- Examples: `TRR-Backend/trr_backend/db/connection.py`, `TRR-APP/apps/web/src/lib/server/postgres.ts`, `screenalytics/apps/api/services/supabase_db.py`.
- Pattern: repo-local resolver with the same source precedence and session-pooler policy.

**Backend Repository/Service Split:**
- Purpose: Separate HTTP router modules from persistence and business logic.
- Examples: `TRR-Backend/api/routers/admin_cast_screentime.py`, `TRR-Backend/trr_backend/repositories/cast_screentime.py`, `TRR-Backend/trr_backend/services/retained_cast_screentime_runtime.py`.
- Pattern: router -> repository/service -> DB/helpers.

**Pipeline Orchestrator:**
- Purpose: Run resumable stage pipelines with manifest-backed progress and skip-by-hash behavior.
- Examples: `TRR-Backend/trr_backend/pipeline/orchestrator.py`, `TRR-Backend/trr_backend/pipeline/repository.py`, `TRR-Backend/trr_backend/pipeline/models.py`.
- Pattern: sequential orchestrator object with persisted run/stage metadata.

**Screenalytics Setup Orchestration:**
- Purpose: Advance multi-stage run setup across detect, embed, cluster, and follow-on stages.
- Examples: `screenalytics/apps/api/services/pipeline_orchestration.py`, `screenalytics/packages/py-screenalytics/src/py_screenalytics/pipeline_stages.py`.
- Pattern: normalized stage aliases plus persisted orchestration state and next-stage transitions.

**Artifact Layout Contract:**
- Purpose: Keep filesystem/object-storage outputs in predictable, stage-aware locations.
- Examples: `screenalytics/packages/py-screenalytics/src/py_screenalytics/run_layout.py`, `screenalytics/packages/py-screenalytics/src/py_screenalytics/artifacts.py`, `screenalytics/tools/episode_run.py`.
- Pattern: shared path/layout helpers reused by API, CLI, and tests.

## Entry Points

**Workspace Startup:**
- Location: `Makefile`, `scripts/dev-workspace.sh`, `scripts/preflight.sh`.
- Triggers: `make dev`, `make dev-local`, `make preflight`, `make status`.
- Responsibilities: select a workspace profile, start repo-local processes, run preflight checks, and expose health/status.

**TRR Backend HTTP Server:**
- Location: `TRR-Backend/api/main.py`.
- Triggers: `uvicorn api.main:app`.
- Responsibilities: validate startup config, prewarm DB pool, initialize realtime broker, register routers, and export metrics.

**TRR Backend CLI:**
- Location: `TRR-Backend/trr_backend/cli/__main__.py`, `TRR-Backend/trr_backend/cli/pipeline.py`.
- Triggers: `python -m trr_backend.cli ...`.
- Responsibilities: batch execution, pipeline runs, and operator-facing CLI workflows.

**TRR App HTTP Surface:**
- Location: `TRR-APP/apps/web/src/app/layout.tsx`, `TRR-APP/apps/web/src/app/page.tsx`, `TRR-APP/apps/web/src/app/api/**/route.ts`.
- Triggers: `next dev`, `next build`, browser navigation, cron hooks, and admin API requests.
- Responsibilities: render pages, host route handlers, and proxy/admin orchestration.

**Screenalytics API:**
- Location: `screenalytics/apps/api/main.py`.
- Triggers: `uvicorn apps.api.main:app`.
- Responsibilities: load env and CPU caps early, register routers, expose health/metrics, and optionally register Celery routes.

**Screenalytics Streamlit Workspace:**
- Location: `screenalytics/apps/workspace-ui/streamlit_app.py`.
- Triggers: `streamlit run screenalytics/apps/workspace-ui/streamlit_app.py`.
- Responsibilities: initialize page config first, expose multipage navigation, and front operator tools.

**Screenalytics CLI/Tooling:**
- Location: `screenalytics/tools/episode_run.py`.
- Triggers: direct CLI execution for episode pipeline runs.
- Responsibilities: set runtime guards, load shared configs, and invoke reusable pipeline code.

**Screenalytics Web Prototype:**
- Location: `screenalytics/web/app/layout.tsx`, `screenalytics/web/app/page.tsx`, `screenalytics/web/app/screenalytics/page.tsx`.
- Triggers: `cd screenalytics/web && npm run dev`.
- Responsibilities: provide an optional Next.js operator UI backed by the Screenalytics API.

## Error Handling

**Strategy:** Fail fast on invalid runtime configuration, normalize upstream/proxy failures into typed responses, and preserve long-running run state across retries and restarts.

**Patterns:**
- `TRR-Backend/api/main.py` validates required auth and DB env at startup and refuses unsupported DB connection classes.
- `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts` converts timeouts and fetch failures into `AdminReadProxyError` with retryable metadata.
- `screenalytics/apps/api/main.py` conditionally mounts Celery routes and exposes a 503 stub when Celery dependencies are unavailable.
- `screenalytics/apps/api/services/pipeline_orchestration.py` updates persisted orchestration state instead of relying on in-memory stage progress.
- Streamlit and CLI entrypoints load env and runtime guards before heavy imports so failure modes are early and actionable.

## Cross-Cutting Concerns

**Logging:** Structured request/runtime logging and metrics live in `TRR-Backend/trr_backend/observability.py` and `screenalytics/apps/api/services/observability.py`; workspace scripts expose status and logs through `scripts/status-workspace.sh` and `scripts/logs-workspace.sh`.

**Validation:** Runtime DB-lane validation is duplicated intentionally per repo in `TRR-Backend/trr_backend/db/connection.py`, `TRR-APP/apps/web/src/lib/server/postgres.ts`, and `screenalytics/apps/api/services/supabase_db.py`. Route and payload validation use FastAPI/Pydantic in backend/screenalytics and TypeScript types in `TRR-APP`.

**Authentication:** `TRR-APP` handles browser auth in `TRR-APP/apps/web/src/lib/server/auth.ts` and Firebase helpers, then uses internal admin headers for backend hops. `TRR-Backend` enforces admin/service auth in `api/auth.py` and `api/screenalytics_auth.py`. `screenalytics` uses service tokens or shared DB access for TRR integration, not browser auth.

---

*Architecture analysis: 2026-04-04*
