# External Integrations

**Analysis Date:** 2026-04-02

## APIs & External Services

**TRR content and media sources:**
- TMDb - Primary show, season, episode, and entity enrichment for `TRR-Backend`.
  - SDK/Client: `requests`-based integrations and sync scripts under `TRR-Backend/scripts/**`; runtime dependency declared in `TRR-Backend/requirements.in`.
  - Auth: `TMDB_BEARER_TOKEN` or `TMDB_API_KEY`, documented in `TRR-Backend/README.md`.
- TVDB - Supplemental show metadata for `TRR-Backend`.
  - SDK/Client: backend sync/import code under `TRR-Backend/scripts/**`.
  - Auth: `TVDB_API_KEY`, documented in `TRR-Backend/README.md`.
- IMDb - Episode, cast, and external-id enrichment for `TRR-Backend`.
  - SDK/Client: backend sync/import code under `TRR-Backend/scripts/**`.
  - Auth: `IMDB_API_KEY`, documented in `TRR-Backend/README.md`.
- Fandom / wiki scraping - Show- and cast-enrichment flows in `TRR-Backend/scripts/backfill_fandom_link_discovery.py`, `TRR-Backend/scripts/import_fandom_gallery_photos.py`, and app-side typecheck surface `TRR-APP/apps/web/tsconfig.typecheck.fandom.json`.
  - SDK/Client: `requests`, `beautifulsoup4`, and crawler utilities from `TRR-Backend/requirements.in`.
  - Auth: none detected.
- Social platform ingestion - Platform adapters are normalized in `TRR-Backend/trr_backend/socials/platforms.py` for `instagram`, `tiktok`, `twitter`/`x.com`, `youtube`, `facebook`, `threads`, and `reddit`.
  - SDK/Client: backend-owned workers and adapters under `TRR-Backend/trr_backend/socials/**` and Modal dispatch in `TRR-Backend/trr_backend/modal_dispatch.py`.
  - Auth: platform-specific secrets are externalized; shared worker dispatch is gated by Modal env vars plus workspace secret contracts in `docs/workspace/env-contract.md`.

**AI and automation services:**
- Google Gemini - Used for backend enrichment and app-side image generation.
  - SDK/Client: `google-genai` in `TRR-Backend/requirements.in` and `screenalytics/requirements-ml.in`; direct HTTP call in `TRR-APP/apps/web/src/app/api/design-docs/generate-image/route.ts`.
  - Auth: `GEMINI_API_KEY` / `GOOGLE_GEMINI_API_KEY` / `GOOGLE_API_KEY` in `screenalytics/apps/api/config/__init__.py` and `TRR-Backend/README.md`.
- OpenAI - Used for image generation in `TRR-APP` and diagnostics in `screenalytics`.
  - SDK/Client: direct HTTP to `/v1/images/generations` in `TRR-APP/apps/web/src/app/api/design-docs/generate-image/route.ts`; Python `openai` client in `screenalytics/apps/api/services/openai_diagnostics.py`.
  - Auth: `OPENAI_API_KEY`.
- Anthropic - Used for Screenalytics diagnostics and computer-use flows.
  - SDK/Client: `anthropic` in `TRR-Backend/requirements.in` and `screenalytics/requirements-core.in`; `screenalytics/apps/api/services/openai_diagnostics.py`; `screenalytics/apps/api/routers/computer_use.py`.
  - Auth: `ANTHROPIC_API_KEY`.
- Modal - Remote execution backend for long-running TRR jobs.
  - SDK/Client: `modal` in `TRR-Backend/requirements.in`; dispatch logic in `TRR-Backend/trr_backend/modal_dispatch.py`.
  - Auth: `TRR_MODAL_*`, `MODAL_ENVIRONMENT`, and related workspace defaults in `docs/workspace/env-contract.md`.
- PyannoteAI webhook callbacks - Async diarization completion callback for Screenalytics.
  - SDK/Client: webhook route in `screenalytics/apps/api/routers/audio.py` at `/webhooks/pyannote/diarization`.
  - Auth: no signature verification detected in the route; correlation is handled through the in-memory job registry in the same file.
- Resemble - Audio/voice pipeline integration surface in Screenalytics.
  - SDK/Client: env-driven audio config in `screenalytics/apps/api/config/__init__.py` and audio router capability checks in `screenalytics/apps/api/routers/audio.py`.
  - Auth: `RESEMBLE_API_KEY`.

**Frontend auth and admin services:**
- Firebase Auth / Firestore / Analytics - Primary client auth stack and Firestore-backed app features for `TRR-APP`.
  - SDK/Client: `TRR-APP/apps/web/src/lib/firebase.ts`, `TRR-APP/apps/web/src/lib/firebase-db.ts`, `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`.
  - Auth: `NEXT_PUBLIC_FIREBASE_*`, `FIREBASE_SERVICE_ACCOUNT`, and emulator toggles in `TRR-APP/apps/web/src/lib/firebase-client-config.ts`.
- Supabase Auth admin lookup - Optional/alternate auth provider path in `TRR-APP`.
  - SDK/Client: `@supabase/supabase-js` in `TRR-APP/apps/web/src/lib/server/auth.ts`.
  - Auth: `TRR_CORE_SUPABASE_URL`, `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY` from `TRR-APP/apps/web/src/lib/server/supabase-trr-admin.ts`.

## Data Storage

**Databases:**
- Supabase-hosted Postgres is the canonical shared operational database.
  - Connection: `TRR_DB_URL` primary, `TRR_DB_FALLBACK_URL` secondary in `TRR-Backend/trr_backend/db/connection.py`, `screenalytics/apps/api/services/supabase_db.py`, and `TRR-APP/apps/web/src/lib/server/postgres.ts`.
  - Client: `psycopg2-binary` in Python repos; `pg` in `TRR-APP/apps/web/package.json`; optional `@supabase/supabase-js` only for auth/admin lookups.
  - Schema ownership: `TRR-Backend/supabase/**` owns migrations and local Supabase CLI config; `screenalytics/apps/api/services/trr_metadata_db.py` explicitly treats `core.*` as read-only consumer state.
- Firebase Firestore is still active for app-specific user/session/survey data.
  - Connection: Firebase client/admin env in `TRR-APP/apps/web/src/lib/firebase-client-config.ts` and `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`.
  - Client: `firebase`, `firebase-admin`.

**File Storage:**
- `TRR-Backend` uses S3-compatible object storage for media mirroring via `TRR-Backend/trr_backend/object_storage.py` and `TRR-Backend/trr_backend/media/s3_mirror.py`.
  - Auth: `OBJECT_STORAGE_BUCKET`, `OBJECT_STORAGE_REGION`, `OBJECT_STORAGE_PUBLIC_BASE_URL`, optional `OBJECT_STORAGE_ENDPOINT_URL`, `OBJECT_STORAGE_ACCESS_KEY_ID`, `OBJECT_STORAGE_SECRET_ACCESS_KEY`, `OBJECT_STORAGE_SESSION_TOKEN`, `OBJECT_STORAGE_PROFILE`.
  - Provider note: config auto-classifies `r2` when endpoint contains `cloudflarestorage.com`.
- `screenalytics` supports `local`, `s3`/`minio`, and `hybrid` artifact backends in `screenalytics/apps/api/services/storage_backend.py`.
  - Auth: `STORAGE_BACKEND`, `OBJECT_STORAGE_*`, plus compatibility names like `S3_BUCKET` / `BUCKET`.
  - Operational examples: cloud R2 configuration is documented in `screenalytics/config/env/screenalytics-cloud.nodocker.example`.

**Caching:**
- Redis is the active cache/broker layer for `screenalytics`.
  - Connection: `REDIS_URL` in `screenalytics/apps/api/config/__init__.py`.
  - Client: `redis` and Celery/Kombu in `screenalytics/requirements-core.in`.
  - Uses: Celery broker/result backend in `screenalytics/apps/api/celery_app.py` and screentime cache in `screenalytics/apps/api/services/screentime_cache.py`.

## Authentication & Identity

**Auth Provider:**
- `TRR-APP` defaults to Firebase auth, with an optional Supabase-auth mode and shadow comparison in `TRR-APP/apps/web/src/lib/server/auth.ts`.
  - Implementation: Firebase ID token or session-cookie verification, fallback Identity Toolkit lookup, and optional Supabase `auth.getUser()` lookup.
- `TRR-Backend` verifies Supabase JWTs and accepts app-signed internal admin JWTs.
  - Implementation: `TRR-Backend/api/auth.py` uses `trr_backend/security/jwt.py` plus `trr_backend/security/internal_admin.py`.
- Service-to-service auth between `TRR-Backend` and `screenalytics` uses a shared bearer token.
  - Implementation: `TRR-Backend/api/screenalytics_auth.py`, `screenalytics/apps/api/routers/cast_screentime.py`, `screenalytics/apps/api/routers/computer_use.py`, and `screenalytics/apps/api/routers/celery_jobs.py`.

## Monitoring & Observability

**Error Tracking:**
- Better Stack / Logtail log shipping is wired into `TRR-Backend/trr_backend/observability.py`.
  - Auth: `BETTER_STACK_SOURCE_TOKEN` or `LOGTAIL_SOURCE_TOKEN`.
- No equivalent external error-tracking SaaS is detected in `screenalytics`; it exposes internal diagnostics endpoints and optional AI analysis.

**Logs:**
- Structured Python logs with trace IDs are emitted by `TRR-Backend/trr_backend/observability.py` and `screenalytics/apps/api/services/observability.py`.
- Prometheus metrics are exposed when `prometheus_client` is installed in both Python APIs.
- Next.js/API route logs are standard console logs in `TRR-APP/apps/web/src/app/api/**`.

## CI/CD & Deployment

**Hosting:**
- `TRR-APP/apps/web` is Vercel-oriented via `TRR-APP/apps/web/vercel.json`.
- `TRR-Backend` is deployable as a containerized web service, with an explicit Render descriptor in `TRR-Backend/render.yaml` and Cloud Run-compatible container entrypoint in `TRR-Backend/Dockerfile`.
- `screenalytics` is container- and worker-oriented; `screenalytics/Dockerfile.pipeline` builds the pipeline/runtime image, while local docs in `screenalytics/README.md` expect API + Celery + optional Streamlit + optional Next.js web services.

**CI Pipeline:**
- `TRR-APP/.github/workflows/web-tests.yml` runs Node 24 full-lane and Node 22 compatibility-lane checks, enforcing pnpm, lint, Vitest, and build.
- `TRR-Backend/.github/workflows/ci.yml` validates env-contract expectations, re-compiles the `uv` lock, imports `api.main`, and runs backend API tests.
- `screenalytics/.github/workflows/ci.yml` validates env contracts, verifies both `uv` locks, runs Ruff/compile gates, unit tests, smoke dry-runs, and a Python 3.12 canary.

## Environment Configuration

**Required env vars:**
- Shared DB/runtime: `TRR_DB_URL`, optional `TRR_DB_FALLBACK_URL`.
- Cross-service secrets: `TRR_INTERNAL_ADMIN_SHARED_SECRET`, `SCREENALYTICS_SERVICE_TOKEN`.
- TRR frontend/backend boundary: `TRR_API_URL` in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.
- TRR app auth: `NEXT_PUBLIC_FIREBASE_*`, optional `FIREBASE_SERVICE_ACCOUNT`, optional `TRR_AUTH_PROVIDER`, `TRR_AUTH_SHADOW_MODE`, `TRR_CORE_SUPABASE_URL`, `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`.
- Screenalytics runtime: `REDIS_URL`, `CELERY_BROKER_URL`, `CELERY_RESULT_BACKEND`, `STORAGE_BACKEND`, `OBJECT_STORAGE_*`, `SCREENALYTICS_ENV`, `SCREENALYTICS_ENABLE_V2_API`.
- AI/media providers: `GEMINI_API_KEY`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `RESEMBLE_API_KEY`, `PYANNOTE_AUTH_TOKEN`.
- Deployment/ops: `CRON_SECRET` for Vercel cron routes, `TRR_MODAL_*` / `MODAL_ENVIRONMENT` for remote jobs, `BETTER_STACK_SOURCE_TOKEN` / `LOGTAIL_SOURCE_TOKEN` for backend log shipping.

**Secrets location:**
- Runtime secrets are expected from repo-local env files and deployment environment managers; checked-in docs standardize names in `docs/workspace/env-contract.md`.
- Local Supabase auth/storage config references `env(...)` secrets in `TRR-Backend/supabase/config.toml`.
- GitHub Actions validate presence/contract shape through `TRR-APP/.github/workflows/web-tests.yml`, `TRR-Backend/.github/workflows/ci.yml`, and `screenalytics/.github/workflows/ci.yml`.

## Webhooks & Callbacks

**Incoming:**
- `screenalytics/apps/api/routers/audio.py` exposes `POST /webhooks/pyannote/diarization` for diarization completion callbacks.
- `TRR-APP/apps/web/src/app/api/cron/episode-progression/route.ts` and `TRR-APP/apps/web/src/app/api/cron/create-survey-runs/route.ts` are Vercel-invoked cron callbacks protected by `CRON_SECRET` in production.

**Outgoing:**
- `screenalytics/apps/api/services/suggestions_webhook.py` sends signed HMAC webhook notifications for successful suggestion runs using `SUGGESTIONS_WEBHOOK_URL` and `SUGGESTIONS_WEBHOOK_SECRET`.
- `screenalytics/apps/api/services/trr_ingest.py` calls back into `TRR-Backend` over HTTP using `TRR_API_URL` plus `SCREENALYTICS_SERVICE_TOKEN`.
- `TRR-APP/apps/web/src/app/api/design-docs/generate-image/route.ts` calls Gemini and OpenAI image APIs directly from the server runtime.

---

*Integration audit: 2026-04-02*
