# Architecture

**Analysis Date:** 2026-04-09

## Pattern Overview

**Overall:** Multi-repo workspace with backend-first contracts, a shared Postgres/Supabase data plane, and a Next.js BFF/admin surface in front of backend APIs.

**Key Characteristics:**
- `TRR-Backend` owns schema, migrations, canonical `/api/v1` HTTP contracts, and long-running admin job dispatch.
- `screenalytics` owns ML and screentime pipeline execution, operator tooling, and analysis-specific API surfaces, while reading and writing against the shared TRR database contract.
- `TRR-APP` owns user/admin UI, route rewriting, auth gating, and server-side proxying to backend/admin APIs instead of calling backend URLs directly from the browser.

## Layers

**Workspace Orchestration Layer:**
- Purpose: Start, stop, validate, and hand off multi-repo development work.
- Location: `Makefile`, `scripts/dev-workspace.sh`, `scripts/handoff-lifecycle.sh`, `scripts/new-cross-collab-task.sh`, `docs/workspace/dev-commands.md`, `docs/workspace/env-contract.md`, `docs/cross-collab/WORKFLOW.md`
- Contains: shared startup profiles, env defaults, browser/MCP wrappers, cross-repo task workflow, and validation entry points.
- Depends on: repo-local startup commands, shared env contracts, workspace scripts under `scripts/lib/`
- Used by: all three repos during local development and formal cross-repo implementation.

**Backend API Layer:**
- Purpose: Expose TRR canonical HTTP endpoints and admin APIs.
- Location: `TRR-Backend/api/`
- Contains: FastAPI bootstrap in `TRR-Backend/api/main.py`, auth/deps modules, realtime broker wiring, and routers under `TRR-Backend/api/routers/`
- Depends on: `TRR-Backend/trr_backend/db/`, `TRR-Backend/trr_backend/repositories/`, `TRR-Backend/trr_backend/services/`, `TRR-Backend/trr_backend/socials/`, `TRR-Backend/trr_backend/integrations/`
- Used by: `TRR-APP`, selected `screenalytics` service-to-service flows, and local scripts/ops tools.

**Backend Domain and Persistence Layer:**
- Purpose: Implement business rules, external integrations, and direct database access for TRR.
- Location: `TRR-Backend/trr_backend/`, `TRR-Backend/supabase/`
- Contains: repositories, media/social integrations, admin job helpers, internal-admin JWT verification, and additive migrations under `TRR-Backend/supabase/migrations/`
- Depends on: shared runtime env, Supabase/Postgres, external providers, storage backends, Modal for remote execution.
- Used by: `TRR-Backend/api/routers/` and backend scripts.

**Screenalytics API and Pipeline Layer:**
- Purpose: Run episode analysis workflows and expose screenalytics-specific API endpoints.
- Location: `screenalytics/apps/api/`, `screenalytics/py_screenalytics/`, `screenalytics/packages/py-screenalytics/`
- Contains: FastAPI app in `screenalytics/apps/api/main.py`, routers, service modules, run/orchestration helpers, and reusable pipeline package code.
- Depends on: shared TRR database through `screenalytics/apps/api/services/supabase_db.py`, artifact storage, optional Redis/Celery surfaces, ML runtimes, and internal-admin auth helpers.
- Used by: screenalytics operator UI, backend bridge flows, local scripts, and optional `screenalytics/web/`.

**Screenalytics Operator UI Layer:**
- Purpose: Provide human-in-the-loop pipeline review and tooling.
- Location: `screenalytics/apps/workspace-ui/`
- Contains: Streamlit app entry point `screenalytics/apps/workspace-ui/streamlit_app.py`, numbered pages in `screenalytics/apps/workspace-ui/pages/`, and reusable widgets/components.
- Depends on: `screenalytics/apps/api/`, artifact storage, and TRR metadata access through screenalytics services.
- Used by: local operators and debugging workflows; not the main public TRR product surface.

**TRR-APP UI and BFF Layer:**
- Purpose: Render user/admin pages and proxy server-side requests to backend services.
- Location: `TRR-APP/apps/web/src/`
- Contains: App Router pages in `TRR-APP/apps/web/src/app/`, middleware-like host/path rewriting in `TRR-APP/apps/web/src/proxy.ts`, server repositories under `TRR-APP/apps/web/src/lib/server/`, and many admin API route handlers under `TRR-APP/apps/web/src/app/api/admin/`
- Depends on: Firebase/Supabase auth, `TRR_API_URL` normalization in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, backend internal-admin JWT signing in `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`, and backend/admin proxies.
- Used by: browser clients, Vercel deployment, and local workspace startup.

## Data Flow

**Admin Browser Request Flow:**

1. Browser requests a page or API route in `TRR-APP/apps/web/src/app/` or `TRR-APP/apps/web/src/app/api/admin/`.
2. `TRR-APP/apps/web/src/proxy.ts` normalizes host/path behavior for admin, public, and alias routes before the request reaches page or route code.
3. Route handlers and server repositories call `TRR-APP/apps/web/src/lib/server/auth.ts` to enforce admin allowlists, then build backend URLs with `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.
4. `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts` signs a short-lived internal-admin JWT, and proxy helpers such as `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts` or `TRR-APP/apps/web/src/lib/server/trr-api/social-admin-proxy.ts` call `TRR-Backend`.
5. `TRR-Backend/api/main.py` routes the request into `TRR-Backend/api/routers/*.py`, which fan into repositories, services, integrations, and the shared database.

**Screenalytics Metadata Sync Flow:**

1. `screenalytics/apps/api/routers/cast.py` or `screenalytics/apps/api/routers/episodes.py` invokes services such as `screenalytics/apps/api/services/episodes_trr_sync.py`.
2. `screenalytics/apps/api/services/trr_ingest.py` reads shared TRR metadata from the canonical database and, when needed, signs outbound bearer auth using `screenalytics/apps/api/services/internal_admin_auth.py`.
3. Backend-owned bridge endpoints in `TRR-Backend/api/routers/screenalytics.py` expose narrow service-to-service reads for episode cast and person photo bootstrapping.
4. Screenalytics persists operational state and artifacts while keeping backend schema/API contracts upstream.

**Long-Running Admin Job Flow:**

1. `TRR-APP` admin routes call backend operation endpoints such as `TRR-APP/apps/web/src/app/api/admin/trr-api/operations/[operationId]/route.ts` or social/admin proxy helpers.
2. `TRR-Backend` records/administers operations through routers such as `TRR-Backend/api/routers/admin_operations.py` and social/admin routers such as `TRR-Backend/api/routers/socials.py`.
3. Execution ownership is resolved by `TRR-Backend/trr_backend/job_plane.py`.
4. Remote execution is dispatched through `TRR-Backend/trr_backend/modal_dispatch.py` when the workspace/backend runtime is in remote Modal mode; otherwise local/backend execution paths remain available for specific lanes.
5. Progress is surfaced back to `TRR-APP` through polling routes, stream routes, or cached admin reads.

**Workspace Dev Startup Flow:**

1. `make dev` in the workspace root loads the cloud-first path defined in `Makefile`.
2. `scripts/dev-workspace.sh` resolves shared env defaults, runtime DB URLs, internal admin secrets, and process toggles from `profiles/*.env` plus `docs/workspace/env-contract.md`.
3. The script starts `TRR-Backend`, `TRR-APP`, and optionally the `screenalytics` API/Streamlit/Web services according to workspace flags.
4. Shared validation and handoff state is coordinated through `docs/cross-collab/WORKFLOW.md`, `docs/ai/local-status/`, and `scripts/handoff-lifecycle.sh`.

**State Management:**
- Canonical relational state lives in the shared database owned by `TRR-Backend/supabase/migrations/`.
- Backend request/operation state is persisted in database tables and surfaced through backend routers.
- Screenalytics run/orchestration state is tracked by service helpers such as `screenalytics/apps/api/services/run_state.py` and `screenalytics/apps/api/services/pipeline_orchestration.py`.
- TRR-APP keeps route-level and admin snapshot caches in modules under `TRR-APP/apps/web/src/lib/server/admin/` and `TRR-APP/apps/web/src/lib/server/trr-api/`.

## Key Abstractions

**Canonical API Boundary:**
- Purpose: Keep downstream consumers on a stable backend versioned surface.
- Examples: `TRR-Backend/api/main.py`, `TRR-Backend/api/routers/`, `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`
- Pattern: all backend HTTP access is normalized to `/api/v1`; UI code should not invent direct backend URLs.

**Internal Admin JWT Contract:**
- Purpose: Authenticate trusted server-to-server calls without exposing shared secrets in headers or browser code.
- Examples: `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`, `TRR-Backend/trr_backend/security/internal_admin.py`, `screenalytics/apps/api/services/internal_admin_auth.py`
- Pattern: short-lived HS256 JWT signed by `TRR_INTERNAL_ADMIN_SHARED_SECRET`, with service-token fallback only as an explicit transitional lane.

**Repository/Service Split in Backend:**
- Purpose: Keep router code thin and push SQL/integration behavior into dedicated modules.
- Examples: `TRR-Backend/api/routers/admin_show_links.py`, `TRR-Backend/trr_backend/repositories/admin_show_reads.py`, `TRR-Backend/trr_backend/integrations/fandom.py`
- Pattern: routers assemble request/response contracts; repositories and service helpers own DB and provider logic.

**Router/Service Split in Screenalytics:**
- Purpose: Separate HTTP surface area from pipeline orchestration and storage access.
- Examples: `screenalytics/apps/api/routers/episodes.py`, `screenalytics/apps/api/services/pipeline_orchestration.py`, `screenalytics/apps/api/services/episodes_trr_sync.py`
- Pattern: routers call service modules; services bridge ML pipeline code, DB access, artifact storage, and TRR sync helpers.

**TRR-APP Server Repository and Proxy Layer:**
- Purpose: Prevent client-side backend coupling and centralize admin fetch behavior.
- Examples: `TRR-APP/apps/web/src/lib/server/admin/social-landing-repository.ts`, `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts`, `TRR-APP/apps/web/src/lib/server/trr-api/social-admin-proxy.ts`
- Pattern: page components call server modules; route handlers reuse shared proxy/auth/error-normalization helpers.

**Setup/Pipeline Stage Orchestration:**
- Purpose: Advance Screenalytics episode work across ordered pipeline stages.
- Examples: `screenalytics/apps/api/services/pipeline_orchestration.py`, `screenalytics/apps/api/services/run_state.py`, `screenalytics/packages/py-screenalytics/src/py_screenalytics/pipeline_config.py`
- Pattern: internal setup stages are normalized, persisted, and optionally auto-advanced from API/Celery/job-service callers.

## Entry Points

**Workspace Dev Entry Point:**
- Location: `Makefile`, `scripts/dev-workspace.sh`
- Triggers: developer runs `make dev`, `make dev-local`, `make status`, or validation targets from the workspace root.
- Responsibilities: cross-repo startup, profile loading, health checks, and workspace-level orchestration.

**TRR Backend API:**
- Location: `TRR-Backend/api/main.py`, `TRR-Backend/start-api.sh`
- Triggers: `uvicorn api.main:app` via repo-local or workspace launchers.
- Responsibilities: startup validation, DB prewarm, realtime broker init, router registration, health/metrics.

**Screenalytics API:**
- Location: `screenalytics/apps/api/main.py`, `screenalytics/scripts/dev.sh`
- Triggers: `uvicorn apps.api.main:app` or the repo-local dev script.
- Responsibilities: startup schema/runtime checks, readiness endpoints, ML/runtime warmup, router registration.

**Screenalytics Operator UI:**
- Location: `screenalytics/apps/workspace-ui/streamlit_app.py`
- Triggers: `streamlit run apps/workspace-ui/streamlit_app.py`
- Responsibilities: operator review, workflow tooling, and visualization against the screenalytics API/artifacts.

**TRR Web App:**
- Location: `TRR-APP/apps/web/src/app/layout.tsx`, `TRR-APP/apps/web/package.json`
- Triggers: `pnpm -C TRR-APP/apps/web run dev|build|start`, Vercel deploys `TRR-APP/apps/web/`
- Responsibilities: render public/admin pages, host app routes, and serve BFF/admin proxy endpoints.

**Database Schema Entry Point:**
- Location: `TRR-Backend/supabase/migrations/`
- Triggers: backend schema changes and repo validation flows.
- Responsibilities: define additive DB evolution consumed by backend, screenalytics, and app layers.

## Error Handling

**Strategy:** Validate critical runtime configuration at startup, surface typed HTTP errors at the proxy boundary, and expose health/readiness endpoints for both backend services.

**Patterns:**
- `TRR-Backend/api/main.py` validates DB/auth/runtime env state before serving traffic and exposes `/health`, `/health/live`, and `/metrics`.
- `screenalytics/apps/api/main.py` splits liveness (`/healthz`) from readiness (`/readyz`) and centralizes startup checks through `screenalytics/apps/api/services/runtime_startup.py` and `runtime_readiness.py`.
- `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts` and `social-admin-proxy.ts` normalize backend timeouts, saturation, unreachable states, and typed retryability for UI consumers.

## Cross-Cutting Concerns

**Logging:** `TRR-Backend/trr_backend/observability.py` and `screenalytics/apps/api/services/observability.py` bind trace IDs, record HTTP metrics, and expose Prometheus-style metrics endpoints. Proxy helpers in `TRR-APP/apps/web/src/lib/server/trr-api/` log route-level latency and backend failures.

**Validation:** DB lane validation is enforced in `TRR-Backend/trr_backend/db/connection.py` and `screenalytics/apps/api/services/supabase_db.py`. Workspace-level runtime defaults are generated and documented from `scripts/workspace-env-contract.sh` into `docs/workspace/env-contract.md`.

**Authentication:** Browser/admin auth is enforced in `TRR-APP/apps/web/src/lib/server/auth.ts` using Firebase or Supabase plus email/UID/display-name allowlists. Trusted service calls use the internal-admin JWT contract across `TRR-APP`, `TRR-Backend`, and `screenalytics`.

**Repo Interaction Order:** Cross-repo implementation order is defined in `AGENTS.md` and `docs/cross-collab/WORKFLOW.md`: `TRR-Backend` first for schema/API/auth, `screenalytics` second for consumers/pipeline behavior, and `TRR-APP` last for UI/admin integration.

---

*Architecture analysis: 2026-04-09*
