# TRR Workspace Stack Map

Updated from workspace scan on 2026-04-07.

## Workspace Scope

- Workspace root: `/Users/thomashulihan/Projects/TRR`
- Primary repos in active cross-repo policy:
  - `TRR-Backend/` - FastAPI + Supabase/Postgres backend
  - `screenalytics/` - FastAPI + Streamlit + Python ML pipeline
  - `TRR-APP/` - Next.js App Router frontend plus a small Vue app
- Shared workspace policy lives in `AGENTS.md`.

## Runtime Baselines

- Workspace target runtime from `AGENTS.md`: Node `24.x`, Python `3.11`
- `TRR-APP/package.json` pins `pnpm@10.15.0` and `engines.node = 24.x`
- `TRR-APP/apps/web/package.json` also pins `engines.node = 24.x`
- `screenalytics/packages/py-screenalytics/pyproject.toml` requires Python `>=3.11`
- `TRR-Backend/.github/workflows/ci.yml` tests Python `3.11.9` with a `3.12` canary lane
- `screenalytics/.github/workflows/ci.yml` tests Python `3.11.9` with a `3.12` canary lane

## Backend Stack

### TRR-Backend

- API framework: FastAPI in `TRR-Backend/api/main.py`
- Realtime path: broker/websocket support under `TRR-Backend/api/realtime/`
- CLI: Typer entrypoint in `TRR-Backend/trr_backend/cli/__main__.py`
- DB access: psycopg2-style access in `TRR-Backend/trr_backend/db/pg.py` and `TRR-Backend/trr_backend/db/connection.py`
- Database system: Supabase/Postgres with migrations under `TRR-Backend/supabase/migrations/`
- Schema documentation: generated docs under `TRR-Backend/supabase/schema_docs/`
- Object storage/media lane: `TRR-Backend/trr_backend/object_storage.py`, `TRR-Backend/trr_backend/media/s3_mirror.py`, `TRR-Backend/trr_backend/media/user_uploads.py`
- Observability: `TRR-Backend/trr_backend/observability.py`
- Local and container runtime: `TRR-Backend/Dockerfile`

### screenalytics

- API framework: FastAPI in `screenalytics/apps/api/main.py`
- Background jobs: Celery support in `screenalytics/apps/api/celery_app.py`, `screenalytics/apps/api/tasks.py`, `screenalytics/apps/api/tasks_v2.py`
- Queue/cache: Redis referenced from `screenalytics/apps/api/config/__init__.py` and readiness checks in `screenalytics/apps/api/main.py`
- UI framework: Streamlit entrypoint in `screenalytics/apps/workspace-ui/streamlit_app.py`
- Python package boundary: reusable package in `screenalytics/packages/py-screenalytics/pyproject.toml`
- ML stack from README and source:
  - RetinaFace / InsightFace
  - ByteTrack
  - ArcFace embeddings
  - ONNX/Torch-dependent pipeline modules in `screenalytics/apps/api/services/onnx_providers.py` and package code under `screenalytics/packages/py-screenalytics/src/py_screenalytics/`
- Storage layer: S3-compatible object storage helpers in `screenalytics/apps/api/services/storage.py` and `screenalytics/apps/api/services/storage_v2.py`
- Postgres access: `screenalytics/apps/api/services/supabase_db.py`

## Frontend Stack

### TRR-APP

- Main app framework: Next.js App Router in `TRR-APP/apps/web/`
- React version: `19.1.0` in `TRR-APP/apps/web/package.json`
- Next version: `16.1.6` in `TRR-APP/apps/web/package.json`
- TypeScript: strict TS config in `TRR-APP/apps/web/tsconfig.json`
- Styling pipeline: PostCSS + Tailwind v4 packages in `TRR-APP/apps/web/package.json`
- Test stack:
  - Vitest in `TRR-APP/apps/web/vitest.config.ts`
  - Playwright in `TRR-APP/apps/web/playwright.config.ts`
  - Testing Library and `vitest-axe` in `TRR-APP/apps/web/package.json`
- Server/client split:
  - server-only modules under `TRR-APP/apps/web/src/lib/server/`
  - client components throughout `TRR-APP/apps/web/src/app/` and `TRR-APP/apps/web/src/components/`
- Secondary app: Vue 3 + Vite in `TRR-APP/apps/vue-wordle/package.json`

## Package and Tooling Systems

- JS package manager: pnpm workspace in `TRR-APP/pnpm-workspace.yaml`
- Python dependency flow:
  - `TRR-Backend/requirements.txt` -> `TRR-Backend/requirements.lock.txt`
  - multiple screenalytics requirements lanes such as `screenalytics/requirements-core.txt`, `screenalytics/requirements-ml.txt`, `screenalytics/requirements-ci.txt`
- Workspace orchestration via root `Makefile`
- Repo-level developer shortcuts:
  - `TRR-Backend/Makefile`
  - `screenalytics/Makefile`

## Platform and Deployment Surfaces

- TRR frontend deployment surface: Vercel cron config in `TRR-APP/apps/web/vercel.json`
- TRR backend deployment hints: `TRR-Backend/Dockerfile` mentions Cloud Run/Render style `PORT`
- screenalytics local/dev infra described in `screenalytics/README.md` and Make targets; Dockerized infra is referenced there for Postgres/Redis/MinIO

## Build and Config Hotspots

- `TRR-APP/apps/web/next.config.ts` contains:
  - Firebase package aliasing
  - typed route opt-in
  - Turbopack root override
  - image remote patterns
  - large redirect/rewrite surface
- `TRR-Backend/api/main.py` contains:
  - startup validation
  - CORS
  - broker lifecycle
  - observability
  - stale-run sweeper wiring
- `screenalytics/apps/api/main.py` contains:
  - dotenv bootstrap
  - CPU limits
  - router registration
  - readiness and dependency checks

## Notable Libraries and Service SDKs Seen in Source

- Supabase auth/admin usage in `TRR-APP/apps/web/src/lib/server/supabase-trr-admin.ts`
- Firebase client/admin usage in:
  - `TRR-APP/apps/web/src/lib/firebase.ts`
  - `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`
  - `TRR-APP/apps/web/src/lib/server/auth.ts`
- Requests-based internal service calls in `screenalytics/apps/api/services/trr_ingest.py` and `screenalytics/apps/api/services/cast_screentime.py`
- PyJWT usage in:
  - `TRR-Backend/trr_backend/security/jwt.py`
  - `TRR-Backend/trr_backend/security/internal_admin.py`
- Boto3-backed storage lanes in:
  - `TRR-Backend/trr_backend/media/s3_mirror.py`
  - `screenalytics/apps/api/services/storage.py`
  - `TRR-APP/scripts/upload-fonts-to-s3.py`
