# Technology Stack

**Analysis Date:** 2026-04-04

## Languages

**Primary:**
- Python 3.11.9 - backend and pipeline runtime across `TRR-Backend/.python-version`, `screenalytics/.python-version`, `TRR-Backend/api/main.py`, `screenalytics/apps/api/main.py`, and `screenalytics/packages/py-screenalytics/pyproject.toml`.
- TypeScript - frontend and server code in `TRR-APP/apps/web/package.json`, `TRR-APP/apps/web/tsconfig.json`, `TRR-APP/apps/web/src/lib/server/postgres.ts`, and `TRR-APP/apps/web/src/lib/firebase.ts`.

**Secondary:**
- JavaScript / ESM scripts - workspace and app automation in `TRR-APP/apps/web/package.json`, `TRR-APP/apps/web/scripts/`, `scripts/env_contract_report.py` references, and `TRR-APP/apps/web/next.config.ts`.
- SQL - schema and migration layer under `TRR-Backend/supabase/migrations/`.
- Bash / shell - workspace orchestration in `Makefile`, `scripts/dev-workspace.sh`, `scripts/preflight.sh`, and `scripts/codex-config-sync.sh`.
- YAML / JSON / TOML - CI, deployment, and tool config in `TRR-Backend/.github/workflows/ci.yml`, `TRR-APP/apps/web/vercel.json`, `TRR-APP/pnpm-workspace.yaml`, `screenalytics/pyproject.toml`, and `docs/agent-governance/mcp_inventory.md`.

## Runtime

**Environment:**
- Node.js 24.x at the workspace and app layer via `.nvmrc`, `TRR-APP/.nvmrc`, `TRR-APP/package.json`, `TRR-APP/apps/web/package.json`, and `screenalytics/web/package.json`.
- Python 3.11.9 for the Python services via `TRR-Backend/.python-version`, `screenalytics/.python-version`, `TRR-Backend/.github/workflows/ci.yml`, and `screenalytics/.github/workflows/ci.yml`.

**Package Manager:**
- `pnpm` 10.15.0 for `TRR-APP` via `TRR-APP/package.json`.
- `pip` install entrypoints backed by `uv pip compile` lock generation in `TRR-Backend/requirements.txt`, `TRR-Backend/requirements.in`, `TRR-Backend/requirements.lock.txt`, `screenalytics/requirements.txt`, `screenalytics/requirements-core.txt`, and `screenalytics/requirements-core.lock.txt`.
- `hatchling` for the packaged Screenalytics shared library in `screenalytics/packages/py-screenalytics/pyproject.toml`.
- Lockfile: present for Node in `TRR-APP/pnpm-lock.yaml`; present for Python as compiled lockfiles in `TRR-Backend/requirements.lock.txt`, `screenalytics/requirements-core.lock.txt`, `screenalytics/requirements-ml.lock.txt`, and `screenalytics/requirements-crawl.lock.txt`.

## Frameworks

**Core:**
- FastAPI - API framework for `TRR-Backend` and `screenalytics` in `TRR-Backend/api/main.py` and `screenalytics/apps/api/main.py`.
- Next.js 16.1.6 - main TRR web app in `TRR-APP/apps/web/package.json` and `TRR-APP/apps/web/next.config.ts`.
- React 19.1.0 - primary TRR app UI runtime in `TRR-APP/apps/web/package.json`.
- Firebase Web SDK / Firebase Admin - auth and Firestore-backed app features in `TRR-APP/apps/web/src/lib/firebase.ts`, `TRR-APP/apps/web/src/lib/firebase-db.ts`, and `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`.
- Vue 3.5.31 + Vite 8 - secondary `vue-wordle` app in `TRR-APP/apps/vue-wordle/package.json`.
- Streamlit - Screenalytics operator UI in `screenalytics/apps/workspace-ui/streamlit_app.py` and the pinned dependency lane in `screenalytics/requirements-core.lock.txt`.
- Modal - remote execution plane for backend long jobs in `TRR-Backend/trr_backend/modal_jobs.py` and `TRR-Backend/trr_backend/modal_dispatch.py`.

**Testing:**
- `pytest` - Python test runner declared in `TRR-Backend/requirements.in`, `TRR-Backend/pytest.ini`, `screenalytics/pyproject.toml`, and CI workflows in `TRR-Backend/.github/workflows/ci.yml` and `screenalytics/.github/workflows/ci.yml`.
- `vitest` - unit test runner for `TRR-APP/apps/web` in `TRR-APP/apps/web/package.json`.
- `@playwright/test` - browser E2E suite in `TRR-APP/apps/web/package.json`.

**Build/Dev:**
- Tailwind CSS 4.x - styling/build pipeline in `TRR-APP/apps/web/package.json` and `screenalytics/web/package.json`.
- ESLint 9 / Next config - linting in `TRR-APP/apps/web/eslint.config.mjs` and `TRR-APP/apps/web/package.json`.
- Ruff + Pyright - Python lint/type tooling in `TRR-Backend/ruff.toml`, `TRR-Backend/pyrightconfig.json`, `screenalytics/pyproject.toml`, and `screenalytics/pyrightconfig.json`.
- Docker - container build surfaces in `TRR-Backend/Dockerfile` and `screenalytics/Dockerfile.pipeline`.
- GitHub Actions - CI lanes in `TRR-Backend/.github/workflows/ci.yml`, `TRR-APP/.github/workflows/web-tests.yml`, and `screenalytics/.github/workflows/ci.yml`.

## Key Dependencies

**Critical:**
- `fastapi` / `uvicorn` / `gunicorn` - Python API serving in `TRR-Backend/requirements.in`, `TRR-Backend/Dockerfile`, and `screenalytics/apps/api/main.py`.
- `next`, `react`, `react-dom` - main UI runtime in `TRR-APP/apps/web/package.json`.
- `firebase`, `firebase-admin` - client auth, admin auth, and Firestore access in `TRR-APP/package.json`, `TRR-APP/apps/web/package.json`, `TRR-APP/apps/web/src/lib/firebase.ts`, and `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`.
- `@supabase/supabase-js` - browser/admin Supabase access for the app in `TRR-APP/apps/web/package.json`.
- `pg` - server-side Postgres access in `TRR-APP/apps/web/package.json` and `TRR-APP/apps/web/src/lib/server/postgres.ts`.
- `psycopg2-binary` - Python Postgres client for runtime DB access in `TRR-Backend/requirements.in` and `screenalytics/apps/api/services/supabase_db.py`.
- `modal` - remote worker and API deployment hooks in `TRR-Backend/requirements.in` and `TRR-Backend/trr_backend/modal_jobs.py`.

**Infrastructure:**
- `boto3` - provider-neutral object storage / S3 / R2 client in `TRR-Backend/requirements.in`, `TRR-Backend/trr_backend/object_storage.py`, `TRR-Backend/trr_backend/media/s3_mirror.py`, and `screenalytics/apps/api/services/storage.py`.
- `redis` / Celery-compatible queue envs - realtime and background processing lanes in `TRR-Backend/api/realtime/broker.py`, `screenalytics/apps/api/config/__init__.py`, and `screenalytics/apps/api/routers/celery_jobs.py`.
- `google-genai` / Gemini ASR hooks - LLM and speech tooling in `TRR-Backend/requirements.in`, `TRR-Backend/trr_backend/vision/text_overlay.py`, and `screenalytics/packages/py-screenalytics/src/py_screenalytics/audio/asr_gemini.py`.
- `openai`, `anthropic`, `pyannote`, `resemble` - audio and diagnostics integrations declared in `screenalytics/apps/api/config/__init__.py`, `screenalytics/apps/api/services/openai_diagnostics.py`, and `screenalytics/.env.example`.
- `crawlee`, `deepface`, `opencv-python`, `onnxruntime`, `torch`, `torchvision` - scraping and ML pipeline dependencies in `TRR-Backend/requirements.in`, `screenalytics/packages/py-screenalytics/pyproject.toml`, and `screenalytics/requirements-ml.txt`.

## Configuration

**Environment:**
- Repo-local env templates define runtime contracts in `TRR-Backend/.env.example`, `TRR-APP/apps/web/.env.example`, and `screenalytics/.env.example`.
- Workspace defaults and profile overlays live in `profiles/default.env`, `profiles/local-cloud.env`, `profiles/local-docker.env`, `profiles/local-full.env`, and `profiles/local-lite.env`.
- Shared env policy and reviewed runtime contracts are documented in `docs/workspace/env-contract.md`, `docs/workspace/vercel-env-review.md`, and enforced by `scripts/env_contract_report.py`.
- The workspace launcher injects the managed local runtime contract from `scripts/dev-workspace.sh`.

**Build:**
- Next.js build and route behavior live in `TRR-APP/apps/web/next.config.ts`.
- Vercel cron config lives in `TRR-APP/apps/web/vercel.json`.
- pnpm workspace shape is declared in `TRR-APP/pnpm-workspace.yaml`.
- Python lint/test config lives in `TRR-Backend/ruff.toml`, `TRR-Backend/pytest.ini`, `TRR-Backend/pyrightconfig.json`, `screenalytics/pyproject.toml`, and `screenalytics/pyrightconfig.json`.
- Container build config lives in `TRR-Backend/Dockerfile` and `screenalytics/Dockerfile.pipeline`.

## Platform Requirements

**Development:**
- Preferred workspace startup is the cloud-first path `make dev` from `Makefile` and `docs/workspace/dev-commands.md`.
- Local development expects Node 24 and Python 3.11 plus repo env files and the managed DB/runtime launcher in `scripts/dev-workspace.sh`.
- Docker is optional and explicitly a fallback path for Screenalytics local Redis/MinIO work via `make dev-local`, `screenalytics/Dockerfile.pipeline`, and `docs/workspace/dev-commands.md`.

**Production:**
- `TRR-APP` targets Vercel, evidenced by `TRR-APP/.vercel/project.json`, `TRR-APP/apps/web/.vercel/project.json`, `TRR-APP/apps/web/vercel.json`, and `docs/workspace/vercel-env-review.md`.
- `TRR-Backend` long-running jobs target Modal via `TRR-Backend/trr_backend/modal_jobs.py`, `TRR-Backend/trr_backend/modal_dispatch.py`, and `profiles/default.env`.
- Python services are also containerized for deployable runtimes via `TRR-Backend/Dockerfile` and `screenalytics/Dockerfile.pipeline`.

---

*Stack analysis: 2026-04-04*
