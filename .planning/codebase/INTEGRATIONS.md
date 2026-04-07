# External Integrations

**Analysis Date:** 2026-04-06

## APIs & External Services

**Cross-repo service boundaries:**
- `TRR-APP` -> `TRR-Backend` - all server-side app calls normalize `TRR_API_URL` to `/api/v1` in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`
  - SDK/Client: native `fetch` plus server helpers under `TRR-APP/apps/web/src/lib/server/trr-api/`
  - Auth: `TRR_INTERNAL_ADMIN_SHARED_SECRET` for privileged internal-admin proxy flows in `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`
- `screenalytics` -> `TRR-Backend` - metadata ingest and cast-screentime sync call the backend base URL from `TRR_API_URL` in `screenalytics/apps/api/services/trr_ingest.py` and `screenalytics/apps/api/services/cast_screentime.py`
  - SDK/Client: `httpx`
  - Auth: `SCREENALYTICS_SERVICE_TOKEN`
- `TRR-Backend` -> `screenalytics` - outbound HTTP is now explicitly legacy/optional; startup logs say screentime and covered image-analysis stay backend-owned if `SCREENALYTICS_API_URL` is absent in `TRR-Backend/api/main.py`
  - SDK/Client: `TRR-Backend/trr_backend/clients/screenalytics.py`
  - Auth: `SCREENALYTICS_SERVICE_TOKEN` or `TRR_INTERNAL_ADMIN_SHARED_SECRET` accepted by `TRR-Backend/api/screenalytics_auth.py`

**App platform services:**
- Vercel - app hosting and scheduled cron invocations for `TRR-APP/apps/web`
  - SDK/Client: platform config in `TRR-APP/apps/web/vercel.json` and project bindings in `TRR-APP/.vercel/project.json`
  - Auth: `CRON_SECRET` for `/api/cron/create-survey-runs` and `/api/cron/episode-progression` in `TRR-APP/apps/web/src/app/api/cron/*/route.ts`
- Firebase - user auth plus local emulator workflow for the app
  - SDK/Client: `firebase`, `firebase-admin`, `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`, and `TRR-APP/apps/web/src/lib/server/auth.ts`
  - Auth: `FIREBASE_SERVICE_ACCOUNT` plus browser `NEXT_PUBLIC_FIREBASE_*`

**Database/admin services:**
- Supabase auth/admin surfaces - app server/admin reads `TRR_CORE_SUPABASE_URL` and `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY` via `TRR-APP/apps/web/src/lib/server/supabase-trr-admin.ts`
  - SDK/Client: `@supabase/supabase-js` in `TRR-APP/apps/web/package.json`
  - Auth: `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`
- Supabase JWT verification - backend auth derives expected issuer/project from Supabase envs in `TRR-Backend/trr_backend/security/jwt.py`
  - SDK/Client: backend JWT helpers plus retained SDK-compatible DB session in `TRR-Backend/trr_backend/db/admin.py`
  - Auth: `SUPABASE_JWT_SECRET`

**Remote execution and browser infrastructure:**
- Modal - backend remote executor for admin, Google News, Reddit, social, and SocialBlade jobs
  - SDK/Client: `TRR-Backend/trr_backend/modal_dispatch.py` and `TRR-Backend/trr_backend/modal_jobs.py`
  - Auth: Modal environment/app linkage via `TRR_MODAL_*` envs and `MODAL_ENVIRONMENT`
- Chrome DevTools MCP - managed browser automation for workspace flows
  - SDK/Client: `scripts/codex-chrome-devtools-mcp.sh`
  - Auth: seeded Chrome profile policy in `docs/workspace/chrome-devtools.md`

**Content, scraping, and AI providers:**
- Google Sheets / Google Auth - backend ingestion tooling in `TRR-Backend/requirements.in`
  - SDK/Client: `gspread`, `google-auth`, `google-auth-oauthlib`
  - Auth: `GOOGLE_APPLICATION_CREDENTIALS`, `GOOGLE_SERVICE_ACCOUNT_FILE`
- TMDb, IMDb, TVDB, Firecrawl, Gemini, OpenAI, NBCUMV, Better Stack - configured in `TRR-Backend/.env.example` and used from `TRR-Backend/trr_backend/integrations/` plus `TRR-Backend/trr_backend/observability.py`
  - SDK/Client: service-specific modules under `TRR-Backend/trr_backend/integrations/`, `TRR-Backend/trr_backend/socials/`, and `TRR-Backend/trr_backend/observability.py`
  - Auth: provider-specific envs such as `TMDB_API_KEY`, `IMDB_API_KEY`, `GEMINI_API_KEY`, `OPENAI_API_KEY`, `NBCUMV_APPSYNC_API_KEY`, `BETTER_STACK_SOURCE_TOKEN`
- PyannoteAI / suggestion webhooks - screenalytics async audio and suggestion callbacks
  - SDK/Client: `screenalytics/apps/api/routers/audio.py` and `screenalytics/apps/api/services/suggestions_webhook.py`
  - Auth: `PYANNOTEAI_API_KEY`, `SUGGESTIONS_WEBHOOK_SECRET`

## Data Storage

**Databases:**
- Supabase Postgres 17 is the shared system of record, with local Supabase config in `TRR-Backend/supabase/config.toml`
  - Connection: `TRR_DB_URL`
  - Client: `psycopg2` in `TRR-Backend/trr_backend/db/connection.py`, `screenalytics/apps/api/services/supabase_db.py`, and `pg` in `TRR-APP/apps/web/src/lib/server/postgres.ts`
- Explicit runtime fallback lane exists but stays secondary
  - Connection: `TRR_DB_FALLBACK_URL`
  - Client: same clients as above; ordering is enforced in `TRR-Backend/trr_backend/db/connection.py`, `screenalytics/apps/api/services/supabase_db.py`, and `TRR-APP/apps/web/src/lib/server/postgres.ts`

**File Storage:**
- S3-compatible object storage is primary across backend and screenalytics
  - Backend: provider-neutral contract in `TRR-Backend/trr_backend/object_storage.py`
  - Screenalytics: local / S3 / MinIO / hybrid abstraction in `screenalytics/apps/api/services/storage_backend.py`
  - Config: `OBJECT_STORAGE_*` in `TRR-Backend/.env.example` and `STORAGE_BACKEND` plus object-store envs in `screenalytics/.env.example`
- Vercel-hosted static/public assets also appear in the app config
  - Example base URL: `NEXT_PUBLIC_HOSTED_FONT_BASE_URL` in `TRR-APP/apps/web/.env.example`

**Caching:**
- Redis-backed realtime/event and worker caching is optional on the backend in `TRR-Backend/api/realtime/broker.py`
- Redis/Celery is an explicit screenalytics queue lane in `screenalytics/apps/api/config/__init__.py` and `screenalytics/.env.example`
- In-process caches also exist for Modal health and webhook retries in `TRR-Backend/trr_backend/modal_dispatch.py` and `screenalytics/apps/api/services/suggestions_webhook.py`

## Authentication & Identity

**Auth Provider:**
- Firebase remains the app-facing auth provider
  - Implementation: `TRR-APP/apps/web/src/lib/server/auth.ts` and `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`
- Supabase remains the server/admin and browser data/auth helper surface
  - Implementation: browser env contract in `TRR-APP/apps/web/.env.example` and admin env contract in `TRR-APP/apps/web/src/lib/server/supabase-trr-admin.ts`
- Internal service-to-service auth is HMAC/JWT/shared-secret based
  - Implementation: `TRR-Backend/trr_backend/security/internal_admin.py`, `TRR-Backend/api/screenalytics_auth.py`, and `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`

## Monitoring & Observability

**Error Tracking:**
- Better Stack / Logtail style HTTP log shipping is built into the backend in `TRR-Backend/trr_backend/observability.py`
- Prometheus-style metrics are exposed from backend and screenalytics API middleware in `TRR-Backend/trr_backend/observability.py` and `screenalytics/apps/api/main.py`

**Logs:**
- Workspace process/log management runs through `.logs/workspace/` and root scripts such as `scripts/dev-workspace.sh`, `scripts/status-workspace.sh`, and `scripts/logs-workspace.sh`
- App cron routes and service proxies log to platform/runtime logs in `TRR-APP/apps/web/src/app/api/cron/*/route.ts`

## CI/CD & Deployment

**Hosting:**
- `TRR-APP` -> Vercel project `trr-app` in `TRR-APP/.vercel/project.json`
- `TRR-Backend` -> FastAPI service plus Modal remote-job app `trr-backend-jobs`; the repo clearly pins Modal as the active remote executor, while the API base is supplied by `TRR_API_URL`
- `screenalytics` -> separate hosted/runtime process outside the root workspace startup, with local API/Streamlit/Web toggles managed by `scripts/dev-workspace.sh`

**CI Pipeline:**
- No single root CI config is the operative source of truth for this map
- Workspace verification is standardized in `Makefile` and `docs/workspace/dev-commands.md`
- Formal cross-repo rollout order and environment review gates live in `docs/cross-collab/WORKFLOW.md` and `docs/workspace/vercel-env-review.md`

## Environment Configuration

**Required env vars:**
- Shared runtime DB: `TRR_DB_URL`, optional `TRR_DB_FALLBACK_URL`
- App server/admin Supabase: `TRR_CORE_SUPABASE_URL`, `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`
- App browser Supabase: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- Cross-repo HTTP: `TRR_API_URL`, `SCREENALYTICS_API_URL`
- Shared secrets: `TRR_INTERNAL_ADMIN_SHARED_SECRET`, `SCREENALYTICS_SERVICE_TOKEN`
- App auth/admin: `FIREBASE_SERVICE_ACCOUNT`, `ADMIN_EMAIL_ALLOWLIST`, `ADMIN_DISPLAYNAME_ALLOWLIST`
- Backend auth: `SUPABASE_JWT_SECRET`
- Vercel cron auth: `CRON_SECRET`

**Secrets location:**
- Contracts are documented in `TRR-Backend/.env.example`, `TRR-APP/apps/web/.env.example`, `screenalytics/.env.example`, `docs/workspace/env-contract.md`, and `AGENTS.md`
- Workspace-generated local fallbacks for shared service secrets are injected by `scripts/dev-workspace.sh`
- Vercel-reviewed retained env surface is documented in `docs/workspace/vercel-env-review.md`

## Webhooks & Callbacks

**Incoming:**
- `screenalytics/apps/api/routers/audio.py` exposes `/webhooks/pyannote/diarization` for PyannoteAI diarization completion
- `TRR-APP/apps/web/src/app/api/cron/create-survey-runs/route.ts` and `TRR-APP/apps/web/src/app/api/cron/episode-progression/route.ts` receive Vercel Cron requests
- No public third-party webhook endpoints were detected in `TRR-Backend/api/` during this tech audit

**Outgoing:**
- `screenalytics/apps/api/services/suggestions_webhook.py` POSTs signed suggestion-ready notifications to `SUGGESTIONS_WEBHOOK_URL`
- `screenalytics/apps/api/services/trr_ingest.py` and `screenalytics/apps/api/services/cast_screentime.py` call `TRR-Backend`
- `TRR-APP/apps/web/src/lib/server/trr-api/` calls `TRR-Backend`
- `TRR-Backend/trr_backend/modal_dispatch.py` dispatches remote work to Modal

---

*Integration audit: 2026-04-06*
