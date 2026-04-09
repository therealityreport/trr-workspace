# Workspace health-dot summary-only hardening

Date: 2026-04-08

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-04-08
  current_phase: "health-dot summary-only hardening landed and the original oversized-pool regression is closed"
  next_action: "monitor for renewed watchdog or pool-contention warnings and only reopen this lane if those symptoms recur under active admin traffic"
  detail: self
```

## Root cause
- The default workspace profile forced `TRR_DB_POOL_MINCONN=2` and `TRR_DB_POOL_MAXCONN=8` even though the backend already treats Supavisor session mode as safe only at `1/2`.
- The backend `/api/v1/admin/socials/ingest/health-dot` route called `get_queue_status(...)`, which still ran reconciliation, blocked-job recovery, running-job reads, dispatch-health reads, and other queue-detail work even when the caller only needed the header-dot summary.
- Under active admin traffic, the watchdog `/health` probe and the social admin polling paths competed for the same constrained backend DB pool, producing intermittent probe warnings and prior watchdog restart history.

## Changes
- `profiles/default.env`
  - Restored the default workspace session-pool sizing to `TRR_DB_POOL_MINCONN=1` and `TRR_DB_POOL_MAXCONN=2`.
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
  - Added `summary_only=True` support to `get_queue_status(...)`.
  - Summary-only mode now skips queue reconciliation, blocked-job recovery, running-job enumeration, stuck-job/detail reads, dispatch-blocked reads, dispatch-health reads, and runs-summary reads.
- `TRR-Backend/api/routers/socials.py`
  - Switched `/ingest/health-dot` to call `get_queue_status(..., summary_only=True)`.

## Validation
- `bash scripts/check-workspace-contract.sh`
- `cd TRR-Backend && ruff check --ignore E501 api/routers/socials.py trr_backend/repositories/social_season_analytics.py tests/api/routers/test_socials_season_analytics.py tests/repositories/test_social_season_analytics.py`
- `cd TRR-Backend && pytest -q tests/repositories/test_social_season_analytics.py::test_get_queue_status_uses_cache_ttl_and_skips_recent_failures_when_disabled tests/repositories/test_social_season_analytics.py::test_get_queue_status_fresh_true_bypasses_cache tests/repositories/test_social_season_analytics.py::test_get_queue_status_summary_only_skips_expensive_side_effects`
- `cd TRR-Backend && pytest -q tests/api/routers/test_socials_season_analytics.py -k health_dot_endpoint`
- Fresh `make dev` run after the profile change showed backend startup at `minconn=1 maxconn=2` with no new oversized-session-pool warning.

## Remaining watch items
- The app still logs some slow admin routes and the backend can still show transient pool contention under heavy local admin browsing because the dev lane is intentionally conservative at `1/2`.
- If watchdog warnings recur after this hardening, the next step should be to inspect the app-side polling mix on the active admin pages and trim duplicate live-status fetches rather than raising the backend pool again.
