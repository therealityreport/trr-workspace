# Technology Stack

**Analysis Date:** 2026-04-06

## Languages

**Primary:**
- Python 3.11 - backend and pipeline runtime in `TRR-Backend/requirements.in`, `TRR-Backend/ruff.toml`, `screenalytics/packages/py-screenalytics/pyproject.toml`, and workspace target in `AGENTS.md`
- TypeScript - app and UI/server code in `TRR-APP/apps/web/`, plus the secondary Vue app in `TRR-APP/apps/vue-wordle/`
- Bash - workspace orchestration and agent/browser wrappers in `Makefile`, `scripts/dev-workspace.sh`, `scripts/workspace-env-contract.sh`, and `scripts/codex-chrome-devtools-mcp.sh`

**Secondary:**
- SQL - Supabase migrations and seed data in `TRR-Backend/supabase/migrations/` and `TRR-Backend/supabase/seed.sql`
- Markdown - workspace policy, handoff, and planning assets in `AGENTS.md`, `docs/`, and `.planning/`
- TOML / JSON / YAML - runtime and tool config in `TRR-Backend/supabase/config.toml`, `screenalytics/pyproject.toml`, `TRR-APP/apps/web/vercel.json`, `TRR-APP/.vercel/project.json`, and `.planning/config.json`

## Runtime

**Environment:**
- Node.js 24.x - workspace baseline from `.nvmrc`, `TRR-APP/package.json`, and `TRR-APP/apps/web/package.json`
- Python 3.11 - workspace baseline in `AGENTS.md`, backend lint target in `TRR-Backend/ruff.toml`, and screenalytics package requirement in `screenalytics/packages/py-screenalytics/pyproject.toml`

**Package Manager:**
- `pnpm` 10.15.0 - app package manager in `TRR-APP/package.json`
- `pip` with `uv`-compiled lockfiles - backend installs from `TRR-Backend/requirements.txt` -> `TRR-Backend/requirements.lock.txt`, and screenalytics installs from `screenalytics/requirements*.txt`
- Lockfile: present in `TRR-APP/pnpm-lock.yaml`, `TRR-APP/apps/web/pnpm-lock.yaml`, `TRR-Backend/requirements.lock.txt`, `screenalytics/requirements-core.lock.txt`, and `screenalytics/requirements-crawl.lock.txt`

## Frameworks

**Core:**
- Next.js 16.1.6 - primary web/admin app in `TRR-APP/apps/web/package.json` with config in `TRR-APP/apps/web/next.config.ts`
- React 19.1.0 - UI runtime for `TRR-APP/apps/web/`
- FastAPI 0.135.2 - backend API in `TRR-Backend/api/main.py` and backend deps in `TRR-Backend/requirements.in`
- FastAPI - screenalytics API in `screenalytics/apps/api/main.py`
- Vue 3.5.31 + Vite 8 - secondary app in `TRR-APP/apps/vue-wordle/package.json`
- Streamlit - workspace UI owned under `screenalytics/apps/workspace-ui/` and referenced in `screenalytics/AGENTS.md`

**Testing:**
- Vitest 2.1.9 - app unit/integration tests in `TRR-APP/apps/web/package.json`
- Playwright 1.58.2 - app end-to-end tests in `TRR-APP/apps/web/package.json`
- Pytest - backend and screenalytics tests in `TRR-Backend/pytest.ini` and `screenalytics/pyproject.toml`

**Build/Dev:**
- Webpack and Turbopack - Next.js dev/build lanes in `TRR-APP/apps/web/package.json`, `TRR-APP/apps/web/next.config.ts`, and `scripts/dev-workspace.sh`
- Vite / `vue-tsc` - Vue app build in `TRR-APP/apps/vue-wordle/package.json`
- Ruff - Python linting/formatting in `TRR-Backend/ruff.toml` and `screenalytics/pyproject.toml`
- Firebase Emulator Suite - local auth/firestore workflow in `TRR-APP/firebase.json` and `TRR-APP/package.json`
- Supabase CLI - local DB/API/auth stack configured in `TRR-Backend/supabase/config.toml`
- Modal CLI / SDK - remote long-job executor in `TRR-Backend/requirements.in`, `TRR-Backend/trr_backend/modal_dispatch.py`, and `scripts/dev-workspace.sh`
- Make + workspace shell scripts - root entrypoint in `Makefile`

## Key Dependencies

**Critical:**
- `next`, `react`, `react-dom` - app runtime in `TRR-APP/apps/web/package.json`
- `pg` - server-side Postgres access in `TRR-APP/apps/web/package.json` and runtime policy in `TRR-APP/apps/web/src/lib/server/postgres.ts`
- `@supabase/supabase-js` - browser/admin Supabase access in `TRR-APP/apps/web/package.json`
- `firebase` and `firebase-admin` - client and server auth/integration in `TRR-APP/package.json`, `TRR-APP/apps/web/package.json`, and `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`
- `fastapi`, `uvicorn`, `gunicorn` - TRR backend API serving in `TRR-Backend/requirements.in`
- `psycopg2-binary` - backend and screenalytics Postgres connectivity in `TRR-Backend/requirements.in` and `screenalytics/apps/api/services/supabase_db.py`
- `httpx` - backend and screenalytics service-to-service/webhook clients in `TRR-Backend/requirements.in` and `screenalytics/apps/api/services/suggestions_webhook.py`

**Infrastructure:**
- `modal` - remote admin/google-news/reddit/social job dispatch in `TRR-Backend/requirements.in` and `TRR-Backend/trr_backend/modal_dispatch.py`
- `boto3` - backend object storage and S3-compatible uploads in `TRR-Backend/requirements.in` and `TRR-Backend/trr_backend/object_storage.py`
- `supabase` / `postgrest` - retained backend SDK-compatible helpers and RPC access in `TRR-Backend/requirements.in` and `TRR-Backend/trr_backend/db/admin.py`
- `crawlee` - social scraping runtime in `TRR-Backend/requirements.in` and `TRR-Backend/trr_backend/socials/*/crawlee_adapter.py`
- `anthropic` and `google-genai` - LLM-assisted backend flows in `TRR-Backend/requirements.in`
- `gspread` and `google-auth*` - Sheets and Google service access in `TRR-Backend/requirements.in`
- `deepface`, `opencv-python`, `torch`, `onnxruntime`, `nemo_toolkit` - vision/audio/ML pipeline stack across `TRR-Backend/requirements.in`, `screenalytics/packages/py-screenalytics/pyproject.toml`, and `screenalytics/.env.example`
- `redis` / Celery-compatible configuration - screenalytics job queue lane in `screenalytics/apps/api/config/__init__.py`, `screenalytics/apps/api/celery_app.py`, and `screenalytics/.env.example`

## Configuration

**Environment:**
- Workspace startup contract lives in `scripts/dev-workspace.sh`, documented in `docs/workspace/env-contract.md`, and exposed through `Makefile`
- Repo-scoped example envs define the supported contract in `TRR-Backend/.env.example`, `TRR-APP/apps/web/.env.example`, and `screenalytics/.env.example`
- Cross-repo policy and shared secret names are defined in `AGENTS.md`
- Active planning/workstream metadata lives under `.planning/`, especially `.planning/active-workstream` and `.planning/workstreams/feature-b/STATE.md`

**Build:**
- App deployment/build config: `TRR-APP/apps/web/vercel.json`, `TRR-APP/apps/web/next.config.ts`, `TRR-APP/package.json`, `TRR-APP/pnpm-workspace.yaml`
- Backend local platform config: `TRR-Backend/supabase/config.toml`, `TRR-Backend/Dockerfile`, `TRR-Backend/requirements.lock.txt`
- Screenalytics package/runtime config: `screenalytics/pyproject.toml`, `screenalytics/packages/py-screenalytics/pyproject.toml`, `screenalytics/requirements*.txt`
- Browser/MCP runtime wrappers: `scripts/codex-chrome-devtools-mcp.sh` and `docs/workspace/chrome-devtools.md`

## Platform Requirements

**Development:**
- Node 24.x and Python 3.11 installed locally
- `pnpm`, `make`, and repo Python virtualenv workflows
- Supabase CLI for local database/API/auth services in `TRR-Backend/supabase/config.toml`
- Optional Docker only for the explicit screenalytics fallback lane via `make dev-local` in `Makefile`
- Managed Chrome / Chrome DevTools wrapper support via `scripts/codex-chrome-devtools-mcp.sh`

**Production:**
- `TRR-APP` deploys on Vercel, with active project metadata in `TRR-APP/.vercel/project.json`
- TRR remote long jobs target Modal app `trr-backend-jobs` per `scripts/dev-workspace.sh` and `TRR-Backend/trr_backend/modal_dispatch.py`
- Shared data plane expects Supabase Postgres 17 / Supavisor session-mode pooling via `TRR-Backend/supabase/config.toml`, `TRR-Backend/trr_backend/db/connection.py`, and `TRR-APP/apps/web/src/lib/server/postgres.ts`

---

*Stack analysis: 2026-04-06*
