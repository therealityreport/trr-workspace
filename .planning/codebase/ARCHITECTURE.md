# Architecture

**Analysis Date:** 2026-04-04

## Pattern Overview

**Overall:** Multi-repo workspace with a root orchestration layer, a Next.js App Router frontend/BFF, a FastAPI backend for TRR domain data, and a separate FastAPI + Streamlit Screenalytics system for video-analysis workflows.

**Key Characteristics:**
- Workspace startup, policy checks, handoff sync, and browser automation are centralized at the root in `Makefile`, `scripts/dev-workspace.sh`, `scripts/preflight.sh`, `docs/workspace/dev-commands.md`, and `docs/workspace/env-contract.md`.
- `TRR-APP` behaves as both UI and backend-for-frontend: page routes live under `TRR-APP/apps/web/src/app/`, and many admin/data routes proxy to `TRR-Backend` through `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.
- `TRR-Backend` owns shared contracts first: FastAPI routers in `TRR-Backend/api/routers/` call repository and service code in `TRR-Backend/trr_backend/`, while schema state and migrations live in `TRR-Backend/supabase/`.
- `screenalytics` is split into three layers: API surfaces in `screenalytics/apps/api/`, operator UI in `screenalytics/apps/workspace-ui/`, and reusable pipeline/runtime code in `screenalytics/packages/py-screenalytics/src/py_screenalytics/`.
- Cross-repo ordering is explicit in `AGENTS.md` and `docs/cross-collab/WORKFLOW.md`: shared contract changes land in `TRR-Backend` first, then `screenalytics`, then `TRR-APP`.

## Layers

**Workspace Orchestration Layer:**
- Purpose: Start local services, enforce workspace policy, generate env/handoff docs, and coordinate multi-repo development.
- Location: `Makefile`, `scripts/dev-workspace.sh`, `scripts/preflight.sh`, `scripts/workspace-env-contract.sh`, `scripts/status-workspace.sh`, `scripts/check-policy.sh`.
- Contains: profile loading, port/runtime wiring, health checks, generated-doc verification, browser/MCP wrappers, and shared auth-secret derivation for local dev.
- Depends on: repo-local runtimes in `TRR-APP/`, `TRR-Backend/`, and `screenalytics/`, plus generated docs under `docs/workspace/`.
- Used by: local development, preflight validation, multi-repo handoff flow, and policy enforcement.

**TRR-APP Presentation + BFF Layer:**
- Purpose: Render public/admin pages and expose App Router route handlers that normalize access to backend and third-party services.
- Location: `TRR-APP/apps/web/src/app/`, `TRR-APP/apps/web/src/components/`, `TRR-APP/apps/web/src/lib/server/`, `TRR-APP/apps/web/src/lib/server/trr-api/`.
- Contains: App Router pages/layouts, client components, server-only repositories, auth/session routes, and admin proxy routes.
- Depends on: `TRR-Backend` via `TRR_API_URL`, Firebase auth/session helpers in `TRR-APP/apps/web/src/lib/firebase*`, and direct Postgres/Supabase utilities in `TRR-APP/apps/web/src/lib/server/postgres.ts` and `TRR-APP/apps/web/src/lib/supabase/`.
- Used by: browser clients and admin operators.

**TRR-Backend API Layer:**
- Purpose: Own the canonical TRR API, auth boundaries, shared admin endpoints, realtime endpoints, and Screenalytics-facing service endpoints.
- Location: `TRR-Backend/api/main.py`, `TRR-Backend/api/routers/`, `TRR-Backend/api/auth.py`, `TRR-Backend/api/screenalytics_auth.py`.
- Contains: FastAPI app setup, CORS, observability middleware, startup validation, health/metrics endpoints, public routers, admin routers, and service-to-service routers.
- Depends on: domain/persistence code in `TRR-Backend/trr_backend/`, shared DB URL env contracts, and schema objects under `TRR-Backend/supabase/`.
- Used by: `TRR-APP`, `screenalytics`, and direct operational scripts.

**TRR-Backend Domain + Persistence Layer:**
- Purpose: Encapsulate SQL access, integration clients, media/social services, and internal runtime utilities behind stable modules.
- Location: `TRR-Backend/trr_backend/db/`, `TRR-Backend/trr_backend/repositories/`, `TRR-Backend/trr_backend/services/`, `TRR-Backend/trr_backend/clients/`, `TRR-Backend/trr_backend/security/`.
- Contains: `DbSession` abstractions in `TRR-Backend/trr_backend/db/session.py`, pooled DB access in `TRR-Backend/trr_backend/db/pg.py`, repositories per domain object, internal token verification, and feature-specific services.
- Depends on: the shared Postgres/Supabase database and external integrations implemented in `TRR-Backend/trr_backend/integrations/` and `TRR-Backend/trr_backend/socials/`.
- Used by: FastAPI routers and worker/scripts inside `TRR-Backend`.

**Screenalytics API + Jobs Layer:**
- Purpose: Expose video-processing endpoints, manage run/job orchestration, and bridge operational state to shared TRR infrastructure.
- Location: `screenalytics/apps/api/main.py`, `screenalytics/apps/api/routers/`, `screenalytics/apps/api/services/`, `screenalytics/apps/api/tasks*.py`.
- Contains: FastAPI app setup, optional Celery router/task registration, run-state services, storage abstraction, TRR ingest adapters, and V2 pipeline endpoints.
- Depends on: direct Postgres access via `screenalytics/apps/api/services/supabase_db.py`, pipeline library code in `screenalytics/packages/py-screenalytics/src/py_screenalytics/`, and service-to-service calls to `TRR-Backend`.
- Used by: Streamlit UI, background workers, and possibly external API clients in local/dev workflows.

**Screenalytics Operator UI Layer:**
- Purpose: Provide a multi-page Streamlit workspace for upload, review, cast, screentime, and diagnostics flows.
- Location: `screenalytics/apps/workspace-ui/streamlit_app.py`, `screenalytics/apps/workspace-ui/pages/`, `screenalytics/apps/workspace-ui/components/`, `screenalytics/ui_helpers.py`.
- Contains: a single Streamlit entrypoint, numbered page modules, interactive review helpers, and shared UI/session helpers.
- Depends on: `screenalytics/apps/api/` endpoints and reusable workspace helpers under `screenalytics/packages/py-screenalytics/src/py_screenalytics/workspace_ui/`.
- Used by: internal Screenalytics operators.

**Screenalytics Pipeline Library Layer:**
- Purpose: Hold reusable processing logic and artifact/run contracts outside the API layer.
- Location: `screenalytics/packages/py-screenalytics/src/py_screenalytics/`.
- Contains: run layout helpers in `screenalytics/packages/py-screenalytics/src/py_screenalytics/run_layout.py`, stage plans in `screenalytics/packages/py-screenalytics/src/py_screenalytics/pipeline_stages.py`, audio pipeline modules, reporting modules, config resolvers, and artifact contracts.
- Depends on: config files in `screenalytics/config/pipeline/` and runtime storage paths/artifact conventions.
- Used by: `screenalytics/apps/api/`, CLI tools in `screenalytics/tools/`, and tests in `screenalytics/tests/`.

## Data Flow

**Frontend Request Flow (`TRR-APP` -> `TRR-Backend`):**

1. A route under `TRR-APP/apps/web/src/app/` renders a page or a route handler receives a browser request.
2. Server-only modules under `TRR-APP/apps/web/src/lib/server/` or `TRR-APP/apps/web/src/app/api/**/route.ts` build upstream URLs via `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.
3. The request is forwarded to `TRR-Backend/api/main.py` under the `/api/v1` prefix, usually through admin proxy helpers such as `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts` or `TRR-APP/apps/web/src/lib/server/trr-api/social-admin-proxy.ts`.
4. A FastAPI router in `TRR-Backend/api/routers/` invokes repositories/services in `TRR-Backend/trr_backend/`.
5. Data is read or written through `TRR-Backend/trr_backend/db/` and returned to the app route/page for rendering or client mutation responses.

**Admin Authentication Flow (`TRR-APP` -> `TRR-Backend`):**

1. Browser login/session routes in `TRR-APP/apps/web/src/app/api/session/login/route.ts` create the app session cookie.
2. Server-side admin proxy code generates a short-lived internal bearer token in `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`.
3. Backend dependencies in `TRR-Backend/api/auth.py` and `TRR-Backend/api/screenalytics_auth.py` accept allowlisted user JWTs, service-role JWTs, or the signed internal admin token.
4. Backend admin routers continue the request as authenticated internal/admin work without exposing backend-only secrets to the browser.

**Screenalytics Metadata + Run Persistence Flow:**

1. Screenalytics API/services use `screenalytics/apps/api/services/supabase_db.py` to resolve the shared TRR database URL and read/write shared metadata directly.
2. Screenalytics also calls `TRR-Backend` service endpoints in `TRR-Backend/api/routers/screenalytics.py` and `TRR-Backend/api/routers/screenalytics_runs_v2.py` for service-to-service cast/photo/run operations.
3. Authentication is enforced with `SCREENALYTICS_SERVICE_TOKEN` or the shared internal admin token path handled by `TRR-Backend/api/screenalytics_auth.py`.
4. Run status and artifact pointers are normalized in `screenalytics/apps/api/services/run_state.py`, which relies on `screenalytics/packages/py-screenalytics/src/py_screenalytics/run_layout.py` for storage layout.

**Screenalytics Processing Flow:**

1. API routers under `screenalytics/apps/api/routers/` trigger jobs, run state transitions, or review endpoints.
2. Task modules such as `screenalytics/apps/api/tasks_v2.py` and orchestration helpers in `screenalytics/apps/api/services/pipeline_orchestration.py` coordinate stage transitions.
3. Shared stage plans and artifact naming come from `screenalytics/packages/py-screenalytics/src/py_screenalytics/pipeline_stages.py` and `screenalytics/packages/py-screenalytics/src/py_screenalytics/run_layout.py`.
4. Artifacts are persisted through storage/run services in `screenalytics/apps/api/services/storage*.py`, `screenalytics/apps/api/services/run_persistence.py`, and related helpers, then surfaced back through API or Streamlit UI.

**Workspace Startup Flow:**

1. `make dev` in `Makefile` calls `scripts/preflight.sh` and then `scripts/dev-workspace.sh`.
2. `scripts/preflight.sh` validates Node/runtime/db contracts, syncs handoffs, and checks shared policy/docs.
3. `scripts/dev-workspace.sh` loads a profile from `profiles/*.env`, resolves the runtime DB lane, derives local shared secrets when needed, and starts repo-local processes.
4. The default contract keeps `TRR-APP`, `TRR-Backend`, and the Screenalytics API active, while Streamlit/Web UI stay opt-in through workspace env toggles documented in `docs/workspace/env-contract.md`.

**State Management:**
- UI routing state is file-system based in `TRR-APP/apps/web/src/app/`; client state is localized inside client components such as `TRR-APP/apps/web/src/app/page.tsx` and large admin clients under `TRR-APP/apps/web/src/app/admin/`.
- App server state lives in route handlers and server-only repositories under `TRR-APP/apps/web/src/lib/server/`, with session state stored in the `__session` cookie managed by `TRR-APP/apps/web/src/app/api/session/login/route.ts`.
- TRR backend state is intentionally stateless at process level apart from startup hooks, broker/runtime services in `TRR-Backend/api/realtime/`, and DB-backed domain state.
- Screenalytics state is split between DB metadata, filesystem/S3-style artifact layout from `screenalytics/packages/py-screenalytics/src/py_screenalytics/run_layout.py`, and orchestration snapshots managed by `screenalytics/apps/api/services/run_state.py`.

## Key Abstractions

**Backend Router Modules:**
- Purpose: Expose one bounded API surface per domain or admin area.
- Examples: `TRR-Backend/api/routers/shows.py`, `TRR-Backend/api/routers/admin_cast.py`, `TRR-Backend/api/routers/screenalytics_runs_v2.py`.
- Pattern: thin FastAPI routers calling repository/service modules, all mounted from `TRR-Backend/api/main.py` under `/api/v1`.

**Repository Modules:**
- Purpose: Isolate SQL and persistence operations from HTTP-layer code.
- Examples: `TRR-Backend/trr_backend/repositories/shows.py`, `TRR-Backend/trr_backend/repositories/media_assets.py`, `TRR-Backend/trr_backend/repositories/screenalytics_runs.py`.
- Pattern: snake_case modules grouped by domain entity; routers import them directly or through services.

**Server-Only App Proxies:**
- Purpose: Keep backend URLs, auth headers, and admin proxy logic off the client.
- Examples: `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts`, `TRR-APP/apps/web/src/lib/server/trr-api/social-admin-proxy.ts`, `TRR-APP/apps/web/src/lib/server/admin/*.ts`.
- Pattern: `"server-only"` modules consumed by App Router route handlers or server components.

**Internal Admin Token Bridge:**
- Purpose: Allow `TRR-APP` and trusted services to call backend admin routes without passing browser-only credentials directly.
- Examples: `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`, `TRR-Backend/trr_backend/security/internal_admin.py`, `TRR-Backend/api/auth.py`.
- Pattern: short-lived signed token minted in the app, verified in backend dependencies.

**Run Layout / Stage Contracts:**
- Purpose: Give Screenalytics one canonical vocabulary for run IDs, stage progression, artifact paths, and storage keys.
- Examples: `screenalytics/packages/py-screenalytics/src/py_screenalytics/run_layout.py`, `screenalytics/packages/py-screenalytics/src/py_screenalytics/pipeline_stages.py`, `screenalytics/apps/api/services/run_state.py`.
- Pattern: API/services import shared package helpers instead of inventing per-endpoint filenames or stage names.

**Workspace Contract Docs as Executable Architecture:**
- Purpose: Make shared repo order, env names, and handoff behavior part of the system boundary.
- Examples: `AGENTS.md`, `docs/cross-collab/WORKFLOW.md`, `docs/workspace/env-contract.md`.
- Pattern: root docs are enforced by root scripts rather than treated as passive prose.

## Entry Points

**Workspace Dev Entry Point:**
- Location: `Makefile`
- Triggers: local operator runs `make dev`, `make preflight`, `make status`, or related root commands.
- Responsibilities: select the canonical cloud-first lane, invoke preflight, and delegate to root scripts.

**Workspace Process Orchestrator:**
- Location: `scripts/dev-workspace.sh`
- Triggers: `make dev` or `make dev-local`.
- Responsibilities: load profile defaults, resolve DB/env state, derive local shared secrets, and start repo-local processes with consistent ports and toggles.

**TRR Backend API:**
- Location: `TRR-Backend/api/main.py`
- Triggers: Uvicorn startup, then all HTTP requests to `TRR-Backend`.
- Responsibilities: validate runtime config, prewarm DB pool, initialize realtime broker, install middleware, mount routers, and expose health/metrics endpoints.

**TRR App Root Layout:**
- Location: `TRR-APP/apps/web/src/app/layout.tsx`
- Triggers: every App Router request rendered by Next.js.
- Responsibilities: install global fonts/styles/providers and wrap page content in shared UI/runtime boundaries.

**TRR App API Surface:**
- Location: `TRR-APP/apps/web/src/app/api/**/route.ts`
- Triggers: browser requests to app-owned API routes.
- Responsibilities: act as BFF routes, cron entrypoints, auth/session endpoints, and backend/admin proxies.

**Screenalytics API:**
- Location: `screenalytics/apps/api/main.py`
- Triggers: Uvicorn startup and HTTP requests to the Screenalytics API.
- Responsibilities: load env defaults early, apply CPU limits, mount routers, expose health/ready/storage endpoints, and optionally expose Celery-backed routes.

**Screenalytics Workspace UI:**
- Location: `screenalytics/apps/workspace-ui/streamlit_app.py`
- Triggers: Streamlit startup.
- Responsibilities: set page config first, initialize UI helpers, and route operators into numbered page modules.

## Error Handling

**Strategy:** Fail fast at startup for invalid runtime lanes or missing critical auth config, then convert runtime failures into HTTP-level errors close to the boundary that owns them.

**Patterns:**
- `TRR-Backend/api/main.py` validates database/auth configuration during lifespan startup and rejects unsupported runtime lanes before serving traffic.
- `TRR-Backend/api/auth.py` and `TRR-Backend/api/screenalytics_auth.py` translate auth failures into `401`, `403`, or `500` depending on whether the problem is user input or auth-service availability.
- `TRR-APP` proxy routes typically guard missing `TRR_API_URL` early and return normalized error JSON from route handlers instead of surfacing raw upstream failures.
- `screenalytics/apps/api/errors.py` is installed from `screenalytics/apps/api/main.py`, while many services keep degraded-mode paths for optional dependencies such as Celery or psycopg2.
- Health/readiness endpoints in both API apps provide the canonical place to distinguish boot failure, dependency failure, and steady-state traffic.

## Cross-Cutting Concerns

**Logging:** Request observability is centralized in `TRR-Backend/api/main.py` and `screenalytics/apps/api/main.py`; root orchestration logs live under `.logs/workspace/` via `scripts/dev-workspace.sh`.

**Validation:** Runtime/env validation happens in `scripts/preflight.sh`, `scripts/dev-workspace.sh`, `TRR-Backend/api/main.py`, and `screenalytics/apps/api/services/supabase_db.py`; request validation relies on FastAPI/Pydantic models and Next route-handler guards.

**Authentication:** Browser auth/session logic lives in `TRR-APP/apps/web/src/app/api/session/login/route.ts`; admin proxy auth bridges through `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`; backend enforcement lives in `TRR-Backend/api/auth.py`; Screenalytics service auth lives in `TRR-Backend/api/screenalytics_auth.py`.

**Cross-Repo Dependencies:** `TRR-APP` depends on `TRR-Backend` URL/auth/error contracts, especially through `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`; `screenalytics` depends on `TRR-Backend` for service endpoints in `TRR-Backend/api/routers/screenalytics*.py` and on the shared DB contract in `TRR_DB_URL`; root workflow docs and scripts define the required implementation order across all three repos.

---

*Architecture analysis: 2026-04-04*
