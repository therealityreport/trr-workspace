# Technology Stack

**Analysis Date:** 2026-04-09

## Languages

**Primary:**
- Python `3.11.9` for backend services and ML/pipeline code in `TRR-Backend/.python-version`, `screenalytics/.python-version`, `TRR-Backend/api/`, `TRR-Backend/trr_backend/`, `screenalytics/apps/api/`, and `screenalytics/apps/workspace-ui/`.
- TypeScript for the web applications in `TRR-APP/apps/web/` and `screenalytics/web/`, with compiler settings in `TRR-APP/apps/web/tsconfig.json`, `TRR-APP/apps/web/tsconfig.typecheck.json`, `screenalytics/web/tsconfig.json`.

**Secondary:**
- JavaScript / MJS for repo scripts and config in `TRR-APP/apps/web/scripts/`, `TRR-APP/apps/web/next.config.ts`, `screenalytics/web/next.config.mjs`, and workspace scripts under `scripts/`.
- SQL via Supabase migrations and schema tooling in `TRR-Backend/supabase/`.
- Shell / Make for workspace orchestration in `Makefile`, `scripts/dev-workspace.sh`, `TRR-Backend/start-api.sh`, `TRR-Backend/Makefile`, and `screenalytics/Makefile`.

## Runtime

**Environment:**
- Workspace Node target is `24.x` in `.nvmrc`; `TRR-APP/.nvmrc`, `TRR-APP/package.json`, and `screenalytics/web/package.json` also pin Node `24.x`.
- Python runtime target is `3.11.9` in `TRR-Backend/.python-version` and `screenalytics/.python-version`.

**Package Manager:**
- `pnpm@10.15.0` for `TRR-APP` from `TRR-APP/package.json`.
- `npm` with `package-lock.json` for the optional `screenalytics/web/` prototype from `screenalytics/web/package.json` and `screenalytics/web/package-lock.json`.
- `pip` / requirements lockfiles for `TRR-Backend` and `screenalytics` from `TRR-Backend/requirements.txt`, `TRR-Backend/requirements.lock.txt`, `screenalytics/requirements.txt`, `screenalytics/requirements-core.lock.txt`, and `screenalytics/requirements-ml.lock.txt`.
- `make` is the shared developer entrypoint at workspace root in `Makefile`.

## Repo Stack Matrix

**Workspace Root:**
- Purpose: shared developer workflow, ports, env defaults, browser tooling, and cross-repo commands.
- Key files: `Makefile`, `scripts/dev-workspace.sh`, `docs/workspace/dev-commands.md`, `docs/workspace/env-contract.md`, `docs/agent-governance/mcp_inventory.md`, `docs/workspace/chrome-devtools.md`.
- Default dev path: `make dev` starts `TRR-APP`, `TRR-Backend`, and the Screenalytics API in a cloud-first lane; `make dev-local` is the explicit Docker fallback for Screenalytics-only Redis/MinIO work.

**TRR-Backend:**
- Frameworks: FastAPI app in `TRR-Backend/api/main.py`; Uvicorn launcher in `TRR-Backend/start-api.sh`; Typer CLI commands wired via `TRR-Backend/Makefile`.
- Data layer: Supabase/Postgres-first backend with local Supabase CLI config in `TRR-Backend/supabase/config.toml`.
- Deployment surface: Docker image in `TRR-Backend/Dockerfile`; Render service definition in `TRR-Backend/render.yaml`.
- Background execution: local worker loops in `TRR-Backend/scripts/workers/*.py` and `TRR-Backend/scripts/socials/worker.py`; remote Modal dispatch wiring through `TRR-Backend/scripts/_workspace_runtime_env.py`.

**screenalytics:**
- Frameworks: FastAPI app in `screenalytics/apps/api/main.py`; Streamlit workspace UI in `screenalytics/apps/workspace-ui/streamlit_app.py` and `screenalytics/apps/workspace-ui/pages/`; optional Next.js workspace in `screenalytics/web/`.
- Background execution: Celery + Redis in `screenalytics/apps/api/celery_app.py`, `screenalytics/apps/api/tasks.py`, and `screenalytics/apps/api/tasks_v2.py`.
- ML / pipeline lane: Python pipeline and artifact tooling at repo root, with optional heavy dependencies split into `screenalytics/requirements-ml.in`.
- Local infra: explicit Docker fallback exists at `screenalytics/infra/docker/compose.yaml` but is not the default workspace path.

**TRR-APP:**
- Frameworks: Next.js App Router app in `TRR-APP/apps/web/`; root repo orchestrates frontend plus Firebase emulators in `TRR-APP/package.json`.
- Runtime access: server-side reads use direct Postgres in `TRR-APP/apps/web/src/lib/server/postgres.ts`; backend HTTP access is normalized through `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.
- Deployment surface: Vercel config in `TRR-APP/apps/web/vercel.json`; repo-local Vercel linkage exists under `TRR-APP/.vercel/`.
- Test surfaces: Vitest in `TRR-APP/apps/web/vitest.config.ts`; Playwright in `TRR-APP/apps/web/playwright.config.ts`.

## Frameworks

**Core:**
- FastAPI `0.135.2` in `TRR-Backend/requirements.lock.txt` for the production backend API at `TRR-Backend/api/main.py`.
- FastAPI `0.129.0` in `screenalytics/requirements-core.in` for the Screenalytics API at `screenalytics/apps/api/main.py`.
- Next.js `16.1.6` in `TRR-APP/apps/web/package.json` for the main app at `TRR-APP/apps/web/`.
- Next.js `14.2.35` in `screenalytics/web/package.json` for the optional Screenalytics web prototype at `screenalytics/web/`.
- Streamlit `1.54.0` in `screenalytics/requirements-core.in` for operator-facing workflow pages in `screenalytics/apps/workspace-ui/`.

**Testing:**
- `pytest` for Python repos in `TRR-Backend/pytest.ini` and `screenalytics/pyproject.toml`.
- `vitest` in `TRR-APP/apps/web/package.json` and `TRR-APP/apps/web/vitest.config.ts`.
- `@playwright/test` in `TRR-APP/apps/web/package.json` and `TRR-APP/apps/web/playwright.config.ts`.

**Build/Dev:**
- Uvicorn `0.42.0` in `TRR-Backend/requirements.lock.txt` and `0.41.0` in `screenalytics/requirements-core.in`.
- Tailwind CSS `4.2.1` in `TRR-APP/apps/web/package.json` and `4.2.2` in `screenalytics/web/package.json`.
- Firebase emulator tooling in `TRR-APP/package.json` and `TRR-APP/firebase.json`.
- OpenAPI client generation in `screenalytics/web/package.json` via `openapi-typescript`.
- Prisma tooling in `screenalytics/web/package.json`.

## Key Dependencies

**TRR-Backend critical packages:**
- `supabase==2.28.3` and `postgrest==2.28.3` from `TRR-Backend/requirements.lock.txt` for Supabase-backed data access.
- `modal==1.4.0` from `TRR-Backend/requirements.lock.txt` for remote long-job execution.
- `boto3==1.42.76` from `TRR-Backend/requirements.lock.txt` for object storage mirroring.
- `google-genai==1.68.0` from `TRR-Backend/requirements.lock.txt` for Gemini-backed enrichment lanes.
- `anthropic==0.86.0` from `TRR-Backend/requirements.lock.txt` for computer-use and AI-assisted tooling.
- `apify-client==2.5.0` from `TRR-Backend/requirements.lock.txt` for external scraper orchestration.
- `deepface==0.0.99` and `opencv-python==4.13.0.92` from `TRR-Backend/requirements.lock.txt` for image analysis lanes.

**screenalytics critical packages:**
- `celery[redis]==5.6.2` and `redis==6.4.0` from `screenalytics/requirements-core.in` for background jobs.
- `boto3==1.35.28` from `screenalytics/requirements-core.in` for S3/MinIO-compatible artifact storage.
- `torch==2.3.1`, `torchvision==0.18.1`, `insightface>=0.7.3`, `onnxruntime>=1.17.0`, and `faiss-cpu==1.8.0` from `screenalytics/requirements-ml.in` for ML pipeline work.
- `google-genai>=1.0.0` and `anthropic>=0.43.0` from `screenalytics/requirements-ml.in` / `screenalytics/requirements-core.in` for diagnostic and AI-assisted flows.
- `openai@^4.52.0`, `@tanstack/react-query@^5.95.2`, and `@prisma/client@^5.10.1` from `screenalytics/web/package.json` for the optional web client.

**TRR-APP critical packages:**
- `next@16.1.6`, `react@19.1.0`, and `typescript@^5.9.3` from `TRR-APP/apps/web/package.json`.
- `firebase@^12.10.0` and `firebase-admin@^12.7.0` from `TRR-APP/apps/web/package.json` and `TRR-APP/package.json`.
- `@supabase/supabase-js@^2.98.0` from `TRR-APP/apps/web/package.json` for server-side admin access.
- `pg@^8.19.0` from `TRR-APP/apps/web/package.json` for direct Postgres reads.
- `vitest@^2.1.9` and `@playwright/test@^1.58.2` from `TRR-APP/apps/web/package.json`.

## Configuration

**Environment:**
- Workspace-wide runtime toggles are generated into `docs/workspace/env-contract.md` and implemented by `scripts/dev-workspace.sh`.
- Backend runtime and secret contracts are documented in `TRR-Backend/README.md`, `TRR-Backend/.env.example`, and enforced in `TRR-Backend/api/main.py`.
- App env requirements are documented in `TRR-APP/apps/web/README.md` and implemented by `TRR-APP/apps/web/src/lib/firebase-client-config.ts`, `TRR-APP/apps/web/src/lib/server/postgres.ts`, and `TRR-APP/apps/web/src/lib/server/supabase-trr-admin.ts`.
- Screenalytics runtime env is centered in `screenalytics/apps/api/config/__init__.py`, `screenalytics/apps/api/services/supabase_db.py`, `screenalytics/apps/api/services/storage.py`, and `screenalytics/README.md`.
- `.env` and `.env.*` files are expected across repos but are intentionally not read into this document.

**Build / runtime config files:**
- `TRR-Backend/Dockerfile`
- `TRR-Backend/render.yaml`
- `TRR-Backend/supabase/config.toml`
- `TRR-APP/apps/web/next.config.ts`
- `TRR-APP/apps/web/vercel.json`
- `TRR-APP/firebase.json`
- `screenalytics/web/next.config.mjs`
- `TRR-Backend/ruff.toml`
- `TRR-APP/ruff.toml`
- `screenalytics/pyproject.toml`

## Build, Test, and Dev Entrypoints

**Workspace:**
- `make dev`, `make dev-local`, `make test-fast`, `make test-full`, `make codex-check`, and `make mcp-clean` from `Makefile`.

**TRR-Backend:**
- Dev API launcher: `TRR-Backend/start-api.sh`.
- Local run target: `TRR-Backend/Makefile` `dev`.
- Pipeline CLI: `python -m trr_backend.cli ...` from `TRR-Backend/Makefile`.
- Validation: `ruff check .`, `ruff format --check .`, `pytest -q`, and `make schema-docs-check` from `TRR-Backend/AGENTS.md`.

**screenalytics:**
- API: `python -m uvicorn apps.api.main:app --reload` from `screenalytics/README.md`.
- Celery: `celery -A apps.api.celery_app:celery_app worker -l info` from `screenalytics/apps/api/celery_app.py`.
- Streamlit: `streamlit run apps/workspace-ui/streamlit_app.py` or page entrypoints under `screenalytics/apps/workspace-ui/pages/`.
- Optional web: `npm run dev` in `screenalytics/web/package.json`.

**TRR-APP:**
- Root orchestration: `pnpm run dev` in `TRR-APP/package.json` can start the backend and web together.
- Web-only: `pnpm -C apps/web run dev`, `build`, `lint`, `test:ci`, and `test:e2e` from `TRR-APP/apps/web/package.json`.
- Emulator lane: `pnpm run emulators` and `pnpm -C apps/web run dev:emu` from `TRR-APP/package.json` and `TRR-APP/apps/web/README.md`.

## Platform Requirements

**Development:**
- Node `24.x` and Python `3.11.9` are the canonical local runtimes.
- Docker is not required for the default workspace path, but remains required for the Screenalytics local infra fallback referenced by `make dev-local` and `screenalytics/infra/docker/compose.yaml`.
- Managed browser automation depends on the shared Chrome / MCP wrappers described in `docs/workspace/chrome-devtools.md`.

**Production / hosted targets:**
- `TRR-APP/apps/web/` targets Vercel via `TRR-APP/apps/web/vercel.json`.
- `TRR-Backend` can run as a Dockerized Render service via `TRR-Backend/render.yaml`.
- Background long jobs default to a remote Modal lane in workspace dev, wired by `scripts/dev-workspace.sh` and `TRR-Backend/scripts/_workspace_runtime_env.py`.

## CI and Repo Automation

- Workspace verification is script-driven from `Makefile`.
- `TRR-Backend/.github/workflows/ci.yml`, `mirror-media-assets.yml`, `repo_map.yml`, and `secret-scan.yml` cover backend CI and automation.
- `screenalytics/.github/workflows/ci.yml`, `codex-manual.yml`, `codex-review.yml`, `on-push-doc-sync.yml`, and `repo_map.yml` cover Screenalytics automation.
- `TRR-APP/.github/workflows/web-tests.yml`, `firebase-rules.yml`, and `repo_map.yml` cover web and Firebase policy lanes.

---

*Stack analysis: 2026-04-09*
