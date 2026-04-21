# Instagram Full-History Backfill Regression

Last updated: 2026-04-20 (debug session)

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-04-20
  current_phase: "debug-session fixes landed"
  next_action: "re-run sync-handoffs check and keep future local-status notes on the canonical template"
  detail: self
```

## Scope
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- `TRR-Backend/trr_backend/socials/control_plane/runtime.py`
- `TRR-Backend/trr_backend/socials/control_plane/__init__.py`
- `TRR-Backend/tests/repositories/test_social_season_analytics.py`

## Problem (original — kickoff mode drift)
- Instagram `catalog_action=backfill` plus `catalog_action_scope=full_history` was being launched with `ingest_mode_override=details_refresh`.
- That mode refreshes existing saved posts instead of discovering earlier history, which can plateau around the first saved page and never prove oldest-post coverage.
- Live BravoTV runs on 2026-04-20 showed the bad shape directly: `1fd6db41-8111-43af-bf28-7d4ddcc3645c` started with `details_refresh`, then recovered into the wrong frontier behavior.

## Problem (debug session — universal "Failed to start" regression)
- Admin UI click on `Backfill Posts` produced the verbatim fallback string "Failed to start social account catalog backfill" for every account / every environment.
- UI fallback masks the real backend response; the actual root cause was not apparent until the admin-UI network path was traced.

## Changes
- Restored Instagram full-history backfill kickoff to the normal catalog frontier path.
- Preserved frontier auto-resume when a resumable cursor already exists.
- Expanded drift remediation selection so it also catches active full-history runs that were launched in `details_refresh` mode, not just runs already marked with `newest_first_frontier`.
- **[debug-session]** Added `_resolve_runtime_version_stamp` to the `control_plane` re-export plumbing (`runtime.py` + package `__init__.py`). The WIP Task 2 heartbeat patch imported this symbol from `trr_backend.socials.control_plane`, but the symbol is defined only in `trr_backend.repositories.social_season_analytics`. The missing re-export caused:
  - `scripts/socials/worker.py:18` to raise `ImportError` at module load, blocking the worker from starting.
  - `trr_backend/modal_dispatch.py:361` (inside `_record_dispatcher_heartbeat`) to silently swallow the same `ImportError` via `except Exception`, suppressing the runtime_version metadata publication Task 2 was meant to deliver.
- **[debug-session]** Fixed `_runtime_version_satisfies_requirement` so that a minimal pin (execution_backend only, no `modal_image` / `commit_sha`) is satisfied by any observed runtime with a matching backend and a stronger identity anchor. The prior label-equality fallback made equivalent runtimes with different decorative labels read as mismatches, which prevented workers from claiming jobs and manifested in the UI as persistent Runtime Version Drift / Pin Mismatch alerts + stuck recovery handoffs (`Recovery Wait Exceeded · no partitions discovered`).

## Known follow-ups (not changed in this session)
- **DB pool sizing under catalog worker concurrency.** The user's `TRR_DB_POOL_MAXCONN=4` cannot support 3 shard workers + history discovery + API polling simultaneously, which surfaces as "connection pool exhausted" errors and drops in-flight shard progress when a commit fails mid-transaction. Recommend bumping `TRR_DB_POOL_MAXCONN` to 8–12 in `TRR-Backend/.env` when running the catalog backfill with multiple parallel shards. Not a code bug — the pool-return correctness fix from 2026-03-26 (`workspace-screenalytics-api-only-and-db-pool-return-hardening.md`) is orthogonal.

## Validation
- `pytest -q TRR-Backend/tests/repositories/test_social_season_analytics.py::test_get_run_progress_snapshot_modal_runtime_pin_mismatch_uses_semantic_match` → **1 passed** (was FAILING before this session)
- `pytest -q TRR-Backend/tests/repositories/test_social_season_analytics.py -k 'runtime or heartbeat or dispatch or pin_mismatch'` → **37 passed** (was 36 passed + 1 failed before)
- `pytest -q TRR-Backend/tests/repositories/test_social_season_analytics.py -k 'start_social_account_catalog_backfill or remediate_social_account_catalog_strategy_drift or runtime_version'` → **21 passed** (baseline held)
- `pytest -q TRR-Backend/tests/api/routers/test_socials_season_analytics.py -k 'catalog_remediate_drift or catalog_backfill'` → **19 passed** (baseline held)
- `ruff check` + `ruff format --check` on changed files → clean
- Runtime import sanity: `python -c "from trr_backend.socials.control_plane import _resolve_runtime_version_stamp; from scripts.socials import worker; print('imports OK')"` → OK
- End-to-end UI: run `9caa09ed` queued at 23:07 (post re-export fix) successfully kicked off, discovered + scraped 4,686 posts before being cancelled due to the pool-saturation + unfixed-pin-mismatch combination; the Task 3 semantic-matching fix shipped in this session should unblock future runs on mixed-runtime worker pools.
