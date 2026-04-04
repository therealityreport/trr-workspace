# External Integrations

**Analysis Date:** 2026-04-04

## APIs & External Services

**Database / Platform Backbone:**
- Supabase Postgres - shared primary data plane for TRR metadata and app state.
  - SDK/Client: `psycopg2` in `TRR-Backend/trr_backend/db/`, `screenalytics/apps/api/services/supabase_db.py`; `pg` in `TRR-APP/apps/web/src/lib/server/postgres.ts`; `@supabase/supabase-js` in `TRR-APP/apps/web/src/lib/server/auth.ts`.
  - Auth: `TRR_DB_URL`, `TRR_DB_FALLBACK_URL`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`, `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `TRR_CORE_SUPABASE_URL`, `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`.
- Supabase local/project config - migrations, schema docs, and local replay in `TRR-Backend/supabase/config.toml` and `TRR-Backend/Makefile`.
  - SDK/Client: Supabase CLI/runtime config.
  - Auth: local config reads env-backed values in `TRR-Backend/supabase/config.toml`.

**TV Metadata, Media, and Brand Sources:**
- TMDb - list ingestion, external IDs, show metadata, watch providers, and person metadata in `TRR-Backend/trr_backend/integrations/tmdb/client.py` and `TRR-Backend/trr_backend/integrations/tmdb_person.py`.
  - SDK/Client: direct `requests`.
  - Auth: `TMDB_API_KEY`, optional `TMDB_BEARER_TOKEN` / `TMDB_BEARER`.
- IMDb GraphQL / title pages - credits, lists, episodic metadata, galleries, and company/title parsing in `TRR-Backend/trr_backend/integrations/imdb/`.
  - SDK/Client: direct `requests`.
  - Auth: runtime headers and tuning envs under the `IMDB_*` namespace; `TRR-Backend/scripts/README.md` documents `IMDB_API_KEY` for scripts.
- Brandfetch - logo discovery for networks/providers in `TRR-Backend/trr_backend/integrations/brandfetch.py`.
  - SDK/Client: direct `requests`.
  - Auth: `BRANDFETCH_API_KEY`.
- Logopedia / Fandom logos - fallback logo discovery in `TRR-Backend/trr_backend/integrations/logopedia.py`.
  - SDK/Client: direct `requests`.
  - Auth: no credential detected; timeout/retry envs `LOGOPEDIA_TIMEOUT_SEC`, `LOGOPEDIA_RETRY_ATTEMPTS`, `LOGOPEDIA_RETRY_BACKOFF_MS`.
- Getty Images - editorial image discovery and local-assisted access in `TRR-Backend/trr_backend/integrations/getty.py`, `TRR-Backend/trr_backend/integrations/getty_local_prefetch.py`, `TRR-Backend/scripts/getty_local_server.py`, and root `Makefile` targets `getty-server` / `getty-tunnel`.
  - SDK/Client: `requests`, BeautifulSoup, and optional browser/local tunnel flow.
  - Auth: `TRR_GETTY_*` env family plus optional local scraper secret `TRR_GETTY_SCRAPER_SECRET`.
- NBCUniversal Media Village - asset lookup via GraphQL/AppSync plus AWS endpoints in `TRR-Backend/trr_backend/integrations/nbcumv.py`.
  - SDK/Client: `requests`, `PIL`.
  - Auth: `NBCUMV_APPSYNC_URL`, `NBCUMV_APPSYNC_API_KEY`, `NBCUMV_BATCH_DOWNLOAD_URL`, `NBCUMV_CLOUDSEARCH_URL`.
- Bravo / Fandom / Free logo sources / PicDetective - editorial and brand-source enrichment in `TRR-Backend/trr_backend/integrations/bravo_jsonapi.py`, `TRR-Backend/trr_backend/integrations/fandom.py`, `TRR-Backend/trr_backend/integrations/free_logo_sources.py`, and `TRR-Backend/trr_backend/integrations/picdetective.py`.
  - SDK/Client: direct `requests` / urllib / HTML parsing.
  - Auth: no secret contract detected in the repo for these paths.

**Social Platforms and Discovery:**
- Reddit - app-side OAuth-assisted discovery in `TRR-APP/apps/web/src/lib/server/admin/reddit-oauth-client.ts`; backend refresh and reads in `TRR-Backend/api/routers/socials.py`.
  - SDK/Client: native `fetch`.
  - Auth: `REDDIT_CLIENT_ID`, `REDDIT_CLIENT_SECRET`, optional `REDDIT_USER_AGENT`.
- YouTube Data API - official handle/video/comment enrichment in `TRR-Backend/trr_backend/socials/youtube/api_client.py`.
  - SDK/Client: direct `requests`.
  - Auth: `SOCIAL_AUTH_YOUTUBE_API_KEY`.
- Instagram / TikTok / Twitter / Threads / Facebook / YouTube scraping - browser/Crawlee-driven ingestion in `TRR-Backend/trr_backend/socials/` and `TRR-Backend/scripts/socials/`.
  - SDK/Client: `crawlee`, `requests`, Playwright/browser runtime through Modal image setup in `TRR-Backend/trr_backend/modal_jobs.py`.
  - Auth: platform-specific cookie/session envs are referenced across `TRR-Backend/trr_backend/socials/*/cookie_refresh.py`; shared worker auth uses `SCREENALYTICS_SERVICE_TOKEN` and internal admin auth.
- SocialBlade - growth scraping and persistence in `TRR-Backend/trr_backend/socials/socialblade/service.py` and `TRR-Backend/trr_backend/repositories/socialblade_growth.py`.
  - SDK/Client: scraper callback + Postgres persistence.
  - Auth: no SocialBlade API secret detected; freshness and refresh toggles use `SOCIALBLADE_*` envs.

**AI / ML Providers:**
- OpenAI - fandom cleanup in `TRR-Backend/trr_backend/integrations/openai_fandom_cleanup.py`; diagnostics in `screenalytics/apps/api/services/openai_diagnostics.py`; optional screenalytics web dependency in `screenalytics/web/package.json`.
  - SDK/Client: direct HTTPS in backend; `openai` Python/JS clients in screenalytics.
  - Auth: `OPENAI_API_KEY`, optional `OPENAI_FANDOM_MODEL`, `OPENAI_DIAGNOSTIC_MODEL`.
- Anthropic - backend computer-use router in `TRR-Backend/trr_backend/clients/computer_use.py`; diagnostics option in `screenalytics/apps/api/services/openai_diagnostics.py`.
  - SDK/Client: `claude-computer-use` and `anthropic`.
  - Auth: `ANTHROPIC_API_KEY`, optional `ANTHROPIC_DIAGNOSTIC_MODEL`.
- Google Gemini / Google APIs - pipeline/model usage in `TRR-Backend/requirements.in`, `TRR-APP/requirements.in`, and `screenalytics/apps/api/config/__init__.py`.
  - SDK/Client: `google-genai` / `google-generativeai`, `google-auth`, `gspread`.
  - Auth: `GEMINI_API_KEY`, `GOOGLE_GEMINI_API_KEY`, `GOOGLE_API_KEY`, `GEMINI_MODEL`, `GEMINI_MODEL_FAST`, `GEMINI_MODEL_PRO`.
- PyannoteAI / audio tooling - webhook-driven diarization completion in `screenalytics/apps/api/routers/audio.py`.
  - SDK/Client: application webhook endpoint plus local processing pipeline.
  - Auth: `PYANNOTE_AUTH_TOKEN`.
- Resemble AI - audio pipeline config in `screenalytics/apps/api/config/__init__.py`.
  - SDK/Client: runtime env/config only detected here.
  - Auth: `RESEMBLE_API_KEY`.

## Data Storage

**Databases:**
- Shared Supabase-hosted Postgres is the canonical runtime database.
  - Connection: `TRR_DB_URL` primary, `TRR_DB_FALLBACK_URL` fallback per `docs/workspace/env-contract-inventory.md`.
  - Client: `psycopg2` in `TRR-Backend/trr_backend/db/` and `screenalytics/apps/api/services/supabase_db.py`; `pg` in `TRR-APP/apps/web/src/lib/server/postgres.ts`; `@supabase/supabase-js` in `TRR-APP/apps/web/src/lib/server/auth.ts`.
- Supabase Auth/admin surfaces remain active for backend verification and app-side admin access.
  - Connection: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`, `TRR_CORE_SUPABASE_URL`, `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`.
  - Client: `TRR-Backend/api/auth.py`, `TRR-APP/apps/web/src/lib/server/auth.ts`, `TRR-APP/apps/web/src/lib/server/supabase-trr-admin.ts`.

**File Storage:**
- S3-compatible object storage is the canonical media/artifact layer.
  - `TRR-Backend` uses `TRR-Backend/trr_backend/object_storage.py` for S3/R2-compatible clients with `OBJECT_STORAGE_*` env vars.
  - `screenalytics` uses `screenalytics/apps/api/services/storage.py` for S3/MinIO-compatible artifacts plus facebank mirrors.
  - Local fallback / dev infra: explicit Docker-backed MinIO path is documented in `Makefile`, `docs/workspace/dev-commands.md`, and `screenalytics/apps/api/config/__init__.py`/storage code.

**Caching:**
- Redis-backed broker/cache is used when configured.
  - `TRR-Backend` realtime pub/sub switches from in-memory to Redis when `REDIS_URL` is set in `TRR-Backend/api/realtime/broker.py`.
  - `screenalytics` uses Redis for Celery broker/result backend and screentime caching in `screenalytics/apps/api/config/__init__.py`, `screenalytics/apps/api/celery_app.py`, and `screenalytics/apps/api/services/screentime_cache.py`.

## Authentication & Identity

**Auth Provider:**
- `TRR-Backend`: Supabase JWT verification for user/service-role access plus internal admin JWTs signed with `TRR_INTERNAL_ADMIN_SHARED_SECRET` in `TRR-Backend/api/auth.py`.
  - Implementation: bearer-token verification through `trr_backend/security/jwt.py` and `trr_backend/security/internal_admin.py`.
- `TRR-APP`: Firebase Auth is the default primary provider with optional Supabase provider/shadow mode in `TRR-APP/apps/web/src/lib/server/auth.ts`, `TRR-APP/apps/web/src/lib/firebase.ts`, and `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`.
  - Implementation: browser Firebase auth, server Firebase Admin verification, optional Supabase `auth.getUser(token)` path.
- `screenalytics`: service-to-service bearer auth for protected control routes in `screenalytics/apps/api/main.py` and `screenalytics/apps/api/routers/celery_jobs.py`.
  - Implementation: `SCREENALYTICS_SERVICE_TOKEN` bearer checks; TRR-Backend compatibility auth in `TRR-Backend/api/screenalytics_auth.py`.

## Monitoring & Observability

**Error Tracking:**
- Dedicated error-tracking SaaS integration is not detected.
- Optional Better Stack HTTP log shipping is documented for `TRR-Backend` in `TRR-Backend/docs/api/run.md`.

**Logs:**
- Structured runtime observability is built into `TRR-Backend/trr_backend/observability.py` and `screenalytics/apps/api/services/observability.py`.
- Workspace log lifecycle is managed by `scripts/logs-workspace.sh`, `scripts/logs-prune.sh`, and `scripts/status-workspace.sh`.
- Backend/API metrics surfaces are wired in `TRR-Backend/api/main.py` and `screenalytics/apps/api/main.py`.

## CI/CD & Deployment

**Hosting:**
- `TRR-APP` is the only clearly declared app-hosting target and uses Vercel via `TRR-APP/apps/web/vercel.json` and `docs/workspace/vercel-env-review.md`.
- `TRR-Backend` ships as a containerized FastAPI service via `TRR-Backend/Dockerfile`; deployment guidance references a Render-hosted API plus Modal async plane in `TRR-Backend/docs/api/run.md`.
- `TRR-Backend` long-running jobs and browser-enabled scraping execute on Modal in `TRR-Backend/trr_backend/modal_jobs.py` and `TRR-Backend/trr_backend/modal_dispatch.py`.
- `screenalytics` has local/API deployment surfaces in `screenalytics/apps/api/main.py` and `screenalytics/Dockerfile.pipeline`; no separate workspace-level production hosting policy is detected.

**CI Pipeline:**
- Workspace-level verification commands are standardized in `AGENTS.md`, `Makefile`, and `docs/workspace/dev-commands.md`.
- Repo-local quality gates are exposed through `TRR-Backend/Makefile`, `screenalytics/Makefile`, and `TRR-APP/apps/web/package.json`.

## Environment Configuration

**Required env vars:**
- Shared canonical cross-repo env names are inventoried in `docs/workspace/env-contract-inventory.md`.
- Backend/app/db fundamentals: `TRR_API_URL`, `SCREENALYTICS_API_URL`, `TRR_DB_URL`, `TRR_DB_FALLBACK_URL`.
- Shared secrets: `TRR_INTERNAL_ADMIN_SHARED_SECRET`, `SCREENALYTICS_SERVICE_TOKEN`.
- TRR-APP browser/server auth: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `TRR_CORE_SUPABASE_URL`, `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`, `FIREBASE_SERVICE_ACCOUNT`, `NEXT_PUBLIC_FIREBASE_*`.
- Backend auth/runtime: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`.
- Storage/runtime platforms: `OBJECT_STORAGE_*`, `REDIS_URL`, `TRR_MODAL_*`, `WORKSPACE_TRR_*`.

**Secrets location:**
- Shared env contract and naming policy live in `docs/workspace/env-contract.md`, `docs/workspace/env-contract-inventory.md`, and `scripts/env_contract_report.py`.
- Local development composes env through `scripts/dev-workspace.sh`.
- Modal named-secret preparation is handled by `TRR-Backend/scripts/modal/prepare_named_secrets.py`.
- Vercel-managed env review lives in `docs/workspace/vercel-env-review.md`.
- Secret values are intentionally not stored in these docs; runtime secret handling is policy-driven from `AGENTS.md`.

## Webhooks & Callbacks

**Incoming:**
- `screenalytics` receives PyannoteAI diarization callbacks at `screenalytics/apps/api/routers/audio.py` route `POST /webhooks/pyannote/diarization`.
- Vercel cron callbacks hit `TRR-APP/apps/web/src/app/api/cron/episode-progression/route.ts` and `TRR-APP/apps/web/src/app/api/cron/create-survey-runs/route.ts`, guarded by `CRON_SECRET` in production.

**Outgoing:**
- `screenalytics` sends suggestion-ready webhooks from `screenalytics/apps/api/services/suggestions_webhook.py`, enqueued by Celery from `screenalytics/apps/api/tasks_v2.py`.
- `TRR-APP` performs server-to-server proxy calls into `TRR-Backend` via `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`, `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts`, and `TRR-APP/apps/web/src/lib/server/trr-api/social-admin-proxy.ts`.
- `screenalytics` imports TRR metadata over HTTP or direct DB reads through `screenalytics/apps/api/services/trr_ingest.py`.

## Background Jobs & Queues

**Background Jobs:**
- `TRR-Backend` remote job ownership is Modal-first for admin operations, Google News sync, Reddit refresh, social ingest, SocialBlade, and admin vision in `TRR-Backend/trr_backend/modal_jobs.py` and `TRR-Backend/trr_backend/modal_dispatch.py`.
- `screenalytics` async processing uses Celery workers for ML pipelines, audio stages, grouping, and webhook delivery in `screenalytics/apps/api/celery_app.py`, `screenalytics/apps/api/tasks.py`, `screenalytics/apps/api/tasks_v2.py`, and `screenalytics/apps/api/jobs_audio.py`.
- `TRR-APP` scheduled jobs are Vercel crons defined in `TRR-APP/apps/web/vercel.json`.

**Queues:**
- `TRR-Backend` keeps realtime event/broker state in Redis when `REDIS_URL` is present, else falls back to in-process broker semantics in `TRR-Backend/api/realtime/broker.py`.
- `screenalytics` uses Redis as Celery broker/result backend and for screentime cache state in `screenalytics/apps/api/config/__init__.py` and `screenalytics/apps/api/services/screentime_cache.py`.
- Local Screenalytics Docker fallback explicitly supplies Redis + MinIO via workspace commands in `Makefile` and `docs/workspace/dev-commands.md`.

---

*Integration audit: 2026-04-04*
