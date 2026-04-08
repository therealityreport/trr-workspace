# Architecture

**Analysis Date:** 2026-04-07

## Pattern Overview

**Overall:** Multi-repo workspace with a shared coordination layer and three product repos arranged as system-of-record backend -> analytics worker/api -> presentation/admin UI.

**Key Characteristics:**
- Keep shared contracts upstream. `TRR-Backend/` owns schema, exposed SQL, API shape, and service-to-service auth. `screenalytics/` consumes those contracts. `TRR-APP/` consumes both through UI-safe server boundaries.
- Split runtime concerns by repo. `TRR-Backend/api/main.py` is the canonical API surface, `screenalytics/apps/api/main.py` and `screenalytics/apps/workspace-ui/streamlit_app.py` run analytics operations, and `TRR-APP/apps/web/src/app/` renders public and admin experiences.
- Use workspace-level automation for cross-repo bootstrapping, environment checks, Chrome/MCP management, and handoff flow in `scripts/` and `docs/`.

## Layers

**Workspace Coordination Layer:**
- Purpose: Own shared workflow, local runtime scripts, planning artifacts, and cross-repo policy.
- Location: `/Users/thomashulihan/Projects/TRR/scripts`, `/Users/thomashulihan/Projects/TRR/docs`, `/Users/thomashulihan/Projects/TRR/.planning`
- Contains: bootstrap scripts, doctor/preflight helpers, Chrome/MCP wrappers, workflow docs, planning outputs.
- Depends on: repo-local commands and env contracts.
- Used by: all repos during local development, verification, and cross-repo handoff.

**TRR Core Backend Layer:**
- Purpose: Serve canonical TRR data, admin endpoints, realtime hooks, and shared SQL-backed domain operations.
- Location: `/Users/thomashulihan/Projects/TRR/TRR-Backend/api`, `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend`, `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase`
- Contains: FastAPI routers, auth dependencies, repositories, integrations, media services, pipeline helpers, SQL migrations.
- Depends on: Postgres/Supabase through `TRR-Backend/trr_backend/db/connection.py` and `TRR-Backend/trr_backend/db/session.py`.
- Used by: `TRR-APP/` via `TRR_API_URL`, `screenalytics/` via shared DB access and service-token routes, and backend scripts in `TRR-Backend/scripts/`.

**Screenalytics Processing Layer:**
- Purpose: Run episode-processing pipelines, expose analytics APIs, persist operational state, and provide operator UI.
- Location: `/Users/thomashulihan/Projects/TRR/screenalytics/apps/api`, `/Users/thomashulihan/Projects/TRR/screenalytics/packages/py-screenalytics/src/py_screenalytics`, `/Users/thomashulihan/Projects/TRR/screenalytics/apps/workspace-ui`, `/Users/thomashulihan/Projects/TRR/screenalytics/tools`
- Contains: FastAPI routers and services, Streamlit pages, CLI pipeline runner, reusable ML/audio/pipeline package, YAML pipeline config.
- Depends on: TRR shared database through `screenalytics/apps/api/services/supabase_db.py`, TRR backend HTTP through `screenalytics/apps/api/services/trr_ingest.py`, local/object storage through `screenalytics/apps/api/services/storage.py`.
- Used by: backend screentime flows, operators in Streamlit, and the optional `screenalytics/web` Next.js app.

**TRR App Presentation Layer:**
- Purpose: Render public site, admin tools, survey/games UX, and Next.js route handlers that proxy or reshape backend data.
- Location: `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app`, `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/components`, `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib`
- Contains: App Router pages, API route handlers, admin UI components, auth helpers, route caches, direct Postgres/Supabase server utilities.
- Depends on: `TRR-Backend/` through `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts` and `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts`, Firebase/Supabase auth in `TRR-APP/apps/web/src/lib/server/auth.ts`, and direct DB access in `TRR-APP/apps/web/src/lib/server/postgres.ts`.
- Used by: public users, admin operators, and automated Next.js route consumers.

## Data Flow

**Admin Read Flow (TRR-APP -> TRR-Backend):**

1. Admin pages under `TRR-APP/apps/web/src/app/admin/**` call local Next route handlers in `TRR-APP/apps/web/src/app/api/admin/**`.
2. Route handlers authenticate with `TRR-APP/apps/web/src/lib/server/auth.ts`, then proxy to backend routes through `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts`.
3. The proxy builds internal-admin headers in `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts` and resolves the canonical `/api/v1` base in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.
4. `TRR-Backend/api/main.py` dispatches to feature routers in `TRR-Backend/api/routers/`, which call repositories and services under `TRR-Backend/trr_backend/`.
5. Responses may be cached per user in `TRR-APP/apps/web/src/lib/server/admin/route-response-cache.ts` before returning to the browser.

**Screenalytics Ingest and Run-State Flow (screenalytics <-> TRR-Backend):**

1. Screenalytics services read TRR metadata directly from the shared database via `screenalytics/apps/api/services/supabase_db.py` and `screenalytics/apps/api/services/trr_ingest.py`.
2. When HTTP integration is required, Screenalytics calls backend service-to-service routes under `TRR-Backend/api/routers/screenalytics.py` and `TRR-Backend/api/routers/screenalytics_runs_v2.py`.
3. Backend protects those routes with `TRR-Backend/api/screenalytics_auth.py`, accepting `SCREENALYTICS_SERVICE_TOKEN` or the internal admin token contract.
4. Run records, artifacts, and metrics are persisted through backend repository code in `TRR-Backend/trr_backend/repositories/screenalytics_runs.py` and screenalytics API services in `screenalytics/apps/api/services/run_persistence.py`, `screenalytics/apps/api/services/runs_v2.py`, and related modules.

**Episode Pipeline Execution Flow (screenalytics CLI/API/UI):**

1. Operators start work from `screenalytics/apps/workspace-ui/streamlit_app.py`, `screenalytics/apps/api/routers/jobs.py`, `screenalytics/apps/api/routers/runs.py`, or `screenalytics/tools/episode_run.py`.
2. Shared orchestration logic in `screenalytics/apps/api/services/pipeline_orchestration.py` and `screenalytics/packages/py-screenalytics/src/py_screenalytics/pipeline/episode_engine.py` normalizes stage order and run metadata.
3. The reusable pipeline package reads YAML config from `screenalytics/config/pipeline/*.yaml`, stores artifacts/manifests through `screenalytics/apps/api/services/storage.py`, and writes run-scoped status via `py_screenalytics` helpers.
4. The API and UI read that persisted state back through services such as `screenalytics/apps/api/services/run_state.py`, `screenalytics/apps/api/services/storage_v2.py`, and page modules under `screenalytics/apps/workspace-ui/pages/`.

**State Management:**
- Shared business state is persisted in Postgres/Supabase. Backend migrations live in `TRR-Backend/supabase/migrations/`.
- TRR app uses short-lived in-memory caching only for server route dedupe and response caching in `TRR-APP/apps/web/src/lib/server/admin/route-response-cache.ts`.
- Screenalytics combines DB state with filesystem/object-storage artifacts via `screenalytics/apps/api/services/storage.py` and `py_screenalytics.artifacts`.
- Long-running backend ownership is switched by environment flags in `TRR-Backend/trr_backend/job_plane.py`.

## Key Abstractions

**Backend Router -> Repository -> DB Pattern:**
- Purpose: Keep FastAPI route modules thin and move SQL/data access into reusable backend modules.
- Examples: `TRR-Backend/api/routers/admin_show_reads.py`, `TRR-Backend/trr_backend/repositories/admin_show_reads.py`, `TRR-Backend/trr_backend/db/session.py`
- Pattern: routers validate/authenticate, repositories query or mutate, DB session provides a Supabase-like query facade over psycopg2.

**Next Server Proxy Pattern:**
- Purpose: Keep secrets and backend topology out of the browser while preserving App Router ergonomics.
- Examples: `TRR-APP/apps/web/src/app/api/admin/trr-api/shows/route.ts`, `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts`, `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`
- Pattern: page/component -> local route handler -> authenticated backend fetch -> optional response cache -> browser JSON.

**Screenalytics Shared Pipeline Package:**
- Purpose: Centralize ML/audio/pipeline logic outside the API and UI entrypoints.
- Examples: `screenalytics/packages/py-screenalytics/src/py_screenalytics/pipeline/episode_engine.py`, `screenalytics/packages/py-screenalytics/src/py_screenalytics/audio/episode_audio_pipeline.py`, `screenalytics/tools/episode_run.py`
- Pattern: thin entrypoint shells call a repo-local package so the same stage logic is reusable from CLI, API, and Streamlit.

**Shared DB Lane Validation:**
- Purpose: Enforce the same session-pooler runtime policy across backend, analytics, and app server code.
- Examples: `TRR-Backend/trr_backend/db/connection.py`, `screenalytics/apps/api/services/supabase_db.py`, `TRR-APP/apps/web/src/lib/server/postgres.ts`
- Pattern: resolve `TRR_DB_URL` first, allow `TRR_DB_FALLBACK_URL`, reject direct or transaction-pooler lanes in deployed/runtime-sensitive code.

## Entry Points

**Workspace Dev and Policy Entry:**
- Location: `/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh`, `/Users/thomashulihan/Projects/TRR/scripts/preflight.sh`, `/Users/thomashulihan/Projects/TRR/AGENTS.md`
- Triggers: local workspace startup, shared validation, agent workflow.
- Responsibilities: boot repos in the correct order, enforce workspace env/policy, expose shared helpers.

**TRR Backend API:**
- Location: `/Users/thomashulihan/Projects/TRR/TRR-Backend/api/main.py`
- Triggers: `uvicorn api.main:app`, backend tests, consumers using `TRR_API_URL`.
- Responsibilities: app startup validation, middleware, router registration, health/readiness, realtime broker lifecycle.

**TRR Backend Schema Layer:**
- Location: `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations`, `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/config.toml`
- Triggers: Supabase CLI and migration workflow.
- Responsibilities: evolve canonical database structure and exported SQL views.

**Screenalytics API:**
- Location: `/Users/thomashulihan/Projects/TRR/screenalytics/apps/api/main.py`
- Triggers: API server startup for analytics operations.
- Responsibilities: CORS, observability, router wiring, optional Celery/V2 endpoints, startup cleanup.

**Screenalytics Workspace UI:**
- Location: `/Users/thomashulihan/Projects/TRR/screenalytics/apps/workspace-ui/streamlit_app.py`
- Triggers: Streamlit startup.
- Responsibilities: initialize page config and route operators into page modules under `screenalytics/apps/workspace-ui/pages/`.

**Screenalytics CLI Runner:**
- Location: `/Users/thomashulihan/Projects/TRR/screenalytics/tools/episode_run.py`
- Triggers: direct CLI execution for dev or manual pipeline runs.
- Responsibilities: prepare import path, apply CPU limits, resolve YAML config, invoke package-level pipeline code.

**TRR App Web Entry:**
- Location: `/Users/thomashulihan/Projects/TRR/TRR-APP/package.json`, `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app/layout.tsx`
- Triggers: `pnpm` workspace scripts, Next.js runtime.
- Responsibilities: start web dev/build flows, attach global styles/providers, mount App Router pages and route handlers.

## Error Handling

**Strategy:** Fail fast on invalid environment or lane selection, convert cross-service failures into typed HTTP responses, and keep long-running pipeline state resumable.

**Patterns:**
- Backend startup validates DB/auth/runtime conditions in `TRR-Backend/api/main.py` before serving traffic.
- TRR app wraps backend fetch failures with `AdminReadProxyError` in `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts`.
- Screenalytics API installs centralized FastAPI error handlers from `screenalytics/apps/api/errors.py` and records run-stage state transitions in orchestration services instead of dropping failures.

## Cross-Cutting Concerns

**Logging:** Backend and Screenalytics both add request/trace middleware in `TRR-Backend/api/main.py` and `screenalytics/apps/api/main.py`. Runtime observability helpers live in `TRR-Backend/trr_backend/observability.py` and `screenalytics/apps/api/services/observability.py`.

**Validation:** Route payloads use Pydantic models in files such as `TRR-Backend/api/routers/screenalytics_runs_v2.py` and `screenalytics/apps/api/schemas/job_params.py`. Runtime env and lane validation live in `TRR-Backend/trr_backend/db/connection.py`, `screenalytics/apps/api/services/supabase_db.py`, and `TRR-APP/apps/web/src/lib/server/postgres.ts`.

**Authentication:** TRR app authenticates admins in `TRR-APP/apps/web/src/lib/server/auth.ts`. Backend protects internal admin and Screenalytics service routes in `TRR-Backend/api/auth.py`, `TRR-Backend/api/screenalytics_auth.py`, and `TRR-Backend/trr_backend/security/internal_admin.py`. Browser auth providers stay behind Next server boundaries.

---

*Architecture analysis: 2026-04-07*
