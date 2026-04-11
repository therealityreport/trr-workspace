# External Integrations

**Analysis Date:** 2026-04-09

## APIs & External Services

**Database / platform services:**
- Supabase Postgres and Supabase platform services back the shared TRR data model.
  - Backend runtime lane: `TRR-Backend/api/main.py`, `TRR-Backend/api/deps.py`, `TRR-Backend/supabase/config.toml`
  - Screenalytics runtime lane: `screenalytics/apps/api/services/supabase_db.py`
  - App admin lane: `TRR-APP/apps/web/src/lib/server/supabase-trr-admin.ts`, `TRR-APP/apps/web/src/lib/server/postgres.ts`
  - Auth / config references: `TRR-Backend/README.md`, `TRR-APP/apps/web/README.md`

**Identity / auth:**
- Firebase client auth and admin verification power the primary app auth flow.
  - Client SDK: `TRR-APP/apps/web/src/lib/firebase.ts`
  - Admin SDK: `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`
  - Server auth bridge: `TRR-APP/apps/web/src/lib/server/auth.ts`
  - Emulator support: `TRR-APP/package.json`, `TRR-APP/firebase.json`, `TRR-APP/apps/web/README.md`
- Supabase JWT verification powers backend bearer-token validation.
  - Backend verification: `TRR-Backend/api/auth.py`, `TRR-Backend/api/main.py`

**Remote compute / background execution:**
- Modal is the default remote executor for TRR long jobs.
  - Workspace toggles: `docs/workspace/env-contract.md`, `scripts/dev-workspace.sh`
  - Backend worker entrypoints: `TRR-Backend/scripts/workers/admin_operations_worker.py`, `TRR-Backend/scripts/workers/google_news_worker.py`, `TRR-Backend/scripts/workers/reddit_refresh_worker.py`
  - Screenalytics client hooks inside backend: `TRR-Backend/trr_backend/clients/screenalytics.py`
- Celery + Redis remain active inside `screenalytics` for queue-backed processing.
  - Broker config: `screenalytics/apps/api/config/__init__.py`
  - Celery app: `screenalytics/apps/api/celery_app.py`
  - Tasks: `screenalytics/apps/api/tasks.py`, `screenalytics/apps/api/tasks_v2.py`

**Object storage and media delivery:**
- Backend object storage supports S3-compatible providers, including Cloudflare R2-style endpoints.
  - Config loader: `TRR-Backend/trr_backend/object_storage.py`
  - Media mirroring enforcement: `TRR-Backend/trr_backend/media/s3_mirror.py`
- Screenalytics supports `local`, `s3`, `minio`, and `hybrid` storage backends.
  - Validation: `screenalytics/apps/api/services/validation.py`
  - Storage implementation: `screenalytics/apps/api/services/storage.py`
  - Readiness checks: `screenalytics/apps/api/services/runtime_readiness.py`
- App-side media consumers allow Cloudflare R2/public CDN hosts in `TRR-APP/apps/web/next.config.ts` and design-doc scripts in `TRR-APP/apps/web/scripts/design-docs/generate-nyt-games-media-artifacts.mjs`.

**External content and data APIs:**
- TMDb, TVDB, IMDb, Fandom, and Famous Birthdays are upstream metadata sources for `TRR-Backend`.
  - Source summary: `TRR-Backend/README.md`
  - Sync entrypoints: `TRR-Backend/scripts/sync/*.py`
- Google Gemini / `google-genai` is used in both `TRR-Backend` and `screenalytics`.
  - Backend dependency: `TRR-Backend/requirements.lock.txt`
  - Screenalytics config and ML deps: `screenalytics/apps/api/config/__init__.py`, `screenalytics/requirements-ml.in`
- OpenAI and Anthropic are optional diagnostics / AI-tooling providers in `screenalytics`.
  - Diagnostic client wiring: `screenalytics/apps/api/services/openai_diagnostics.py`
- Anthropic is also used by backend computer-use tooling.
  - Client config: `TRR-Backend/trr_backend/clients/computer_use.py`
- Apify is wired in the backend dependency set for external scraper orchestration.
  - Dependency source: `TRR-Backend/requirements.lock.txt`

**Social / publisher integrations:**
- TRR social ingestion owns platform-specific lanes for Instagram, TikTok, Twitter/X, YouTube, Reddit, Google News, and SocialBlade.
  - Worker and scripts: `TRR-Backend/scripts/socials/worker.py`, `TRR-Backend/scripts/socials/instagram/`, `TRR-Backend/scripts/socials/tiktok/`, `TRR-Backend/scripts/socials/twitter/`, `TRR-Backend/scripts/socials/youtube/`
  - Admin routes in app: `TRR-APP/apps/web/src/app/api/admin/trr-api/social/`, `TRR-APP/apps/web/src/app/api/admin/reddit/`
  - Remote worker loops: `TRR-Backend/scripts/workers/reddit_refresh_worker.py`, `TRR-Backend/scripts/workers/google_news_worker.py`
- Getty scraping is handled by a local residential-IP helper server with an optional Cloudflare Tunnel.
  - Local server: `TRR-Backend/scripts/getty_local_server.py`
  - Tunnel config: `TRR-Backend/scripts/cloudflared-tunnel-config.yml`
  - Workspace commands: `Makefile`

## Data Storage

**Databases:**
- Shared primary database is Postgres via Supabase session pooler URLs.
  - Connection envs: `TRR_DB_URL`, `TRR_DB_FALLBACK_URL`
  - Backend enforcement: `TRR-Backend/api/main.py`, `TRR-Backend/api/deps.py`
  - Screenalytics enforcement: `screenalytics/apps/api/services/supabase_db.py`
  - App enforcement: `TRR-APP/apps/web/src/lib/server/postgres.ts`
- Screenalytics also writes operational tables into shared Postgres schemas such as `screenalytics.*`.
  - Example worker-side queries: `screenalytics/apps/api/services/cast_screentime.py`, `screenalytics/apps/api/services/runs_v2.py`

**File / object storage:**
- `TRR-Backend` uses S3-compatible object storage with a required public base URL for hosted media.
  - Config: `TRR-Backend/trr_backend/object_storage.py`
  - Media workers: `TRR-Backend/trr_backend/media/`
- `screenalytics` stores artifacts in local disk or S3/MinIO-compatible buckets.
  - Storage root and artifact logic: `screenalytics/apps/api/services/storage.py`, `screenalytics/apps/shared/storage.py`
- Local Docker-based MinIO fallback exists for Screenalytics dev only.
  - Existence only: `screenalytics/infra/docker/compose.yaml`

**Caching / queues:**
- Redis is optional in `TRR-Backend`; when absent, realtime falls back to in-memory broker mode.
  - Broker abstraction: `TRR-Backend/api/realtime/broker.py`
  - Multi-worker safety gate: `TRR-Backend/start-api.sh`
- Redis is core to `screenalytics` Celery queues and job locking.
  - Config: `screenalytics/apps/api/config/__init__.py`
  - Readiness checks: `screenalytics/apps/api/services/runtime_readiness.py`
  - Job locking: `screenalytics/apps/api/tasks.py`

## Authentication & Identity

**Auth providers:**
- Firebase is the end-user identity provider for `TRR-APP`.
  - Client config envs: `TRR-APP/apps/web/src/lib/firebase-client-config.ts`
  - Client runtime: `TRR-APP/apps/web/src/lib/firebase.ts`
  - Server verification: `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`, `TRR-APP/apps/web/src/lib/server/auth.ts`
- Supabase JWTs are accepted by the backend for API auth.
  - Verification path: `TRR-Backend/api/auth.py`

**Service-to-service auth:**
- `TRR_INTERNAL_ADMIN_SHARED_SECRET` is the canonical cross-repo secret for internal admin JWT minting and verification.
  - Workspace policy: `AGENTS.md`
  - App-side minting: `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`
  - Backend verification: `TRR-Backend/api/auth.py`
  - Screenalytics verification and minting fallback: `screenalytics/apps/api/services/internal_admin_auth.py`
- `SCREENALYTICS_SERVICE_TOKEN` remains as transitional fallback for Screenalytics service auth.
  - Workspace policy: `AGENTS.md`
  - Backend verification: `TRR-Backend/api/screenalytics_auth.py`
  - Screenalytics fallback logic: `screenalytics/apps/api/services/internal_admin_auth.py`

**Allowlists and admin boundaries:**
- Backend admin access depends on `ADMIN_EMAIL_ALLOWLIST` plus internal admin/service-role lanes in `TRR-Backend/api/auth.py`.
- App host and admin-route isolation is configured via `ADMIN_APP_ORIGIN`, `ADMIN_APP_HOSTS`, and related envs in `TRR-APP/apps/web/README.md` and `docs/workspace/env-contract.md`.

## Monitoring & Observability

**Metrics / health:**
- `TRR-Backend` exposes structured observability and metrics via `TRR-Backend/api/main.py`.
- `screenalytics` exposes health, ready, and metrics surfaces via `screenalytics/apps/api/main.py` and `screenalytics/apps/api/services/runtime_readiness.py`.
- Workspace process, port, and health probes are orchestrated by `scripts/dev-workspace.sh`, `scripts/status-workspace.sh`, and `Makefile`.

**Logging:**
- Python services use application logging configured in their entrypoints such as `TRR-Backend/api/main.py`, `screenalytics/apps/api/main.py`, and worker launchers in both repos.
- No external error-tracking SaaS is confirmed from inspected files.

## CI/CD & Deployment

**Hosting:**
- `TRR-APP/apps/web/` deploys to Vercel.
  - Config: `TRR-APP/apps/web/vercel.json`
  - Repo guidance: `TRR-APP/AGENTS.md`, `TRR-APP/apps/web/README.md`
- `TRR-Backend` has a Render Docker service definition.
  - Config: `TRR-Backend/render.yaml`
- Screenalytics is primarily operated locally or on self-managed infra; no single hosted deployment target is pinned in the inspected files.

**CI pipeline:**
- GitHub Actions is the detected CI system across all three repos.
  - Backend workflows: `TRR-Backend/.github/workflows/`
  - Screenalytics workflows: `screenalytics/.github/workflows/`
  - App workflows: `TRR-APP/.github/workflows/`

**Scheduled jobs:**
- Vercel Cron invokes app routes in `TRR-APP/apps/web/vercel.json`.
  - `/api/cron/episode-progression`
  - `/api/cron/create-survey-runs`
- Modal-backed worker loops are the default long-job scheduler path in workspace dev.

## Environment Configuration

**Required env vars by surface:**
- Shared workspace contracts:
  - `TRR_INTERNAL_ADMIN_SHARED_SECRET`
  - `SCREENALYTICS_SERVICE_TOKEN`
  - `TRR_API_URL`
  - Reference docs: `AGENTS.md`, `docs/workspace/env-contract.md`
- Backend core:
  - `TRR_DB_URL`
  - `TRR_DB_FALLBACK_URL`
  - `SUPABASE_JWT_SECRET`
  - `SUPABASE_PROJECT_REF` or `SUPABASE_JWT_ISSUER` when issuer inference needs help
  - `SCREENALYTICS_API_URL`
  - `OBJECT_STORAGE_BUCKET`, `OBJECT_STORAGE_REGION`, `OBJECT_STORAGE_PUBLIC_BASE_URL`
  - Optional provider creds: `OBJECT_STORAGE_ACCESS_KEY_ID`, `OBJECT_STORAGE_SECRET_ACCESS_KEY`, `OBJECT_STORAGE_PROFILE`
  - Source refs: `TRR-Backend/api/main.py`, `TRR-Backend/trr_backend/object_storage.py`, `TRR-Backend/README.md`
- App core:
  - `NEXT_PUBLIC_FIREBASE_*`
  - `FIREBASE_SERVICE_ACCOUNT`
  - `TRR_CORE_SUPABASE_URL`
  - `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`
  - `TRR_DB_URL` or `TRR_DB_FALLBACK_URL`
  - Source refs: `TRR-APP/apps/web/src/lib/firebase-client-config.ts`, `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`, `TRR-APP/apps/web/src/lib/server/supabase-trr-admin.ts`, `TRR-APP/apps/web/src/lib/server/postgres.ts`
- Screenalytics core:
  - `TRR_DB_URL`
  - `TRR_DB_FALLBACK_URL`
  - `REDIS_URL`
  - `CELERY_BROKER_URL`
  - `STORAGE_BACKEND`
  - `OBJECT_STORAGE_BUCKET`, `OBJECT_STORAGE_ENDPOINT_URL`, `OBJECT_STORAGE_ACCESS_KEY_ID`, `OBJECT_STORAGE_SECRET_ACCESS_KEY`
  - `TRR_API_URL`
  - Optional AI keys: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`
  - Source refs: `screenalytics/apps/api/config/__init__.py`, `screenalytics/apps/api/services/supabase_db.py`, `screenalytics/apps/api/services/storage.py`, `screenalytics/apps/api/services/openai_diagnostics.py`

**Secrets location:**
- Secret values belong in repo-local `.env` files, developer secret stores, Vercel envs, Firebase service-account envs, Modal secret names, or Supabase-managed secrets.
- Secret contracts are documented, but raw values are intentionally excluded from this document.
- Examples and names are referenced in `TRR-Backend/.env.example`, `TRR-APP/apps/web/README.md`, `docs/workspace/env-contract.md`, and `AGENTS.md`.

## Webhooks & Callbacks

**Incoming:**
- Vercel Cron hits app-owned API routes configured in `TRR-APP/apps/web/vercel.json`.
- Screenalytics FastAPI routes expose queue and processing endpoints under `screenalytics/apps/api/main.py` and `screenalytics/apps/api/routers/`.

**Outgoing:**
- App server-side admin routes proxy requests into `TRR-Backend` using `TRR_API_URL` and internal admin JWTs via `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts` and `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`.
- Screenalytics cast-screentime service calls back into backend APIs using `TRR_API_URL` and internal admin bearer tokens in `screenalytics/apps/api/services/cast_screentime.py`.
- Screenalytics Celery v2 task set includes a webhook-oriented task name in `screenalytics/apps/api/tasks_v2.py`; destination details are runtime-configured, not hardcoded in the inspected files.

## MCP / Developer Tooling Integrations

**Workspace MCPs:**
- `chrome-devtools` for authenticated browser work
- `figma`
- `github`
- `context7`
- `supabase`
- Source of truth: `docs/agent-governance/mcp_inventory.md`, `AGENTS.md`

**Workspace browser wrappers and managed tooling:**
- `scripts/codex-chrome-devtools-mcp.sh`
- `scripts/ensure-managed-chrome.sh`
- `scripts/open-or-refresh-browser-tab.sh`
- `scripts/chrome-devtools-mcp-status.sh`
- Policy docs: `docs/workspace/chrome-devtools.md`

## Not Detected

- Stripe, Resend, Sentry, Datadog, PostHog, Segment, or a dedicated SaaS observability platform were not confirmed from the inspected files.
- Third-party webhook receivers beyond Vercel Cron and internal service callbacks were not concretely pinned in the inspected configuration.

---

*Integration audit: 2026-04-09*
