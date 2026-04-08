# Technology Stack

**Analysis Date:** 2026-04-07

## Languages

**Primary:**
- TypeScript - Primary frontend and server-route language in `TRR-APP/apps/web/`, especially `TRR-APP/apps/web/src/app/` and `TRR-APP/apps/web/src/lib/`.
- Python 3.11.9 - Primary backend, pipeline, and API language in `TRR-Backend/api/`, `TRR-Backend/trr_backend/`, `screenalytics/apps/api/`, and `screenalytics/packages/py-screenalytics/`.

**Secondary:**
- SQL - Supabase/Postgres schema and migration source in `TRR-Backend/supabase/`.
- Bash - Workspace orchestration and repo automation in `Makefile`, `scripts/dev-workspace.sh`, `TRR-Backend/start-api.sh`, and `screenalytics/scripts/dev.sh`.
- JavaScript / MJS - Build and data-generation scripts in `TRR-APP/apps/web/scripts/` and the optional `screenalytics/web/` app.

## Runtime

**Environment:**
- Node.js `24.x` - Workspace baseline from `.nvmrc`, `TRR-APP/package.json`, and `TRR-APP/apps/web/package.json`.
- Python `3.11.9` - Repo-pinned in `TRR-Backend/.python-version` and `screenalytics/.python-version`.

**Package Manager:**
- `pnpm@10.15.0` - Primary JavaScript package manager for `TRR-APP/` from `TRR-APP/package.json`.
- `pip` with uv-compiled lockfiles - Python install flow for `TRR-Backend/requirements.txt`, `TRR-Backend/requirements.lock.txt`, `screenalytics/requirements-core.txt`, and `screenalytics/requirements-ml.txt`.
- `npm` - Present only for the optional `screenalytics/web/` prototype via `screenalytics/web/package-lock.json`.
- Lockfile: present at `TRR-APP/pnpm-lock.yaml`, `TRR-Backend/requirements.lock.txt`, `screenalytics/requirements-core.lock.txt`, `screenalytics/requirements-ml.lock.txt`, and `screenalytics/requirements-crawl.lock.txt`.

## Frameworks

**Core:**
- Next.js `16.1.6` - Main TRR web app framework in `TRR-APP/apps/web/package.json` with config in `TRR-APP/apps/web/next.config.ts`.
- React `19.1.0` - UI runtime for `TRR-APP/apps/web/`.
- FastAPI `0.135.2` - TRR backend API in `TRR-Backend/api/main.py` and Screenalytics API in `screenalytics/apps/api/main.py`.
- Streamlit - Screenalytics workspace UI in `screenalytics/apps/workspace-ui/streamlit_app.py`.
- Celery - Optional Screenalytics async worker lane wired from `screenalytics/apps/api/main.py`, `screenalytics/apps/api/config/__init__.py`, and `screenalytics/apps/api/routers/cast_screentime.py`.
- Modal - Remote long-job execution layer for TRR backend from `TRR-Backend/trr_backend/modal_jobs.py` and `TRR-Backend/trr_backend/modal_dispatch.py`.

**Testing:**
- Vitest `2.1.9` - Unit and integration tests for `TRR-APP/apps/web/` from `TRR-APP/apps/web/package.json`.
- Playwright `1.58.2` - Browser and e2e tests for `TRR-APP/apps/web/`.
- Pytest - Backend and pipeline testing configured in `TRR-Backend/pytest.ini`, `screenalytics/pyproject.toml`, and GitHub workflows under `TRR-Backend/.github/workflows/ci.yml` and `screenalytics/.github/workflows/ci.yml`.

**Build/Dev:**
- Turbopack / Webpack - Next.js dev and build bundlers in `TRR-APP/apps/web/package.json` and `TRR-APP/apps/web/next.config.ts`.
- Docker / Docker Compose - Container and local-infra fallback in `TRR-Backend/Dockerfile`, `screenalytics/Dockerfile.pipeline`, and `screenalytics/infra/docker/compose.yaml`.
- Firebase Emulator Suite - Local auth / Firestore emulation in `TRR-APP/package.json`, `TRR-APP/apps/web/README.md`, and `TRR-APP/.github/workflows/firebase-rules.yml`.
- Supabase CLI - Schema replay and docs generation in `TRR-Backend/Makefile` and `TRR-Backend/.github/workflows/repo_map.yml`.

## Key Dependencies

**Critical:**
- `firebase` and `firebase-admin` - Primary auth stack for the app, configured in `TRR-APP/package.json`, `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`, and `TRR-APP/apps/web/src/app/api/session/login/route.ts`.
- `@supabase/supabase-js` - Server-side admin auth fallback and direct Supabase access in `TRR-APP/apps/web/package.json`, `TRR-APP/apps/web/src/lib/server/auth.ts`, and `TRR-APP/apps/web/src/lib/server/supabase-trr-admin.ts`.
- `psycopg2` / direct Postgres access - Shared DB access for Screenalytics via `screenalytics/apps/api/services/supabase_db.py`; TRR backend uses its own DB session layer from `TRR-Backend/trr_backend/db/connection.py` and `TRR-Backend/api/deps.py`.
- `boto3` - Shared object-storage client in `TRR-Backend/trr_backend/object_storage.py`, `TRR-Backend/trr_backend/media/s3_mirror.py`, and `screenalytics/apps/api/services/storage.py`.
- `modal` - Remote worker orchestration and deployment contract in `TRR-Backend/trr_backend/modal_jobs.py`.

**Infrastructure:**
- `redis` - Optional realtime broker / cache / worker transport in `TRR-Backend/api/realtime/broker.py`, `screenalytics/apps/api/config/__init__.py`, and `screenalytics/apps/api/services/screentime_cache.py`.
- `anthropic`, `google-genai`, `openai` - AI-assisted diagnostics and generation surfaces in `TRR-Backend/requirements.lock.txt`, `TRR-APP/apps/web/src/app/api/design-docs/generate-image/route.ts`, and `screenalytics/apps/api/services/openai_diagnostics.py`.
- `requests` / `httpx` - External HTTP integrations across TMDb, Google News, and auth in `TRR-Backend/trr_backend/integrations/tmdb/client.py`, `TRR-Backend/trr_backend/scraping/google_news_parser.py`, and `TRR-Backend/trr_backend/db/admin.py`.

## Configuration

**Environment:**
- Workspace startup is profile-driven from `Makefile`, `scripts/dev-workspace.sh`, `profiles/default.env`, and the generated contract in `docs/workspace/env-contract.md`.
- Repo-local environment files exist at `TRR-Backend/.env`, `TRR-Backend/.env.example`, `screenalytics/.env`, `screenalytics/.env.example`, and repo-specific examples such as `screenalytics/web/.env.local.example`. Their contents were intentionally not read.
- `TRR_DB_URL` with optional `TRR_DB_FALLBACK_URL` is the runtime DB contract across repos, enforced in `TRR-Backend/trr_backend/db/connection.py` and `screenalytics/apps/api/services/supabase_db.py`.

**Build:**
- Next.js build config lives in `TRR-APP/apps/web/next.config.ts`.
- Vercel project linkage exists in `TRR-APP/.vercel/project.json`.
- Container entrypoints live in `TRR-Backend/Dockerfile`, `TRR-Backend/start-api.sh`, and `screenalytics/Dockerfile.pipeline`.
- CI definitions live under `TRR-APP/.github/workflows/`, `TRR-Backend/.github/workflows/`, and `screenalytics/.github/workflows/`.

## Platform Requirements

**Development:**
- Use `make dev` from the workspace root for the canonical cloud-first setup per `Makefile` and `docs/workspace/dev-commands.md`.
- Use `make dev-local` only when Screenalytics needs explicit local Redis + MinIO via `screenalytics/infra/docker/compose.yaml`.
- `ffmpeg` is required for Screenalytics media processing, documented in `screenalytics/README.md` and baked into `screenalytics/Dockerfile.pipeline`.

**Production:**
- `TRR-APP` targets Vercel with root directory `apps/web` per `TRR-APP/apps/web/DEPLOY.md` and `TRR-APP/.vercel/project.json`.
- `TRR-Backend` is containerized for Cloud Run / Render style hosting via `TRR-Backend/Dockerfile` and also dispatches long jobs to Modal via `TRR-Backend/trr_backend/modal_jobs.py`.
- `screenalytics` supports API/UI hosting plus Redis/object-storage backed workers, with Render-oriented deployment docs in `screenalytics/docs/ops/deployment/DEPLOYMENT_RENDER.md`.

---

*Stack analysis: 2026-04-07*
