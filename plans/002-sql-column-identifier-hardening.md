# Plan 002: Validate dynamically-built SQL column identifiers in the screentime `update_*` repositories

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan in
> `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: from `TRR-Backend/`, run
> `git diff --stat 8ea7aa1a..HEAD -- trr_backend/repositories/cast_screentime.py trr_backend/repositories/screenalytics_runs.py trr_backend/db/session.py`
> If any of these changed since this plan was written, compare the "Current
> state" excerpts against the live code before proceeding; on a mismatch, treat
> it as a STOP condition. If SHA `8ea7aa1a` does not resolve, compare excerpts
> to live code by hand and say so in your report.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: security (defense-in-depth)
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-06

## Why this matters

Several screentime repository `update_*` functions build the SQL `SET` clause by
interpolating **dict keys directly as column names** via f-string
(`f"{key} = %s"`), with no identifier validation. The *values* are correctly
parameterized, but the *column names* are not. Every current caller passes
hardcoded key sets from Pydantic-validated models or internal code, so there is
no live injection path today — this is a latent vector: the day any caller
forwards request-controlled dict keys into one of these functions, it becomes
column-name SQL injection on an authenticated endpoint. The repo already has a
tested identifier validator (`trr_backend/db/session.py:_validate_identifier`);
these functions simply don't use it. Adding the guard is a small, low-risk
change that closes the class of bug and fails loudly if a bad key ever arrives.

This was independently flagged by two audit passes (correctness and security).
Note: `trr_backend/socials/social_season_analytics_impl.py` also interpolates
table/column identifiers from internal config dicts (e.g. lines ~19431, ~20793,
~20864). Those are **out of scope here** (higher blast radius, internal-only
values) and are recorded as a separate backlog item — do not touch them in this
plan.

## Current state

- `trr_backend/db/session.py:42` — the existing validator to reuse (regex-based,
  raises on anything that is not a plain SQL identifier):

  ```python
  def _validate_identifier(name: str) -> str:
      # (module-private; validates against a safe identifier pattern and
      #  returns the name, raising ValueError on violation)
  ```

  Read the actual implementation before using it — confirm the exact function
  name, its module path (`trr_backend.db.session`), whether it is intended to be
  imported by other modules (it is prefixed `_`, so you may prefer to add a
  small public wrapper or a local copy — see Step 1), and what exception type it
  raises.

- `trr_backend/repositories/cast_screentime.py:84-99` — `update_media_upload_session`:

  ```python
  def update_media_upload_session(upload_session_id: str, payload: dict[str, Any]) -> dict[str, Any] | None:
      if not payload:
          return get_media_upload_session(upload_session_id)
      assignments: list[str] = []
      params: list[Any] = []
      for key, value in payload.items():
          assignments.append(f"{key} = %s")          # <-- unvalidated column name
          params.append(_json(_normalize(value)))
      params.append(upload_session_id)
      rows = pg.execute_returning(
          f"UPDATE ml.analysis_media_upload_sessions SET {', '.join(assignments)} WHERE id = %s RETURNING *",
          params,
      )
      return rows[0] if rows else None
  ```

- `trr_backend/repositories/cast_screentime.py:700-714` — `update_run` (same
  pattern, target table `ml.screentime_runs`). Its caller `set_run_heartbeat`
  (`cast_screentime.py:717`) passes internal keys (`worker_heartbeat_at`,
  `status`).

- `trr_backend/repositories/screenalytics_runs.py:194` — a **third, separately-named**
  copy of the same pattern. Note this is a *different* function from
  `cast_screentime.py`'s `update_run` (line 700) even though both are named
  `update_run` and both target `ml.screentime_runs` — grepping `def update_run`
  returns both. This screenalytics one begins at line 194:

  ```python
  if not payload:
      return get_run(run_id)
  assignments = []
  params: list[Any] = []
  for key, value in payload.items():
      assignments.append(f"{key} = %s")              # <-- unvalidated column name
      params.append(_json(_normalize(value)))
  params.append(run_id)
  sql = f"UPDATE ml.screentime_runs SET {', '.join(assignments)} WHERE id = %s RETURNING *"
  rows = pg.execute_returning(sql, params)
  return rows[0] if rows else None
  ```

- **Convention**: repository functions live under `trr_backend/repositories/`,
  use `pg.execute_returning` / `pg.fetch_one` for DB access, `_json`/`_normalize`
  helpers for value coercion, ruff (line length 120, double quotes). Tests mirror
  the module path under `tests/repositories/`.

## Commands you will need

Run from `TRR-Backend/` with the venv active.

| Purpose | Command | Expected on success |
|---|---|---|
| Import gate | `.venv/bin/python -c "import api.main"` | exit 0 |
| Repo tests (screentime) | `.venv/bin/python -m pytest tests/repositories/test_cast_screentime_repository.py -q` | all pass |
| New tests (Step 3) | `.venv/bin/python -m pytest tests/repositories/test_cast_screentime_repository.py tests/repositories/test_screenalytics_runs.py -q` | all pass incl. new |
| API gate (unregressed) | `.venv/bin/python -m pytest tests/api -q` | all pass |
| Lint | `ruff check trr_backend/repositories/cast_screentime.py trr_backend/repositories/screenalytics_runs.py` | exit 0 |

## Scope

**In scope**:
- `trr_backend/repositories/cast_screentime.py` (guard `update_media_upload_session`, `update_run`)
- `trr_backend/repositories/screenalytics_runs.py` (guard the `update_*` function shown above)
- `tests/repositories/test_cast_screentime_repository.py` (add rejection tests)
- `tests/repositories/test_screenalytics_runs.py` (create if absent; add rejection test)
- Optionally `trr_backend/db/session.py` **only** to add a public re-export
  wrapper if you decide not to import the underscored `_validate_identifier`
  directly (see Step 1). Do not change its logic.

**Out of scope**:
- `trr_backend/socials/social_season_analytics_impl.py` identifier interpolation
  — separate backlog item, higher blast radius.
- Any change to the *values* path (`_json`/`_normalize`) — already parameterized.
- The column allowlist contents of any Pydantic model — callers are fine; this
  is a defense-in-depth guard at the DB boundary.

## Git workflow

- Branch: `advisor/002-sql-column-identifier-hardening`
- Conventional-commit messages (e.g. `fix(db): validate dynamic column names in screentime update_*`).
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Decide how to reach the validator

Read `trr_backend/db/session.py:42-58`. There are **two** relevant existing,
tested helpers — both raise `ValueError` on a bad identifier:

- `_validate_identifier(name: str) -> str` (line 42) — validates one name.
- `_validate_mapping_keys(payload: dict) -> dict` (line 55) — validates **every
  key** of a payload dict and returns it. This is exactly the per-key guard this
  plan needs and is already used in `session.py:130`.

Pick one approach and use it consistently across all three functions:

- **Option A (preferred)**: import and call `_validate_mapping_keys` once at the
  top of each `update_*` function, right after the `if not payload:` guard:
  `payload = _validate_mapping_keys(payload)`. Simplest, purpose-built, validates
  all keys.
- **Option B**: import `_validate_identifier` and call it per key inside the
  existing loop (see Step 2). Equivalent safety.
- **Option C**: if you object to importing a module-private name across modules,
  add a thin public wrapper in `session.py` (e.g.
  `def validate_mapping_keys(payload): return _validate_mapping_keys(payload)`)
  and import that. Do **not** alter the existing helpers' behavior.

Importing the underscore-prefixed names across modules is import-safe here (no
circular import — repositories import `trr_backend.db.pg`, not each other); add a
one-line comment at the call site noting why a private import is used if you take
Option A or B.

**Verify**: `.venv/bin/python -c "from trr_backend.db.session import _validate_identifier; print(_validate_identifier('status'))"` → prints `status`; and a bad
identifier raises (try `_validate_identifier('a = 1; --')` in a throwaway
`python -c` and confirm it raises).

### Step 2: Guard each `SET`-clause builder

In each of the three loops, validate the key before interpolating:

```python
for key, value in payload.items():
    safe_key = _validate_identifier(key)      # raises on non-identifier keys
    assignments.append(f"{safe_key} = %s")
    params.append(_json(_normalize(value)))
```

Apply to `update_media_upload_session` and `update_run` in
`cast_screentime.py`, and the `update_*` function in `screenalytics_runs.py`.
Keep everything else identical.

**Verify**: `.venv/bin/python -c "import api.main"` → exit 0, and
`ruff check trr_backend/repositories/cast_screentime.py trr_backend/repositories/screenalytics_runs.py` → exit 0.

### Step 3: Add rejection tests

In `tests/repositories/test_cast_screentime_repository.py`, add tests that a
payload with a malicious key is rejected before any SQL executes.

**These rejection tests need NO database mock.** The guard raises *before*
`pg.execute_returning` is ever reached, so — unlike the other tests in this file
that monkeypatch `cast_screentime.pg` — a rejection test can call the function
directly and assert it raises. Do not copy the `pg`-monkeypatch scaffolding for
these; it is unnecessary and misleading.

```python
import pytest
from trr_backend.repositories import cast_screentime

def test_update_run_rejects_non_identifier_column():
    with pytest.raises(ValueError):   # _validate_identifier / _validate_mapping_keys raise ValueError
        cast_screentime.update_run("some-run-id", {"status = 'x'; --": "y"})
```

Add the analogous rejection test for `update_media_upload_session` and for the
`screenalytics_runs.update_run` function. Create
`tests/repositories/test_screenalytics_runs.py` (it does **not** exist today),
following the structure of `test_cast_screentime_repository.py`. Give the
screenalytics test a disambiguating name (e.g.
`test_screenalytics_update_run_rejects_non_identifier_column`) since both modules
have an `update_run`.

Do **not** attempt to add happy-path tests in this plan: verified, **no existing
test** calls `update_run` or `update_media_upload_session`, and a happy-path test
*would* need the `pg` monkeypatch (unlike the rejection tests). Adding happy-path
coverage is a reasonable follow-up but is out of scope here — the rejection tests
plus the `import api.main` gate and `tests/api` are sufficient proof for this
defense-in-depth change.

**Verify**: `.venv/bin/python -m pytest tests/repositories/test_cast_screentime_repository.py tests/repositories/test_screenalytics_runs.py -q` → all pass, including the new rejection tests. (This command works only *after* you create
`test_screenalytics_runs.py` in this step — running it before will error with a
collection failure, not a test failure.)

### Step 4: Regression gate

**Verify**: `.venv/bin/python -m pytest tests/api -q` → all pass.

## Test plan

- New tests: one rejection test per guarded function (3 total), asserting a
  non-identifier key raises before SQL runs. Cover the happy path if not already
  covered.
- Structural pattern: model after existing tests in
  `tests/repositories/test_cast_screentime_repository.py`.
- Verification: the Step 3 command passes with the 3 new tests present.

## Done criteria

ALL must hold:

- [ ] All three `update_*` functions call the identifier validator on each key
- [ ] `.venv/bin/python -m pytest tests/repositories/test_cast_screentime_repository.py tests/repositories/test_screenalytics_runs.py -q` → all pass incl. new rejection tests
- [ ] `.venv/bin/python -m pytest tests/api -q` → all pass
- [ ] `ruff check` on both repository files → exit 0
- [ ] `git status` shows only in-scope files modified/created
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `_validate_identifier` does not exist at the cited location or has a different
  signature/behavior than described (drift) — do not hand-roll a regex; report.
- `tests/api` starts failing because a *real* current caller passes a key that is
  not a plain identifier (e.g. a quoted or dotted column) into one of these
  functions — that means a legitimate key is being rejected; report the key and
  caller instead of loosening the validator. (No current caller is expected to do
  this, but the `tests/api` gate is where it would surface.)
- Adding the guard requires touching a Pydantic model or a router — it should
  not; report why if it appears to.

## Maintenance notes

- Follow-up (separate backlog item): apply the same identifier validation to the
  f-string table/column interpolation in
  `trr_backend/socials/social_season_analytics_impl.py` (~lines 19431, 20793,
  20864). Larger blast radius — needs its own plan and characterization tests.
- A reviewer should confirm the guard runs on **every** key (use
  `_validate_mapping_keys`, or call `_validate_identifier` inside the loop — not
  just on the first key).
- Note on error surfacing: a raised `ValueError` from the repository will surface
  as an unhandled **500** unless a router catches it. That is acceptable for this
  fail-loud defense-in-depth guard (no current caller passes bad keys, so it
  never fires today), so this plan does not add router-level 400 handling. If a
  future caller legitimately needs a 400, that is a separate router-layer change.
