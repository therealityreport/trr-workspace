# Architecture

**Analysis Date:** 2026-04-08

## Pattern Overview

**Overall:** Federated workspace with repo-owned runtimes, a shared Supabase/Postgres contract, and workspace-level orchestration scripts.

**Key Characteristics:**
- `TRR-Backend/` owns canonical schema, API contracts, internal auth verification, and upstream data ingestion into Supabase-backed `core.*` and pipeline schemas.
- `screenalytics/` is a downstream compute and analytics system that reads TRR metadata from the shared database, exposes its own FastAPI and Streamlit surfaces, and runs long-lived ML and media pipelines.
- `TRR-APP/` is the user-facing Next.js surface that mixes direct server-side Postgres reads with explicit proxy calls to `TRR-Backend/` for admin and mutation-heavy flows.

## Layers

**Workspace Orchestration Layer:**
- Purpose: Starts local runtimes, applies workspace defaults, validates shared contracts, and synchronizes cross-repo handoff state.
- Location: `Makefile`, `scripts/dev-workspace.sh`, `scripts/bootstrap.sh`, `scripts/handoff-lifecycle.sh`, `scripts/check-workspace-contract.sh`, `docs/workspace/env-contract.md`, `docs/cross-collab/WORKFLOW.md`
- Contains: startup wrappers, health checks, shared env defaults, cross-repo task workflow, generated handoff sync.
- Depends on: repo-local entrypoints in `TRR-Backend/`, `TRR-APP/`, and `screenalytics/`
- Used by: every local development and cross-repo implementation flow.

**TRR-Backend API Layer:**
- Purpose: Exposes canonical HTTP and WebSocket surfaces for shows, surveys, discussions, admin tools, social ingestion, and Screenalytics-facing internal endpoints.
- Location: `TRR-Backend/api/main.py`, `TRR-Backend/api/routers/`, `TRR-Backend/api/realtime/`
- Contains: `FastAPI` app setup, router registration, request middleware, observability, startup validation, realtime broker hooks.
- Depends on: `TRR-Backend/trr_backend/`, `TRR-Backend/supabase/migrations/`, shared env contracts such as `TRR_DB_URL`, `TRR_INTERNAL_ADMIN_SHARED_SECRET`, and `SUPABASE_JWT_SECRET`
- Used by: `TRR-APP/apps/web/`, `screenalytics/`, background workers, and direct admin tooling.

**TRR-Backend Domain Library Layer:**
- Purpose: Holds reusable backend logic separate from HTTP transport.
- Location: `TRR-Backend/trr_backend/`
- Contains: DB access in `trr_backend/db/`, integrations in `trr_backend/integrations/`, repositories in `trr_backend/repositories/`, services in `trr_backend/services/`, pipeline code in `trr_backend/pipeline/`, and CLI code in `trr_backend/cli/`
- Depends on: database schema in `TRR-Backend/supabase/`, external providers, and runtime env loaders.
- Used by: `TRR-Backend/api/`, `TRR-Backend/scripts/`, and `python -m trr_backend.cli`.

**TRR-Backend Schema and Script Layer:**
- Purpose: Owns schema evolution and bulk data movement.
- Location: `TRR-Backend/supabase/migrations/`, `TRR-Backend/supabase/schema_docs/`, `TRR-Backend/scripts/`
- Contains: migrations, schema docs, replay docs, sync scripts, backfills, admin ops, media tasks, and social ingestion workers.
- Depends on: Supabase/Postgres and backend library helpers.
- Used by: release flows, one-off backfills, local ops, and cross-repo schema-first changes.

**TRR-APP Route Layer:**
- Purpose: Defines the public and admin web route tree in the Next.js App Router.
- Location: `TRR-APP/apps/web/src/app/`
- Contains: `page.tsx`, `layout.tsx`, route handlers under `src/app/api/`, admin route groups under `src/app/admin/`, public show and people routes under `src/app/[showId]/` and `src/app/people/`
- Depends on: server utilities in `TRR-APP/apps/web/src/lib/server/`, client components in `TRR-APP/apps/web/src/components/`, and environment configuration from `TRR-APP/apps/web/.env.example`
- Used by: browser clients, Vercel runtime, and local workspace startup.

**TRR-APP Server Integration Layer:**
- Purpose: Encapsulates server-only reads, backend proxying, admin auth, and direct database access.
- Location: `TRR-APP/apps/web/src/lib/server/`
- Contains: backend base resolution in `src/lib/server/trr-api/backend.ts`, admin proxy helpers in `src/lib/server/trr-api/admin-read-proxy.ts`, social proxy helpers in `src/lib/server/trr-api/social-admin-proxy.ts`, internal JWT creation in `src/lib/server/trr-api/internal-admin-auth.ts`, and direct Postgres pooling in `src/lib/server/postgres.ts`
- Depends on: `TRR_API_URL`, `TRR_DB_URL`, `TRR_DB_FALLBACK_URL`, and `TRR_INTERNAL_ADMIN_SHARED_SECRET`
- Used by: route handlers in `TRR-APP/apps/web/src/app/api/` and server components under `TRR-APP/apps/web/src/app/`

**screenalytics API Layer:**
- Purpose: Exposes episode processing, metadata, facebank, run management, and optional v2 asset-centric APIs.
- Location: `screenalytics/apps/api/main.py`, `screenalytics/apps/api/routers/`, `screenalytics/apps/api/services/`
- Contains: `FastAPI` app setup, CORS, observability middleware, job endpoints, metadata accessors, DB lane validation, and optional Celery routes.
- Depends on: pipeline code in `screenalytics/tools/` and `screenalytics/packages/py-screenalytics/`, shared DB envs `TRR_DB_URL` and `TRR_DB_FALLBACK_URL`, and optional storage or worker services.
- Used by: `screenalytics/apps/workspace-ui/`, optional `screenalytics/web/`, and backend-admin image-analysis flows.

**screenalytics Pipeline Layer:**
- Purpose: Runs ML/media processing and persists run artifacts.
- Location: `screenalytics/tools/episode_run.py`, `screenalytics/tools/`, `screenalytics/packages/py-screenalytics/src/py_screenalytics/`, `screenalytics/config/pipeline/`
- Contains: detect-track-embed-cluster orchestration, artifact layout helpers, configuration resolution, run state tracking, and export tooling.
- Depends on: `py_screenalytics`, `apps.api.services.storage`, pipeline YAML config, and optionally the shared TRR Postgres metadata DB.
- Used by: CLI operators, `screenalytics/apps/api/routers/episodes.py`, and workspace UI actions.

**screenalytics Workspace UI Layer:**
- Purpose: Provides the operator-facing Streamlit workflow for episode uploads, runs, review, cast management, and health views.
- Location: `screenalytics/apps/workspace-ui/streamlit_app.py`, `screenalytics/apps/workspace-ui/pages/`, `screenalytics/apps/workspace-ui/ui_helpers.py`
- Contains: multi-page Streamlit app, API launch helpers, session state utilities, custom components, and review surfaces.
- Depends on: `screenalytics/apps/api/`, local/session env, and pipeline artifacts.
- Used by: local operators and QA flows.

## Data Flow

**Workspace Startup Flow:**

1. `make dev` in `Makefile` runs `scripts/preflight.sh` and then `scripts/dev-workspace.sh` with `PROFILE=default`.
2. `scripts/dev-workspace.sh` resolves the workspace DB lane through `scripts/lib/runtime-db-env.sh`, exports `TRR_DB_URL`, applies profile defaults from `profiles/default.env`, and derives local auth secrets when needed.
3. The script launches `TRR-Backend/start-api.sh`, `TRR-APP` dev scripts from `TRR-APP/package.json`, and the screenalytics API depending on `WORKSPACE_SCREENALYTICS*` flags.
4. `scripts/status-workspace.sh`, `scripts/stop-workspace.sh`, and related wrappers manage health, lifecycle, and cleanup for the shared local stack.

**TRR-APP Admin Read Flow:**

1. A browser request reaches a route handler under `TRR-APP/apps/web/src/app/api/admin/...` or a server component in `TRR-APP/apps/web/src/app/admin/...`.
2. The server-only layer builds a backend URL via `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, which normalizes `TRR_API_URL` to `/api/v1`.
3. `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts` mints a short-lived HS256 bearer token from `TRR_INTERNAL_ADMIN_SHARED_SECRET`.
4. `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts` or `social-admin-proxy.ts` performs a no-store fetch to `TRR-Backend/api/main.py` routers and normalizes timeout, saturation, and retry semantics.
5. `TRR-Backend/api/routers/*` resolve domain services and repositories in `TRR-Backend/trr_backend/`, then respond with canonical admin JSON.

**TRR-APP Direct Server Read Flow:**

1. A server component or route handler calls repositories under `TRR-APP/apps/web/src/lib/server/`.
2. `TRR-APP/apps/web/src/lib/server/postgres.ts` resolves `TRR_DB_URL` then `TRR_DB_FALLBACK_URL`, validates the lane, and creates a shared `pg` pool.
3. Repository modules under `TRR-APP/apps/web/src/lib/server/surveys/` or `TRR-APP/apps/web/src/lib/server/admin/` read from the shared Postgres schema directly.
4. The App Router renders the result as HTML or returns it through `route.ts` handlers.

**Backend-to-screenalytics Contract Flow:**

1. Backend code that needs Screenalytics assistance uses helpers in `TRR-Backend/trr_backend/clients/screenalytics.py` or Screenalytics-facing routes in `TRR-Backend/api/routers/screenalytics.py`.
2. `TRR-Backend/api/screenalytics_auth.py` accepts either `SCREENALYTICS_SERVICE_TOKEN` or an internal-admin JWT signed with `TRR_INTERNAL_ADMIN_SHARED_SECRET`.
3. `screenalytics/apps/api/main.py` routes the request to routers in `screenalytics/apps/api/routers/`, which call services under `screenalytics/apps/api/services/`.
4. For metadata-backed work, screenalytics resolves the shared runtime DB lane through `screenalytics/apps/api/services/supabase_db.py` and reads canonical data through `screenalytics/apps/api/services/trr_metadata_db.py`.

**screenalytics Episode Run Flow:**

1. An operator triggers a job from `screenalytics/apps/workspace-ui/pages/2_Episode_Run.py` or an HTTP endpoint in `screenalytics/apps/api/routers/episodes.py`.
2. `screenalytics/apps/api/routers/episodes.py` delegates to `screenalytics/tools/episode_run.py` and service modules such as `apps/api/services/run_state.py`, `apps/api/services/storage.py`, and `apps/api/services/trr_ingest.py`.
3. `screenalytics/tools/episode_run.py` inserts repo and package paths, applies CPU limits, loads config from `screenalytics/config/pipeline/`, and orchestrates `py_screenalytics` stages.
4. Artifacts are written through the `py_screenalytics` run layout and storage service, then surfaced back through the API and Streamlit UI.

**Cross-Repo Planning and Handoff Flow:**

1. Formal multi-repo work follows `docs/cross-collab/WORKFLOW.md`.
2. Before planning, `scripts/handoff-lifecycle.sh pre-plan` verifies generated handoff state.
3. During implementation, each touched repo updates `docs/cross-collab/TASK*/STATUS.md` or `docs/ai/local-status/*.md`.
4. `scripts/handoff-lifecycle.sh post-phase` and `scripts/sync-handoffs.py` regenerate concise handoff indexes such as `docs/ai/HANDOFF.md`.

**State Management:**
- Canonical relational state lives in the shared Supabase/Postgres schema managed by `TRR-Backend/supabase/migrations/`.
- `TRR-APP/` uses server-side Postgres pooling in `TRR-APP/apps/web/src/lib/server/postgres.ts` plus backend proxying for admin operations that should not reimplement backend business rules.
- `screenalytics/` stores large run artifacts in its artifact layout and object storage abstractions while reading canonical show and people metadata from the shared DB.

## Key Abstractions

**Canonical Backend URL Resolution:**
- Purpose: Makes `TRR-APP/` treat `TRR_API_URL` as the single source of truth for backend-originated HTTP calls.
- Examples: `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, `TRR-APP/apps/web/src/app/api/shows/list/route.ts`
- Pattern: Normalize once to `/api/v1`, then build route-specific URLs in proxy/repository helpers.

**Internal Admin Token Boundary:**
- Purpose: Allows service-to-service admin access without exposing raw shared secrets in request headers.
- Examples: `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`, `TRR-Backend/api/screenalytics_auth.py`, `TRR-Backend/trr_backend/security/internal_admin.py`
- Pattern: Sign short-lived bearer tokens in the caller, verify centrally in the backend.

**Shared Runtime DB Lane:**
- Purpose: Keeps all repos on `TRR_DB_URL` primary with `TRR_DB_FALLBACK_URL` as the only intentional fallback.
- Examples: `TRR-Backend/trr_backend/db/connection.py`, `TRR-APP/apps/web/src/lib/server/postgres.ts`, `screenalytics/apps/api/services/supabase_db.py`, `docs/workspace/env-contract.md`
- Pattern: classify the connection string, reject unsupported lanes, and keep session-mode Supavisor as the deployed contract.

**Repo-Owned Transport, Shared Domain:**
- Purpose: Split HTTP transport from reusable domain logic.
- Examples: `TRR-Backend/api/routers/` + `TRR-Backend/trr_backend/`, `screenalytics/apps/api/routers/` + `screenalytics/apps/api/services/`, `TRR-APP/apps/web/src/app/api/` + `TRR-APP/apps/web/src/lib/server/`
- Pattern: route/module pairs delegate into service or repository modules rather than embedding all business logic in handlers.

**Cross-Repo Task Metadata:**
- Purpose: Persist implementation order, status, and locked contracts outside chat history.
- Examples: `docs/cross-collab/WORKFLOW.md`, `TRR-Backend/docs/cross-collab/TASK*/`, `TRR-APP/docs/cross-collab/TASK*/`, `screenalytics/docs/cross-collab/TASK*/`
- Pattern: one task folder per repo, synchronized through workspace scripts and generated handoffs.

## Entry Points

**Workspace Dev Entry Point:**
- Location: `Makefile`
- Triggers: `make dev`, `make dev-local`, `make status`, `make stop`, `make handoff-sync`
- Responsibilities: select the workspace profile, call shared scripts, and provide the canonical daily developer interface.

**Workspace Runtime Launcher:**
- Location: `scripts/dev-workspace.sh`
- Triggers: `make dev` and `make dev-local`
- Responsibilities: resolve env defaults, launch repo runtimes, manage ports and health checks, and enforce workspace contract defaults.

**Backend HTTP Entry Point:**
- Location: `TRR-Backend/api/main.py`
- Triggers: `uvicorn api.main:app`, `TRR-Backend/start-api.sh`, workspace startup
- Responsibilities: initialize `FastAPI`, install middleware, validate runtime config, register routers, and host `/api/v1` surfaces.

**Backend CLI Entry Point:**
- Location: `TRR-Backend/trr_backend/cli/__main__.py`
- Triggers: `python -m trr_backend.cli ...`
- Responsibilities: expose Typer commands for pipeline orchestration and run inspection.

**TRR-APP Web Entry Point:**
- Location: `TRR-APP/apps/web/src/app/layout.tsx` and `TRR-APP/apps/web/src/app/page.tsx`
- Triggers: Next.js dev or production runtime through `TRR-APP/apps/web/package.json`
- Responsibilities: initialize the App Router shell and render public or admin route trees.

**TRR-APP API Entry Points:**
- Location: `TRR-APP/apps/web/src/app/api/` and `TRR-APP/apps/web/src/app/api/admin/`
- Triggers: browser fetches and server actions
- Responsibilities: proxy backend admin operations, expose app-owned APIs, and bridge server-only logic to the browser.

**screenalytics API Entry Point:**
- Location: `screenalytics/apps/api/main.py`
- Triggers: `uvicorn apps.api.main:app --reload`
- Responsibilities: initialize the Screenalytics API, install error and observability middleware, and expose pipeline/metadata routes.

**screenalytics Streamlit Entry Point:**
- Location: `screenalytics/apps/workspace-ui/streamlit_app.py`
- Triggers: `streamlit run apps/workspace-ui/streamlit_app.py`
- Responsibilities: configure the Streamlit workspace and link operators into episode and cast workflows.

**screenalytics Pipeline CLI Entry Point:**
- Location: `screenalytics/tools/episode_run.py`
- Triggers: direct CLI runs and API-triggered processing
- Responsibilities: execute detection, tracking, embedding, clustering, and artifact generation for a single episode run.

## Error Handling

**Strategy:** Fail fast on misconfigured runtime lanes, then normalize network and upstream failures into typed API-level errors close to the transport boundary.

**Patterns:**
- `TRR-Backend/api/main.py` validates critical startup config and rejects invalid DB lane or missing deployed secrets before serving traffic.
- `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts` and `social-admin-proxy.ts` convert backend timeouts, saturation, and unreachable-host failures into typed responses for admin pages.
- `screenalytics/apps/api/main.py` installs global error handlers and conditionally stubs missing Celery routes with explicit `503` responses instead of crashing the whole app.
- `screenalytics/apps/api/routers/episodes.py` raises `HTTPException` when required backing services such as S3 or shared DB access are unavailable.

## Cross-Cutting Concerns

**Logging:** Structured request timing and trace IDs are installed in `TRR-Backend/api/main.py` and `screenalytics/apps/api/main.py`; workspace orchestration logs to `.logs/workspace/` through `scripts/dev-workspace.sh` and `scripts/handoff-lifecycle.sh`.

**Validation:** Runtime connection validation is centralized in `TRR-Backend/trr_backend/db/connection.py`, `TRR-APP/apps/web/src/lib/server/postgres.ts`, and `screenalytics/apps/api/services/supabase_db.py`; workspace contract drift is checked in `scripts/check-workspace-contract.sh`.

**Authentication:** Public/app auth lives in `TRR-APP/apps/web/src/lib/firebase.ts` and related auth modules; internal admin auth is signed in `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts` and verified in backend code; Screenalytics service-to-service auth is enforced by `TRR-Backend/api/screenalytics_auth.py`.

---

*Architecture analysis: 2026-04-08*
