# Plan 010: Make social job finish and run-counter updates atomic

> **Executor instructions**: This touches the social run state machine. Keep the
> diff narrow and preserve the characterization tests from plan 004.
>
> **Drift check**: `git -C TRR-Backend diff --stat 8ea7aa1a..HEAD -- trr_backend/socials/social_season_analytics_impl.py trr_backend/socials/control_plane/run_lifecycle.py tests/repositories/test_run_lifecycle_counters.py`

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: 004
- **Category**: correctness
- **Planned at**: TRR-Backend `8ea7aa1a`, 2026-07-07

## Why this matters

`_finish_job()` updates the job row, then run counters are updated separately.
If the second write fails, a job can be terminal while the run summary is stale.
There is a recovery sweep, but the hot write path should be atomic.

## Current state

- `trr_backend/socials/social_season_analytics_impl.py:13605` defines
  `_finish_job(...)`.
- `trr_backend/socials/social_season_analytics_impl.py:13619` updates
  `social.scrape_jobs`.
- `trr_backend/socials/social_season_analytics_impl.py:13711` calls
  `_increment_run_counters_on_job_finish(...)` after the job update.
- `trr_backend/socials/control_plane/run_lifecycle.py:1111` defines the counter
  update helper.

## Scope

**In scope**:
- `trr_backend/socials/social_season_analytics_impl.py`
- `trr_backend/socials/control_plane/run_lifecycle.py`
- `tests/repositories/test_run_lifecycle_counters.py`

**Out of scope**:
- Broad extraction of `social_season_analytics_impl.py`.
- Changing run status names or recovery sweep semantics.

## Steps

1. Read the plan 004 tests and confirm they pass before editing.
2. Thread one transaction/connection through the job-finish update and counter
   update. Prefer the smallest existing DB helper pattern already used nearby.
3. Add one regression test that forces the counter update to fail and verifies
   the job status update is not committed independently.
4. Keep recovery behavior unchanged for already-stale historical rows.

## Commands

Run from `TRR-Backend/`:

```bash
.venv/bin/python -m pytest tests/repositories/test_run_lifecycle_counters.py -q
.venv/bin/python -m pytest tests/api -q
ruff check trr_backend/socials/social_season_analytics_impl.py trr_backend/socials/control_plane/run_lifecycle.py tests/repositories/test_run_lifecycle_counters.py
```

## Done criteria

- Job terminal update and run counter update succeed or fail as one unit.
- Existing run-lifecycle characterization tests still pass.
- New failure-path regression test exists and passes.
