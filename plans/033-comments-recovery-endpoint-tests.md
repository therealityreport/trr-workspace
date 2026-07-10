# Plan 033: Add merge-blocking tests for the comments resume & auth-repair recovery endpoints

> **Executor instructions**: Follow step by step. Run every verification command
> before moving on. If a "STOP conditions" item occurs, stop and report. Update
> the `plans/README.md` status row when done unless a reviewer maintains it.
> This plan adds tests only — it changes no product code.
>
> **Drift check (run first)**:
> `git -C TRR-Backend diff --stat -- api/routers/socials/__init__.py`
> Also confirm the endpoints still exist:
> `grep -n "comments/runs/{run_id}/resume\|comments/runs/{run_id}/repair-auth" TRR-Backend/api/routers/socials/__init__.py`
> The nested `TRR-Backend` tree is authoritative and dirty. On mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: tests
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-08 — working tree authoritative
- **Repo**: TRR-Backend

## Why this matters

The Instagram comments **recovery** path — resume a stalled run, and repair its
auth (which can trigger a real cookie refresh) — is exercised by **zero tests**
anywhere in the suite. These are exactly the endpoints an operator hits when a
comment run stalls, and the repair-auth endpoint fires a fire-and-forget
`background_tasks.add_task(execute_social_account_comments_run_auth_repair, ...)`
that can burn/refresh cookies. A regression here silently breaks recovery or
mis-fires a cookie refresh with no test signal at any gate. This plan adds tests
in the **blocking** `tests/api` lane so a regression fails at merge.

## Current state

`api/routers/socials/__init__.py` — two handlers (line numbers drift; grep):

1. `post_social_account_comments_run_resume_route` (POST
   `/profiles/{platform}/{account_handle}/comments/runs/{run_id}/resume`):

   ```python
   from trr_backend.socials.pipelines.comments.instagram import resume_social_account_comments_run
   try:
       result = resume_social_account_comments_run(
           platform=platform, account_handle=account_handle,
           run_id=str(run_id), initiated_by=(user or {}).get("email"),
       )
       _clear_account_profile_caches()
       return result
   except SocialIngestConflictError as exc:
       raise HTTPException(status_code=409, detail={"code": exc.code, ...}) from exc
   except SocialIngestValidationError as exc:
       status_code = 503 if exc.code == "SOCIAL_INSTAGRAM_COMMENTS_AUTH_REPAIR_FAILED" else 400
       raise HTTPException(status_code=status_code, detail={"code": exc.code, "message": str(exc)}) from exc
   except SocialWorkerUnavailableError as exc:
       raise HTTPException(status_code=503, detail={...}) from exc
   ```

2. `post_social_account_comments_run_repair_auth_route` (POST
   `.../comments/runs/{run_id}/repair-auth`):

   ```python
   from trr_backend.socials.pipelines.comments.instagram import (
       execute_social_account_comments_run_auth_repair,
       request_social_account_comments_run_auth_repair,
   )
   try:
       _require_instagram_auth_refresh_confirmation(platform, payload.operator_confirmation)
       result = request_social_account_comments_run_auth_repair(
           platform=platform, account_handle=account_handle,
           run_id=str(run_id), initiated_by=(user or {}).get("email"),
       )
       background_tasks.add_task(
           execute_social_account_comments_run_auth_repair,
           platform=platform, account_handle=account_handle, ...
       )
       ...
   ```

The exemplar for FastAPI socials router tests (auth-override fixture, patching
pipeline functions, asserting kwargs) is
`tests/api/routers/test_socials_season_analytics.py` — it already patches
`start_social_account_comments_authenticated_followup` and
`rebalance_slow_instagram_comments_shards`, so the mocking pattern for these
pipeline functions is established there.

Repo conventions: pytest, tests mirror source. `tests/api` is the ONLY
merge-blocking lane (`.github/workflows/ci.yml`), which is why the new tests go
there.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Confirm endpoints | `grep -n "comments/runs/{run_id}/resume\|repair-auth" TRR-Backend/api/routers/socials/__init__.py` | 2 route decorators |
| Confirm no prior coverage | `grep -rn "resume_social_account_comments_run\|request_social_account_comments_run_auth_repair" TRR-Backend/tests/` | empty (if not, STOP) |
| Run new tests | `cd TRR-Backend && .venv/bin/python -m pytest tests/api/routers/test_socials_comments_recovery.py -q` | all pass |
| Lint | `cd TRR-Backend && ruff check tests/api/routers/test_socials_comments_recovery.py` | exit 0 |

## Scope

**In scope**:
- `TRR-Backend/tests/api/routers/test_socials_comments_recovery.py` (create).

**Out of scope**:
- Any product code. If a test reveals a real bug, STOP and report it — do not fix
  it in this plan.
- The pipeline functions themselves (mock them; do not test their internals here).

## Steps

### Step 1: Test the resume route branch matrix

In a new `tests/api/routers/test_socials_comments_recovery.py`, using the FastAPI
test client + auth override from the existing socials router tests, patch
`trr_backend.socials.pipelines.comments.instagram.resume_social_account_comments_run`
and assert:
1. **Happy path**: returns 200 and forwards `platform`, `account_handle`,
   `run_id`, and `initiated_by=<user email>` exactly.
2. **Conflict**: patched to raise `SocialIngestConflictError` → response 409 with
   `detail["code"]` equal to the error's code.
3. **Auth-repair-failed validation → 503**: patched to raise
   `SocialIngestValidationError(code="SOCIAL_INSTAGRAM_COMMENTS_AUTH_REPAIR_FAILED")`
   → response **503** (this is the branch that is easy to regress to 400).
4. **Other validation → 400**: patched to raise `SocialIngestValidationError`
   with a different code → response 400.

### Step 2: Test the repair-auth route (background task + confirmation gate)

Patch `request_social_account_comments_run_auth_repair` and
`execute_social_account_comments_run_auth_repair`, and assert:
1. **Missing/invalid operator confirmation** → the request is rejected by
   `_require_instagram_auth_refresh_confirmation` (assert the status it returns;
   inspect that helper to get the exact code) and **no** background task is
   scheduled and `request_...auth_repair` is **not** called.
2. **Valid confirmation** → `request_...auth_repair` is called with the right
   kwargs, and a background task is scheduled to run
   `execute_social_account_comments_run_auth_repair` with the matching
   `platform`/`account_handle`/`run_id` (assert via FastAPI's
   `BackgroundTasks`—either inspect the scheduled task or patch
   `BackgroundTasks.add_task` and assert its call args, whichever the existing
   tests do).

**Verify**: `cd TRR-Backend && .venv/bin/python -m pytest tests/api/routers/test_socials_comments_recovery.py -q` → all pass.

## Test plan

- New `tests/api/routers/test_socials_comments_recovery.py` covering the resume
  branch matrix (4 cases) and the repair-auth confirmation-gate + background-task
  scheduling (2 cases).
- Verification: focused test command above → all pass; the file lives in the
  blocking lane.

## Done criteria

- [ ] `cd TRR-Backend && .venv/bin/python -m pytest tests/api/routers/test_socials_comments_recovery.py -q` passes with the 6 cases
- [ ] The 503-vs-400 resume branch is asserted both ways
- [ ] The repair-auth confirmation gate is asserted to block the background task
      when confirmation is absent
- [ ] `ruff check tests/api/routers/test_socials_comments_recovery.py` exits 0
- [ ] No product files modified (`git -C TRR-Backend status` shows only the new test)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:

- The endpoints or their exception branches do not match the "Current state"
  excerpts.
- Prior coverage already exists (the confirm-no-coverage grep returns hits).
- A test surfaces a real defect in the handlers (report it as a finding; do not
  fix here).
- The auth-override/test-client fixture in the existing socials tests can't be
  reused (report what's blocking rather than inventing a new auth bypass).

## Maintenance notes

- This is one instance of a broader gate-placement gap (TEST-01/02/06 in the
  backlog): several critical scrape/budget paths are covered only in the
  non-blocking full lane. Promoting a curated subset into `tests/api` (or adding a
  second required CI job) is the umbrella follow-up.
- A reviewer should confirm the background-task assertion actually proves the
  task was scheduled (not just that the route returned 200).
