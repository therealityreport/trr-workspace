# External Integrations

**Analysis Date:** 2026-04-07

## APIs & External Services

**Cross-repo internal APIs:**
- `TRR-Backend` - Primary application API consumed by `TRR-APP`.
  - SDK/Client: direct `fetch` wrapper in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`
  - Auth: `TRR_API_URL`, `TRR_INTERNAL_ADMIN_SHARED_SECRET`
- `screenalytics` - Legacy outbound image-analysis / screentime HTTP target from `TRR-Backend`.
  - SDK/Client: `TRR-Backend/trr_backend/clients/screenalytics.py`
  - Auth: `SCREENALYTICS_API_URL`, `SCREENALYTICS_SERVICE_TOKEN`

**Identity & auth providers:**
- Firebase Auth / Firestore - Primary user auth and admin SDK lane for `TRR-APP`.
  - SDK/Client: `firebase`, `firebase-admin`
  - Auth: `NEXT_PUBLIC_FIREBASE_*`, `FIREBASE_SERVICE_ACCOUNT`, `NEXT_PUBLIC_USE_FIREBASE_EMULATORS`
- Supabase Auth - Secondary or cutover auth lane for `TRR-APP` server verification.
  - SDK/Client: `@supabase/supabase-js`
  - Auth: `TRR_CORE_SUPABASE_URL`, `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`, `TRR_AUTH_PROVIDER`, `TRR_AUTH_SHADOW_MODE`

**Metadata and content APIs:**
- TMDb - Show, season, person, and external-id enrichment in `TRR-Backend/trr_backend/integrations/tmdb/client.py`, `TRR-Backend/trr_backend/integrations/tmdb_person.py`, and sync scripts under `TRR-Backend/scripts/sync/`.
  - SDK/Client: `requests`
  - Auth: `TMDB_API_KEY`, `TMDB_BEARER_TOKEN`, `TMDB_BEARER`
- Google News RSS - News ingestion and canonical URL / featured image resolution in `TRR-Backend/trr_backend/scraping/google_news_parser.py`.
  - SDK/Client: `requests`, `beautifulsoup4`
  - Auth: none detected
- Fandom / IMDb media sources - Media normalization and mirroring paths in `TRR-Backend/trr_backend/media/s3_mirror.py` and scripts under `TRR-Backend/scripts/media/`.
  - SDK/Client: `requests`, optional `yt-dlp` for Twitter/X video resolution paths
  - Auth: none detected for read-side access

**AI providers:**
- Google Gemini - Image generation in `TRR-APP/apps/web/src/app/api/design-docs/generate-image/route.ts`, text overlay / enrichment in `TRR-Backend/trr_backend/vision/text_overlay.py`, and audio/diagnostic paths in `screenalytics/packages/py-screenalytics/src/py_screenalytics/audio/asr_gemini.py`.
  - SDK/Client: direct HTTP in `TRR-APP`; `google-genai` in Python repos
  - Auth: `GEMINI_API_KEY`, `GOOGLE_GEMINI_API_KEY`, `GOOGLE_API_KEY`
- OpenAI - Design-doc image generation in `TRR-APP/apps/web/src/app/api/design-docs/generate-image/route.ts`, backend cleanup / analytics tasks, and Screenalytics diagnostics and ASR.
  - SDK/Client: direct HTTP in `TRR-APP`; `openai` in Python repos
  - Auth: `OPENAI_API_KEY`
- Anthropic - Computer-use and diagnostics flows in `screenalytics/apps/api/routers/computer_use.py`, `screenalytics/apps/api/services/openai_diagnostics.py`, and backend client helpers under `TRR-Backend/trr_backend/clients/computer_use.py`.
  - SDK/Client: `anthropic`, `claude-computer-use`
  - Auth: `ANTHROPIC_API_KEY`

**Remote execution and social ingestion:**
- Modal - Remote TRR long jobs and social workers from `TRR-Backend/trr_backend/modal_jobs.py` and `TRR-Backend/trr_backend/modal_dispatch.py`.
  - SDK/Client: `modal`
  - Auth: `TRR_MODAL_*`, `MODAL_ENVIRONMENT`, named secrets prepared by `TRR-Backend/scripts/modal/prepare_named_secrets.py`
- Social platform scraping - Instagram, Reddit, Twitter/X, YouTube, and SocialBlade oriented ingestion lives under `TRR-Backend/trr_backend/socials/` and `TRR-Backend/trr_backend/media/s3_mirror.py`.
  - SDK/Client: `requests`, Playwright/browser helpers, Apify adapter paths
  - Auth: workspace-managed Modal secrets and platform-specific cookie/runtime secrets; do not store raw values in docs

## Data Storage

**Databases:**
- Shared Supabase/Postgres database for all three repos.
  - Connection: `TRR_DB_URL`, `TRR_DB_FALLBACK_URL`
  - Client: TRR backend DB session layer in `TRR-Backend/trr_backend/db/connection.py`; Screenalytics Postgres helper in `screenalytics/apps/api/services/supabase_db.py`; frontend admin Supabase auth bridge in `TRR-APP/apps/web/src/lib/server/supabase-trr-admin.ts`
- Frontend server-side Supabase admin surface for auth and admin data access.
  - Connection: `TRR_CORE_SUPABASE_URL`
  - Client: `@supabase/supabase-js` in `TRR-APP/apps/web/src/lib/server/auth.ts`

**File Storage:**
- S3-compatible object storage, with Cloudflare R2 recognized as a provider option in `TRR-Backend/trr_backend/object_storage.py`.
- TRR backend media mirroring, user uploads, and hosted asset variants use `TRR-Backend/trr_backend/media/s3_mirror.py`, `TRR-Backend/trr_backend/media/user_uploads.py`, and `TRR-Backend/trr_backend/object_storage.py`.
- Screenalytics artifacts, exports, and facebank storage use `screenalytics/apps/api/services/storage.py`, `screenalytics/apps/shared/storage.py`, and `screenalytics/apps/api/services/run_artifact_store.py`.
- Local MinIO fallback exists in `screenalytics/infra/docker/compose.yaml`.

**Caching:**
- Redis-backed realtime broker in `TRR-Backend/api/realtime/broker.py`.
- Redis-backed Screenalytics Celery and screentime cache in `screenalytics/apps/api/config/__init__.py` and `screenalytics/apps/api/services/screentime_cache.py`.

## Authentication & Identity

**Auth Provider:**
- Primary app auth is Firebase, implemented in `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`, `TRR-APP/apps/web/src/app/api/session/login/route.ts`, and `TRR-APP/apps/web/src/lib/server/auth.ts`.
  - Implementation: Firebase ID token or session cookie verification, with emulator support in development.
- Secondary app auth is Supabase, implemented in `TRR-APP/apps/web/src/lib/server/auth.ts` and `TRR-APP/apps/web/src/lib/server/supabase-trr-admin.ts`.
  - Implementation: dual-provider verification with shadow diagnostics and cutover counters.
- Internal service auth uses shared bearer secrets.
  - Implementation: `TRR_INTERNAL_ADMIN_SHARED_SECRET` for app-to-backend admin calls, `SCREENALYTICS_SERVICE_TOKEN` for backend-to-screenalytics or internal Screenalytics routes such as `screenalytics/apps/api/routers/cast_screentime.py` and `screenalytics/apps/api/routers/computer_use.py`.
- Backend runtime also requires Supabase JWT verification material.
  - Implementation: `SUPABASE_JWT_SECRET` is validated in `TRR-Backend/api/main.py`.

## Monitoring & Observability

**Error Tracking:**
- Not detected as a dedicated third-party service. No Sentry, Bugsnag, or Rollbar integration was found in active runtime code.

**Logs:**
- Structured application logs and request metrics are initialized in `TRR-Backend/api/main.py` and `screenalytics/apps/api/main.py`.
- Workspace process and watchdog logs are written under `.logs/workspace/` by `scripts/dev-workspace.sh`.
- CI artifacts and generated maps are uploaded from GitHub Actions workflows under each repo’s `.github/workflows/`.

## CI/CD & Deployment

**Hosting:**
- `TRR-APP` - Vercel deployment, documented in `TRR-APP/apps/web/DEPLOY.md` and linked in `TRR-APP/.vercel/project.json`.
- `TRR-Backend` - Containerized API runtime for Cloud Run / Render style deployment via `TRR-Backend/Dockerfile`, plus Modal-hosted long jobs via `TRR-Backend/trr_backend/modal_jobs.py`.
- `screenalytics` - API/UI + worker deployment with Render-oriented docs at `screenalytics/docs/ops/deployment/DEPLOYMENT_RENDER.md`, and Docker-backed local fallback via `screenalytics/infra/docker/compose.yaml`.

**CI Pipeline:**
- GitHub Actions for all repos.
- `TRR-APP/.github/workflows/web-tests.yml` runs Node 24/22 web CI; `TRR-APP/.github/workflows/firebase-rules.yml` validates and deploys Firestore rules.
- `TRR-Backend/.github/workflows/ci.yml` runs Python CI; `TRR-Backend/.github/workflows/mirror-media-assets.yml` runs manual S3 mirroring; `TRR-Backend/.github/workflows/secret-scan.yml` runs Gitleaks.
- `screenalytics/.github/workflows/ci.yml` runs Python CI; `screenalytics/.github/workflows/codex-review.yml`, `screenalytics/.github/workflows/codex-manual.yml`, and `screenalytics/.github/workflows/on-push-doc-sync.yml` add AI-assisted automation.

## Environment Configuration

**Required env vars:**
- Shared DB: `TRR_DB_URL`, optional `TRR_DB_FALLBACK_URL`
- Shared secrets: `TRR_INTERNAL_ADMIN_SHARED_SECRET`, `SCREENALYTICS_SERVICE_TOKEN`
- TRR app auth: `NEXT_PUBLIC_FIREBASE_*`, `FIREBASE_SERVICE_ACCOUNT`, `TRR_AUTH_PROVIDER`, `TRR_AUTH_SHADOW_MODE`
- Frontend direct Supabase admin lane: `TRR_CORE_SUPABASE_URL`, `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`
- Backend auth/runtime: `SUPABASE_JWT_SECRET`, `SCREENALYTICS_API_URL` for legacy HTTP flows
- Object storage: `OBJECT_STORAGE_BUCKET`, `OBJECT_STORAGE_REGION`, `OBJECT_STORAGE_PUBLIC_BASE_URL`, `OBJECT_STORAGE_ENDPOINT_URL`, `OBJECT_STORAGE_ACCESS_KEY_ID`, `OBJECT_STORAGE_SECRET_ACCESS_KEY`, optional `OBJECT_STORAGE_PROFILE`
- Screenalytics storage aliases: `SCREENALYTICS_OBJECT_STORE_*`, `SCREENALYTICS_S3_BUCKET`, `STORAGE_BACKEND`
- Queue / cache: `REDIS_URL`, `CELERY_BROKER_URL`
- AI and metadata APIs: `TMDB_API_KEY`, `TMDB_BEARER_TOKEN`, `OPENAI_API_KEY`, `GEMINI_API_KEY`, `ANTHROPIC_API_KEY`
- Modal: `TRR_MODAL_ENABLED`, `TRR_MODAL_APP_NAME`, `TRR_MODAL_ADMIN_OPERATION_FUNCTION`, `TRR_MODAL_GOOGLE_NEWS_FUNCTION`, `TRR_MODAL_SOCIAL_JOB_FUNCTION`, `TRR_MODAL_RUNTIME_SECRET_NAME`, `TRR_MODAL_SOCIAL_SECRET_NAME`

**Secrets location:**
- Local repo env files exist at `TRR-Backend/.env` and `screenalytics/.env`; examples exist alongside them.
- Vercel environment variables back `TRR-APP` per `TRR-APP/apps/web/DEPLOY.md`.
- GitHub Actions secrets are referenced in `.github/workflows/` across all repos.
- Modal uses named secrets prepared by scripts under `TRR-Backend/scripts/modal/`.

## Webhooks & Callbacks

**Incoming:**
- Third-party webhook receivers were not detected in active runtime code.
- Internal authenticated routes exist for service-to-service calls, for example `screenalytics/apps/api/routers/cast_screentime.py` and `screenalytics/apps/api/routers/computer_use.py`, but they are not public webhook integrations.

**Outgoing:**
- `TRR-APP` sends server-side requests to `TRR-Backend` through `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.
- `TRR-Backend` calls TMDb, Google News, object storage, Modal, and social-source endpoints via modules under `TRR-Backend/trr_backend/integrations/`, `TRR-Backend/trr_backend/scraping/`, `TRR-Backend/trr_backend/media/`, and `TRR-Backend/trr_backend/socials/`.
- `screenalytics` calls shared Postgres, S3-compatible storage, Redis/Celery infrastructure, and AI providers through `screenalytics/apps/api/services/` and `screenalytics/packages/py-screenalytics/src/`.

---

*Integration audit: 2026-04-07*
