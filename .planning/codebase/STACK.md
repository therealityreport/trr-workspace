# Technology Stack

**Analysis Date:** 2026-04-07

## Languages

**Primary:**
- Python 3.11 for `TRR-Backend/` and `screenalytics/`, with the workspace baseline called out in `AGENTS.md`, runtime images in `TRR-Backend/Dockerfile` and `screenalytics/Dockerfile.pipeline`, and package metadata in `screenalytics/packages/py-screenalytics/pyproject.toml`
- TypeScript for the main app in `TRR-APP/apps/web/` and the secondary Vue app in `TRR-APP/apps/vue-wordle/`
- Bash for workspace orchestration, browser wrappers, status helpers, and handoff tooling in `Makefile` and `scripts/*.sh`

**Secondary:**
- SQL in `TRR-Backend/supabase/migrations/` and `TRR-Backend/supabase/seed.sql`
- TOML / YAML / JSON for project and runtime config in `TRR-Backend/supabase/config.toml`, `screenalytics/pyproject.toml`, `TRR-APP/apps/web/vercel.json`, `TRR-APP/pnpm-workspace.yaml`, and `docs/workspace/env-contract.md`
- Markdown for policy, planning, and design/ops docs in `AGENTS.md`, `docs/`, and `.planning/`

## Runtime

**Environment:**
- Node `24.x` for the workspace and app repos, defined in `.nvmrc`, `TRR-APP/package.json`, `TRR-APP/apps/web/package.json`, and `screenalytics/web/package.json`
- Python `3.11` for backend and analytics runtime, reflected in `AGENTS.md`, `TRR-Backend/Dockerfile`, `screenalytics/Dockerfile.pipeline`, and `screenalytics/packages/py-screenalytics/pyproject.toml`

**Package Manager:**
- `pnpm@10.15.0` for `TRR-APP/`, with workspace packages declared in `TRR-APP/pnpm-workspace.yaml`
- `pip` installs from `requirements*.txt`, with lockfiles compiled by `uv` in both Python repos
- Lockfiles are present in `TRR-APP/pnpm-lock.yaml`, `TRR-APP/apps/web/pnpm-lock.yaml`, `TRR-Backend/requirements.lock.txt`, `screenalytics/requirements-core.lock.txt`, and `screenalytics/requirements-ml.lock.txt`

## Frameworks

**Core application frameworks:**
- Next.js `16.1.6` + React `19.1.0` for the main web/admin surface in `TRR-APP/apps/web/package.json`
- Vue `3.5.31` + Vite `8` for `TRR-APP/apps/vue-wordle/package.json`
- FastAPI for `TRR-Backend/api/main.py` and `screenalytics/apps/api/main.py`
- Streamlit for the operator UI in `screenalytics/apps/workspace-ui/streamlit_app.py`
- Typer for backend CLI entrypoints in `TRR-Backend/trr_backend/cli/__main__.py`

**Testing and tooling:**
- Vitest in `TRR-APP/apps/web/vitest.config.ts`
- Playwright in `TRR-APP/apps/web/playwright.config.ts`
- Pytest in `TRR-Backend/tests/` and `screenalytics/tests/`
- Ruff in `screenalytics/pyproject.toml` and repo validation commands in `TRR-Backend/AGENTS.md`

**Build and local platform:**
- Webpack and Turbopack are both active Next.js lanes in `TRR-APP/apps/web/package.json` and `TRR-APP/apps/web/next.config.ts`
- Supabase CLI is the backend’s local DB/auth/storage platform via `TRR-Backend/supabase/config.toml`
- Modal remains the preferred remote execution plane per `docs/workspace/env-contract.md`
- Firebase Emulator Suite supports app-local auth/firestore flows in `TRR-APP/package.json`

## Key Dependencies

**TRR-APP:**
- `next`, `react`, `react-dom` in `TRR-APP/apps/web/package.json`
- `firebase` and `firebase-admin` in `TRR-APP/package.json` and `TRR-APP/apps/web/package.json`
- `@supabase/supabase-js` and `pg` for server-side data access and admin helpers in `TRR-APP/apps/web/package.json`
- `@playwright/test`, `vitest`, `@testing-library/*`, and `vitest-axe` for testing

**TRR-Backend:**
- `fastapi`, `uvicorn`, and `gunicorn` from `TRR-Backend/requirements.lock.txt`
- `httpx`, `boto3`, `firebase-admin`, `supabase`-adjacent libs, `crawlee`, `modal`, `anthropic`, and `google-genai`
- Vision and media packages such as `deepface`, `opencv-python`, and related ML dependencies from `TRR-Backend/requirements.lock.txt`

**screenalytics:**
- `py-screenalytics` packaged in `screenalytics/packages/py-screenalytics/pyproject.toml`
- Core runtime layered across `screenalytics/requirements-core.txt`, `screenalytics/requirements-ml.txt`, and `screenalytics/requirements-ci.txt`
- `torch`, `torchvision`, `onnxruntime`, `numpy`, and audio/vision extras declared in `screenalytics/packages/py-screenalytics/pyproject.toml`
- `next`, `@prisma/client`, and `@tanstack/react-query` in `screenalytics/web/package.json`

## Configuration

**Workspace-level configuration:**
- Shared policy and repo order in `AGENTS.md`
- Generated runtime contract in `docs/workspace/env-contract.md`
- Workspace startup and profile loading in `Makefile`, `scripts/dev-workspace.sh`, and `profiles/*.env`
- Planning state in `.planning/PROJECT.md`, `.planning/active-workstream`, and `.planning/workstreams/`

**Repo-level configuration:**
- Backend platform config in `TRR-Backend/supabase/config.toml`
- App deployment config in `TRR-APP/apps/web/vercel.json`
- App bundler/runtime config in `TRR-APP/apps/web/next.config.ts`
- Screenalytics code quality/test config in `screenalytics/pyproject.toml`

## Platform Requirements

**Development:**
- Node 24.x, Python 3.11, `pnpm`, `make`, and repo-local virtualenvs
- Supabase CLI for backend-local database workflows
- Optional Docker for explicit local fallback paths, especially `screenalytics`
- Managed Chrome tooling via `scripts/codex-chrome-devtools-mcp.sh`

**Hosted / production surfaces:**
- `TRR-APP` deploys through Vercel using `TRR-APP/.vercel/project.json`
- `TRR-Backend` serves FastAPI and dispatches long jobs to Modal-backed workers
- `screenalytics` runs as its own FastAPI / Streamlit / optional Next.js surfaces with direct shared-DB access

---

*Stack analysis refreshed: 2026-04-07*
