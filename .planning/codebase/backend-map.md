# TRR Backend / Runtime Map

## Scope
- Workspace: `/Users/thomashulihan/Projects/TRR`
- Source basis: live repo files only, no saved notes or prior session logs.
- Goal: map the backend/runtime layer, its contract edges, and the highest-risk seams.

## Dependency Chain
- `TRR-APP` sets `TRR_API_URL` and calls the backend through `/api/v1` proxy routes.
- `api/main.py` wires FastAPI routers, health checks, auth, and observability.
- `trr_backend/db/*` resolves DB lanes and owns pool behavior.
- `trr_backend/modal_*` and `scripts/modal/*` own remote-job dispatch and deploy verification.
- Supabase migrations + schema docs define the storage contract the backend reads and writes.

## 1) API Entry Surface
- FastAPI bootstrap and router fan-in live in [TRR-Backend/api/main.py:443](/Users/thomashulihan/Projects/TRR/TRR-Backend/api/main.py:443).
- Registered public and admin router groups are attached under `/api/v1` in [TRR-Backend/api/main.py:515](/Users/thomashulihan/Projects/TRR/TRR-Backend/api/main.py:515).
- Core live endpoints are:
  - `/`, `/health`, `/health/live`, `/health/db-pressure`, `/admin/health/db-pressure`, `/health/runtime`, `/metrics`
  - see [TRR-Backend/api/main.py:596](/Users/thomashulihan/Projects/TRR/TRR-Backend/api/main.py:596).
- The backend error envelope for DB saturation/unavailability is centralized in [TRR-Backend/api/main.py:466](/Users/thomashulihan/Projects/TRR/TRR-Backend/api/main.py:466).
- Auth boundaries are in [TRR-Backend/api/auth.py](/Users/thomashulihan/Projects/TRR/TRR-Backend/api/auth.py):
  - Supabase JWT verification
  - internal-admin shared-secret flow
  - optional service-role allowlist escape hatches

## 2) Backend Routers
- Browse/read contract for shows, seasons, episodes, cast, and watch-provider data is in [TRR-Backend/api/routers/shows.py:1](/Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/shows.py:1).
- Admin operation lifecycle, cancel, and stream surfaces are in [TRR-Backend/api/routers/admin_operations.py:17](/Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/admin_operations.py:17).
- Social admin surfaces are consolidated under [TRR-Backend/api/routers/socials/__init__.py:148](/Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/socials/__init__.py:148):
  - Instagram, TikTok, Twitter/X, YouTube, Facebook, Threads
  - ingest, catalog, comments, analytics, worker health, live status, and resumable runs
- Other router clusters on the same include path are:
  - show/person/media/brand/admin read models
  - cast screentime, assets, images, socialblade, brute-force import/sync helpers
  - see the include list in [TRR-Backend/api/main.py:515](/Users/thomashulihan/Projects/TRR/TRR-Backend/api/main.py:515).

## 3) Workers, Scrapers, and Jobs
- Job ownership mode is normalized in [TRR-Backend/trr_backend/job_plane.py](/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/job_plane.py):
  - `local` vs `remote`
  - `modal` vs `legacy_worker`
  - canonical execution metadata for logs and diagnostics
- Modal dispatch policy and function-name mapping live in [TRR-Backend/trr_backend/modal_dispatch.py:60](/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/modal_dispatch.py:60).
- Modal image, app name, secret names, concurrency limits, browser deps, and runtime defaults live in [TRR-Backend/trr_backend/modal_jobs.py:104](/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/modal_jobs.py:104).
- Social worker implementation lives under [TRR-Backend/trr_backend/socials/instagram/](/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/instagram/):
  - scraper/runtime adapters
  - auth refresh, cookie handling, catalog ingest, post/comments jobs
  - browser/scrapling/crawlee/crawl4ai runtime shims
- Adjacent non-social workers and scrape surfaces live under:
  - [TRR-Backend/trr_backend/ingestion/](/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/ingestion/)
  - [TRR-Backend/trr_backend/bravotv/](/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/bravotv/)
  - [TRR-Backend/trr_backend/vision/](/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/vision/)
  - [TRR-Backend/trr_backend/media/](/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/media/)
  - [TRR-Backend/trr_backend/integrations/](/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/integrations/)

## 4) Supabase / Database Contract
- DB URL lane resolution is centralized in [TRR-Backend/trr_backend/db/connection.py:1](/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/db/connection.py:1):
  - `TRR_DB_DIRECT_URL`
  - `TRR_DB_SESSION_URL`
  - `TRR_DB_URL`
  - `TRR_DB_TRANSACTION_URL`
  - `TRR_DB_FALLBACK_URL`
- Pool sizing, named pools, `application_name`, and health summaries are managed in [TRR-Backend/trr_backend/db/pg.py:1](/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/db/pg.py:1).
- The backend health endpoints use those pool lanes directly:
  - readiness probe in [TRR-Backend/api/main.py:602](/Users/thomashulihan/Projects/TRR/TRR-Backend/api/main.py:602)
  - admin pressure view in [TRR-Backend/api/main.py:707](/Users/thomashulihan/Projects/TRR/TRR-Backend/api/main.py:707)
- Supabase local contract is declared in [TRR-Backend/supabase/config.toml](/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/config.toml):
  - exposed schemas: `public`, `graphql_public`, `core`, `admin`
  - local API/db/pooler ports
  - local seed wiring via `seed.sql`
- Schema truth is split between:
  - generated schema docs in [TRR-Backend/supabase/schema_docs/INDEX.md](/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/schema_docs/INDEX.md)
  - migrations in [TRR-Backend/supabase/migrations/](/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/)
  - seed data in [TRR-Backend/supabase/seed.sql](/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/seed.sql)
- High-signal tables and views to watch for backend breakage are:
  - `core.shows`, `core.seasons`, `core.episodes`
  - `core.people`, `core.credits`, `core.cast_photos`, `core.media_assets`
  - `core.sync_state`, `core.admin_operations`, `core.google_news_sync_jobs`
  - `core.show_images`, `core.episode_images`, `core.person_images`

## 5) Modal / Deploy Surfaces
- Modal app wiring and runtime defaults live in [TRR-Backend/trr_backend/modal_jobs.py:202](/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/modal_jobs.py:202).
- Modal readiness and cutover verification live in [TRR-Backend/scripts/modal/verify_modal_readiness.py:1](/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/modal/verify_modal_readiness.py:1):
  - verifies app and secret presence
  - resolves expected function names
  - can run remote auth and worker probes
- Modal runtime reconciliation helpers are adjacent in:
  - [TRR-Backend/scripts/modal/reconcile_modal_runtime.py](/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/modal/reconcile_modal_runtime.py)
  - [TRR-Backend/scripts/modal/prepare_named_secrets.py](/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/modal/prepare_named_secrets.py)
- Render deploy config still exists at [TRR-Backend/render.yaml](/Users/thomashulihan/Projects/TRR/TRR-Backend/render.yaml):
  - Docker web service `trr-backend-api`
  - `/health` health check path
- Workspace launch contract for remote vs local execution is in:
  - [Makefile](/Users/thomashulihan/Projects/TRR/Makefile)
  - [docs/workspace/env-contract.md:35](/Users/thomashulihan/Projects/TRR/docs/workspace/env-contract.md:35)

## 6) Runtime Config / Env Usage
- Backend setup values live in [TRR-Backend/.env.example:1](/Users/thomashulihan/Projects/TRR/TRR-Backend/.env.example:1).
- App-side backend bridge config lives in [TRR-APP/apps/web/.env.example:1](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/.env.example:1):
  - `TRR_API_URL`
  - DB routing vars
  - internal-admin secret
  - social proxy timeout knobs
- Runtime lane ownership is documented in [docs/workspace/env-contract.md:35](/Users/thomashulihan/Projects/TRR/docs/workspace/env-contract.md:35):
  - direct vs session vs transaction DB URLs
  - fallback URL policy
  - Modal enablement and remote worker toggles
  - backend pool sizing and application-name labels
- Key runtime consumers:
  - [TRR-Backend/api/main.py:246](/Users/thomashulihan/Projects/TRR/TRR-Backend/api/main.py:246) for startup validation, sweeps, and modal scheduler flags
  - [TRR-Backend/api/auth.py](/Users/thomashulihan/Projects/TRR/TRR-Backend/api/auth.py) for admin/internal auth envs
  - [TRR-Backend/trr_backend/db/pg.py](/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/db/pg.py) for pool sizing and DB lane pressure
  - [TRR-Backend/trr_backend/modal_jobs.py](/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/modal_jobs.py) and [TRR-Backend/trr_backend/modal_dispatch.py](/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/modal_dispatch.py) for Modal function names, secret names, and social caps
- Shared env ownership is tracked in [docs/workspace/shared-env-manifest.json](/Users/thomashulihan/Projects/TRR/docs/workspace/shared-env-manifest.json).

## 7) Tests and Validation
- API smoke and health coverage are concentrated in:
  - [TRR-Backend/tests/test_api_smoke.py:1](/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/test_api_smoke.py:1)
  - [TRR-Backend/tests/api/test_health.py:1](/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/api/test_health.py:1)
  - [TRR-Backend/tests/api/test_auth.py:1](/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/api/test_auth.py:1)
- Modal/runtime verification coverage is in:
  - [TRR-Backend/tests/test_modal_dispatch.py](/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/test_modal_dispatch.py)
  - [TRR-Backend/tests/test_modal_jobs.py:1](/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/test_modal_jobs.py:1)
  - [TRR-Backend/tests/scripts/test_verify_modal_readiness.py](/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/scripts/test_verify_modal_readiness.py)
  - [TRR-Backend/tests/scripts/test_reconcile_modal_runtime.py](/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/scripts/test_reconcile_modal_runtime.py)
- Router-specific contract tests live under:
  - [TRR-Backend/tests/api/routers/](/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/api/routers/)
  - [TRR-Backend/tests/repositories/](/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/)
  - [TRR-Backend/tests/services/](/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/services/)
  - [TRR-Backend/tests/ingestion/](/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/ingestion/)
- Validation entrypoints:
  - [TRR-Backend/Makefile:16](/Users/thomashulihan/Projects/TRR/TRR-Backend/Makefile:16) for `doctor`, `schema-docs-check`, and `ci-local`
  - [Makefile:32](/Users/thomashulihan/Projects/TRR/Makefile:32) for `dev`, `dev-cloud`, `dev-hybrid`, and workspace preflight
  - [TRR-Backend/pytest.ini](/Users/thomashulihan/Projects/TRR/TRR-Backend/pytest.ini) for the test path/test naming baseline

## 8) App-Facing Boundaries
- The app normalizes the backend base URL and appends `/api/v1` in [TRR-APP/apps/web/src/lib/server/trr-api/backend.ts:1](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/trr-api/backend.ts:1).
- Admin proxy calls build internal-admin headers and forward to backend-owned routes in [TRR-APP/apps/web/src/lib/server/trr-api/social-admin-proxy.ts:1](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/server/trr-api/social-admin-proxy.ts:1).
- App contract pressure points:
  - `TRR_API_URL` must already point at the backend root the app expects
  - route shape changes in backend routers ripple into `/api/admin/trr-api/**` proxy files in TRR-APP
  - social/admin read routes are the most coupling-heavy surfaces
- The most important app-visible backend surfaces are:
  - `/api/v1/shows`
  - `/api/v1/surveys`
  - `/api/v1/admin/*`
  - `/api/v1/admin/socials/*`

## 9) Risky Seams
- DB lane drift:
  - `direct` vs `session` vs `transaction` lane mismatch can make startup, health, and pool-pressure diagnostics disagree.
- Internal-admin auth drift:
  - `TRR_INTERNAL_ADMIN_SHARED_SECRET`, JWT issuer/audience, or allowlist changes can break app proxy routes without touching the public API.
- Modal function/secret drift:
  - `modal_jobs.py` and `verify_modal_readiness.py` must stay aligned on app name, secret names, and function names.
- App/backend URL normalization:
  - the app’s `/api/v1` suffixing logic is hidden but real; changing the backend prefix requires coordinated proxy updates.
- Schema doc drift:
  - `supabase/migrations` is the contract source; `supabase/schema_docs` is a generated snapshot that must stay in sync.
