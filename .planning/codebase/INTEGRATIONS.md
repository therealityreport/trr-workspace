# External Integrations

**Analysis Date:** 2026-04-04

## APIs & External Services

**Core Data Platform:**
- Supabase Postgres / Supavisor - canonical runtime database for all three repos.
  - SDK/Client: Python connection resolution in `TRR-Backend/trr_backend/db/connection.py` and `screenalytics/apps/api/services/supabase_db.py`; Node `pg` client in `TRR-APP/apps/web/src/lib/server/postgres.ts`.
  - Auth: `TRR_DB_URL`, `TRR_DB_FALLBACK_URL`, `SUPABASE_JWT_SECRET`, `TRR_CORE_SUPABASE_URL`, `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`, `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` from `TRR-Backend/.env.example` and `TRR-APP/apps/web/.env.example`.

**App Auth & User Data:**
- Firebase Auth + Firestore - user auth, profile, survey, and game state in `TRR-APP/apps/web/src/lib/firebase.ts`, `TRR-APP/apps/web/src/lib/firebase-db.ts`, and `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`.
  - SDK/Client: `firebase`, `firebase-admin` from `TRR-APP/package.json` and `TRR-APP/apps/web/package.json`.
  - Auth: `NEXT_PUBLIC_FIREBASE_*`, `FIREBASE_SERVICE_ACCOUNT` from `TRR-APP/apps/web/.env.example`.

**Remote Job Plane:**
- Modal - backend remote execution plane for admin operations, Google News sync, Reddit refresh, social jobs, and vision jobs in `TRR-Backend/trr_backend/modal_jobs.py` and `TRR-Backend/trr_backend/modal_dispatch.py`.
  - SDK/Client: `modal` from `TRR-Backend/requirements.in`.
  - Auth: named-secret contract and function names in `profiles/default.env`, `docs/workspace/env-contract.md`, and `TRR-Backend/trr_backend/modal_jobs.py`.

**Object Storage / Hosted Media:**
- S3-compatible object storage - provider-neutral media storage used by backend and Screenalytics in `TRR-Backend/trr_backend/object_storage.py`, `TRR-Backend/trr_backend/media/s3_mirror.py`, and `screenalytics/apps/api/services/storage.py`.
  - SDK/Client: `boto3` from `TRR-Backend/requirements.in`.
  - Auth: `OBJECT_STORAGE_*` envs in `TRR-Backend/.env.example`, `screenalytics/.env.example`, and `screenalytics/config/env/screenalytics-cloud.nodocker.example`.
- Cloudflare R2 - explicitly supported S3-compatible backend and public asset host in `screenalytics/config/env/screenalytics-cloud.nodocker.example`, `TRR-APP/apps/web/src/styles/cdn-fonts.css`, and `TRR-APP/apps/web/src/lib/fonts/hosted-fonts.ts`.
  - SDK/Client: same `boto3` S3 client path as above.
  - Auth: `OBJECT_STORAGE_ENDPOINT_URL`, `OBJECT_STORAGE_ACCESS_KEY_ID`, `OBJECT_STORAGE_SECRET_ACCESS_KEY`.

**Queue / Cache / PubSub:**
- Redis - backend realtime broker and Screenalytics cache/queue backend in `TRR-Backend/api/realtime/broker.py`, `screenalytics/apps/api/config/__init__.py`, `screenalytics/apps/api/services/screentime_cache.py`, and `screenalytics/apps/api/routers/grouping.py`.
  - SDK/Client: `redis` import at runtime in `TRR-Backend/api/realtime/broker.py` and `screenalytics/apps/api/routers/grouping.py`.
  - Auth: `REDIS_URL`, `CELERY_BROKER_URL`, `CELERY_RESULT_BACKEND` from `screenalytics/.env.example` and `screenalytics/config/env/screenalytics-cloud.nodocker.example`.

**Media / Metadata Sources:**
- TMDb - show/person metadata fetches in `TRR-Backend/trr_backend/integrations/tmdb/client.py` and `TRR-Backend/trr_backend/integrations/tmdb_person.py`.
  - SDK/Client: raw `requests` client.
  - Auth: `TMDB_API_KEY`, `TMDB_BEARER_TOKEN`, `TMDB_BEARER` from `TRR-Backend/.env.example`.
- IMDb / TVDB / Firecrawl - scrape and fallback surfaces are declared in `TRR-Backend/.env.example`.
  - SDK/Client: repo-specific scraper logic under `TRR-Backend/trr_backend/repositories/` and scripts.
  - Auth: `IMDB_API_KEY`, `TVDB_API_KEY`, `FIRECRAWL_API_KEY`.
- Reddit OAuth - Reddit API rate-limit avoidance and refresh lanes in `TRR-Backend/trr_backend/repositories/reddit_refresh.py` and `TRR-Backend/trr_backend/modal_jobs.py`.
  - SDK/Client: backend repository client code.
  - Auth: `REDDIT_CLIENT_ID`, `REDDIT_CLIENT_SECRET`, `REDDIT_USER_AGENT` from `TRR-Backend/.env.example`.
- Getty local scraper via Cloudflare Tunnel - residential-IP scrape bridge in `TRR-Backend/scripts/getty_local_server.py`, `TRR-Backend/scripts/cloudflared-tunnel-config.yml`, `Makefile`, and `TRR-APP/apps/web/src/lib/server/admin/getty-local-scrape.ts`.
  - SDK/Client: local FastAPI/Next fetch bridge plus Cloudflare Tunnel command surface.
  - Auth: `TRR_GETTY_LOCAL_URL`, `TRR_GETTY_SCRAPER_SECRET`, and optional Getty login envs handled in `TRR-Backend/trr_backend/integrations/getty_local_prefetch.py`.
- Google Sheets / Google service-account access - pipeline inputs declared in `TRR-Backend/.env.example`.
  - SDK/Client: `gspread`, `google-auth`, `google-auth-oauthlib` from `TRR-Backend/requirements.in`.
  - Auth: `SPREADSHEET_NAME`, `SPREADSHEET_ID`, `GOOGLE_APPLICATION_CREDENTIALS`, `GOOGLE_SERVICE_ACCOUNT_FILE`.

**LLM / AI Services:**
- Google Generative Language / Gemini - design-doc image analysis in `TRR-APP/apps/web/src/app/api/design-docs/analyze-image/route.ts`, image generation fallback in `TRR-APP/apps/web/src/app/api/design-docs/generate-image/route.ts`, backend text-overlay detection in `TRR-Backend/trr_backend/vision/text_overlay.py`, and Gemini ASR in `screenalytics/packages/py-screenalytics/src/py_screenalytics/audio/asr_gemini.py`.
  - SDK/Client: HTTP fetch in `TRR-APP`, `google-genai` in Python services.
  - Auth: `GEMINI_API_KEY`, `GOOGLE_GEMINI_API_KEY`, `GOOGLE_API_KEY`.
- OpenAI - design-doc image generation in `TRR-APP/apps/web/src/app/api/design-docs/generate-image/route.ts` and Screenalytics audio/diagnostics in `screenalytics/apps/api/config/__init__.py` and `screenalytics/apps/api/services/openai_diagnostics.py`.
  - SDK/Client: raw HTTP in `TRR-APP`, Python config/services in `screenalytics`.
  - Auth: `OPENAI_API_KEY`.
- Anthropic - Screenalytics diagnostics and workspace UI helpers in `screenalytics/apps/api/services/openai_diagnostics.py` and `screenalytics/apps/workspace-ui/ui_helpers.py`.
  - SDK/Client: `anthropic` Python package.
  - Auth: Anthropic API key env expected by those services.

## Data Storage

**Databases:**
- PostgreSQL on Supabase is the shared relational store.
  - Connection: `TRR_DB_URL` primary, `TRR_DB_FALLBACK_URL` secondary per `TRR-Backend/trr_backend/db/connection.py`, `screenalytics/apps/api/services/supabase_db.py`, and `TRR-APP/apps/web/src/lib/server/postgres.ts`.
  - Client: backend DB helpers under `TRR-Backend/trr_backend/db/`; `psycopg2` in `screenalytics/apps/api/services/supabase_db.py`; `pg` in `TRR-APP/apps/web/src/lib/server/postgres.ts`.
- Supabase API/admin access is used in the app.
  - Connection: `TRR_CORE_SUPABASE_URL`, `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`, `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
  - Client: `@supabase/supabase-js` dependency in `TRR-APP/apps/web/package.json`; env readers in `TRR-APP/apps/web/src/lib/server/supabase-trr-admin.ts`.

**File Storage:**
- S3-compatible object storage with hosted public URLs is the canonical media/artifact store via `TRR-Backend/trr_backend/object_storage.py`, `TRR-Backend/trr_backend/media/s3_mirror.py`, and `screenalytics/apps/api/services/storage.py`.
- Cloudflare R2-hosted public fonts/assets are used directly from `TRR-APP/apps/web/src/styles/cdn-fonts.css` and `TRR-APP/apps/web/src/lib/fonts/hosted-fonts.ts`.
- Local filesystem is still used for temp job state and operator artifacts in `screenalytics/apps/workspace-ui/` and Getty prefetch temp files in `TRR-APP/apps/web/src/lib/server/admin/getty-local-scrape.ts`.

**Caching:**
- Redis-backed broker/cache when configured, otherwise backend falls back to in-memory pub/sub in `TRR-Backend/api/realtime/broker.py`.
- Screenalytics uses Redis/Celery-backed execution and cache lanes in `screenalytics/apps/api/config/__init__.py`, `screenalytics/apps/api/routers/celery_jobs.py`, and `screenalytics/apps/api/services/screentime_cache.py`.

## Authentication & Identity

**Auth Provider:**
- Firebase is the user-facing auth provider for `TRR-APP`.
  - Implementation: browser Firebase auth in `TRR-APP/apps/web/src/lib/firebase.ts`; server/admin auth in `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`; session routes in `TRR-APP/apps/web/src/app/api/session/login/route.ts`.
- Supabase JWT validation is used on the backend side for API token verification.
  - Implementation: HS256 verification in `TRR-Backend/trr_backend/security/jwt.py`.
- Internal service-to-service auth is separate from end-user auth.
  - Implementation: `TRR-APP` signs internal-admin bearer JWTs in `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`; backend verifies them in `TRR-Backend/trr_backend/security/internal_admin.py`; backend also accepts `SCREENALYTICS_SERVICE_TOKEN` in `TRR-Backend/api/screenalytics_auth.py`; Screenalytics protects Celery/computer-use routes with `SCREENALYTICS_SERVICE_TOKEN` in `screenalytics/apps/api/routers/celery_jobs.py` and `screenalytics/apps/api/routers/computer_use.py`.

## Monitoring & Observability

**Error Tracking:**
- Not detected as an external SaaS. No Sentry/PostHog/Rollbar-style service is referenced in the runtime files reviewed.

**Logs:**
- Backend request tracing and metrics wiring live in `TRR-Backend/api/main.py` and `TRR-Backend/trr_backend/observability`.
- Screenalytics request tracing and metrics wiring live in `screenalytics/apps/api/main.py` and `screenalytics/apps/api/services/observability`.
- Workspace/runtime status aggregation lives in `scripts/status-workspace.sh`.

## CI/CD & Deployment

**Hosting:**
- Vercel hosts the primary app surface via `TRR-APP/.vercel/project.json`, `TRR-APP/apps/web/.vercel/project.json`, `TRR-APP/apps/web/vercel.json`, and `docs/workspace/vercel-env-review.md`.
- Modal hosts the backend remote job plane via `TRR-Backend/trr_backend/modal_jobs.py`, `TRR-Backend/trr_backend/modal_dispatch.py`, and the workspace defaults in `profiles/default.env`.
- Python container images exist for deployable service lanes in `TRR-Backend/Dockerfile` and `screenalytics/Dockerfile.pipeline`.
- Cloudflare Tunnel exposes the Getty local scraper via `Makefile` and `TRR-Backend/scripts/cloudflared-tunnel-config.yml`.

**CI Pipeline:**
- GitHub Actions is the CI system, with workflows in `TRR-Backend/.github/workflows/ci.yml`, `TRR-APP/.github/workflows/web-tests.yml`, `TRR-APP/.github/workflows/firebase-rules.yml`, and `screenalytics/.github/workflows/ci.yml`.

## Environment Configuration

**Required env vars:**
- Shared runtime DB: `TRR_DB_URL`, `TRR_DB_FALLBACK_URL` from `TRR-Backend/.env.example`, `TRR-APP/apps/web/.env.example`, and `screenalytics/.env.example`.
- Shared service auth: `TRR_INTERNAL_ADMIN_SHARED_SECRET`, `SCREENALYTICS_SERVICE_TOKEN` from `docs/workspace/env-contract.md`, `scripts/dev-workspace.sh`, `TRR-Backend/.env.example`, and `screenalytics/.env.example`.
- App auth/data: `NEXT_PUBLIC_FIREBASE_*`, `FIREBASE_SERVICE_ACCOUNT`, `TRR_CORE_SUPABASE_URL`, `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`, `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` from `TRR-APP/apps/web/.env.example`.
- Backend integrations: `SUPABASE_JWT_SECRET`, `TMDB_*`, `REDDIT_*`, `OBJECT_STORAGE_*`, `TRR_API_URL`, `SCREENALYTICS_API_URL`, `TRR_GETTY_*` from `TRR-Backend/.env.example`.
- Screenalytics runtime: `REDIS_URL`, `CELERY_*`, `OBJECT_STORAGE_*`, `TRR_API_URL`, `SCREENALYTICS_API_URL`, `OPENAI_API_KEY`, `GEMINI_*`, `RESEMBLE_API_KEY`, `PYANNOTE_*` from `screenalytics/.env.example` and `screenalytics/config/env/screenalytics-cloud.nodocker.example`.

**Secrets location:**
- Tracked templates only: `TRR-Backend/.env.example`, `TRR-APP/apps/web/.env.example`, `screenalytics/.env.example`, `screenalytics/config/env/screenalytics-cloud.nodocker.example`.
- Local runtime files exist at `TRR-Backend/.env`, `screenalytics/.env`, and workspace `profiles/*.env`; values are intentionally not documented here.
- Vercel-managed env inventory is reviewed in `docs/workspace/vercel-env-review.md`.
- Modal named-secret references live in `profiles/default.env` and `TRR-Backend/trr_backend/modal_jobs.py`.

## Webhooks & Callbacks

**Incoming:**
- Vercel cron callbacks hit `TRR-APP` at `/api/cron/episode-progression` and `/api/cron/create-survey-runs` per `TRR-APP/apps/web/vercel.json`.
- Screenalytics mutating service endpoints require bearer service auth in `screenalytics/apps/api/routers/celery_jobs.py`, `screenalytics/apps/api/routers/computer_use.py`, and `screenalytics/apps/api/routers/cast_screentime.py`.
- Getty local scraper receives authenticated scrape requests at the local/tunneled FastAPI server in `TRR-Backend/scripts/getty_local_server.py`.

**Outgoing:**
- `TRR-APP` proxies/admin routes call `TRR-Backend` using `TRR_API_URL` via `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts` and route handlers under `TRR-APP/apps/web/src/app/api/admin/trr-api/`.
- `TRR-Backend` optionally calls Screenalytics over HTTP using `SCREENALYTICS_API_URL` in `TRR-Backend/api/main.py` and `TRR-Backend/api/screenalytics_auth.py`.
- `screenalytics` calls back into `TRR-Backend` using `TRR_API_URL` and `SCREENALYTICS_SERVICE_TOKEN` in `screenalytics/apps/api/services/cast_screentime.py` and `screenalytics/apps/api/routers/cast.py`.
- `TRR-APP` design-docs routes call Google and OpenAI generation endpoints in `TRR-APP/apps/web/src/app/api/design-docs/analyze-image/route.ts` and `TRR-APP/apps/web/src/app/api/design-docs/generate-image/route.ts`.
- Getty local scrape helper calls the local/tunneled scraper using `TRR_GETTY_LOCAL_URL` in `TRR-APP/apps/web/src/lib/server/admin/getty-local-scrape.ts`.

## MCP-Relevant Tooling

**Workspace MCPs:**
- `chrome-devtools`, `figma`, `figma-desktop`, `github`, `context7`, and project-scoped `supabase` are the documented MCP surfaces in `docs/agent-governance/mcp_inventory.md`.
- Managed browser automation uses the shared Chrome wrapper and `codex@thereality.report` profile per `docs/workspace/chrome-devtools.md` and `scripts/codex-chrome-devtools-mcp.sh`.

---

*Integration audit: 2026-04-04*
