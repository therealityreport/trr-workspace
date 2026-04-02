# Architecture

**Analysis Date:** 2026-04-02

## Pattern Overview

**Overall:** Polyrepo workspace with a shared data contract.

**Key Characteristics:**
- Use the workspace root as an orchestration shell only. `Makefile` and `scripts/dev-workspace.sh` start and wire `TRR-Backend`, `screenalytics`, and `TRR-APP`; the root is not the primary home for feature code.
- Treat `TRR-Backend` as the upstream contract owner for schemas, API routes, and shared runtime rules. The ordering is documented in `AGENTS.md`, reinforced in `docs/cross-collab/WORKFLOW.md`, and reflected in code under `TRR-Backend/api/` and `TRR-Backend/supabase/`.
- Treat `screenalytics` and `TRR-APP` as downstream consumers of backend-owned contracts. `screenalytics/apps/api/services/supabase_db.py` reads `core.*` metadata and writes `screenalytics.*`; `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts` normalizes all backend calls onto `TRR_API_URL` plus `/api/v1`.

## Layers

**Workspace Orchestration Layer:**
- Purpose: Start local runtimes, load profile defaults, enforce workspace env contracts, and coordinate cross-repo workflows.
- Location: `Makefile`, `scripts/dev-workspace.sh`, `scripts/lib/runtime-db-env.sh`, `docs/workspace/dev-commands.md`, `docs/workspace/env-contract.md`, `docs/cross-collab/WORKFLOW.md`
- Contains: startup commands, health checks, profile loading, browser/MCP wrappers, cross-repo process management
- Depends on: repo-local commands in `TRR-Backend/`, `screenalytics/`, and `TRR-APP/`
- Used by: every local development session

**Backend HTTP Layer:**
- Purpose: Expose TRR data and admin operations over FastAPI.
- Location: `TRR-Backend/api/main.py`, `TRR-Backend/api/routers/`, `TRR-Backend/api/realtime/`
- Contains: app startup, CORS and timeout middleware, router registration, websocket/realtime broker integration
- Depends on: `TRR-Backend/trr_backend/`, `TRR-Backend/trr_backend/db/`, `TRR-Backend/trr_backend/observability.py`
- Used by: `TRR-APP`, legacy Screenalytics HTTP consumers, and direct admin/API clients

**Backend Domain and Data-Access Layer:**
- Purpose: Keep reusable backend logic outside the FastAPI surface.
- Location: `TRR-Backend/trr_backend/`
- Contains: repositories in `TRR-Backend/trr_backend/repositories/`, DB helpers in `TRR-Backend/trr_backend/db/`, integrations in `TRR-Backend/trr_backend/integrations/`, media and socials runtimes, pipeline orchestration, security helpers
- Depends on: Supabase/Postgres, external services, object storage, remote execution settings
- Used by: `TRR-Backend/api/`, `TRR-Backend/scripts/`, and `TRR-Backend/trr_backend/cli/`

**Backend Schema and Migration Layer:**
- Purpose: Define and evolve the shared database contract.
- Location: `TRR-Backend/supabase/migrations/`, `TRR-Backend/supabase/config.toml`, `TRR-Backend/supabase/schema_docs/`
- Contains: ordered SQL migrations for `core.*`, `screenalytics.*`, survey, social, and pipeline schemas
- Depends on: Supabase CLI/runtime
- Used by: `TRR-Backend`, `screenalytics`, and `TRR-APP` server-side database access

**App Router UI Layer:**
- Purpose: Render public and admin web surfaces in Next.js.
- Location: `TRR-APP/apps/web/src/app/`, `TRR-APP/apps/web/src/components/`
- Contains: App Router pages, layouts, route handlers, public UI, admin UI, game surfaces, design-system pages
- Depends on: server-only modules in `TRR-APP/apps/web/src/lib/server/`, client helpers in `TRR-APP/apps/web/src/lib/`, admin route normalization in `TRR-APP/apps/web/src/proxy.ts`
- Used by: browser clients

**App Server Integration Layer:**
- Purpose: Separate server-only data access from page and component code.
- Location: `TRR-APP/apps/web/src/lib/server/`
- Contains: Postgres access in `TRR-APP/apps/web/src/lib/server/postgres.ts`, auth in `TRR-APP/apps/web/src/lib/server/auth.ts`, backend proxy helpers in `TRR-APP/apps/web/src/lib/server/trr-api/`, app-owned repositories in `TRR-APP/apps/web/src/lib/server/shows/` and `TRR-APP/apps/web/src/lib/server/surveys/`
- Depends on: `TRR_DB_URL` or `TRR_DB_FALLBACK_URL`, `TRR_API_URL`, Firebase or Supabase auth, backend internal-admin flows
- Used by: App Router route handlers in `TRR-APP/apps/web/src/app/api/` and server-rendered page logic

**Screenalytics API Layer:**
- Purpose: Provide Screenalytics operational APIs over FastAPI.
- Location: `screenalytics/apps/api/main.py`, `screenalytics/apps/api/routers/`, `screenalytics/apps/api/services/`
- Contains: API router registration, observability middleware, v1 and v2 route sets, optional Celery routing, service classes
- Depends on: `screenalytics/apps/api/services/supabase_db.py`, storage adapters, pipeline package code, TRR DB contracts
- Used by: local workspace tools, Streamlit UI, and backend-admin integrations

**Screenalytics Pipeline Package Layer:**
- Purpose: Hold reusable ML and pipeline primitives outside the API and UI.
- Location: `screenalytics/packages/py-screenalytics/src/py_screenalytics/`, `screenalytics/config/pipeline/`, `screenalytics/tools/episode_run.py`
- Contains: pipeline stages, artifact contracts, run manifests, layout rules, ONNX/Torch safety helpers, CLI execution
- Depends on: YAML config under `screenalytics/config/pipeline/`, optional ML runtimes, storage services
- Used by: `screenalytics/tools/episode_run.py`, API services, and runtime tooling

**Screenalytics Workspace UI Layer:**
- Purpose: Provide the operator-facing Streamlit workspace.
- Location: `screenalytics/apps/workspace-ui/streamlit_app.py`, `screenalytics/apps/workspace-ui/pages/`, `screenalytics/apps/workspace-ui/components/`
- Contains: Streamlit entrypoint, numbered page modules, review and diagnostics components, UI state helpers
- Depends on: API services, local storage helpers, Streamlit session state, artifact inspection helpers
- Used by: local operators and development workflows

## Data Flow

**Web Request Flow:**

1. The browser enters through `TRR-APP/apps/web/src/app/layout.tsx` and the route tree under `TRR-APP/apps/web/src/app/`.
2. `TRR-APP/apps/web/src/proxy.ts` canonicalizes host- and path-based admin routing before page or API logic runs.
3. Route handlers in `TRR-APP/apps/web/src/app/api/` call server-only modules in `TRR-APP/apps/web/src/lib/server/`.
4. Those server modules either:
   - read app-owned Postgres tables through `TRR-APP/apps/web/src/lib/server/postgres.ts`, or
   - proxy backend-owned reads and writes through `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts` and sibling modules under `TRR-APP/apps/web/src/lib/server/trr-api/`.
5. The response returns to a Server Component page or to a client-heavy admin page such as `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`.

**Backend Request Flow:**

1. `TRR-Backend/api/main.py` validates runtime configuration, prewarms the DB pool, and registers routers.
2. A router such as `TRR-Backend/api/routers/shows.py` parses request parameters and shapes HTTP responses with Pydantic models.
3. Router code reaches into database helpers or reusable repositories under `TRR-Backend/trr_backend/`, for example `TRR-Backend/trr_backend/repositories/shows.py`.
4. Repository and client modules talk to Supabase/Postgres, object storage, or remote services such as Screenalytics via `TRR-Backend/trr_backend/clients/screenalytics.py`.
5. Observability middleware in `TRR-Backend/api/main.py` records timing and trace IDs on the way out.

**Screenalytics V2 Run Flow:**

1. `screenalytics/apps/api/routers/runs_v2.py` accepts a `video_asset_id` and delegates to `runs_v2_service`.
2. `screenalytics/apps/api/services/runs_v2.py` reads metadata from `screenalytics.video_assets`, derives candidate cast from `core.v_episode_cast` or related core views, and persists run state into `screenalytics.runs_v2`.
3. Artifact locations are assigned by `screenalytics/apps/api/services/storage_v2.py` using the `screenalytics/runs/{run_id}/...` key layout.
4. Deeper execution paths can use the installable pipeline package in `screenalytics/packages/py-screenalytics/src/py_screenalytics/` or the CLI in `screenalytics/tools/episode_run.py`.
5. The Streamlit workspace under `screenalytics/apps/workspace-ui/` reads those APIs and artifacts for operator review.

**Schema Evolution Flow:**

1. New shared data structures land first in `TRR-Backend/supabase/migrations/`.
2. Backend runtime code in `TRR-Backend/trr_backend/` and `TRR-Backend/api/` adopts the new columns, views, or RPCs.
3. `screenalytics/apps/api/services/supabase_db.py` and related services adapt next if they read or write the changed shared contract.
4. `TRR-APP/apps/web/src/lib/server/trr-api/` and any app-owned projections in `TRR-APP/apps/web/src/lib/server/` adapt last.

**State Management:**
- Shared persistent state is database-centric. `TRR-Backend/supabase/migrations/` defines the contract, `TRR-Backend/trr_backend/db/` and `screenalytics/apps/api/services/supabase_db.py` enforce runtime lane selection, and `TRR-APP/apps/web/src/lib/server/postgres.ts` applies the same connection-lane restrictions on the app side.
- Backend pipeline state is stored as run rows plus manifests via `TRR-Backend/trr_backend/pipeline/orchestrator.py` and `TRR-Backend/trr_backend/pipeline/manifests.py`.
- Screenalytics run state is stored in `screenalytics.*` tables plus object storage keys defined by `screenalytics/apps/api/services/storage_v2.py`.
- Next.js UI state is mostly local to route segments and client components; the large admin show surface in `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx` keeps page state client-side rather than through a shared frontend store.

## Key Abstractions

**Backend Repository Modules:**
- Purpose: Encapsulate direct table/view access and retry behavior.
- Examples: `TRR-Backend/trr_backend/repositories/shows.py`, `TRR-Backend/trr_backend/repositories/social_posts.py`, `TRR-Backend/trr_backend/repositories/cast_screentime.py`
- Pattern: Keep SQL, PostgREST, schema-cache retries, and data-shaping in repository modules rather than inside routers.

**Backend Pipeline Run Model:**
- Purpose: Represent resumable staged jobs.
- Examples: `TRR-Backend/trr_backend/pipeline/orchestrator.py`, `TRR-Backend/trr_backend/pipeline/models.py`, `TRR-Backend/trr_backend/pipeline/repository.py`
- Pattern: Sequential stage execution with persisted run/stage rows and manifest files keyed by run ID.

**Execution Plane Selector:**
- Purpose: Decide whether long jobs stay local or move to a remote executor.
- Examples: `TRR-Backend/trr_backend/job_plane.py`, `TRR-Backend/trr_backend/modal_dispatch.py`, `scripts/dev-workspace.sh`
- Pattern: Normalize env flags into a canonical local, legacy worker, or Modal execution owner.

**Next Server-Only Repository Modules:**
- Purpose: Keep database and backend-fetch logic out of pages and client bundles.
- Examples: `TRR-APP/apps/web/src/lib/server/shows/shows-repository.ts`, `TRR-APP/apps/web/src/lib/server/surveys/repository.ts`, `TRR-APP/apps/web/src/lib/server/trr-api/trr-shows-repository.ts`
- Pattern: Use `import "server-only";`, perform database or backend calls centrally, and expose typed functions to route handlers and pages.

**Admin Route Canonicalizer:**
- Purpose: Map many admin aliases and legacy path shapes onto a stable internal route graph.
- Examples: `TRR-APP/apps/web/src/proxy.ts`, `TRR-APP/apps/web/src/lib/admin/show-admin-routes.ts`
- Pattern: Canonical URL rewriting happens before page code; route state helpers keep admin UI tabs synchronized with pathname/query state.

**Screenalytics Service Objects:**
- Purpose: Encapsulate operational workflows behind API routers.
- Examples: `screenalytics/apps/api/services/runs_v2.py`, `screenalytics/apps/api/services/trr_ingest.py`, `screenalytics/apps/api/services/pipeline_orchestration.py`
- Pattern: Routers stay thin; services own DB access, candidate derivation, storage keys, ingest adapters, and run lifecycle logic.

**Installable Pipeline Package:**
- Purpose: Provide reusable, framework-agnostic pipeline primitives.
- Examples: `screenalytics/packages/py-screenalytics/src/py_screenalytics/pipeline_stages.py`, `screenalytics/packages/py-screenalytics/src/py_screenalytics/run_manifests.py`, `screenalytics/packages/py-screenalytics/src/py_screenalytics/pipeline_config.py`
- Pattern: Put reusable ML and artifact logic in the package first; let `screenalytics/apps/api/` and `screenalytics/tools/` compose it.

## Entry Points

**Workspace Dev Entry:**
- Location: `Makefile`
- Triggers: developer runs `make dev`, `make dev-local`, or test/status commands from the workspace root
- Responsibilities: call preflight, dispatch into `scripts/dev-workspace.sh`, and expose shared dev/test commands

**Workspace Runtime Bootstrap:**
- Location: `scripts/dev-workspace.sh`
- Triggers: `make dev` or `make dev-local`
- Responsibilities: load profile env files, resolve DB lanes, compute shared local secrets, start repo runtimes, and manage health/watchdog behavior

**Backend API Entry:**
- Location: `TRR-Backend/api/main.py`
- Triggers: `uvicorn api.main:app` or workspace startup
- Responsibilities: startup validation, DB prewarm, broker lifecycle, middleware setup, router registration

**Backend Pipeline CLI Entry:**
- Location: `TRR-Backend/trr_backend/cli/__main__.py`, `TRR-Backend/trr_backend/cli/pipeline.py`
- Triggers: `python -m trr_backend.cli ...`
- Responsibilities: expose staged pipeline execution and inspection outside FastAPI

**Next.js App Entry:**
- Location: `TRR-APP/apps/web/src/app/layout.tsx`, `TRR-APP/apps/web/next.config.ts`, `TRR-APP/apps/web/src/proxy.ts`
- Triggers: `next dev`, `next build`, incoming HTTP requests
- Responsibilities: load fonts and global UI wrappers, configure Next.js runtime behavior, normalize request routing before pages resolve

**Screenalytics API Entry:**
- Location: `screenalytics/apps/api/main.py`
- Triggers: FastAPI startup in local dev or deployment
- Responsibilities: load env, apply CPU limits, register routers, expose observability and readiness behavior

**Screenalytics Streamlit Entry:**
- Location: `screenalytics/apps/workspace-ui/streamlit_app.py`
- Triggers: Streamlit startup
- Responsibilities: initialize page config first, bootstrap workspace navigation, and link into the numbered page modules

**Screenalytics CLI Entry:**
- Location: `screenalytics/tools/episode_run.py`
- Triggers: direct CLI invocation for single-episode or stage execution
- Responsibilities: resolve package imports, load pipeline config, apply CPU limits, and run detection/tracking-oriented workflows

## Error Handling

**Strategy:** Fail fast on configuration and connection-lane mistakes, then keep HTTP layers thin and explicit about runtime errors.

**Patterns:**
- Validate startup contracts before serving traffic. `TRR-Backend/api/main.py` rejects missing auth env or invalid DB lanes; `screenalytics/apps/api/services/supabase_db.py` rejects direct or transaction pooler lanes.
- Keep router-level errors close to transport. `TRR-Backend/api/routers/shows.py` raises `HTTPException`; `screenalytics/apps/api/routers/runs_v2.py` maps service exceptions into HTTP 404, 503, or 500; `TRR-APP/apps/web/src/app/api/admin/shows/route.ts` converts auth and repository failures into `NextResponse` statuses.
- Add compatibility fallbacks where optional infrastructure may be absent. `screenalytics/apps/api/main.py` installs stub Celery endpoints when Celery is unavailable; `TRR-APP/apps/web/src/lib/server/auth.ts` falls back from admin SDK verification to token inspection flows.
- Retry known schema-cache failure modes in the data layer. `TRR-Backend/trr_backend/repositories/shows.py` reloads the PostgREST schema cache on `PGRST204` errors before surfacing a repository error.

## Cross-Cutting Concerns

**Logging:** Structured request timing and trace IDs are installed in `TRR-Backend/api/main.py` and `screenalytics/apps/api/main.py`. Workspace-level operational logs are managed by `scripts/logs-workspace.sh` and the `.logs/workspace/` runtime path created by `scripts/dev-workspace.sh`.

**Validation:** DB lane validation appears in `TRR-Backend/api/main.py`, `TRR-APP/apps/web/src/lib/server/postgres.ts`, and `screenalytics/apps/api/services/supabase_db.py`. Request and response validation is primarily Pydantic-based in FastAPI routers, while app route handlers rely on typed server modules and auth guards.

**Authentication:** Backend shared-secret and service-token expectations are enforced from `TRR-Backend/api/main.py` and `TRR-Backend/trr_backend/security/`. App auth and admin gating live in `TRR-APP/apps/web/src/lib/server/auth.ts` plus `TRR-APP/apps/web/src/proxy.ts`. Screenalytics uses `SCREENALYTICS_SERVICE_TOKEN` in adapters such as `screenalytics/apps/api/services/trr_ingest.py` when it calls upstream services.

---

*Architecture analysis: 2026-04-02*
