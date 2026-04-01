# Supabase read-path stabilization and Flashback RPCs

Last updated: 2026-03-30

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-30
  current_phase: "complete"
  next_action: "If the separate social-ingest contract mismatch needs attention, handle it as its own slice; do not fold it back into this Supabase performance work."
  detail: self
```

- `workspace`
  - Kept the current Supabase runtime lane on Supavisor session mode and preserved the canonical `TRR_DB_URL` / optional `TRR_DB_FALLBACK_URL` contract.
  - Hardened local startup so `make dev` fails fast when `TRR-APP` lacks canonical `TRR_DB_URL`, instead of surfacing a missing connection string later during unrelated reads.
  - Updated [`reload_postgrest_schema.sh`](/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/reload_postgrest_schema.sh) to use the canonical runtime DB envs instead of legacy `SUPABASE_DB_URL`.
- `TRR-APP`
  - Standardized lightweight admin read diagnostics across the heavy cached GET routes already on the route-response cache path:
    - brands profile
    - brands logos
    - brands shows/franchises
    - networks-streaming detail
    - survey detail bootstrap
    - recent people
  - Added shared `x-trr-cache` and `x-trr-upstream-ms` response headers, with optional `x-trr-total-ms` behind `TRR_ADMIN_READ_DIAGNOSTICS=1`.
  - Kept route payloads bounded; no new giant bootstrap route was introduced.
  - Replaced Flashback’s three read-then-write flows in [`supabase.ts`](/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/flashback/supabase.ts) with atomic RPC-backed helpers while preserving the frontend API shape.
- `TRR-Backend`
  - Added env-gated structured timing for:
    - public show cast
    - survey results
    - survey submit
    - admin networks-streaming reads
    - person slug resolution
  - Added additive migration [`20260330195500_add_flashback_atomic_rpc_helpers.sql`](/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/20260330195500_add_flashback_atomic_rpc_helpers.sql) for:
    - `public.flashback_get_or_create_session`
    - `public.flashback_save_placement`
    - `public.flashback_update_user_stats`
  - Applied the migration to the live Supabase project and reloaded the PostgREST schema cache successfully.
- `validation`
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec vitest run tests/postgres-connection-string-resolution.test.ts tests/brand-profile-route.test.ts tests/brands-franchise-proxy-routes.test.ts tests/brands-logos-route.test.ts tests/networks-streaming-detail-route.test.ts tests/recent-people-route.test.ts tests/survey-detail-route.test.ts tests/flashback-supabase.test.ts`
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web run lint`
    - passed with warnings only; no errors remained in this slice
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec next build --webpack`
  - `ruff check /Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/shows.py /Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/surveys.py /Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/admin_networks_streaming_reads.py /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/admin_people_reads.py /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/read_path_diagnostics.py`
  - `ruff format --check /Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/shows.py /Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/surveys.py /Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/admin_networks_streaming_reads.py /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/admin_people_reads.py /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/read_path_diagnostics.py`
  - `pytest -q /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/test_admin_people_reads_repository.py /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/test_admin_networks_streaming_reads_repository.py /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/api/routers/test_shows.py /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/api/test_survey_submit.py /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/test_api_smoke.py`
  - `./scripts/reload_postgrest_schema.sh`
- `notes`
  - The separate social-ingest contract mismatch remains out of scope:
    - [`test_socials_season_analytics.py`](/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/api/routers/test_socials_season_analytics.py) still expects `SOCIAL_WORKER_UNAVAILABLE`
    - live code still returns `SOCIAL_REMOTE_WORKER_REQUIRED`
  - `make schema-docs-check` is still noisy because the checked-in schema docs already drift from the live database in multiple unrelated areas outside this Flashback RPC change. That drift was not folded into this slice.
