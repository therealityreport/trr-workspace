# External Integrations

**Analysis Date:** 2026-04-07

## APIs & Service Boundaries

**Cross-repo service calls:**
- `TRR-APP` calls `TRR-Backend` through the normalized base in `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`
  - Client: native `fetch` from server helpers under `TRR-APP/apps/web/src/lib/server/trr-api/`
  - Auth: internal admin/shared-secret flows via `TRR_INTERNAL_ADMIN_SHARED_SECRET`
- `screenalytics` calls `TRR-Backend` from services such as `screenalytics/apps/api/services/trr_ingest.py` and `screenalytics/apps/api/services/cast_screentime.py`
  - Client: `httpx`
  - Auth: `SCREENALYTICS_SERVICE_TOKEN`
- `TRR-Backend` still carries legacy outbound HTTP to `screenalytics` through `TRR-Backend/trr_backend/clients/screenalytics.py`
  - Contract: `SCREENALYTICS_API_URL`
  - Status: optional / legacy per startup logs in `TRR-Backend/api/main.py`

## Platform Services

**Web hosting and scheduled execution:**
- Vercel hosts `TRR-APP/apps/web`, with cron routes defined in `TRR-APP/apps/web/vercel.json`
- Cron endpoints live under `TRR-APP/apps/web/src/app/api/cron/`
- `CRON_SECRET` protects cron-triggered routes

**Auth and identity:**
- Firebase client/admin auth is wired through `TRR-APP/apps/web/src/lib/firebase*` and `TRR-APP/apps/web/src/lib/server/auth.ts`
- Supabase JWT and admin helpers are used in backend security and app admin/server reads
- Internal service auth is enforced through shared-secret and JWT helpers in `TRR-Backend/trr_backend/security/` and `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`

**Remote execution and browser automation:**
- Modal is the preferred remote executor per `docs/workspace/env-contract.md`
- Managed Chrome / DevTools automation is standardized by `scripts/codex-chrome-devtools-mcp.sh` and `docs/workspace/chrome-devtools.md`

## External APIs & Providers

**Backend-integrated external providers:**
- Google APIs / Sheets through `gspread`, `google-auth`, and related credentials in `TRR-Backend/requirements.lock.txt`
- AI providers via `anthropic` and `google-genai`
- Content / media / metadata providers referenced across backend env contracts and integration modules:
  - TMDb
  - IMDb
  - TVDB
  - Firecrawl
  - NBCUniversal-related sources
  - Better Stack for observability

**screenalytics-specific providers:**
- PyannoteAI webhook-driven diarization flows in `screenalytics/apps/api/routers/audio.py`
- Suggestions callback flow in `screenalytics/apps/api/services/suggestions_webhook.py`

## Data Storage

**Primary database:**
- Shared Supabase Postgres is the system of record, with canonical schema history in `TRR-Backend/supabase/migrations/`
- Runtime precedence is:
  1. `TRR_DB_URL`
  2. `TRR_DB_FALLBACK_URL`
- This precedence is enforced across:
  - `TRR-Backend/api/main.py`
  - `TRR-Backend/trr_backend/db/connection.py`
  - `screenalytics/apps/api/services/supabase_db.py`
  - `TRR-APP/apps/web/src/lib/server/postgres.ts`

**Object and file storage:**
- Backend uses S3-compatible object storage abstractions in `TRR-Backend/trr_backend/object_storage.py`
- Screenalytics uses pluggable storage in `screenalytics/apps/api/services/storage_backend.py`
- Supabase local storage/S3 protocol is configured in `TRR-Backend/supabase/config.toml`

**Queue/cache-like infrastructure:**
- Redis- and Celery-shaped configuration exists in `screenalytics/apps/api/config/` and related queue/task modules
- Backend realtime and queue-ish behavior lives in `TRR-Backend/api/realtime/` and backend job orchestration layers

## Monitoring & Observability

- Backend runtime observability is wired in `TRR-Backend/trr_backend/observability.py` and installed from `TRR-Backend/api/main.py`
- Screenalytics request tracing and metrics are installed in `screenalytics/apps/api/main.py`
- Workspace runtime logs are coordinated under `.logs/workspace/`

## Environment Contracts

**Shared critical env vars:**
- `TRR_API_URL`
- `SCREENALYTICS_API_URL`
- `TRR_DB_URL`
- `TRR_DB_FALLBACK_URL`
- `TRR_INTERNAL_ADMIN_SHARED_SECRET`
- `SCREENALYTICS_SERVICE_TOKEN`
- `SUPABASE_JWT_SECRET`

**App-specific important env vars:**
- `NEXT_PUBLIC_FIREBASE_*`
- `FIREBASE_SERVICE_ACCOUNT`
- `TRR_CORE_SUPABASE_URL`
- `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`
- `CRON_SECRET`

**Workspace-generated contract source:**
- `docs/workspace/env-contract.md`

## Webhooks & Callbacks

**Incoming:**
- Vercel cron callbacks under `TRR-APP/apps/web/src/app/api/cron/`
- PyannoteAI callback routes in `screenalytics/apps/api/routers/audio.py`

**Outgoing:**
- `TRR-APP` server helpers call `TRR-Backend`
- `screenalytics` services call `TRR-Backend`
- `screenalytics` suggestion services call configured downstream webhook targets
- `TRR-Backend` dispatches work to Modal

---

*Integration audit refreshed: 2026-04-07*
