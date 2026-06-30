# TRR-Backend Map

Generated: 2026-06-23

Root: `/Users/thomashulihan/Projects/TRR/TRR-Backend`

## Practical Shape

`TRR-Backend` is the Supabase-first backend repo. It owns backend API behavior, shared backend libraries, schema and migrations, sync/ops scripts, Modal runtime surfaces, and social scraping/control-plane code.

Primary surfaces:

- `api/` - FastAPI app, routers, auth, realtime, and middleware.
- `trr_backend/` - shared backend library code.
- `scripts/` - sync, ops, Modal, social, import, and verification tools.
- `supabase/` - schema config, migrations, and generated schema docs.
- `tests/` - backend test coverage across API, DB, services, scripts, socials, media, and integrations.

## API Ownership

`api/main.py` is the FastAPI composition root. It:

- loads `.env`;
- configures observability;
- installs request timeout and CORS middleware;
- initializes realtime broker lifecycle hooks;
- wires admin/public routers;
- owns health and runtime diagnostics;
- enforces startup checks for sensitive runtime configuration.

Key router families:

- Public browsing and user routes: shows, surveys, discussions, DMs, WebSockets.
- Admin routes: shows, people, cast, media, brands, networks/streaming, operations, scrape/import, show sync, SocialBlade, Reddit, NBCUMV, Bravo TV images, screentime, and health.
- Social routes: profile reads, analytics, catalog/backfill, queue status, worker health, platform-specific scrape/control flows.

High-risk API surface:

- `api/routers/socials/__init__.py` is very large and mixes social ingest, analytics, worker health, cookie/auth health, queue status, and fallback behavior.
- `api/main.py` mixes router composition, startup validation, and Modal runtime scheduler ownership.

## Shared Library Ownership

Important `trr_backend/` modules:

- `trr_backend/db/connection.py` resolves database URL candidates and lane precedence.
- `trr_backend/db/pg.py` owns direct SQL pool mechanics, named pool sizing, timeout classification, and database-service-unavailable responses.
- `trr_backend/db/session.py` provides the Supabase-like session wrapper.
- `trr_backend/repositories/` owns table-level read/write operations and admin read models.
- `trr_backend/pipeline/` owns resumable pipeline orchestration.
- `trr_backend/ingestion/` owns metadata and source ingestion.
- `trr_backend/integrations/` owns external clients such as TMDb, IMDb, Fandom, NBCUMV, Getty, Brandfetch, and related sources.
- `trr_backend/media/` owns media normalization, Bravo TV image runs, image variants, object storage, and user-upload/media helpers.
- `trr_backend/socials/` owns social platform scraping, account catalog, analytics read models, control-plane queueing, auth/cookie runtime, and platform-specific adapters.
- `trr_backend/modal_dispatch.py` owns Modal dispatch config and function-name resolution.
- `trr_backend/modal_jobs.py` owns Modal app/function definitions and container image composition.
- `trr_backend/job_plane.py` owns local-vs-remote execution semantics.

## Database And Schema Ownership

Schema ownership lives in `supabase/`:

- `supabase/migrations/` is the schema change log.
- `supabase/config.toml` controls local Supabase schema exposure and pooler behavior.
- `supabase/schema_docs/` is generated schema documentation and should move with migrations when schema ownership changes.

DB lane contract:

- `TRR_DB_DIRECT_URL` is the local direct lane.
- `TRR_DB_SESSION_URL` is the preferred session/pooler lane.
- `TRR_DB_URL` remains a compatibility session/local source.
- `TRR_DB_TRANSACTION_URL` is only selected by explicit transaction flight-test controls.
- `TRR_DB_FALLBACK_URL` is a fallback lane.

Direct SQL pool ownership is in `trr_backend/db/pg.py`, including default, health, social profile, social control, and social progress named pools.

## Modal And Jobs

Remote execution ownership is split across:

- `trr_backend/job_plane.py` - canonical execution backend and owner labels.
- `trr_backend/modal_dispatch.py` - Modal app/function lookup, dispatch config, readiness classification, and spawn helpers.
- `trr_backend/modal_jobs.py` - Modal app definition, function defaults, images, secrets, schedules, and per-function concurrency/timeouts.
- `scripts/modal/prepare_named_secrets.py` - secret rendering/apply path.
- `scripts/modal/verify_modal_readiness.py` - operator readiness check for app, secrets, functions, web endpoints, and auth probes.

Important defaults:

- Modal app: `trr-backend-jobs`.
- Runtime secret: `trr-backend-runtime`.
- Social auth secret: `trr-social-auth`.
- Common functions include admin operation, Google News sync, Reddit refresh, social jobs by stage, SocialBlade scrape, vision, cast screentime, heartbeat, stale-worker cleanup, and social recovery.

Modal-related backend, worker, scraper, job, runtime, or secret-prep implementation changes require Modal follow-through unless the user asks for local-only work.

## Social Runtime

Social implementation spans:

- `api/routers/socials/` for API exposure.
- `trr_backend/socials/control_plane/` for dispatch, run lifecycle, queue status, recovery, worker health, and shared status.
- `trr_backend/socials/account_catalog/` for account discovery/catalog progress.
- `trr_backend/socials/analytics/` and read models for social profile/season analytics.
- `trr_backend/socials/instagram/`, `tiktok/`, `threads/`, `twitter/`, `facebook/`, `youtube/`, `reddit/`, and `socialblade/` platform code.
- `scripts/socials/` for operator scripts, smoke tests, backfills, repair tools, queue snapshots, and local workers.

Important social runtime notes:

- Decodo is a residential proxy provider, not the scraper implementation.
- Instagram public-first mode, Scrapling/Patchright browser setup, cookie refresh, media mirror, comments, and backfill recovery are separate lanes.
- Social media queue recovery has dedicated Makefile targets at the root.

## Validation

Backend-local checks:

- `make doctor` runs environment diagnostics.
- `pytest` runs the backend test suite.
- `make schema-docs-check` regenerates schema docs and fails on drift.
- `make ci-local` performs local Supabase replay plus schema-doc checks.
- `python -m trr_backend.cli pipeline run --all --verbose` runs the pipeline orchestrator.
- `scripts/modal/verify_modal_readiness.py --json` is the Modal readiness truth surface.

Root-level checks that include backend:

- `make preflight`
- `make test-fast`
- `make test`
- `make test-changed`

## Confusing Ownership Points

- `api/main.py` owns too many runtime concerns: route composition, startup validation, and Modal maintenance scheduling.
- `api/routers/socials/__init__.py` is broad enough that queueing, analytics, fallback execution, and health can blur together.
- DB access has two important surfaces: `trr_backend/db/session.py` and `trr_backend/db/pg.py`. Be explicit about whether a change is Supabase-wrapper behavior or direct SQL pool behavior.
- `job_plane.py` and `modal_dispatch.py` both encode remote/local execution semantics, so env changes can drift if only one is updated.
- Schema changes need both migration SQL and generated schema-doc alignment.

## Evidence Files Read

- `TRR-Backend/AGENTS.md`
- `TRR-Backend/README.md`
- `TRR-Backend/Makefile`
- `TRR-Backend/api/main.py`
- `TRR-Backend/api/routers/*`
- `TRR-Backend/trr_backend/db/pg.py`
- `TRR-Backend/trr_backend/modal_dispatch.py`
- `TRR-Backend/trr_backend/modal_jobs.py`
- `TRR-Backend/trr_backend/socials/**`
- `TRR-Backend/scripts/socials/**`
- `TRR-Backend/scripts/modal/**`
- `TRR-Backend/supabase/**`
- live filesystem and Git status output
