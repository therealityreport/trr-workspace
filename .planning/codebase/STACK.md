# Technology Stack

**Analysis Date:** 2026-04-02

## Languages

**Primary:**
- TypeScript - Frontend and server route code in `TRR-APP/apps/web/src/**`, optional Next.js prototype code in `screenalytics/web/**`, and workspace app code in `TRR-APP/apps/vue-wordle/**`.
- Python 3.11.9 - Backend and pipeline code in `TRR-Backend/api/**`, `TRR-Backend/trr_backend/**`, `screenalytics/apps/**`, and `screenalytics/packages/py-screenalytics/**`.

**Secondary:**
- JavaScript / ESM scripts - Build, migration, and design-doc tooling in `TRR-APP/apps/web/scripts/**`.
- TOML / YAML / JSON - Runtime and deployment config in `TRR-Backend/supabase/config.toml`, `TRR-Backend/render.yaml`, `TRR-APP/apps/web/vercel.json`, `TRR-APP/pnpm-workspace.yaml`, and GitHub Actions workflow files under each repo’s `.github/workflows/`.
- SQL - Database ownership lives under `TRR-Backend/supabase/**`; app-side migrations are triggered by `TRR-APP/apps/web/scripts/run-migrations.mjs`.

## Runtime

**Environment:**
- Node `24.x` is the workspace JS target from `.nvmrc`, `TRR-APP/.nvmrc`, `TRR-APP/package.json`, and `screenalytics/web/package.json`.
- Python `3.11.9` is the pinned backend/runtime target from `TRR-Backend/.python-version` and `screenalytics/.python-version`.
- Container runtime targets use Debian Bookworm slim base images in `TRR-Backend/Dockerfile` and `screenalytics/Dockerfile.pipeline`.

**Package Manager:**
- `pnpm@10.15.0` is the canonical JS package manager in `TRR-APP/package.json`.
- Lockfile: present in `TRR-APP/pnpm-lock.yaml` and `TRR-APP/apps/web/pnpm-lock.yaml`.
- Python installs use `pip install -r requirements.txt`, but Python locks are compiled with `uv` from `TRR-Backend/requirements.in` -> `TRR-Backend/requirements.lock.txt` and `screenalytics/requirements-*.in` -> `screenalytics/requirements-*.lock.txt`.
- `hatchling` builds the shared Python package defined in `screenalytics/packages/py-screenalytics/pyproject.toml`.

## Frameworks

**Core:**
- Next.js `16.1.6` + React `19.1.0` in `TRR-APP/apps/web/package.json` for the primary TRR web/admin surface.
- FastAPI `0.135.2` in `TRR-Backend/requirements.lock.txt` for the TRR API in `TRR-Backend/api/main.py`.
- FastAPI `0.129.0` in `screenalytics/requirements-core.in` for the Screenalytics API in `screenalytics/apps/api/main.py`.
- Streamlit `1.54.0` in `screenalytics/requirements-core.in` for the Screenalytics operator UI under `screenalytics/apps/workspace-ui/**`.
- Next.js `14.2.35` + React `18.2.0` in `screenalytics/web/package.json` for the optional Screenalytics web prototype.

**Testing:**
- Vitest `2.1.9` in `TRR-APP/apps/web/package.json` with config in `TRR-APP/apps/web/vitest.config.ts`.
- Playwright `1.58.2` in `TRR-APP/apps/web/package.json` for E2E coverage via `TRR-APP/apps/web/scripts` and `TRR-APP/apps/web/tests/e2e/**`.
- Pytest `8.x` in `TRR-Backend/requirements.in`, `screenalytics/requirements-core.in`, and their CI workflows.

**Build/Dev:**
- Turbopack and Webpack are both used by `TRR-APP/apps/web/package.json`; `TRR-APP/apps/web/next.config.ts` keeps Webpack aliases and Turbopack root config in sync.
- Tailwind CSS `4.x` and `@tailwindcss/postcss` drive frontend styling in `TRR-APP/apps/web/package.json` and `screenalytics/web/package.json`.
- Uvicorn + Gunicorn back the Python APIs via `TRR-Backend/Dockerfile`, `TRR-Backend/requirements.in`, and `screenalytics/apps/api/main.py`.
- Celery `5.6.2` with Redis backs background jobs in `screenalytics/apps/api/celery_app.py`.
- Modal `1.4.0` backs TRR remote long-job execution in `TRR-Backend/trr_backend/modal_dispatch.py`.

## Key Dependencies

**Critical:**
- `firebase` / `firebase-admin` in `TRR-APP/apps/web/package.json` and `TRR-APP/package.json` for client auth, session setup, Firestore-backed features, and emulator support in `TRR-APP/apps/web/src/lib/firebase.ts`, `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`, and `TRR-APP/apps/web/src/lib/server/auth.ts`.
- `@supabase/supabase-js` in `TRR-APP/apps/web/package.json` for Supabase-auth verification and admin access in `TRR-APP/apps/web/src/lib/server/auth.ts` and `TRR-APP/apps/web/src/lib/server/supabase-trr-admin.ts`.
- `pg` in `TRR-APP/apps/web/package.json` for direct Postgres reads/writes and migrations in `TRR-APP/apps/web/src/lib/server/postgres.ts` and `TRR-APP/apps/web/scripts/run-migrations.mjs`.
- `supabase==2.28.3` and `postgrest==2.28.3` in `TRR-Backend/requirements.in` for backend-side Supabase access.
- `psycopg2-binary` in `TRR-Backend/requirements.in` and `screenalytics/requirements-core.in` for direct Postgres access.
- `boto3` in `TRR-Backend/requirements.in` and `screenalytics/requirements-core.in` for S3/R2-compatible object storage.
- `modal` in `TRR-Backend/requirements.in` for remote execution ownership and job dispatch.
- `celery[redis]` and `redis` in `screenalytics/requirements-core.in` for asynchronous Screenalytics processing.

**Infrastructure:**
- `google-genai` in `TRR-Backend/requirements.in` and `screenalytics/requirements-ml.in` for Gemini-based enrichment and ML-adjacent tooling.
- `anthropic` in `TRR-Backend/requirements.in` and `screenalytics/requirements-core.in` for Claude-based computer-use and diagnostics flows.
- `openai` appears in `screenalytics/web/package.json` and is used directly in `screenalytics/apps/api/services/openai_diagnostics.py` and `TRR-APP/apps/web/src/app/api/design-docs/generate-image/route.ts`.
- `torch`, `torchvision`, `ultralytics`, `insightface`, `onnxruntime`, `faiss-cpu`, `hdbscan`, and `pgvector` in `screenalytics/requirements-ml.in` define the optional ML pipeline.
- `@tanstack/react-query`, `zod`, `@prisma/client`, and `prisma` in `screenalytics/web/package.json` support the optional Screenalytics Next.js app.

## Configuration

**Environment:**
- Root Node version pin lives in `.nvmrc`; repo-level pins live in `TRR-APP/.nvmrc`, `TRR-Backend/.python-version`, and `screenalytics/.python-version`.
- Workspace env contract is documented in `docs/workspace/env-contract.md`.
- Env files are present but must not be read directly: `TRR-Backend/.env`, `TRR-Backend/.env.example`, `TRR-APP/apps/web/.env.example`, `TRR-APP/apps/web/.env.local`, `TRR-APP/apps/web/.env.production.local`, `TRR-APP/apps/web/.env.vercel.local`, `screenalytics/.env`, `screenalytics/.env.example`, and `screenalytics/web/.env.local.example`.
- Runtime DB resolution is standardized on `TRR_DB_URL` then `TRR_DB_FALLBACK_URL` in `TRR-Backend/trr_backend/db/connection.py`, `screenalytics/apps/api/services/supabase_db.py`, and `TRR-APP/apps/web/src/lib/server/postgres.ts`.
- Frontend auth/config surfaces are statically read from `TRR-APP/apps/web/src/lib/firebase-client-config.ts`, `TRR-APP/apps/web/src/lib/server/auth.ts`, and `TRR-APP/apps/web/src/lib/server/supabase-trr-admin.ts`.

**Build:**
- JS workspace config: `TRR-APP/pnpm-workspace.yaml`, `TRR-APP/apps/web/tsconfig.json`, `TRR-APP/apps/web/next.config.ts`, `TRR-APP/apps/web/vitest.config.ts`.
- Optional Screenalytics web config: `screenalytics/web/next.config.mjs`, `screenalytics/web/tsconfig.json`.
- Python local Supabase stack config: `TRR-Backend/supabase/config.toml`.
- Deployment descriptors: `TRR-APP/apps/web/vercel.json`, `TRR-Backend/render.yaml`, `TRR-Backend/Dockerfile`, `screenalytics/Dockerfile.pipeline`.
- CI workflows: `TRR-APP/.github/workflows/web-tests.yml`, `TRR-Backend/.github/workflows/ci.yml`, `screenalytics/.github/workflows/ci.yml`.

## Platform Requirements

**Development:**
- Node `24.x` with Corepack/pnpm for `TRR-APP/**`.
- Python `3.11.9` virtualenvs for `TRR-Backend/**` and `screenalytics/**`.
- Docker is required for the Supabase local stack in `TRR-Backend/supabase/config.toml` and for the default Screenalytics local infra described in `screenalytics/README.md`; `screenalytics` also supports a no-Docker mode with external Redis/object storage.
- `ffmpeg` is required by `screenalytics/Dockerfile.pipeline` and the Screenalytics local setup in `screenalytics/README.md`.

**Production:**
- `TRR-APP/apps/web` is Vercel-oriented via `TRR-APP/apps/web/vercel.json` and cron route handlers in `TRR-APP/apps/web/src/app/api/cron/**`.
- `TRR-Backend` is containerized for generic HTTP platforms via `TRR-Backend/Dockerfile`; `TRR-Backend/render.yaml` explicitly defines a Render web service, and the container entrypoint is also Cloud Run compatible.
- `screenalytics` production is container- and worker-oriented: API in `screenalytics/apps/api/main.py`, Celery workers in `screenalytics/apps/api/celery_app.py`, optional Streamlit UI in `screenalytics/apps/workspace-ui/streamlit_app.py`, and object storage/Redis/Postgres dependencies from `screenalytics/apps/api/config/__init__.py`.

---

*Stack analysis: 2026-04-02*
