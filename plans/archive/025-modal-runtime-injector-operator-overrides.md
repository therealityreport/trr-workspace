# Plan 025: Let operators override tunable social knobs via Modal secret / env (stop the injector clobbering them)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git -C TRR-Backend diff --stat -- trr_backend/modal_jobs.py tests/test_modal_jobs.py`
> This repo's nested `TRR-Backend` working tree is **authoritative and dirty**
> (a prior improvement pass, plans 001–024, is uncommitted). The "Planned at"
> SHA below may not resolve cleanly; do NOT trust it over the live file.
> Before editing, re-read the excerpts in "Current state" against the live
> `trr_backend/modal_jobs.py`. If the `_inject_modal_runtime_defaults` function
> or the `_CANONICAL_MODAL_RUNTIME_DEFAULTS` dict no longer match the shape
> shown here, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: dx / correctness
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-08 — working tree authoritative
- **Repo**: TRR-Backend

## Why this matters

`trr_backend/modal_jobs.py` pins 99 runtime environment variables into
`os.environ` at import time with an **unconditional** assignment
(`os.environ[key] = value`, not `setdefault`). Because this runs on every Modal
container boot *after* Modal injects the deployment secret, any operator who
changes a tunable knob — the Instagram comments proxy provider, the SocialBlade
proxy provider, the public-relay GraphQL page size — through the Modal secret or
a `.env` value sees **no effect**: the injector overwrites their value with the
pinned literal. The worst concrete case is `SOCIAL_INSTAGRAM_COMMENTS_PROXY_PROVIDER`,
force-pinned to `decodo`: turning the comments proxy off or pointing it elsewhere
is impossible without a code change and redeploy.

The fix must be surgical. Many of the pinned keys are **deliberate safety
clamps** — the `TRR_*DB_POOL_*` sizes and the `*_CONCURRENCY_LIMIT` /
`SOCIAL_WORKER_POOL_*` caps bound how many Supavisor session-pooler backends the
comments fleet can pin (see `comments_db_session_budget_status()` at
`trr_backend/modal_jobs.py:130`). Loosening those blindly could exhaust the DB
pooler. So this plan makes only a **curated allowlist of non-DB-budget knobs**
operator-overridable (via `setdefault`) and leaves every safety/identity key
pinned exactly as today. The pool/concurrency knobs remain intentionally pinned;
making them tunable is a separate, larger change gated on the DB-session-budget
analysis and is explicitly out of scope here.

## Current state

- `trr_backend/modal_jobs.py` — Modal entrypoint module. Defines the canonical
  defaults dict and injects it at import.

Excerpt — the injector (around `trr_backend/modal_jobs.py:689`):

```python
def _inject_modal_runtime_defaults() -> None:
    for key, value in _CANONICAL_MODAL_RUNTIME_DEFAULTS.items():
        os.environ[key] = value
    if (os.getenv("OBJECT_STORAGE_ACCESS_KEY_ID") or "").strip() and (
        os.getenv("OBJECT_STORAGE_SECRET_ACCESS_KEY") or ""
    ).strip():
        os.environ.pop("OBJECT_STORAGE_PROFILE", None)
```

Called unconditionally at import (around `trr_backend/modal_jobs.py:748`):

```python
_validate_modal_maintenance_owner_config()
_secrets = _resolve_modal_secrets()
_inject_modal_runtime_defaults()
```

The dict `_CANONICAL_MODAL_RUNTIME_DEFAULTS` is defined at
`trr_backend/modal_jobs.py:289`. It contains, among 99 keys:

- **DB-pool / session-budget safety clamps** (KEEP PINNED — do not make tunable):
  every key starting `TRR_DB_POOL_`, `TRR_SOCIAL_PROFILE_DB_POOL_`,
  `TRR_SOCIAL_CONTROL_DB_POOL_`, `TRR_SOCIAL_PROGRESS_DB_POOL_`,
  `TRR_HEALTH_DB_POOL_`, and every key containing `CONCURRENCY_LIMIT`, plus
  `SOCIAL_WORKER_POOL_COMMENTS`, `SOCIAL_WORKER_POOL_MEDIA_MIRROR`,
  `SOCIAL_WORKER_POOL_COMMENT_MEDIA_MIRROR`, `SOCIAL_MIRROR_PLATFORM_CAP`,
  `SOCIAL_CATALOG_RUN_IN_FLIGHT_CAP`, `SOCIAL_MODAL_DISPATCH_LIMIT`.
- **Deployment-identity / routing** (KEEP PINNED): every key starting
  `TRR_MODAL_` that names a function/label, `TRR_JOB_PLANE_MODE`,
  `TRR_REMOTE_EXECUTOR`, `TRR_MODAL_ENABLED`, `TRR_LONG_JOB_ENFORCE_REMOTE`,
  `TRR_ADMIN_IMAGE_EXECUTION_BACKEND`, `SOCIAL_QUEUE_ENABLED`.
- **Operator-tunable knobs** currently dead-on-arrival (MAKE OVERRIDABLE):
  ```python
  "SOCIAL_INSTAGRAM_COMMENTS_PROXY_PROVIDER": "decodo",
  "SOCIALBLADE_PROXY_PROVIDER": "decodo",
  "SOCIAL_THREADS_POSTS_PROXY_PROVIDER": "decodo",
  "SOCIAL_INSTAGRAM_COMMENTS_COAUTHOR_GRAPHQL_PAGE_SIZE": "50",
  "SOCIAL_INSTAGRAM_COMMENTS_COAUTHOR_GRAPHQL_CHILD_PAGE_SIZE": "50",
  ```

Read sites confirm the pinned value is what runtime sees (all read *after*
injection): `SOCIAL_INSTAGRAM_COMMENTS_PROXY_PROVIDER` at
`trr_backend/socials/instagram/comments_scrapling/public_mode.py:19` and
`trr_backend/socials/instagram/public_probe.py:43`.

Repo conventions:
- ruff, py311, line length 120, double quotes (`TRR-Backend/ruff.toml`).
- Tests mirror source; the modal_jobs tests live in
  `TRR-Backend/tests/test_modal_jobs.py`, which already has env-management
  fixtures that snapshot/clear Modal-owner env vars via `monkeypatch`
  (e.g. `_clear_modal_owner_env` near the top of the file). Model your new
  env-mutation tests on that `monkeypatch`-based pattern — snapshot and restore
  `os.environ` so no test leaks env state.
- Domain vocabulary: this is the "Modal container boot → canonical runtime
  defaults" path; keep the existing comment style (the dict has extensive
  inline rationale comments — preserve them).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Import gate | `cd TRR-Backend && TRR_MODAL_RUNTIME_SCHEDULER_ENABLED=1 .venv/bin/python -c "import trr_backend.modal_jobs"` | exit 0, no output |
| Focused tests | `cd TRR-Backend && TRR_MODAL_RUNTIME_SCHEDULER_ENABLED=1 .venv/bin/python -m pytest tests/test_modal_jobs.py -q` | all pass |
| Lint | `cd TRR-Backend && ruff check trr_backend/modal_jobs.py tests/test_modal_jobs.py` | exit 0 |

> **Why `TRR_MODAL_RUNTIME_SCHEDULER_ENABLED=1` prefixes the import/test commands**:
> importing `trr_backend.modal_jobs` runs an import-time guard
> (`_validate_modal_maintenance_owner_config`) that raises `RuntimeError: Modal
> maintenance has no active owner` unless exactly one Modal-owner env var is set.
> This is unrelated to the change in this plan; setting
> `TRR_MODAL_RUNTIME_SCHEDULER_ENABLED=1` satisfies the guard for the import and
> test runs. Do NOT remove or alter this guard — it is out of scope.

## Scope

**In scope** (the only files you should modify):
- `TRR-Backend/trr_backend/modal_jobs.py`
- `TRR-Backend/tests/test_modal_jobs.py` (add tests)

**Out of scope** (do NOT touch):
- The DB-pool and `*_CONCURRENCY_LIMIT` / `SOCIAL_WORKER_POOL_*` values — they
  stay unconditionally pinned. Making them tunable requires the
  `comments_db_session_budget_status()` analysis and is a separate plan.
- The module-constant reads at `trr_backend/modal_jobs.py:110-120`
  (`_SOCIAL_CONCURRENCY_LIMIT` etc.) that feed the `@app.function` decorators —
  do not change how those are computed.
- Any read site under `trr_backend/socials/**`.
- `.env.example` and docs — a sibling plan (026-docs-half, if present) owns the
  `.env.example` annotation; do not edit env docs here.

## Git workflow

- Branch: `advisor/025-modal-runtime-injector-operator-overrides`
- Single logical commit; message style matches repo (`git -C TRR-Backend log
  --oneline -5` shows short imperative subjects, e.g. "harden backend admin
  social and show workflows").
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Split the canonical dict into pinned vs. operator-tunable

In `trr_backend/modal_jobs.py`, immediately after the
`_CANONICAL_MODAL_RUNTIME_DEFAULTS` dict definition (ends at the line with the
closing `}` around `:428`), add a frozen set naming exactly the operator-tunable
keys:

```python
# Operator-tunable subset of _CANONICAL_MODAL_RUNTIME_DEFAULTS. For these keys
# the canonical literal is a DEFAULT (applied via setdefault) so an operator can
# override it through the Modal secret or environment. Everything NOT in this set
# stays unconditionally pinned — in particular every DB-pool size and worker/
# container concurrency cap, which are Supavisor session-budget safety clamps
# (see comments_db_session_budget_status). Do not add a *_DB_POOL_*, *_CONCURRENCY_LIMIT,
# or SOCIAL_WORKER_POOL_* key here without the DB-session-budget analysis.
_OPERATOR_TUNABLE_RUNTIME_DEFAULT_KEYS: Final[frozenset[str]] = frozenset(
    {
        "SOCIAL_INSTAGRAM_COMMENTS_PROXY_PROVIDER",
        "SOCIALBLADE_PROXY_PROVIDER",
        "SOCIAL_THREADS_POSTS_PROXY_PROVIDER",
        "SOCIAL_INSTAGRAM_COMMENTS_COAUTHOR_GRAPHQL_PAGE_SIZE",
        "SOCIAL_INSTAGRAM_COMMENTS_COAUTHOR_GRAPHQL_CHILD_PAGE_SIZE",
    }
)
```

Do not move the keys out of the dict — they stay in `_CANONICAL_MODAL_RUNTIME_DEFAULTS`
so the canonical value is still the default. The set only marks which keys the
injector applies with `setdefault`.

**Verify**: `cd TRR-Backend && TRR_MODAL_RUNTIME_SCHEDULER_ENABLED=1 .venv/bin/python -c "import trr_backend.modal_jobs"` → exit 0.

### Step 2: Make the injector honor the tunable set

Change `_inject_modal_runtime_defaults` so tunable keys use `setdefault`
(operator/secret value wins) and all other keys keep the unconditional set:

```python
def _inject_modal_runtime_defaults() -> None:
    for key, value in _CANONICAL_MODAL_RUNTIME_DEFAULTS.items():
        if key in _OPERATOR_TUNABLE_RUNTIME_DEFAULT_KEYS:
            os.environ.setdefault(key, value)
        else:
            os.environ[key] = value
    if (os.getenv("OBJECT_STORAGE_ACCESS_KEY_ID") or "").strip() and (
        os.getenv("OBJECT_STORAGE_SECRET_ACCESS_KEY") or ""
    ).strip():
        os.environ.pop("OBJECT_STORAGE_PROFILE", None)
```

Note the semantics: `setdefault` only sets the key when it is **absent**. Modal
injects the deployment secret into `os.environ` before this module imports, so a
secret-provided value is present and wins. An operator who sets nothing still
gets the canonical default.

**Verify**: `cd TRR-Backend && TRR_MODAL_RUNTIME_SCHEDULER_ENABLED=1 .venv/bin/python -c "import trr_backend.modal_jobs"` → exit 0.

### Step 3: Add regression tests

In `tests/test_modal_jobs.py`, add tests that call
`modal_jobs._inject_modal_runtime_defaults()` under a controlled `os.environ`
and assert the two behaviors. Use the existing env-restoration fixture in this
file as the structural pattern (search the file for how it snapshots/restores
`os.environ`; do not leak env mutations across tests).

Cover exactly these cases:
1. **Tunable key: operator override wins.** Pre-set
   `os.environ["SOCIAL_INSTAGRAM_COMMENTS_PROXY_PROVIDER"] = "none"`, call the
   injector, assert the value is still `"none"` (not overwritten to `"decodo"`).
2. **Tunable key: default applies when unset.** Ensure
   `SOCIALBLADE_PROXY_PROVIDER` is absent, call the injector, assert it equals
   the canonical `"decodo"`.
3. **Safety key stays pinned.** Pre-set
   `os.environ["TRR_MODAL_SOCIAL_COMMENTS_JOB_CONCURRENCY_LIMIT"] = "999"`, call
   the injector, assert it is overwritten back to the canonical `"4"` (proves the
   DB-budget clamp cannot be loosened by env).
4. **Guard against silent drift:** assert every key in
   `_OPERATOR_TUNABLE_RUNTIME_DEFAULT_KEYS` is present in
   `_CANONICAL_MODAL_RUNTIME_DEFAULTS` (a tunable key that isn't in the dict is a
   bug).

**Verify**: `cd TRR-Backend && TRR_MODAL_RUNTIME_SCHEDULER_ENABLED=1 .venv/bin/python -m pytest tests/test_modal_jobs.py -q` → all pass, including the 4 new cases.

## Test plan

- New tests in `tests/test_modal_jobs.py` per Step 3, modeled on the existing
  env-snapshot fixture already in that file.
- Verification: `cd TRR-Backend && TRR_MODAL_RUNTIME_SCHEDULER_ENABLED=1 .venv/bin/python -m pytest tests/test_modal_jobs.py -q` → all pass.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd TRR-Backend && TRR_MODAL_RUNTIME_SCHEDULER_ENABLED=1 .venv/bin/python -c "import trr_backend.modal_jobs"` exits 0
- [ ] `cd TRR-Backend && TRR_MODAL_RUNTIME_SCHEDULER_ENABLED=1 .venv/bin/python -m pytest tests/test_modal_jobs.py -q` exits 0; the 4 new cases exist and pass
- [ ] `cd TRR-Backend && ruff check trr_backend/modal_jobs.py tests/test_modal_jobs.py` exits 0
- [ ] `grep -n "os.environ.setdefault" TRR-Backend/trr_backend/modal_jobs.py` shows the new setdefault branch
- [ ] No `TRR_*DB_POOL*`, `*CONCURRENCY_LIMIT`, or `SOCIAL_WORKER_POOL_*` key appears in `_OPERATOR_TUNABLE_RUNTIME_DEFAULT_KEYS` (`grep -A8 "_OPERATOR_TUNABLE_RUNTIME_DEFAULT_KEYS" TRR-Backend/trr_backend/modal_jobs.py`)
- [ ] No files outside the in-scope list are modified (`git -C TRR-Backend status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The live `_inject_modal_runtime_defaults` or `_CANONICAL_MODAL_RUNTIME_DEFAULTS`
  does not match the "Current state" excerpts (the file drifted).
- Any of the 5 tunable keys is **absent** from the live dict (the Step 3 case-4
  assertion would fail — report which key is missing rather than adding it).
- A test fails twice after a reasonable fix attempt.
- You discover a read site that captures one of the tunable keys into a
  module-level constant *before* `_inject_modal_runtime_defaults()` runs (that
  would make the override still ineffective — report it; do not try to re-order
  imports).

## Maintenance notes

- The pool/concurrency/container-cap knobs are intentionally left pinned. The
  real follow-up (making `SOCIAL_MODAL_DISPATCH_LIMIT`, the comments container
  cap, and worker-pool sizes operator-tunable within the Supavisor session
  budget) needs `comments_db_session_budget_status()` to be consulted at
  injection time — a distinct plan, higher risk.
- A reviewer should confirm the 5 tunable keys are genuinely non-DB-budget knobs
  and that no code path reads them into a pre-injection module constant.
- The `.env.example` half (annotating which keys are pinned vs. tunable) is
  tracked separately — see the ranked backlog item for DOC-02 in
  `plans/README.md`.
