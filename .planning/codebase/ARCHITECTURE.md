# Architecture

**Analysis Date:** 2026-04-07

## Pattern Overview

**Overall pattern:** Multi-repo workspace with strict ownership boundaries and a shared data contract.

**Key characteristics:**
- `TRR-Backend/` owns canonical schema, API, auth validation, and contract-first backend logic
- `screenalytics/` owns analytics workflows, ML/pipeline tooling, and operator-facing workspace UI
- `TRR-APP/` owns the public/admin web UI plus Next.js server proxy and app-specific server reads
- Root `Makefile`, `scripts/`, `docs/`, and `.planning/` coordinate the repos instead of replacing repo ownership

## Layers

**Workspace orchestration layer:**
- Purpose: start, stop, validate, and observe the full workspace
- Location: `Makefile`, `scripts/dev-workspace.sh`, `scripts/status-workspace.sh`, `scripts/preflight.sh`, `scripts/handoff-lifecycle.sh`
- Depends on: nested repo runtimes, workspace env profiles, shared docs

**Planning and continuity layer:**
- Purpose: hold workstream state, milestone context, and generated map docs
- Location: `.planning/PROJECT.md`, `.planning/active-workstream`, `.planning/workstreams/`, `.planning/codebase/`
- Important note: there is no root `.planning/STATE.md` in the current workspace

**Backend contract/data layer:**
- Purpose: schema ownership, API surface, core business logic, shared data access
- Location: `TRR-Backend/api/`, `TRR-Backend/trr_backend/`, `TRR-Backend/supabase/migrations/`
- Entry: `TRR-Backend/api/main.py`

**App presentation/proxy layer:**
- Purpose: route/render UI and mediate app-side access to backend/admin surfaces
- Location: `TRR-APP/apps/web/src/app/`, `TRR-APP/apps/web/src/components/`, `TRR-APP/apps/web/src/lib/server/`
- Entry: `TRR-APP/apps/web/src/app/layout.tsx`

**Analytics/pipeline layer:**
- Purpose: expose analytics APIs, run pipeline tools, support operator workflows, and persist analytics results
- Location: `screenalytics/apps/api/`, `screenalytics/apps/workspace-ui/`, `screenalytics/tools/`, `screenalytics/packages/py-screenalytics/`
- Entries: `screenalytics/apps/api/main.py`, `screenalytics/apps/workspace-ui/streamlit_app.py`, `screenalytics/tools/episode_run.py`

## Data Flow

**Workspace startup flow:**
1. `Makefile` routes `make dev` into root scripts.
2. `scripts/dev-workspace.sh` loads profiles, resolves runtime env, and decides which services to boot.
3. Repo-local runtimes start and write operational state under `.logs/workspace/`.

**TRR-APP -> TRR-Backend flow:**
1. App routes or pages invoke helpers under `TRR-APP/apps/web/src/lib/server/trr-api/`.
2. `TRR_API_URL` is normalized to `/api/v1` in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.
3. Route handlers or server helpers forward to backend endpoints, attaching internal admin/service credentials when required.
4. Backend routers delegate to repositories/services in `TRR-Backend/trr_backend/`.

**TRR-Backend <-> screenalytics flow:**
1. Backend exposes screenalytics-facing endpoints and shared contracts first.
2. Screenalytics reads or writes shared state through DB access and token-protected service calls.
3. Legacy backend-to-screenalytics HTTP flows still exist but are no longer the preferred path for every analytics operation.

**Shared database flow:**
1. Canonical schema changes land in `TRR-Backend/supabase/migrations/`.
2. Backend runtime validates the selected DB lane at startup in `TRR-Backend/api/main.py`.
3. Screenalytics and selected app server code consume the same DB precedence contract.

## State Management

- Shared durable state is database-first in Supabase/Postgres
- Workspace operational state is file-based in `.logs/workspace/` and `.planning/`
- App runtime state is request/server-component driven, with selected client state inside React pages/components
- Screenalytics combines shared DB state with local artifact/manifests directories and long-running pipeline outputs under `screenalytics/data/` and `screenalytics/tools/`

## Key Abstractions

**Repo-order ownership contract:**
- Defined by `AGENTS.md`
- Cross-repo order is backend first, then screenalytics, then app

**Backend base normalization:**
- `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`
- Prevents path drift and keeps `/api/v1` ownership centralized

**Runtime DB contract:**
- Shared precedence of `TRR_DB_URL` then `TRR_DB_FALLBACK_URL`
- Enforced by backend, app server helpers, and screenalytics DB services

**Workstream-first planning model:**
- Active marker: `.planning/active-workstream`
- Continuity lives under `.planning/workstreams/`, not a root state file

## Entry Points

**Workspace:**
- `Makefile`
- `scripts/dev-workspace.sh`

**Backend:**
- `TRR-Backend/api/main.py`
- `TRR-Backend/trr_backend/cli/__main__.py`

**App:**
- `TRR-APP/apps/web/src/app/layout.tsx`
- `TRR-APP/apps/web/src/app/page.tsx`

**Screenalytics:**
- `screenalytics/apps/api/main.py`
- `screenalytics/apps/workspace-ui/streamlit_app.py`
- `screenalytics/tools/episode_run.py`

## Error Handling

**General strategy:** fail fast on invalid runtime contracts, then normalize boundary errors close to the edge.

**Observed patterns:**
- Backend startup validates env and DB lane configuration in `TRR-Backend/api/main.py`
- Screenalytics installs centralized FastAPI error handlers in `screenalytics/apps/api/main.py`
- App server helpers normalize backend/admin fetch failures into route-safe responses and explicit errors rather than leaking raw upstream failures

## Cross-Cutting Concerns

- Logging: Python `logging` in backend/screenalytics, targeted `console` diagnostics in app server/client code
- Observability: trace IDs and metrics in both FastAPI apps
- Authentication: Firebase for app-facing identity, Supabase/admin JWT validation for server surfaces, shared secrets for internal service flows
- Browser verification: managed Chrome is part of the workspace contract, not an ad hoc per-repo behavior

---

*Architecture analysis refreshed: 2026-04-07*
