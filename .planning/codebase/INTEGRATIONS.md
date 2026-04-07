# TRR Workspace Integrations Map

Updated from workspace scan on 2026-04-07.

## Cross-Repo Contracts

### TRR-APP -> TRR-Backend

- Canonical base URL env: `TRR_API_URL`
- Normalization layer: `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`
- Internal admin bridge: `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`
- App-side server proxies and repositories live under `TRR-APP/apps/web/src/lib/server/trr-api/`

### TRR-Backend <-> screenalytics

- Shared DB contract: `TRR_DB_URL` first, `TRR_DB_FALLBACK_URL` second
- screenalytics DB resolver: `screenalytics/apps/api/services/supabase_db.py`
- screenalytics ingest adapter: `screenalytics/apps/api/services/trr_ingest.py`
- backend-facing worker/service token contract:
  - `SCREENALYTICS_SERVICE_TOKEN`
  - code path: `screenalytics/apps/api/services/cast_screentime.py`
- backend legacy outbound Screenalytics URL contract:
  - `SCREENALYTICS_API_URL`
  - startup validation in `TRR-Backend/api/main.py`

## Authentication and Identity Providers

### Firebase

- Client auth and session flows in:
  - `TRR-APP/apps/web/src/lib/firebase.ts`
  - `TRR-APP/apps/web/src/lib/firebase-db.ts`
  - `TRR-APP/apps/web/src/lib/server/auth.ts`
- Firebase Admin integration in `TRR-APP/apps/web/src/lib/firebaseAdmin.ts`
- Firestore rules CI/deploy workflow in `TRR-APP/.github/workflows/firebase-rules.yml`

### Supabase

- Backend JWT verification in `TRR-Backend/trr_backend/security/jwt.py`
- App-side admin access via:
  - `TRR-APP/apps/web/src/lib/server/supabase-trr-admin.ts`
  - `TRR-APP/apps/web/src/lib/server/auth.ts`
- screenalytics shared Postgres/Supabase runtime adapter in `screenalytics/apps/api/services/supabase_db.py`
- Migrations and schema docs in `TRR-Backend/supabase/`

### Internal Admin Shared Secret

- Shared secret contract from workspace policy: `TRR_INTERNAL_ADMIN_SHARED_SECRET`
- Token creation in `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts`
- Token verification in `TRR-Backend/trr_backend/security/internal_admin.py`

## Data Stores and Queues

### Postgres / Supabase

- TRR canonical schema changes live in `TRR-Backend/supabase/migrations/`
- Backend DB code in `TRR-Backend/trr_backend/db/`
- screenalytics runtime DB access in `screenalytics/apps/api/services/supabase_db.py`
- App direct DB reads exist for selected admin/survey surfaces in `TRR-APP/apps/web/src/lib/server/postgres.ts`

### Redis

- Backend realtime broker references Redis in `TRR-Backend/api/realtime/broker.py`
- screenalytics readiness and cache checks in `screenalytics/apps/api/main.py`
- screenalytics runtime key management in `screenalytics/apps/api/services/redis_keys.py`
- Celery broker integration is optional but expected around `screenalytics/apps/api/celery_app.py`

### Object Storage

- Backend media/object storage paths:
  - `TRR-Backend/trr_backend/object_storage.py`
  - `TRR-Backend/trr_backend/media/s3_mirror.py`
  - `TRR-Backend/trr_backend/media/user_uploads.py`
- screenalytics storage paths:
  - `screenalytics/apps/api/services/storage.py`
  - `screenalytics/apps/api/services/storage_v2.py`
  - `screenalytics/apps/api/services/validation.py`
- frontend operational scripts for hosted fonts:
  - `TRR-APP/scripts/upload-fonts-to-s3.py`
  - `TRR-APP/scripts/collect-and-upload-monotype-fonts.sh`

## External Content and Metadata Providers

### Entertainment / Metadata Sources

- TMDB integrations:
  - `TRR-Backend/trr_backend/integrations/tmdb_person.py`
  - `TRR-Backend/trr_backend/ingestion/tmdb_person_images.py`
  - `TRR-Backend/trr_backend/ingestion/tmdb_show_backfill.py`
- IMDb ingestion and metadata:
  - `TRR-Backend/trr_backend/ingestion/imdb_images.py`
  - `TRR-Backend/trr_backend/ingestion/imdb_show_mediaindex.py`
- Bravo / NBCUniversal:
  - `TRR-Backend/trr_backend/integrations/bravo_jsonapi.py`
  - `TRR-Backend/trr_backend/integrations/nbcumv.py`
  - `TRR-Backend/trr_backend/bravotv/`
- Fandom:
  - `TRR-Backend/trr_backend/integrations/fandom.py`
  - `TRR-Backend/trr_backend/integrations/fandom_discovery.py`
  - `TRR-Backend/trr_backend/ingestion/fandom_person_scraper.py`
  - `TRR-Backend/trr_backend/ingestion/fandom_season_scraper.py`

### Media and Logo Sources

- Getty integration files:
  - `TRR-Backend/trr_backend/integrations/getty.py`
  - `TRR-Backend/trr_backend/integrations/getty_local_prefetch.py`
  - `TRR-Backend/trr_backend/media/getty_replacement.py`
- Brand/logo discovery:
  - `TRR-Backend/trr_backend/integrations/brandfetch.py`
  - `TRR-Backend/trr_backend/integrations/free_logo_sources.py`
  - `TRR-Backend/trr_backend/integrations/logopedia.py`
  - `TRR-Backend/trr_backend/integrations/picdetective.py`

### News, Social, and Community Sources

- Google News parsing in `TRR-Backend/trr_backend/scraping/google_news_parser.py`
- Reddit data and reads in:
  - `TRR-Backend/api/routers/admin_reddit_reads.py`
  - `TRR-Backend/trr_backend/repositories/admin_reddit_reads.py`
  - `TRR-APP/apps/web/src/lib/server/admin/reddit-*`
- Social growth and analytics in:
  - `TRR-Backend/api/routers/admin_socialblade.py`
  - `TRR-Backend/trr_backend/repositories/socialblade_growth.py`
  - `TRR-Backend/trr_backend/repositories/social_posts.py`
  - `TRR-Backend/trr_backend/repositories/social_sync_orchestrator.py`

## ML and AI Service Touchpoints

- screenalytics OpenAI diagnostics path: `screenalytics/apps/api/services/openai_diagnostics.py`
- backend OpenAI cleanup helper: `TRR-Backend/trr_backend/integrations/openai_fandom_cleanup.py`
- Gemini model references appear in screenalytics tests and env validation lanes
- Computer-use client exists in `TRR-Backend/trr_backend/clients/computer_use.py`

## Webhooks and Async Delivery

- screenalytics webhook/suggestions code:
  - `screenalytics/apps/api/services/suggestions_webhook.py`
  - `screenalytics/web/openapi.json` includes a PyannoteAI webhook surface
- frontend scheduled jobs are configured as Vercel crons in `TRR-APP/apps/web/vercel.json`

## Infrastructure and Dev Tooling Integrations

- Supabase CLI/config: `TRR-Backend/supabase/config.toml`
- Vercel deployment helper scripts from root app package:
  - `TRR-APP/scripts/vercel.sh`
  - scripts exposed by `TRR-APP/package.json`
- Managed browser/devtools workspace scripts live under root `scripts/` per workspace `AGENTS.md`

## Key Environment Contracts

- `TRR_API_URL`
- `SCREENALYTICS_API_URL`
- `TRR_DB_URL`
- `TRR_DB_FALLBACK_URL`
- `TRR_INTERNAL_ADMIN_SHARED_SECRET`
- `SCREENALYTICS_SERVICE_TOKEN`
- `SUPABASE_JWT_SECRET`
- `TRR_CORE_SUPABASE_URL`
- `TRR_CORE_SUPABASE_SERVICE_ROLE_KEY`

## Integration Risk Notes

- The same business domain spans three repos, but schema ownership is centralized in `TRR-Backend/supabase/migrations/`
- screenalytics mixes direct DB access and backend HTTP callbacks; both must stay aligned
- TRR-APP uses both Firebase and Supabase-backed admin/server flows, so auth-cutover work must preserve both paths until explicitly retired
