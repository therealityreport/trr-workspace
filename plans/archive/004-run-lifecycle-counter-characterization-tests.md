# Plan 004: Add characterization tests for run-lifecycle counter transitions (safety net before any atomicity refactor)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the next
> step. If anything in the "STOP conditions" section occurs, stop and report — do
> not improvise. When done, update the status row for this plan in
> `plans/README.md` — unless a reviewer dispatched you and told you they maintain
> the index.
>
> **Drift check (run first)**: from `TRR-Backend/`, run
> `git diff --stat 8ea7aa1a..HEAD -- trr_backend/socials/control_plane/run_lifecycle.py trr_backend/socials/social_season_analytics_impl.py tests/repositories/test_social_run_lifecycle_repository.py`
> If any changed, compare the "Current state" excerpts against live code before
> proceeding; on a mismatch treat it as a STOP condition. If SHA `8ea7aa1a` does
> not resolve, compare excerpts by hand and note it.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW (adds tests only — no production code changes)
- **Depends on**: 001 (test-env isolation) should land first so these tests run
  cleanly in the full lane; they can be *written* independently.
- **Category**: tests
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-06

## Why this matters

The social run-lifecycle keeps per-run counters (`total_jobs`, `completed_jobs`,
`failed_jobs`, `active_jobs`, `items_found_total`) that drive run finalization.
An audit found the update path is split across separate DB transactions:
`_finish_job` commits the job-status change on one connection
(`pg.fetch_one`, auto-committed), then `_increment_run_counters_on_job_finish`
opens **its own** `pg.db_connection()` to update the counters. If the process
dies or the counter update hits a statement timeout between the two commits, the
counters drift from reality. There is already a self-healing sweep
(`recover_unfinalized_terminal_runs`, `reconcile_run_summaries`), so the impact
is *delayed run finalization under DB pressure*, not data loss — which is exactly
why the right first move is **not** to refactor the hottest write path blindly,
but to lock in the current behavior with characterization tests. Those tests
become the safety net that makes a later atomicity change reviewable. This plan
writes the net; it changes **no production code**.

## Current state

- `trr_backend/socials/social_season_analytics_impl.py:13605-13732` — `_finish_job`.
  It runs one CTE via `pg.fetch_one(...)` (`social_season_analytics_impl.py:13619`)
  to flip the job's status `FOR UPDATE`, then, when the row has a `run_id`, calls
  the counter updater and swallows deferred failures:

  ```python
  if row and row.get("run_id"):
      try:
          _increment_run_counters_on_job_finish(
              run_id=str(row.get("run_id")),
              stage=str(row.get("stage") or "unknown"),
              prior_status=str(row.get("prior_status") or ""),
              new_status=status,
              prior_items_found=_normalize_non_negative_int(row.get("prior_items_found")),
              new_items_found=_normalize_non_negative_int(items_found),
          )
      except Exception as exc:  # noqa: BLE001
          if pg._is_statement_timeout_error(exc) or isinstance(exc, pg.DatabaseServiceUnavailableError):
              logger.warning("[finish_job] run counter sync deferred after job=%s ...", ...)
          else:
              raise
  ```

- `trr_backend/socials/control_plane/run_lifecycle.py:1120-1177` —
  `_increment_run_counters_on_job_finish`. It computes deltas from
  `prior_status`→`new_status` and opens its own transaction:

  ```python
  active_delta = (1 if _status_is_active(new_status) else 0) - (1 if _status_is_active(prior_status) else 0)
  completed_delta = (1 if _status_is_completed(new_status) else 0) - (1 if _status_is_completed(prior_status) else 0)
  failed_delta = (1 if _status_is_failed(new_status) else 0) - (1 if _status_is_failed(prior_status) else 0)
  ...
  with legacy.pg.db_connection() as conn:
      with legacy.pg.db_cursor(conn=conn) as cur:
          row = legacy.pg.fetch_one_with_cursor(cur, "select total_jobs, completed_jobs, ... from social.scrape_runs where id = %s for update", ...)
  ```

- Real self-healing entry points (they exist — verify signatures):
  `recover_unfinalized_terminal_runs(*, limit: int = 25)` at
  `run_lifecycle.py:705`; `reconcile_run_summaries(*, run_ids=None, limit=100)`
  at `run_lifecycle.py:1358`; `_recompute_run_summary_from_jobs(run_id)` at
  `run_lifecycle.py:1179`; `_persist_run_counters_and_summary(...)` at
  `run_lifecycle.py:907`.
- **Note on `_mark_run_finalize_pending`**: it exists at
  `social_season_analytics_impl.py:14047` (called from `_finish_job`'s finalize
  path at `:13780` and `:13783`) — but it does **not** exist in
  `run_lifecycle.py`. This plan does not call it; it is named here only so you
  don't waste time searching. Do not add new calls to it in this tests-only plan.
- Existing test to model on: `tests/repositories/test_social_run_lifecycle_repository.py`
  (a churn hotspot — read it first to learn the fixture/mock style this suite
  uses for `pg` and `social.scrape_runs`/`social.scrape_jobs`).

## Commands you will need

Run from `TRR-Backend/` with the venv active.

| Purpose | Command | Expected on success |
|---|---|---|
| Import gate | `.venv/bin/python -c "import api.main"` | exit 0 |
| Existing lifecycle tests | `.venv/bin/python -m pytest tests/repositories/test_social_run_lifecycle_repository.py -q` | all pass |
| New tests (Step 2) | `.venv/bin/python -m pytest tests/repositories/test_run_lifecycle_counters.py -q` | all pass |
| Lint | `ruff check tests/repositories/test_run_lifecycle_counters.py` | exit 0 |

## Scope

**In scope**:
- `tests/repositories/test_run_lifecycle_counters.py` (create)

**Out of scope** — do NOT modify any production module in this plan:
- `trr_backend/socials/control_plane/run_lifecycle.py`
- `trr_backend/socials/social_season_analytics_impl.py`
- Any CI config.

Creating a **new test-support fake** (e.g. a `db_connection` context-manager
stub) inside your new test file is expected and allowed — see Step 1. What you
must not do is edit any production module. If you believe a *production* change
is needed to make the code testable, STOP and report.

## Git workflow

- Branch: `advisor/004-run-lifecycle-counter-characterization-tests`
- Commit message style matches `git log` — **plain imperative, NOT conventional
  commits** (recent log: "harden backend admin social and show workflows").
  Example: `characterize run-lifecycle counter transitions`.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Learn the suite's mocking style — and note the gap you must fill

Read `tests/repositories/test_social_run_lifecycle_repository.py` end to end.
Identify how it fakes `pg`: it monkeypatches `pg.fetch_one`, and its closest
precedent (`test_update_run_summary_force_recompute_preserves_audit_fields`,
~lines 396-450) fakes `pg.fetch_one_with_cursor` and `pg.db_cursor` and passes a
sentinel `conn` into the function under test.

**Important gap**: the function this plan targets,
`_increment_run_counters_on_job_finish`, opens its **own**
`with legacy.pg.db_connection() as conn:` (`run_lifecycle.py:1130`) and takes no
`conn` parameter — so the sentinel-conn trick does NOT transfer. **Nothing in
the pattern file fakes `pg.db_connection()`.** You will therefore extend the
harness with a small `db_connection` context-manager fake (monkeypatch
`run_lifecycle.legacy.pg.db_connection` — note the function calls `pg` via the
`legacy` alias — to return a context manager yielding your fake conn, and fake
`db_cursor` / `fetch_one_with_cursor` to serve a seeded `social.scrape_runs`
row). This new fake lives in your test file; it is not a "new mocking approach"
to the suite, just the missing piece the precedent didn't need.

**Also**: `_increment_run_counters_on_job_finish` early-returns unless
`legacy._run_counter_columns_ready()` is truthy (`run_lifecycle.py:1120`). Every
precedent test monkeypatches this to return `True` (see the pattern file ~lines
233, 349, 397). You must do the same or the function no-ops and every assertion
is vacuous.

**Verify**: `.venv/bin/python -m pytest tests/repositories/test_social_run_lifecycle_repository.py -q` → all pass (confirms the harness works on this checkout).

### Step 2: Write characterization tests for the counter deltas

Create `tests/repositories/test_run_lifecycle_counters.py`. Import
`_increment_run_counters_on_job_finish` from
`trr_backend.socials.control_plane.run_lifecycle`. Set up per Step 1
(`_run_counter_columns_ready → True`, faked `db_connection`/`db_cursor`,
seeded run row), then assert the **current** delta behavior:

- active→completed: `active_jobs` −1, `completed_jobs` +1, others unchanged.
- active→failed: `active_jobs` −1, `failed_jobs` +1.
- retrying→completed and retrying→failed. (Confirmed: `run_lifecycle.py:757`
  includes `"retrying"` in the active set via `_status_is_active`, so both are
  `active_jobs` −1 with the completed/failed +1. Assert exactly that.)
- `items_found` delta: `new_items_found − prior_items_found` applied to
  `items_found_total`.

**Verify**: `.venv/bin/python -m pytest tests/repositories/test_run_lifecycle_counters.py -q` → all pass.

### Step 2b: Characterize the deferred-sync swallow (the drift-prone path)

This sub-task targets `_finish_job` in
`trr_backend.socials.social_season_analytics_impl`, NOT `run_lifecycle`.
Subtlety: `_finish_job` (`:13711`) calls a **module-local delegating wrapper**
`_increment_run_counters_on_job_finish` defined at
`social_season_analytics_impl.py:13989` (which re-dispatches to the
`run_lifecycle` impl) — so to force the timeout you must patch the name in the
`social_season_analytics_impl` namespace, e.g. `monkeypatch.setattr(
social_season_analytics_impl, "_increment_run_counters_on_job_finish", raiser)`
where `raiser` raises `pg.DatabaseServiceUnavailableError` (or an exception for
which `pg._is_statement_timeout_error` returns True). You will also need to fake
the `pg.fetch_one` that `_finish_job` runs first (the job-status CTE at
`:13619`) so it returns a row with a `run_id`. The suite has no existing
`_finish_job` test, so this is net-new setup — that is expected.

Assert: `_finish_job` returns normally (does not raise) when the counter sync
raises a timeout/unavailable error — i.e. a counter-sync failure does not
propagate. Add a docstring noting this documents *current* (drift-prone)
behavior, so a future atomicity refactor knows this is the contract to preserve
or intentionally change.

**Verify**: `.venv/bin/python -m pytest tests/repositories/test_run_lifecycle_counters.py -q` → all pass, including the deferred-sync test.

### Step 3: Confirm no production drift and gate stays green

**Verify**:
- `git diff --name-only` shows only `tests/repositories/test_run_lifecycle_counters.py`.
- `.venv/bin/python -m pytest tests/api -q` → all pass.

## Test plan

- New file `tests/repositories/test_run_lifecycle_counters.py` with ~5–7
  characterization tests covering each status-transition delta plus the
  deferred-sync swallow behavior.
- Structural pattern: `tests/repositories/test_social_run_lifecycle_repository.py`.
- Verification: Step 2 command passes.

## Done criteria

ALL must hold:

- [ ] `tests/repositories/test_run_lifecycle_counters.py` exists with tests for
      each transition delta and the deferred-sync swallow
- [ ] `.venv/bin/python -m pytest tests/repositories/test_run_lifecycle_counters.py -q` → all pass
- [ ] `.venv/bin/python -m pytest tests/api -q` → all pass
- [ ] `ruff check tests/repositories/test_run_lifecycle_counters.py` → exit 0
- [ ] No production file changed (`git status` shows only the new test file)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- You cannot fake `pg.db_connection()` / `pg.db_cursor` well enough to exercise
  `_increment_run_counters_on_job_finish` without a real database (extending the
  harness with a context-manager fake, per Step 1, is expected and is NOT a
  reason to stop — only stop if even that proves infeasible). Report what is
  missing rather than standing up a real DB.
- The observed delta behavior contradicts the source excerpts (drift) — report
  the discrepancy; the tests must pin *actual* behavior, so if actual behavior
  looks like a bug, document it in the test docstring and report it, do not
  "correct" it here.
- You find yourself needing to edit `run_lifecycle.py` or
  `social_season_analytics_impl.py` — that means this became a fix plan; STOP and
  report.

## Maintenance notes

- **Deferred follow-up (its own plan, depends on this one)**: make `_finish_job`
  and `_increment_run_counters_on_job_finish` share a single transaction so the
  job-status commit and counter update are atomic — MED/HIGH risk on the hottest
  write path, which is exactly why these characterization tests must exist first.
  A safer intermediate option is to enqueue the run for
  `reconcile_run_summaries(run_ids=[run_id])` when the counter sync is deferred,
  but that also needs these tests as a baseline.
- A reviewer should confirm these tests assert *current* behavior (including the
  swallow), not an idealized version — their job is to make a future refactor
  legible, not to change behavior.
