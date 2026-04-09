# Technology Stack

**Analysis Date:** 2026-04-08

## Languages

**Primary:**
- Python 3.11.9 - backend and pipeline runtime in `TRR-Backend/.python-version`, `screenalytics/.python-version`, `TRR-Backend/api/main.py`, and `screenalytics/apps/api/main.py`
- TypeScript 5.9.3 - primary app language in `TRR-APP/apps/web/package.json`, `TRR-APP/apps/web/src/`, and `TRR-APP/apps/web/next.config.ts`

**Secondary:**
- TypeScript 5.4.5 - optional Screenalytics web prototype in `screenalytics/web/package.json`
- SQL - Supabase schema, migrations, and schema docs in `TRR-Backend/supabase/`
- Bash - workspace orchestration and developer tooling in `Makefile`, `scripts/dev-workspace.sh`, `TRR-APP/scripts/vercel.sh`, and `scripts/workspace-env-contract.sh`
- JSON/TOML/YAML - environment contract, platform config, Docker fallback infra, and CI in `docs/workspace/env-contract.md`, `TRR-APP/.vercel/project.json`, `screenalytics/infra/docker/compose.yaml`, and `.github/workflows/*`

## Runtime

**Environment:**
- Node 24.x - workspace app baseline in `AGENTS.md`, `TRR-APP/.nvmrc`, `TRR-APP/package.json`, `TRR-APP/apps/web/package.json`, and `screenalytics/web/package.json`
- Python 3.11.9 - canonical backend and Screenalytics runtime in `TRR-Backend/.python-version`, `screenalytics/.python-version`, `TRR-Backend/.github/workflows/ci.yml`, and `screenalytics/.github/workflows/ci.yml`

**Package Manager:**
- `pnpm` 10.15.0 - monorepo package manager for `TRR-APP/` from `TRR-APP/package.json`
- `npm` - used only for the optional `screenalytics/web/` prototype from `screenalytics/web/package.json`
- `pip` + `uv` - Python dependency install and lock refresh flow in `TRR-Backend/requirements.txt`, `screenalytics/requirements.txt`, `TRR-Backend/.github/workflows/ci.yml`, and `screenalytics/.github/workflows/ci.yml`
- Lockfile: present in `TRR-APP/pnpm-lock.yaml`, `TRR-Backend/requirements.lock.txt`, `screenalytics/requirements-core.lock.txt`, and `screenalytics/requirements-ml.lock.txt`

## Frameworks

**Core:**
- Next.js 16.1.6 + React 19.1.0 - main app and admin UI in `TRR-APP/apps/web/package.json` and `TRR-APP/apps/web/src/`
- FastAPI 0.135.2 - TRR backend API in `TRR-Backend/requirements.lock.txt` and `TRR-Backend/api/main.py`
- FastAPI 0.129.0 - Screenalytics API in `screenalytics/requirements-core.lock.txt` and `screenalytics/apps/api/main.py`
- Streamlit 1.54.0 - Screenalytics workspace UI in `screenalytics/requirements-core.lock.txt` and `screenalytics/apps/workspace-ui/streamlit_app.py`
- Next.js 14.2.35 + React 18.2.0 - optional Screenalytics web prototype in `screenalytics/web/package.json`

**Testing:**
- Vitest 2.1.9 - unit and integration tests for `TRR-APP/apps/web/` from `TRR-APP/apps/web/package.json`
- Playwright 1.58.2 - end-to-end browser tests for `TRR-APP/apps/web/` from `TRR-APP/apps/web/package.json`
- pytest 9.0.2 - backend tests in `TRR-Backend/requirements.lock.txt`
- pytest 8.3.3 - Screenalytics tests in `screenalytics/requirements-core.lock.txt`

**Build/Dev:**
- Uvicorn 0.42.0 - backend ASGI runtime in `TRR-Backend/requirements.lock.txt`
- Uvicorn 0.41.0 - Screenalytics API runtime in `screenalytics/requirements-core.lock.txt`
- Celery 5.6.2 + Redis 6.4.0 - Screenalytics background jobs in `screenalytics/requirements-core.lock.txt` and `screenalytics/apps/api/celery_app.py`
- Tailwind CSS 4.2.x - app styling in `TRR-APP/apps/web/package.json` and `screenalytics/web/package.json`
- ESLint 9.39.3 - app linting in `TRR-APP/apps/web/package.json`
- Ruff - Python lint policy in `screenalytics/pyproject.toml` and CI in `screenalytics/.github/workflows/ci.yml`

## Key Dependencies

**Critical:**
- `pg` ^8.19.0 - app server reads TRR Postgres directly via `TRR-APP/apps/web/src/lib/server/postgres.ts`
- `@supabase/supabase-js` ^2.98.0 - browser/server Supabase client dependency for app surfaces in `TRR-APP/apps/web/package.json`
- `firebase` ^12.x / `firebase-admin` ^12.x-13.x - browser auth plus server admin auth in `TRR-APP/apps/web/src/lib/firebase.ts` and `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`
- `psycopg2-binary` 2.9.11 - Python Postgres access in `TRR-Backend/requirements.lock.txt` and `screenalytics/requirements-core.lock.txt`
- `boto3` 1.42.76 / 1.35.28 - S3-compatible object storage clients in `TRR-Backend/trr_backend/object_storage.py` and `screenalytics/apps/api/services/storage.py`
- `modal` 1.4.0 - remote long-job dispatch in `TRR-Backend/requirements.lock.txt` and `TRR-Backend/trr_backend/modal_dispatch.py`

**Infrastructure:**
- `anthropic` 0.86.0 - AI diagnostics and computer-use surfaces in `TRR-Backend/requirements.lock.txt` and `screenalytics/apps/api/services/openai_diagnostics.py`
- `openai` ^4.52.0 - Screenalytics web prototype and diagnostics/image generation surfaces in `screenalytics/web/package.json`, `screenalytics/apps/api/services/openai_diagnostics.py`, and `TRR-APP/apps/web/src/app/api/design-docs/generate-image/route.ts`
- `apify-client` 2.5.0 - backend social/data ingestion dependency in `TRR-Backend/requirements.lock.txt`
- `httpx` 0.28.1 and `requests` 2.33.0 / 2.32.x - outbound API/http clients across all repos in `TRR-Backend/requirements.lock.txt`, `screenalytics/requirements-core.lock.txt`, and `TRR-APP/requirements.lock.txt`
- `openapi-typescript` 7.13.0 + `prisma` ^5.10.1 - optional Screenalytics web client codegen and DB tooling in `screenalytics/web/package.json`

## Configuration

**Environment:**
- Workspace startup and shared local wiring come from `Makefile`, `scripts/dev-workspace.sh`, and `docs/workspace/env-contract.md`
- Canonical runtime DB contract is `TRR_DB_URL` with optional `TRR_DB_FALLBACK_URL` in `TRR-Backend/trr_backend/db/connection.py`, `TRR-APP/apps/web/src/lib/server/postgres.ts`, and `screenalytics/apps/api/services/supabase_db.py`
- App backend base URL is `TRR_API_URL`, normalized to `/api/v1` in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`
- Shared service auth is `TRR_INTERNAL_ADMIN_SHARED_SECRET`; Screenalytics legacy compatibility still allows `SCREENALYTICS_SERVICE_TOKEN` in `TRR-Backend/api/screenalytics_auth.py` and `screenalytics/apps/api/services/trr_ingest.py`
- App server/admin Supabase contract is `TRR_CORE_SUPABASE_URL` plus `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY` in `TRR-APP/apps/web/src/lib/server/supabase-trr-admin.ts`
- App browser auth/config uses `NEXT_PUBLIC_FIREBASE_*` and optional `NEXT_PUBLIC_USE_FIREBASE_EMULATORS` in `TRR-APP/apps/web/src/lib/firebase-client-config.ts`
- Browser Supabase is retained for route-scoped features and Vercel env review in `docs/workspace/vercel-env-review.md`

**Build:**
- App build config lives in `TRR-APP/apps/web/next.config.ts` and `TRR-APP/apps/web/vercel.json`
- Screenalytics web build config lives in `screenalytics/web/next.config.mjs`
- Python lint/test config lives in `screenalytics/pyproject.toml`
- Workspace-generated env contract is maintained by `scripts/workspace-env-contract.sh`
- CI pipelines live in `TRR-Backend/.github/workflows/ci.yml`, `TRR-APP/.github/workflows/web-tests.yml`, and `screenalytics/.github/workflows/ci.yml`

## Platform Requirements

**Development:**
- Local daily workflow is the cloud-first `make dev` path from `Makefile` and `docs/workspace/dev-commands.md`
- Docker is optional and only required for the explicit Screenalytics fallback lane in `screenalytics/infra/docker/compose.yaml`, `Makefile`, and `scripts/dev-workspace.sh`
- Managed Chrome/Chrome DevTools is part of the workspace toolchain in `docs/workspace/chrome-devtools.md`
- Screenalytics pipeline work expects `ffmpeg`; GPU is optional but explicitly documented in `screenalytics/README.md`

**Production:**
- `TRR-APP` deploys to Vercel with active project metadata in `TRR-APP/.vercel/project.json` and app-level cron config in `TRR-APP/apps/web/vercel.json`
- TRR long jobs run on Modal when the remote executor is enabled in `TRR-Backend/trr_backend/job_plane.py` and `TRR-Backend/trr_backend/modal_dispatch.py`
- Object storage is S3-compatible and can target Cloudflare R2 or S3 depending on `OBJECT_STORAGE_*` config in `TRR-Backend/trr_backend/object_storage.py`
- Screenalytics production hosting is not declared in a single deploy manifest; current repo-owned runtime surfaces are `uvicorn`, `celery`, `streamlit`, and optional `screenalytics/web`

---

*Stack analysis: 2026-04-08*
