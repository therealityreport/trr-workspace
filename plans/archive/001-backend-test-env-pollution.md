# Plan 001: Isolate `os.environ` mutation in `test_modal_jobs.py` so the full backend test lane can become blocking

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: from `TRR-Backend/`, run
> `git diff --stat 8ea7aa1a..HEAD -- trr_backend/modal_jobs.py tests/test_modal_jobs.py`
> If either file changed since this plan was written, compare the "Current
> state" excerpts against the live code before proceeding; on a mismatch,
> treat it as a STOP condition. If the SHA `8ea7aa1a` does not resolve
> (rebased/GC'd), compare every "Current state" excerpt against live code by
> hand and note in your report that the SHA was unresolvable.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none (this is the unblocker other test-lane work depends on)
- **Category**: tests
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-06
- **State**: **RESOLVED LOCALLY (2026-07-07, uncommitted in the main TRR-Backend
  tree; not yet on `advisor/001`).** The fix is exactly this plan's Steps 2–3:
  a `tests/conftest.py` pristine-env baseline (`_PRISTINE_ENVIRON = dict(os.environ)`
  + `pristine_environ` fixture) and an autouse `_restore_modal_env` fixture in
  `tests/test_modal_jobs.py` that restores only the
  `_CANONICAL_MODAL_RUNTIME_DEFAULTS` keys. Result: `pytest tests/test_modal_jobs.py`
  is now **green in isolation (48 passed)**. The "Execution findings" below are
  kept as the record of why a first executor pass STOPPED (the file was red in
  isolation *before* this fixture existed); the surgical-restore concern noted
  there turned out not to break the file's own tests.

## Execution findings (2026-07-07) — why the first pass STOPPED (now resolved)

A first executor run and reviewer verification found that, *before the fix*,
**`tests/test_modal_jobs.py` was NOT green in isolation.** Three tests failed
when the file was run alone:

- `test_social_concurrency_limit_reads_env`
- `test_social_comments_concurrency_limit_reads_comments_env`
- `test_reload_falls_back_to_stub_when_modal_module_is_partial`

Each fails inside `importlib.reload(modal_jobs)` with
`RuntimeError: Modal maintenance has no active owner...` (raised at
`trr_backend/modal_jobs.py:577`). Mechanism: these tests `monkeypatch.delenv`
the owner-enabler vars (`TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED` /
`TRR_MODAL_RUNTIME_SCHEDULER_ENABLED`), then the reload re-runs
`_inject_modal_runtime_defaults()`, which sets
`TRR_MODAL_MAINTENANCE_OWNER_REQUIRED=1` **without** an owner enabler → the guard
raises. `TRR_LOCAL_DEV=1` does **not** fix this (verified — still 3 fail).

Implication that breaks this plan's approach: the file both **causes** pollution
(leaking `TRR_JOB_PLANE_MODE=remote` etc.) **and depends on** pollution — in the
full lane it only passes because some earlier test leaks an owner-enabler var
into `os.environ`. A surgical teardown that restores the pristine env (this
plan's Steps 2–3) would *remove that owner-enabler leak too*, and could break
whatever currently rides on it. So env isolation cannot be done blindly here.

**Rethink direction for the next author** (do NOT just re-run this plan): first
map, in the full non-api lane, which tests SET vs DEPEND-ON each canonical key
(especially the owner-enabler vars). The fix likely must (a) make
`test_modal_jobs.py` self-sufficient — set the owner-enabler it needs within its
own fixtures rather than relying on a leak — AND (b) isolate its outbound leaks.
Both halves are needed; this plan only addressed (b). Consider whether the
owner-guard's test-time behavior should be relaxed via a documented test-only
env (e.g. an explicit fixture setting one owner enabler) rather than fighting the
reload. Characterization-map first, fix second.

## Why this matters

`TRR-Backend` CI only gates on `pytest tests/api` (58 of 447 test files). The full
suite (`test-full` job) runs with `continue-on-error: true` because it has ~18
cross-test-pollution failures that pass in isolation. That means regressions in
the run-lifecycle state machine, dispatch runtime, JWT verification, and the
Modal deploy surface can merge undetected. The single largest source of that
pollution is `test_modal_jobs.py`: it repeatedly calls
`modal_jobs._inject_modal_runtime_defaults()` and `importlib.reload(modal_jobs)`,
both of which write ~50 production-like values directly into the real
`os.environ` (`TRR_JOB_PLANE_MODE=remote`, `TRR_REMOTE_EXECUTOR=modal`, pool
sizes, sticky-proxy flags, …) and never restore them. Every test that runs after
`test_modal_jobs.py` in the same process inherits that mutated environment.

Fixing the leak is the prerequisite for making the full suite trustworthy enough
to promote to a blocking gate (tracked separately). This plan does **not** flip
the CI gate — it removes the pollution so a later plan safely can.

## Current state

- `trr_backend/modal_jobs.py:681-687` — the injector writes straight into the
  real process environment:

  ```python
  def _inject_modal_runtime_defaults() -> None:
      for key, value in _CANONICAL_MODAL_RUNTIME_DEFAULTS.items():
          os.environ[key] = value
      if (os.getenv("OBJECT_STORAGE_ACCESS_KEY_ID") or "").strip() and (
          os.getenv("OBJECT_STORAGE_SECRET_ACCESS_KEY") or ""
      ).strip():
          os.environ.pop("OBJECT_STORAGE_PROFILE", None)
  ```

  It is also called at module import (`trr_backend/modal_jobs.py:742`,
  bare `_inject_modal_runtime_defaults()` at module scope). **Do not change the
  import-time call or the function body** — production relies on it. The fix is
  test-side isolation.

- `tests/test_modal_jobs.py` calls the injector and/or reloads the module at
  many sites without restoring `os.environ`. Confirmed call sites (line numbers
  as of the planned-at SHA): `_inject_modal_runtime_defaults()` at lines 210,
  274, 287, 300; `importlib.reload(modal_jobs)` at lines 474, 482, 490, 500,
  791, 802 (and more below 802 — grep for the full set). The representative
  offender at `tests/test_modal_jobs.py:202-215`:

  ```python
  def test_inject_modal_runtime_defaults_sets_canonical_modal_flags(
      monkeypatch: pytest.MonkeyPatch,
  ) -> None:
      for key in modal_jobs._CANONICAL_MODAL_RUNTIME_DEFAULTS:
          monkeypatch.delenv(key, raising=False)
      monkeypatch.delenv("TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED", raising=False)
      monkeypatch.delenv("TRR_MODAL_RUNTIME_SCHEDULER_ENABLED", raising=False)

      modal_jobs._inject_modal_runtime_defaults()   # writes real os.environ, never restored

      assert os.environ["TRR_JOB_PLANE_MODE"] == "remote"
      ...
  ```

  `monkeypatch.delenv` only clears keys *before* the call; the values the
  injector then writes are real `os.environ` writes that pytest's monkeypatch
  does not track or roll back.

- The keys written come from `modal_jobs._CANONICAL_MODAL_RUNTIME_DEFAULTS` (a
  module-level dict in `trr_backend/modal_jobs.py`) plus the conditional
  `OBJECT_STORAGE_PROFILE` pop.

- **Convention**: this repo uses pytest + `monkeypatch` for env isolation.
  Existing tests use `monkeypatch.setenv` / `monkeypatch.delenv`; there is no
  autouse env-snapshot fixture today. There is **no `tests/conftest.py` and no
  `tests/api/conftest.py`** at the repo-wide level (per-directory conftests
  exist under `tests/api/routers/`).

> **Why the naive fix fails (read before Step 2)**: A per-test
> `snapshot = dict(os.environ); ... os.environ.update(snapshot)` fixture placed
> in `test_modal_jobs.py` does NOT work. The pollution happens at *import* time:
> `from trr_backend import modal_jobs` (top of the test file) runs the
> module-scope `_inject_modal_runtime_defaults()` during collection, before any
> test's setup. So a snapshot taken at a test's setup already contains the
> canonical keys, and restoring to it preserves them — the leak survives. The fix
> must restore to a baseline captured **before** `modal_jobs` was ever imported.
> That baseline lives in a repo-root `tests/conftest.py`, which pytest imports
> before it imports any test module.

## Commands you will need

Run from `TRR-Backend/` with the venv active (`source .venv/bin/activate`).
`ruff` is the system binary (`/opt/homebrew/bin/ruff`, config at
`TRR-Backend/ruff.toml`); there is no `.venv/bin/ruff`.

| Purpose | Command | Expected on success |
|---|---|---|
| Import gate | `.venv/bin/python -c "import api.main"` | exit 0, prints nothing |
| Target test file alone | `.venv/bin/python -m pytest tests/test_modal_jobs.py -q` | all pass |
| Full non-api lane (repro, Step 1) | `.venv/bin/python -m pytest tests -q -m "not browser and not vision and not live"` | reproduces the ~18 in-suite failures |
| Blocking gate (must stay green) | `.venv/bin/python -m pytest tests/api -q` | all pass |
| Lint | `ruff check tests/test_modal_jobs.py tests/conftest.py` | exit 0 |

## Scope

**In scope** (the only files you should modify):
- `tests/conftest.py` (create — repo-root conftest holding the pristine-env baseline)
- `tests/test_modal_jobs.py` (add the autouse restore fixture)

**Out of scope** (do NOT touch, even though they look related):
- `trr_backend/modal_jobs.py` — the injector's production behavior (import-time
  mutation) is intentional; changing it risks Modal runtime config. This plan is
  test-isolation only.
- The `.github/workflows/ci.yml` gate — flipping `test-full` to blocking is a
  separate plan that depends on this one. Do not touch CI here.
- Any other test file — if you find the same leak elsewhere, record it in your
  report; do not fix it in this plan.

## Git workflow

- Branch: `advisor/001-backend-test-env-pollution`
- Commit message style matches `git log` — **plain imperative, NOT conventional
  commits** (recent log: "align modal lockfile compile headers", "fix backend ci
  gate regressions"). Example: `isolate modal runtime env in test_modal_jobs`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Reproduce the real pollution and identify the coupling

Run the target file alone (must be green), then run the full non-api lane to
reproduce the in-suite failures:

```
.venv/bin/python -m pytest tests/test_modal_jobs.py -q
.venv/bin/python -m pytest tests -q -m "not browser and not vision and not live"
```

From the full-lane failures, identify **which** failing assertions read the
canonical modal env vars (`TRR_JOB_PLANE_MODE`, `TRR_REMOTE_EXECUTOR`,
`TRR_DB_POOL_*`, or any key in `modal_jobs._CANONICAL_MODAL_RUNTIME_DEFAULTS`) —
those are the ones this plan fixes. Confirm each such test passes in isolation
(`pytest <that_test_file> -q`) but fails in the full lane. Record the exact
test IDs and the leaked keys in your report.

**Verify**: you have at least one test that (a) passes alone, (b) fails in the
full lane, and (c) fails because of a leaked canonical modal env var. **STOP and
report if**: no failing assertion couples to these env vars (the ~18 failures may
have a different root cause — e.g. shared DB state or `sys.modules` injection —
which is out of this plan's scope; do not invent an env fix for a non-env
problem).

### Step 2: Capture a pristine env baseline in `tests/conftest.py`

Create `tests/conftest.py` (it does not exist today — only
`tests/api/routers/conftest.py` does). pytest imports this repo-root conftest
before any test module, so a module-level snapshot here predates the
`modal_jobs` import pollution:

```python
import os
import pytest

# Captured at conftest import — before any test module imports trr_backend.modal_jobs,
# whose module-scope _inject_modal_runtime_defaults() writes ~50 canonical values into
# os.environ. This is the true pre-pollution baseline.
_PRISTINE_ENVIRON = dict(os.environ)


@pytest.fixture
def pristine_environ():
    return _PRISTINE_ENVIRON
```

**Verify**: `.venv/bin/python -m pytest tests/api -q` → still all pass (adding a
conftest must not disturb the gate).

### Step 3: Restore the canonical keys after each `test_modal_jobs.py` test

Add an autouse, **function-scoped** fixture to `tests/test_modal_jobs.py` that
restores exactly the keys the injector touches — to their pristine values, or
removes them if they were not present pre-import. This is surgical (it does not
`clear()` all of `os.environ`, so it cannot wipe env that other fixtures set):

```python
@pytest.fixture(autouse=True)
def _restore_modal_env(pristine_environ):
    """_inject_modal_runtime_defaults() / importlib.reload(modal_jobs) write the
    canonical modal keys directly into os.environ (monkeypatch does not track
    those writes). Restore just those keys after each test so they don't leak to
    other test files sharing this process."""
    yield
    for key in modal_jobs._CANONICAL_MODAL_RUNTIME_DEFAULTS:
        if key in pristine_environ:
            os.environ[key] = pristine_environ[key]
        else:
            os.environ.pop(key, None)
```

`test_modal_jobs.py` already imports `os`, `pytest`, and `modal_jobs` (lines
5-12) — reuse those, do not re-import. Do **not** delete the existing
`monkeypatch.delenv` lines — they set each test's pre-call state; this fixture
only cleans up after.

**Verify**: `.venv/bin/python -m pytest tests/test_modal_jobs.py -q` → all pass
(the fixture restores in teardown, so within-test `os.environ` assertions are
unaffected).

### Step 4: Prove the leak is gone

Re-run the exact failing test(s) you identified in Step 1, together in one
process with `test_modal_jobs.py` ordered first:

```
.venv/bin/python -m pytest tests/test_modal_jobs.py <the_coupled_test_file_from_step_1> -q
```

Then re-run the full non-api lane:

```
.venv/bin/python -m pytest tests -q -m "not browser and not vision and not live"
```

**Verify**: the env-coupled failures from Step 1 now pass. If other failures
remain with a different root cause (shared DB state, `sys.modules` injection —
see Maintenance notes), record them as "remaining pollution, different source";
do not fix them here.

### Step 5: Keep the blocking gate green

```
.venv/bin/python -m pytest tests/api -q
```

**Verify**: all pass (this plan must not regress the gate).

## Test plan

- No new *product* tests. The deliverable is test-isolation infrastructure: a
  `tests/conftest.py` pristine-env baseline and an autouse restore fixture in
  `tests/test_modal_jobs.py`.
- Correctness is proven by Step 4 (the env-coupled failure identified in Step 1
  now passes in the full lane) plus Step 3 (the file's own tests still pass).
- Structural pattern to follow: pytest autouse fixtures already used elsewhere
  in `tests/` (search `@pytest.fixture(autouse=True)` for examples).

## Done criteria

ALL must hold:

- [ ] `.venv/bin/python -m pytest tests/test_modal_jobs.py -q` → all pass
- [ ] The specific env-coupled test(s) identified in Step 1 pass in the full
      non-api lane in Step 4 (record the test IDs)
- [ ] `.venv/bin/python -m pytest tests/api -q` → all pass (gate unregressed)
- [ ] `ruff check tests/test_modal_jobs.py tests/conftest.py` → exit 0
- [ ] `git diff --name-only` shows only `tests/test_modal_jobs.py` and
      `tests/conftest.py`
- [ ] `trr_backend/modal_jobs.py` is unchanged (`git diff -- trr_backend/modal_jobs.py` empty)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- Step 1 finds no failing assertion that couples to a canonical modal env var —
  the ~18 failures then have a different root cause (shared DB state,
  `sys.modules` injection) that this env-isolation plan does not address. Do not
  invent an env fix for a non-env problem.
- After the fixture is added, `tests/test_modal_jobs.py`'s own tests fail —
  some test may deliberately assert on state that persists across the reload
  sites within the file; report which, do not delete assertions to make it pass.
- The `_inject_modal_runtime_defaults` body or the `_CANONICAL_MODAL_RUNTIME_DEFAULTS`
  dict differs from the "Current state" excerpt (drift).
- Fixing this appears to require editing `trr_backend/modal_jobs.py` — it does
  not; if you believe it does, report why instead.

## Maintenance notes

- Once this lands, a follow-up plan can promote the `test-full` CI job from
  `continue-on-error: true` to blocking — but only after confirming the *other*
  pollution sources are also resolved. Do not flip the gate until the full
  non-browser/non-vision/non-live lane is green in CI.
- The surgical fixture restores only the keys in
  `_CANONICAL_MODAL_RUNTIME_DEFAULTS`. If the injector later grows to write keys
  outside that dict (e.g. it also pops `OBJECT_STORAGE_PROFILE`), the fixture
  must be widened to match — a reviewer should check the fixture's key set still
  covers everything `_inject_modal_runtime_defaults` mutates.
- Deferred out of scope: a second pollution vector in the same file is the
  `importlib.reload(modal_jobs)` that follows `monkeypatch.setitem(sys.modules, ...)`
  (statements begin near `test_modal_jobs.py:596,635,670,1085,1090`;
  `monkeypatch.setitem` itself is auto-rolled-back by pytest, so the residual
  leak is from the reload, not the setitem). If Step 4's full-lane run still
  shows env leakage after this fix, that reload path is the likely source and
  gets its own plan.
