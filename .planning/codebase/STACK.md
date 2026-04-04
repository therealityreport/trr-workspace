# Technology Stack

**Analysis Date:** 2026-04-04

## Languages

**Primary:**
- Python `3.11` / `3.11.9` - backend, API, ML, pipelines, and workspace automation in `TRR-Backend/api/`, `TRR-Backend/trr_backend/`, `screenalytics/apps/api/`, `screenalytics/packages/py-screenalytics/`, `scripts/`, `TRR-Backend/.python-version`, and `screenalytics/.python-version`.
- TypeScript - application and server code in `TRR-APP/apps/web/src/`, `TRR-APP/apps/web/scripts/`, `TRR-APP/apps/web/tests/`, and `screenalytics/web/`.

**Secondary:**
- JavaScript / ESM - build tooling and migration scripts in `TRR-APP/apps/web/next.config.ts`, `TRR-APP/apps/web/scripts/*.mjs`, and `screenalytics/web/next.config.mjs`.
- SQL - schema and operational data definition in `TRR-Backend/supabase/migrations/` and ad hoc SQL under `TRR-APP/scripts/sql/`.
- Bash / shell - workspace orchestration and operator tooling in `Makefile`, `scripts/`, `TRR-Backend/scripts/`, and `screenalytics/scripts/`.

## Runtime

**Environment:**
- Node `24.x` is the workspace target in `AGENTS.md`, enforced in `TRR-APP/package.json`, `TRR-APP/apps/web/package.json`, and `screenalytics/web/package.json`.
- `.nvmrc` and `TRR-APP/.nvmrc` both pin major `24`.
- Python `3.11` is the workspace target in `AGENTS.md`; `TRR-Backend/.python-version` and `screenalytics/.python-version` pin `3.11.9`.
- Container runtimes use `python:3.11-slim-bookworm` in `TRR-Backend/Dockerfile` and `screenalytics/Dockerfile.pipeline`.

**Package Manager:**
- `pnpm@10.15.0` - primary Node package manager in `TRR-APP/package.json`.
- Lockfile: present in `TRR-APP/pnpm-lock.yaml`.
- `pip` + `venv` + compiled requirements - Python dependency installation via `TRR-Backend/requirements.txt`, `screenalytics/requirements.txt`, `screenalytics/requirements-core.txt`, and `TRR-APP/requirements.txt`.
- Lockfile: present as compiled requirement references in `TRR-Backend/requirements.txt` -> `requirements.lock.txt`, `screenalytics/requirements-core.txt` -> `requirements-core.lock.txt`, and `TRR-APP/requirements.txt` -> `requirements.lock.txt`.
- `hatchling` - package build backend for the reusable Python package in `screenalytics/packages/py-screenalytics/pyproject.toml`.

## Frameworks

**Core:**
- FastAPI - API framework for `TRR-Backend` in `TRR-Backend/api/main.py` and for `screenalytics` in `screenalytics/apps/api/main.py`.
- Next.js `16.1.6` - primary web app framework in `TRR-APP/apps/web/package.json` and `TRR-APP/apps/web/next.config.ts`.
- React `19.1.0` - UI layer for `TRR-APP/apps/web` in `TRR-APP/apps/web/package.json`.
- Streamlit `1.54.0` - screenalytics review UI in `screenalytics/requirements-core.in` and `screenalytics/apps/workspace-ui/streamlit_app.py`.
- Next.js `14.2.35` - secondary screenalytics web surface in `screenalytics/web/package.json` and `screenalytics/web/next.config.mjs`.

**Testing:**
- `pytest` - Python test runner in `TRR-Backend/pytest.ini`, `TRR-Backend/requirements.in`, and `screenalytics/requirements-core.in`.
- `Vitest` - unit/component tests for `TRR-APP` in `TRR-APP/apps/web/package.json` and `TRR-APP/apps/web/vitest.config.ts`.
- `Playwright` - browser and smoke tests for `TRR-APP` in `TRR-APP/apps/web/package.json` and `TRR-APP/apps/web/playwright.config.ts`.

**Build/Dev:**
- Supabase CLI/config - schema docs, migrations, and local DB replay from `TRR-Backend/Makefile` and `TRR-Backend/supabase/config.toml`.
- Modal - remote job runtime in `TRR-Backend/trr_backend/modal_jobs.py`.
- Vercel - deployment and cron surface for the main app in `TRR-APP/apps/web/vercel.json`.
- Tailwind CSS `4.x` - frontend styling in `TRR-APP/apps/web/package.json` and `screenalytics/web/package.json`.
- ESLint - TypeScript/Next linting in `TRR-APP/apps/web/eslint.config.mjs`.
- Ruff / Pyright - Python linting and type checking in `TRR-Backend/ruff.toml`, `TRR-Backend/pyrightconfig.json`, `screenalytics/pyproject.toml`, and `screenalytics/pyrightconfig.json`.

## Key Dependencies

**Critical:**
- `@supabase/supabase-js` - TRR-APP server auth/admin access in `TRR-APP/apps/web/package.json`, `TRR-APP/apps/web/src/lib/server/auth.ts`, and `TRR-APP/apps/web/src/lib/server/supabase-trr-admin.ts`.
- `pg` - direct Postgres access from TRR-APP in `TRR-APP/apps/web/package.json` and `TRR-APP/apps/web/src/lib/server/postgres.ts`.
- `psycopg2-binary` - direct Postgres access in `TRR-Backend/requirements.in`, `TRR-Backend/trr_backend/db/*.py`, and `screenalytics/apps/api/services/supabase_db.py`.
- `firebase` / `firebase-admin` - client and server auth/session surfaces in `TRR-APP/package.json`, `TRR-APP/apps/web/package.json`, `TRR-APP/apps/web/src/lib/firebase.ts`, and `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`.
- `modal` - backend remote execution plane in `TRR-Backend/requirements.in` and `TRR-Backend/trr_backend/modal_jobs.py`.
- `celery[redis]` + `redis` - screenalytics async jobs in `screenalytics/requirements-core.in`, `screenalytics/apps/api/celery_app.py`, and `screenalytics/apps/api/routers/celery_jobs.py`.
- `boto3` - S3/R2/MinIO-compatible storage access in `TRR-Backend/requirements.in`, `TRR-Backend/trr_backend/object_storage.py`, `screenalytics/requirements-core.in`, and `screenalytics/apps/api/services/storage.py`.

**Infrastructure:**
- `fastapi`, `uvicorn`, `gunicorn` - API serving in `TRR-Backend/requirements.in`, `TRR-Backend/Dockerfile`, and `screenalytics/requirements-core.in`.
- `requests` / `httpx` / `undici` - outbound HTTP clients in `TRR-Backend/requirements.in`, `screenalytics/requirements-core.in`, and `TRR-APP/apps/web/src/lib/server/sse-proxy.ts`.
- `crawlee` - social scraping runtime in `TRR-Backend/requirements.in` and `TRR-Backend/trr_backend/socials/crawlee_runtime/`.
- `openai`, `anthropic`, `google-genai` / `google-generativeai` - AI-backed utilities in `TRR-Backend/requirements.in`, `TRR-Backend/trr_backend/integrations/openai_fandom_cleanup.py`, `TRR-Backend/trr_backend/clients/computer_use.py`, `screenalytics/apps/api/services/openai_diagnostics.py`, and `TRR-APP/requirements.in`.
- `torch`, `opencv-python`, `numpy`, `pyarrow`, `pandas` - ML/data pipeline stack in `screenalytics/requirements-core.in` and `screenalytics/packages/py-screenalytics/pyproject.toml`.

## Configuration

**Environment:**
- Shared cross-repo env naming is documented in `docs/workspace/env-contract.md`, `docs/workspace/env-contract-inventory.md`, and enforced by `scripts/env_contract_report.py` and `scripts/check-workspace-contract.sh`.
- Workspace startup and env derivation are centralized in `scripts/dev-workspace.sh` and `scripts/lib/runtime-db-env.sh`.
- Vercel env governance for `TRR-APP` is documented in `docs/workspace/vercel-env-review.md`.
- Repo-specific runtime env surfaces are validated at startup in `TRR-Backend/api/main.py`, `screenalytics/apps/api/main.py`, and `TRR-APP/apps/web/src/lib/server/postgres.ts`.

**Build:**
- Workspace orchestration lives in `Makefile` and `docs/workspace/dev-commands.md`.
- TRR-APP build config is in `TRR-APP/apps/web/next.config.ts`, `TRR-APP/apps/web/vercel.json`, `TRR-APP/apps/web/eslint.config.mjs`, `TRR-APP/apps/web/playwright.config.ts`, and `TRR-APP/apps/web/vitest.config.ts`.
- TRR-Backend build/runtime config is in `TRR-Backend/Dockerfile`, `TRR-Backend/Makefile`, `TRR-Backend/ruff.toml`, `TRR-Backend/pytest.ini`, and `TRR-Backend/supabase/config.toml`.
- screenalytics build/runtime config is in `screenalytics/Dockerfile.pipeline`, `screenalytics/Makefile`, `screenalytics/pyproject.toml`, `screenalytics/requirements-core.in`, and `screenalytics/web/next.config.mjs`.

## Platform Requirements

**Development:**
- Use `make dev` for the canonical cloud-first workspace path from `Makefile` and `docs/workspace/dev-commands.md`.
- Use `make dev-local` only for the explicit Docker-backed Screenalytics fallback with local Redis + MinIO, as documented in `Makefile` and `docs/workspace/dev-commands.md`.
- `TRR-Backend` expects a Python virtualenv plus Supabase-compatible DB/auth envs as documented in `TRR-Backend/docs/api/run.md`.
- `TRR-APP` expects Node `24.x`, `pnpm`, and runtime env injection for Firebase, Supabase admin access, Postgres, and backend base URLs in `TRR-APP/apps/web/src/lib/firebase-client-config.ts`, `TRR-APP/apps/web/src/lib/server/postgres.ts`, and `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.

**Production:**
- `TRR-APP` deploys to Vercel with scheduled cron routes defined in `TRR-APP/apps/web/vercel.json`.
- `TRR-Backend` is containerizable via `TRR-Backend/Dockerfile`; current deployment guidance references a Render API host plus Modal job plane in `TRR-Backend/docs/api/run.md` and `TRR-Backend/trr_backend/modal_jobs.py`.
- Modal is the remote executor for backend long-running work in `TRR-Backend/trr_backend/modal_jobs.py` and `scripts/dev-workspace.sh`.
- `screenalytics` has a local/API pipeline deployment surface plus a secondary Next.js web surface in `screenalytics/apps/api/main.py`, `screenalytics/Dockerfile.pipeline`, and `screenalytics/web/package.json`; no separate workspace-level production hosting contract is declared in shared docs.

---

*Stack analysis: 2026-04-04*
