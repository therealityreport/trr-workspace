# Architecture

**Analysis Date:** 2026-04-06

## Pattern Overview

**Overall:** Workspace-orchestrated multi-repo system with a shared Postgres contract and repo-owned runtimes

**Key Characteristics:**
- The workspace root coordinates startup, verification, browser policy, environment defaults, and handoff flow from `Makefile`, `scripts/`, `docs/workspace/`, and `.planning/`.
- Product code is repo-owned: `TRR-Backend/` owns schema and API contracts, `screenalytics/` owns analytics pipeline and legacy/adjacent API surfaces, and `TRR-APP/` owns UI plus Next.js server-side proxy layers.
- Cross-repo changes follow a fixed boundary order documented in `AGENTS.md`: `TRR-Backend/` first, `screenalytics/` second, `TRR-APP/` last.

## Layers

**Workspace orchestration layer:**
- Purpose: Start local services, enforce runtime defaults, validate prerequisites, and synchronize handoff/planning state.
- Location: `Makefile`, `scripts/dev-workspace.sh`, `scripts/preflight.sh`, `scripts/status-workspace.sh`, `scripts/doctor.sh`, `scripts/handoff-lifecycle.sh`, `scripts/check-workspace-contract.sh`, `scripts/lib/runtime-db-env.sh`, `profiles/default.env`
- Contains: Workspace entrypoints, PID/log management, profile loading, generated env-contract checks, browser wrapper hooks, and cross-repo verification commands.
- Depends on: Repo-local runtimes in `TRR-Backend/`, `TRR-APP/`, and `screenalytics/`, plus workspace docs in `docs/workspace/`.
- Used by: Humans and agents running `make dev`, `make status`, `make stop`, `make test-*`, or formal cross-repo workflows.

**Planning and continuity layer:**
- Purpose: Track active workstream state, milestone history, and codebase reference docs outside the nested repos.
- Location: `.planning/PROJECT.md`, `.planning/active-workstream`, `.planning/workstreams/feature-b/STATE.md`, `.planning/milestones/`, `.planning/codebase/`, `docs/ai/HANDOFF_WORKFLOW.md`, `docs/cross-collab/WORKFLOW.md`
- Contains: Workstream state, roadmap snapshots, codebase maps, handoff policy, and cross-repo sequencing rules.
- Depends on: Workspace policy in `AGENTS.md` and canonical status sources in repo or workspace docs.
- Used by: GSD planning/execution workflows and any agent handing work across sessions.

**TRR backend data and API layer:**
- Purpose: Own canonical schema, Supabase/Postgres access, public/admin HTTP APIs, and shared business logic.
- Location: `TRR-Backend/api/`, `TRR-Backend/trr_backend/`, `TRR-Backend/supabase/migrations/`, `TRR-Backend/tests/`
- Contains: FastAPI app bootstrap in `TRR-Backend/api/main.py`, route modules in `TRR-Backend/api/routers/`, repositories/services/clients in `TRR-Backend/trr_backend/`, and authoritative schema migrations in `TRR-Backend/supabase/migrations/`.
- Depends on: `TRR_DB_URL`/`TRR_DB_FALLBACK_URL`, Supabase auth/env contracts, and optional downstream service endpoints such as `SCREENALYTICS_API_URL`.
- Used by: `TRR-APP/` server-side routes, `screenalytics/` service-to-service callers, background workers, and direct admin tooling.

**TRR app presentation and proxy layer:**
- Purpose: Serve the public/admin web app, own route structure, and proxy internal admin/backend reads through Next.js server code.
- Location: `TRR-APP/apps/web/src/app/`, `TRR-APP/apps/web/src/components/`, `TRR-APP/apps/web/src/lib/server/`, `TRR-APP/apps/web/tests/`
- Contains: App Router routes and layouts, server route handlers, React components, admin proxy helpers, direct Postgres readers, and tests.
- Depends on: `TRR_API_URL` normalization in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, backend internal-admin headers from `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`, and selected direct DB reads under `TRR-APP/apps/web/src/lib/server/`.
- Used by: Public users, admins, workspace dev startup, and Vercel deployments.

**Screenalytics analytics and legacy companion layer:**
- Purpose: Run analytics workflows, expose its own FastAPI/Streamlit surfaces, and read or persist analytics state against the shared TRR database.
- Location: `screenalytics/apps/api/`, `screenalytics/apps/workspace-ui/`, `screenalytics/py_screenalytics/`, `screenalytics/packages/py-screenalytics/`, `screenalytics/tools/`, `screenalytics/tests/`
- Contains: FastAPI API bootstrap in `screenalytics/apps/api/main.py`, Streamlit UI in `screenalytics/apps/workspace-ui/`, reusable analytics package code, standalone pipeline tools, and ML/integration tests.
- Depends on: `TRR_DB_URL`/`TRR_DB_FALLBACK_URL` resolution in `screenalytics/apps/api/services/supabase_db.py`, optional `.env` loading in `screenalytics/apps/api/main.py`, and infrastructure templates in `screenalytics/infra/`.
- Used by: Analytics operators, backend service-to-service paths, and explicit local or hosted screenalytics workflows.

## Data Flow

**Workspace startup flow:**

1. `Makefile` routes `make dev` to `scripts/preflight.sh` and then `scripts/dev-workspace.sh`.
2. `scripts/dev-workspace.sh` loads `profiles/default.env`, resolves `TRR_DB_URL` through `scripts/lib/runtime-db-env.sh`, seeds workspace-only shared secrets when absent, and decides whether screenalytics runs in cloud-backed or explicit Docker fallback mode.
3. The script then starts `TRR-Backend/`, `TRR-APP/`, and optionally `screenalytics/` surfaces, writing runtime state under `.logs/workspace/` and exposing status via `scripts/status-workspace.sh`.

**TRR-APP -> TRR-Backend request flow:**

1. A Next.js page or route in `TRR-APP/apps/web/src/app/` calls server helpers in `TRR-APP/apps/web/src/lib/server/trr-api/` or `TRR-APP/apps/web/src/lib/server/admin/`.
2. `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts` normalizes `TRR_API_URL` to a `/api/v1` base and standardizes loopback behavior.
3. Proxy helpers such as `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts` and `TRR-APP/apps/web/src/app/api/admin/trr-api/cast-screentime/[...path]/route.ts` attach internal-admin headers and forward requests to backend routes.
4. `TRR-Backend/api/routers/*.py` delegate to repositories and services in `TRR-Backend/trr_backend/`, which execute SQL or Supabase admin calls against the shared database.

**TRR-Backend <-> screenalytics flow:**

1. `TRR-Backend/` exposes service-token-protected ingest and run-state endpoints in `TRR-Backend/api/routers/screenalytics.py` and `TRR-Backend/api/routers/screenalytics_runs_v2.py`.
2. `screenalytics/` can call those endpoints with `SCREENALYTICS_SERVICE_TOKEN` / shared service auth when backend-owned state must be updated from analytics work.
3. Legacy outbound backend calls that still depend on a separate screenalytics HTTP surface use `TRR-Backend/trr_backend/clients/screenalytics.py` and `SCREENALYTICS_API_URL`.

**Shared database flow:**

1. `TRR-Backend/` treats `TRR-Backend/supabase/migrations/` as the canonical schema history and validates startup DB lane selection in `TRR-Backend/api/main.py`.
2. `screenalytics/` resolves the same runtime database via `screenalytics/apps/api/services/supabase_db.py` and reads or writes both `core.*` and `screenalytics.*` objects.
3. `TRR-APP/` uses a mixed model: backend proxy calls for many admin/public reads and direct server-side Postgres reads for selected repositories under `TRR-APP/apps/web/src/lib/server/`.

**Planning and handoff flow:**

1. The active workstream is selected by `.planning/active-workstream`, not by a root `.planning/STATE.md`.
2. Current milestone/workstream continuity lives in `.planning/workstreams/feature-b/STATE.md` and `.planning/PROJECT.md`.
3. Formal implementation work is expected to update canonical status docs and then run `scripts/handoff-lifecycle.sh` as defined in `docs/cross-collab/WORKFLOW.md` and `docs/ai/HANDOFF_WORKFLOW.md`.

**State Management:**
- Workspace runtime state is file-based in `.logs/workspace/` and process-oriented through PID/env files emitted by `scripts/dev-workspace.sh`.
- Product state is database-first in the Supabase/Postgres schema managed by `TRR-Backend/supabase/migrations/`.
- `TRR-APP/` uses request-scoped server state and selective route/cache helpers under `TRR-APP/apps/web/src/lib/server/trr-api/`.
- `screenalytics/` combines shared database state with local artifact/manifests directories and long-running pipeline/tool execution in `screenalytics/tools/` and `screenalytics/apps/workspace-ui/`.

## Key Abstractions

**Repo ownership boundary:**
- Purpose: Prevent contract drift by keeping schema/API ownership in backend, analytics adaptation in screenalytics, and UI adaptation in TRR-APP.
- Examples: `AGENTS.md`, `TRR-Backend/AGENTS.md`, `TRR-APP/AGENTS.md`, `screenalytics/AGENTS.md`
- Pattern: Cross-repo sequencing contract

**Normalized backend base URL:**
- Purpose: Make all TRR-APP backend access resolve from one env-driven base and always target `/api/v1`.
- Examples: `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts`, `TRR-APP/apps/web/src/app/api/admin/trr-api/cast-screentime/[...path]/route.ts`
- Pattern: Server-side adapter/proxy layer

**Shared runtime DB contract:**
- Purpose: Ensure backend and screenalytics read the same preferred database env names and reject unsupported pooler lanes.
- Examples: `scripts/lib/runtime-db-env.sh`, `TRR-Backend/api/main.py`, `screenalytics/apps/api/services/supabase_db.py`, `docs/workspace/env-contract.md`
- Pattern: Environment-backed contract with validation

**Workstream-first planning model:**
- Purpose: Keep milestone context under `.planning/workstreams/` while `.planning/PROJECT.md` remains the high-level project anchor.
- Examples: `.planning/active-workstream`, `.planning/workstreams/feature-b/STATE.md`, `.planning/milestones/`
- Pattern: Workspace-local planning state machine

## Entry Points

**Workspace command surface:**
- Location: `Makefile`
- Triggers: Human or agent workspace commands such as `make dev`, `make status`, `make test-fast`, `make codex-check`
- Responsibilities: Route to preflight, orchestration scripts, cleanup, testing, browser helpers, and handoff sync

**Workspace dev orchestrator:**
- Location: `scripts/dev-workspace.sh`
- Triggers: `make dev`, `make dev-local`, or direct script invocation
- Responsibilities: Load profile defaults, resolve runtime DB envs, derive workspace secrets, start repo-local runtimes, and write process/log metadata

**Backend API application:**
- Location: `TRR-Backend/api/main.py`
- Triggers: Uvicorn or deployed backend runtime
- Responsibilities: Validate startup config, prewarm DB, initialize realtime broker, mount middleware, and serve route modules

**Screenalytics API application:**
- Location: `screenalytics/apps/api/main.py`
- Triggers: Uvicorn, local screenalytics API startup, or hosted screenalytics deployment
- Responsibilities: Load optional `.env`, apply CPU limits, install routers/error handlers, validate DB lane usage, and expose analytics endpoints

**TRR web application:**
- Location: `TRR-APP/apps/web/src/app/layout.tsx`
- Triggers: Next.js App Router startup in local or deployed runtime
- Responsibilities: Install global fonts, top-level providers, error boundary, debug panel, and the root page tree

**Screenalytics Streamlit workspace:**
- Location: `screenalytics/apps/workspace-ui/app.py`, `screenalytics/apps/workspace-ui/pages/`
- Triggers: Streamlit startup when explicitly enabled
- Responsibilities: Provide operator-facing workflow pages for upload, run/review, health, settings, and docs

## Error Handling

**Strategy:** Fail fast on invalid runtime contracts and normalize upstream failures at repo boundaries

**Patterns:**
- `TRR-Backend/api/main.py` validates database lane choice and required auth/env configuration during startup instead of tolerating partial misconfiguration.
- `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts` and `TRR-APP/apps/web/src/lib/server/trr-api/social-admin-proxy.ts` convert fetch failures, timeouts, and backend saturation into typed proxy errors and JSON responses.
- `screenalytics/apps/api/main.py` installs centralized FastAPI error handlers and keeps some optional subsystems behind guarded imports so health endpoints can stay up.

## Cross-Cutting Concerns

**Logging:** Workspace scripts log to `.logs/workspace/`; backend and screenalytics both attach request/trace observability in `TRR-Backend/api/main.py` and `screenalytics/apps/api/main.py`.
**Validation:** Workspace validation lives in `scripts/preflight.sh`, `scripts/doctor.sh`, and `scripts/check-workspace-contract.sh`; backend and screenalytics add runtime lane checks in `TRR-Backend/api/main.py` and `screenalytics/apps/api/services/supabase_db.py`.
**Authentication:** Internal admin and service-to-service auth flows are enforced through `TRR_INTERNAL_ADMIN_SHARED_SECRET`, `SCREENALYTICS_SERVICE_TOKEN`, `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`, and `TRR-Backend/api/screenalytics_auth.py`.

---

*Architecture analysis: 2026-04-06*
