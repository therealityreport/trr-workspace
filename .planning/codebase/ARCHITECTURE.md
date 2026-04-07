# TRR Workspace Architecture

## Scope

This document describes the current multi-repo architecture for the TRR workspace rooted at `/Users/thomashulihan/Projects/TRR`.

Primary repos:

- `TRR-Backend/` - canonical API, schema, auth enforcement, object-storage and long-job control plane
- `screenalytics/` - video-analysis API, pipeline execution, artifact handling, and Streamlit workspace
- `TRR-APP/` - public and admin web UI, plus server-side proxies onto backend contracts

Cross-repo ordering and trust boundaries are defined in `AGENTS.md`.

## System Shape

The workspace is a coordinated multi-repo system, not a single app with internal packages.

High-level boundaries:

- `TRR-APP` owns rendering, user/admin interaction, and app-local server routes
- `TRR-Backend` owns shared data contracts, Supabase/Postgres schema, admin APIs, and most external-content ingestion
- `screenalytics` owns video-asset processing, run state, ML pipeline stages, screentime analysis, and review tooling

The main cross-repo contract order is:

1. `TRR-Backend` changes shared schema/API/auth
2. `screenalytics` adapts reader/writer behavior when backend contracts shift
3. `TRR-APP` updates UI and proxy consumers last

## Primary Entry Points

### Workspace Startup

- Root orchestration lives in `Makefile`
- Shared runtime boot logic lives in `scripts/dev-workspace.sh`
- Shared env and health policy live in `docs/workspace/env-contract.md`

The workspace startup model is cloud-first. Local development usually runs `TRR-APP` and `TRR-Backend` directly, with `screenalytics` partially or fully optional depending on the chosen workspace mode.

### `TRR-Backend`

- FastAPI app entrypoint: `TRR-Backend/api/main.py`
- Router registration hub: `TRR-Backend/api/main.py`
- DB lane resolution: `TRR-Backend/trr_backend/db/connection.py`
- DB session/admin wrappers: `TRR-Backend/api/deps.py`, `TRR-Backend/trr_backend/db/`
- Remote job dispatch: `TRR-Backend/trr_backend/modal_dispatch.py`
- Modal function definitions: `TRR-Backend/trr_backend/modal_jobs.py`
- Supabase schema and migrations: `TRR-Backend/supabase/migrations/`

The backend is the authoritative write layer for shared domain objects such as shows, seasons, episodes, cast, brands, social analytics, media assets, and admin operations.

### `screenalytics`

- FastAPI API entrypoint: `screenalytics/apps/api/main.py`
- Streamlit entrypoint: `screenalytics/apps/workspace-ui/streamlit_app.py`
- Celery worker entrypoint: `screenalytics/apps/api/celery_app.py`
- Pipeline/package code: `screenalytics/packages/py-screenalytics/src/py_screenalytics/`
- API service layer: `screenalytics/apps/api/services/`
- Pipeline and model configs: `screenalytics/config/pipeline/`

The Screenalytics API exposes episode, runs, jobs, facebank, cast, screentime, and artifact endpoints. It also manages local or remote artifact state and optional queue-backed processing.

### `TRR-APP`

- Next.js App Router root: `TRR-APP/apps/web/src/app/`
- Global layout: `TRR-APP/apps/web/src/app/layout.tsx`
- Public/admin pages: `TRR-APP/apps/web/src/app/**/page.tsx`
- App-side API routes: `TRR-APP/apps/web/src/app/api/**/route.ts`
- Server-only integration layer: `TRR-APP/apps/web/src/lib/server/`
- Backend base normalization: `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`

The app acts as both a UI layer and a policy-enforcing proxy layer. Many admin routes in `src/app/api/admin/trr-api/` translate local session/auth state into trusted calls to backend admin endpoints.

## Architectural Layers

### Layer 1: Presentation

- Next.js route trees and React components in `TRR-APP/apps/web/src/app/` and `TRR-APP/apps/web/src/components/`
- Streamlit pages in `screenalytics/apps/workspace-ui/pages/`

This layer handles navigation, rendering, client interaction, and route-specific access control.

### Layer 2: Server Adapters and Proxies

- App server adapters in `TRR-APP/apps/web/src/lib/server/`
- Admin backend proxy helpers in `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts` and `TRR-APP/apps/web/src/lib/server/trr-api/social-admin-proxy.ts`
- Screenalytics ingest bridge in `screenalytics/apps/api/services/trr_ingest.py`

This layer converts UI intents into backend- or pipeline-safe requests while enforcing server-only execution and shared-secret based trust boundaries.

### Layer 3: HTTP APIs

- Backend routers in `TRR-Backend/api/routers/`
- Screenalytics routers in `screenalytics/apps/api/routers/`

The router layout is feature-oriented rather than generic CRUD. Large vertical domains such as brands, show sync, social analytics, cast photos, and Screenalytics episodes/runs each own large route modules.

### Layer 4: Services and Domain Logic

- Backend domain code in `TRR-Backend/trr_backend/`
- Screenalytics service layer in `screenalytics/apps/api/services/`
- Shared package logic in `screenalytics/packages/py-screenalytics/src/py_screenalytics/`

This is where orchestration, validation, external API calls, storage decisions, and workflow sequencing live.

### Layer 5: Persistence and Artifact Stores

- Supabase/Postgres via `TRR_DB_URL` and `TRR_DB_FALLBACK_URL`
- Backend object storage via `TRR-Backend/trr_backend/media/s3_mirror.py`
- Screenalytics artifact storage via `screenalytics/apps/api/services/storage_backend.py`, `screenalytics/apps/api/services/storage.py`, and `screenalytics/apps/api/services/storage_v2.py`

The workspace uses a split persistence model:

- relational data in Postgres/Supabase
- media and derived artifacts in S3-compatible object storage
- local manifests, progress files, and run bundles in the Screenalytics data tree

## Major Data Flows

### Admin UI -> Backend Admin API

1. React or server routes in `TRR-APP/apps/web/src/app/admin/**`
2. App-local API routes in `TRR-APP/apps/web/src/app/api/admin/trr-api/**/route.ts`
3. Trusted proxy helpers in `TRR-APP/apps/web/src/lib/server/trr-api/`
4. Backend admin endpoints under `TRR-Backend/api/routers/admin_*.py`
5. Backend repository/service code under `TRR-Backend/trr_backend/`

This is the dominant path for admin workflows.

### App -> Backend Public Reads

1. Public pages under `TRR-APP/apps/web/src/app/`
2. Server repositories like `TRR-APP/apps/web/src/lib/server/trr-api/trr-shows-repository.ts`
3. Backend endpoints under `TRR-Backend/api/routers/shows.py`, `surveys.py`, `socials.py`, and related routers

This path lets the web app stay aligned to backend-owned response contracts instead of duplicating data access logic.

### Backend -> Modal

1. API route or service detects long-running work
2. Dispatch logic resolves the configured function in `TRR-Backend/trr_backend/modal_dispatch.py`
3. Modal app functions in `TRR-Backend/trr_backend/modal_jobs.py` execute remote work
4. Status and recovery surface back through backend operations tables and APIs

This architecture keeps expensive or long-running social and ingestion jobs out of the synchronous API path.

### Backend <-> Screenalytics

1. Backend coordinates or validates shared metadata, auth, and DB contracts
2. Screenalytics pulls or pushes state through `screenalytics/apps/api/services/trr_ingest.py` and `screenalytics/apps/api/services/cast_screentime.py`
3. Both repos align against the same Postgres contract instead of treating each other as separate source-of-truth databases

The preferred integration path is increasingly database and contract based, not arbitrary inter-service HTTP.

### Screenalytics Run Processing

1. Episode/run request enters `screenalytics/apps/api/routers/episodes.py` or `runs_v2.py`
2. Service code coordinates run state in `screenalytics/apps/api/services/run_state.py`, `run_persistence.py`, and `pipeline_orchestration.py`
3. Stage-specific logic executes from the package code in `screenalytics/packages/py-screenalytics/src/py_screenalytics/`
4. Artifacts are written through storage backends and later surfaced to the Streamlit workspace or API callers

This flow is artifact-first and pipeline-stage aware rather than simple row-level CRUD.

## Repo-Specific Architectural Patterns

### `TRR-Backend`

Observed patterns:

- feature-heavy router modules under `api/routers/`
- service and repository helpers under `trr_backend/`
- strict startup validation in `api/main.py`
- operational code colocated with product code for jobs, media, and external ingestion

The backend mixes classic API routing with an internal job-plane architecture. It is closer to an application platform than a thin CRUD service.

### `screenalytics`

Observed patterns:

- router -> service -> storage/pipeline layering in `apps/api/`
- separate human-ops UI in `apps/workspace-ui/`
- packaged ML/domain logic under `packages/py-screenalytics/`
- optional v2 APIs behind feature flags in `apps/api/main.py`

This repo uses a hybrid product architecture: API, local operator UI, and heavy processing code are all in one codebase.

### `TRR-APP`

Observed patterns:

- App Router route ownership in `src/app/`
- server-only helpers under `src/lib/server/`
- large admin feature surface under `src/app/admin/` and `src/components/admin/`
- many app-local route handlers that proxy backend admin APIs

The app is not just a frontend. It is a boundary layer that translates browser sessions and admin tooling into trusted backend interactions.

## Cross-Repo Coupling Points

The highest-coupling areas are:

- shared database env and lane validation across all three repos
- backend-owned admin API paths consumed by `TRR-APP`
- backend-owned schema and views consumed by `screenalytics`
- service secrets `TRR_INTERNAL_ADMIN_SHARED_SECRET` and `SCREENALYTICS_SERVICE_TOKEN`
- shared operational scripts in `scripts/` and workspace docs under `docs/workspace/`

These are the primary areas where cross-repo changes can cascade.

## Architectural Read

The current architecture is intentionally centralized around backend-owned contracts, with the other repos adapting around that center:

- `TRR-Backend` is the system-of-record API and schema layer
- `screenalytics` is a specialized processing subsystem with its own API and operator UI
- `TRR-APP` is a rendering and integration boundary that keeps most critical server logic on the server side

The system favors explicit boundary files, operational guardrails, and contract-first routing over framework purity.
