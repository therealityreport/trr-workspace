# External Integrations

**Analysis Date:** 2026-04-08

## APIs & External Services

**Core data and platform services:**
- Supabase Postgres/Auth - canonical shared data plane for all three repos
  - SDK/Client: Python `psycopg2-binary` via `TRR-Backend/trr_backend/db/connection.py` and `screenalytics/apps/api/services/supabase_db.py`; Node `pg` via `TRR-APP/apps/web/src/lib/server/postgres.ts`; browser/server helpers retained in `TRR-APP/apps/web/src/lib/server/supabase-trr-admin.ts`
  - Auth: `TRR_DB_URL`, `TRR_DB_FALLBACK_URL`, `SUPABASE_JWT_SECRET`, `TRR_CORE_SUPABASE_URL`, `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`
- Firebase Auth/Firestore - app-facing identity and session support in `TRR-APP/apps/web/src/lib/firebase.ts`, `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`, and `TRR-APP/.github/workflows/firebase-rules.yml`
  - SDK/Client: `firebase`, `firebase-admin`
  - Auth: `NEXT_PUBLIC_FIREBASE_*`, `FIREBASE_SERVICE_ACCOUNT`, optional emulator envs

**Metadata and content APIs:**
- TMDb - show, season, episode, image, and list ingestion in `TRR-Backend/trr_backend/integrations/tmdb/client.py`, `TRR-Backend/trr_backend/ingestion/tmdb_show_backfill.py`, and `TRR-Backend/trr_backend/ingestion/tmdb_person_images.py`
  - SDK/Client: `requests`
  - Auth: `TMDB_API_KEY` or `TMDB_BEARER_TOKEN`
- IMDb API / IMDb scraping surfaces - credits, episodic metadata, galleries, and title metadata in `TRR-Backend/trr_backend/integrations/imdb/credits_client.py`, `TRR-Backend/trr_backend/integrations/imdb/episodic_client.py`, and related `TRR-Backend/trr_backend/integrations/imdb/*.py`
  - SDK/Client: `requests`
  - Auth: `IMDB_API_KEY` for the API-backed routes; some parsers are scrape-only
- Google Generative Language (Gemini) - design-doc image analysis/generation in `TRR-APP/apps/web/src/app/api/design-docs/analyze-image/route.ts` and `TRR-APP/apps/web/src/app/api/design-docs/generate-image/route.ts`; backend and Screenalytics model routing is env-driven in `TRR-Backend/README.md`, `screenalytics/apps/api/config/__init__.py`, and `screenalytics/packages/py-screenalytics/src/py_screenalytics/audio/asr_gemini.py`
  - SDK/Client: direct HTTP from app routes; Python runtime code in Screenalytics packages
  - Auth: `GEMINI_API_KEY`, `GOOGLE_GEMINI_API_KEY`, `GOOGLE_API_KEY`, `GEMINI_MODEL*`
- OpenAI - fandom cleanup, design-doc image generation fallback, and diagnostics in `TRR-Backend/trr_backend/integrations/openai_fandom_cleanup.py`, `TRR-APP/apps/web/src/app/api/design-docs/generate-image/route.ts`, and `screenalytics/apps/api/services/openai_diagnostics.py`
  - SDK/Client: direct REST in backend/app routes; `openai` SDK in Screenalytics
  - Auth: `OPENAI_API_KEY`
- Anthropic - Screenalytics diagnostics and computer-use routes in `screenalytics/apps/api/services/openai_diagnostics.py` and `screenalytics/apps/api/routers/computer_use.py`
  - SDK/Client: `anthropic`
  - Auth: `ANTHROPIC_API_KEY`

**Operations and runtime services:**
- Modal - remote TRR job execution in `TRR-Backend/trr_backend/job_plane.py` and `TRR-Backend/trr_backend/modal_dispatch.py`
  - SDK/Client: `modal`
  - Auth: Modal environment and named secret config via `TRR_MODAL_*`, `MODAL_ENVIRONMENT`, and workspace defaults in `scripts/dev-workspace.sh`
- Crawlee-style social scraping runtime - platform-specific scraping runtime switches in `TRR-Backend/trr_backend/socials/crawlee_runtime/config.py`
  - SDK/Client: repo runtime config; downstream scraper packages live outside the mapped subset
  - Auth: platform cookies/accounts are env-driven; exact secrets are intentionally not documented
- Cloudflare Tunnel for Getty scraper exposure - local Getty scraper tunnel commands in `Makefile`
  - SDK/Client: `cloudflared`
  - Auth: Cloudflare tunnel login handled outside repo-tracked files

## Data Storage

**Databases:**
- Supabase/Postgres
  - Connection: `TRR_DB_URL` primary and `TRR_DB_FALLBACK_URL` secondary in `TRR-Backend/trr_backend/db/connection.py`, `TRR-APP/apps/web/src/lib/server/postgres.ts`, and `screenalytics/apps/api/services/supabase_db.py`
  - Client: `psycopg2-binary` for Python repos; `pg` for `TRR-APP`

**File Storage:**
- S3-compatible object storage with Cloudflare R2/S3 support in `TRR-Backend/trr_backend/object_storage.py` and `TRR-Backend/trr_backend/media/s3_mirror.py`
- Screenalytics artifact storage supports `local`, `s3`, `minio`, and `hybrid` in `screenalytics/apps/api/services/storage_backend.py`, `screenalytics/apps/api/services/storage.py`, and `screenalytics/apps/shared/storage.py`
- Local Docker fallback includes MinIO in `screenalytics/infra/docker/compose.yaml`

**Caching:**
- Redis-backed job broker/result backend for Screenalytics in `screenalytics/apps/api/config/__init__.py`, `screenalytics/apps/api/celery_app.py`, and `screenalytics/infra/docker/compose.yaml`
- App/backend in-memory route/job caches exist in code, but no separate external cache service beyond Redis is detected

## Authentication & Identity

**Auth Provider:**
- Firebase Auth for user-facing app identity in `TRR-APP/apps/web/src/lib/firebase.ts` and `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`
  - Implementation: browser Firebase SDK plus server session/login routes and Firebase Admin
- Internal service-to-service JWT for admin proxy calls between `TRR-APP`, `TRR-Backend`, and Screenalytics in `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`, `TRR-Backend/trr_backend/security/internal_admin.py`, and `screenalytics/apps/api/services/internal_admin_auth.py`
  - Implementation: short-lived HS256 bearer token signed with `TRR_INTERNAL_ADMIN_SHARED_SECRET`
- Legacy Screenalytics bearer token remains accepted on compatibility surfaces in `TRR-Backend/api/screenalytics_auth.py` and `screenalytics/apps/api/services/trr_ingest.py`
  - Implementation: `SCREENALYTICS_SERVICE_TOKEN` fallback for old callers
- Supabase JWT local verification is part of backend auth/runtime checks in `TRR-Backend/api/main.py` and `TRR-Backend/trr_backend/security/jwt.py`

## Monitoring & Observability

**Error Tracking:**
- None detected for a hosted third-party error tracker
- Repo-local observability and metrics are implemented in `TRR-Backend/api/main.py`, `TRR-Backend/trr_backend/observability.py`, `screenalytics/apps/api/services/observability.py`, and `screenalytics/apps/api/services/metrics.py`

**Logs:**
- Workspace process logs are written under `.logs/workspace/` by `scripts/dev-workspace.sh`
- Backend and Screenalytics expose request metrics/health endpoints from `TRR-Backend/api/main.py` and `screenalytics/apps/api/main.py`

## CI/CD & Deployment

**Hosting:**
- `TRR-APP` is hosted on Vercel; canonical linked project is `trr-app` in `TRR-APP/.vercel/project.json`
- Long-running backend jobs are designed for Modal remote execution in `TRR-Backend/trr_backend/modal_dispatch.py`
- Screenalytics runtime uses `uvicorn`, `celery`, `streamlit`, and optional `screenalytics/web`; a single production host manifest is not checked in

**CI Pipeline:**
- GitHub Actions drive CI in `TRR-Backend/.github/workflows/ci.yml`, `TRR-APP/.github/workflows/web-tests.yml`, and `screenalytics/.github/workflows/ci.yml`
- Firebase rules deploy from `TRR-APP/.github/workflows/firebase-rules.yml`
- Repo-map/document automation uses GitHub Actions plus `OPENAI_API_KEY` in `TRR-APP/.github/workflows/repo_map.yml` and `TRR-Backend/.github/workflows/repo_map.yml`

## Environment Configuration

**Required env vars:**
- Shared runtime DB: `TRR_DB_URL`, optional `TRR_DB_FALLBACK_URL`
- Shared service auth: `TRR_INTERNAL_ADMIN_SHARED_SECRET`, transitional `SCREENALYTICS_SERVICE_TOKEN`
- App server/admin data access: `TRR_API_URL`, `TRR_CORE_SUPABASE_URL`, `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`
- App auth: `FIREBASE_SERVICE_ACCOUNT`, `NEXT_PUBLIC_FIREBASE_*`
- Backend metadata ingest: `TMDB_API_KEY` or `TMDB_BEARER_TOKEN`, `IMDB_API_KEY`, `TVDB_API_KEY`
- AI services: `OPENAI_API_KEY`, `GEMINI_API_KEY`, `ANTHROPIC_API_KEY`, `RESEMBLE_API_KEY`, `PYANNOTE_AUTH_TOKEN`
- Object storage: `OBJECT_STORAGE_BUCKET`, `OBJECT_STORAGE_REGION`, `OBJECT_STORAGE_PUBLIC_BASE_URL`, optional `OBJECT_STORAGE_ENDPOINT_URL`
- Screenalytics worker/runtime: `REDIS_URL`, `CELERY_BROKER_URL`, `CELERY_RESULT_BACKEND`, `STORAGE_BACKEND`

**Secrets location:**
- Local repo env files are expected in repo roots or app-local files such as `TRR-APP/apps/web/.env.local`; contents were not read
- Vercel-managed app envs are reviewed in `docs/workspace/vercel-env-review.md`
- GitHub Actions secrets are referenced in `.github/workflows/*.yml`
- Workspace local defaults for shared dev auth are synthesized in `scripts/dev-workspace.sh`

## Webhooks & Callbacks

**Incoming:**
- Vercel cron callbacks hit app routes configured in `TRR-APP/apps/web/vercel.json`
- Screenalytics receives Pyannote diarization webhooks at `/webhooks/pyannote/diarization` in `screenalytics/apps/api/routers/audio.py`

**Outgoing:**
- Suggestions-ready webhook posts to an external endpoint from `screenalytics/apps/api/services/suggestions_webhook.py`
- TRR-APP admin proxy routes call TRR-Backend with internal admin bearer tokens via `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`
- Screenalytics imports TRR data over HTTP from `TRR_API_URL` in `screenalytics/apps/api/services/trr_ingest.py`

---

*Integration audit: 2026-04-08*
