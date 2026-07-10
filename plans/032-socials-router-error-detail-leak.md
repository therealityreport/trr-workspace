# Plan 032: Stop leaking raw exception text from socials-router 500/502 responses

> **Executor instructions**: Follow step by step. Run every verification command
> before moving on. If a "STOP conditions" item occurs, stop and report. Update
> the `plans/README.md` status row when done unless a reviewer maintains it.
>
> **Drift check (run first)**:
> `git -C TRR-Backend diff --stat -- api/routers/socials/__init__.py`
> The nested `TRR-Backend` tree is authoritative and dirty. This router is
> ~9.4k lines; do NOT read it whole — use the grep commands below. Confirm the
> pattern before editing. On mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-08 — working tree authoritative
- **Repo**: TRR-Backend

## Why this matters

The socials router raises `HTTPException(status_code=500, detail=str(exc))` (and
one `status_code=502`) at many handlers. `str(exc)` on an internal error can be a
DB driver message, an internal hostname, a filesystem path, or — on the
SocialBlade refresh 502, whose upstream path runs through the Decodo proxy —
upstream URL/host detail. Even behind admin auth, returning raw internal
exception text in API responses is unnecessary internal-detail disclosure and
makes a stable error contract impossible. This plan routes those internal-error
responses through one helper that logs the full exception server-side and returns
a fixed, non-reflective message. Domain-validation `400` responses that already
return a sanitized `{"code","message"}` dict are intentionally left alone.

## Current state

`api/routers/socials/__init__.py` has ~80 `detail=str(exc)` occurrences. The
in-scope subset is the internal-error ones:

```python
        raise HTTPException(status_code=500, detail=str(exc)) from exc
```

and the single 502:

```python
        raise HTTPException(status_code=502, detail=str(exc)) from exc
```

Representative 500 sites (line numbers drift — rely on grep, not these):
3750, 4035, 4140, 4265, 4317, 4404, 4431, 4493, 6001, 7372, 7386, 7441, 7500,
7536, 7556, 7571, 7592, … The 502 site is around 4750.

Several handlers already log before raising (e.g. `logger.exception(...)` near
the SocialBlade 502). The module has a module-level `logger` (confirm:
`grep -n "^logger = \|logger = logging" api/routers/socials/__init__.py`).

Repo conventions: ruff py311, line 120, double quotes. FastAPI routers under
`api/routers/`. The router-shape golden test is
`tests/api/routers/test_socials_route_shape.py`; behavioral socials tests are in
`tests/api/routers/test_socials_season_analytics.py` (blocking lane).

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Count 500/502 leaks | `grep -nE 'status_code=(500\|502), detail=str\(exc\)' TRR-Backend/api/routers/socials/__init__.py \| wc -l` | the count to fix (record it) |
| Confirm none remain (after) | `grep -nE 'status_code=(500\|502), detail=str\(exc\)' TRR-Backend/api/routers/socials/__init__.py` | no matches |
| Import gate | `cd TRR-Backend && .venv/bin/python -c "import api.main"` | exit 0 |
| Blocking lane | `cd TRR-Backend && .venv/bin/python -m pytest tests/api/routers/test_socials_error_detail.py tests/api/routers/test_socials_route_shape.py -q` | all pass |
| Lint | `cd TRR-Backend && ruff check api/routers/socials/__init__.py tests/api/routers/test_socials_error_detail.py` | exit 0 |

## Scope

**In scope**:
- `TRR-Backend/api/routers/socials/__init__.py` — only `status_code=500` and
  `status_code=502` handlers currently using `detail=str(exc)`, plus one helper.
- `TRR-Backend/tests/api/routers/test_socials_error_detail.py` (create).

**Out of scope** (do NOT touch):
- `status_code=400` / `404` / `409` / `503` handlers — many return sanitized
  `{"code","message"}` dicts or user-actionable validation text. Changing them
  risks breaking clients that read the code/message contract.
- Any handler logic other than the raise line.
- The route shape / signatures (the golden shape test must stay green).

## Steps

### Step 1: Add one internal-error helper

Near the top of the module (after `logger` is defined), add:

```python
def _internal_error_response(exc: Exception, *, status_code: int = 500) -> HTTPException:
    """Log the full exception server-side; return a non-reflective client error.

    Never surface raw internal exception text (DB/driver messages, hostnames,
    proxy/upstream detail) to clients. Callers do `raise _internal_error_response(exc) from exc`.
    """
    logger.exception("socials_router_internal_error status_code=%s", status_code)
    message = "Upstream request failed." if status_code == 502 else "Internal server error."
    return HTTPException(status_code=status_code, detail={"code": "INTERNAL_ERROR", "message": message})
```

**Verify**: `cd TRR-Backend && .venv/bin/python -c "import api.main"` → exit 0.

### Step 2: Replace the 500/502 leak sites

Replace every `raise HTTPException(status_code=500, detail=str(exc)) from exc`
with `raise _internal_error_response(exc) from exc`, and the single
`status_code=502` one with `raise _internal_error_response(exc, status_code=502) from exc`.

Do this mechanically for each site the grep in "Commands" lists. Do not touch any
handler where an existing `logger.exception`/`logger.error` call would now double
-log — if a site already logs the exception immediately above the raise, you may
leave that existing log (the helper's log is harmless) or remove the now-redundant
local log; note which you did.

**Verify**: `grep -nE 'status_code=(500|502), detail=str\(exc\)' TRR-Backend/api/routers/socials/__init__.py` → no matches.

### Step 3: Test

Create `tests/api/routers/test_socials_error_detail.py`. Using the FastAPI test
client pattern already used in `tests/api/routers/test_socials_season_analytics.py`:
1. Patch one in-scope handler's underlying function to raise an exception whose
   message contains a sentinel like `"INTERNAL-DB-SECRET-a1b2"`.
2. Call the endpoint; assert the response status is 500 and the response body
   does **not** contain the sentinel (proves the raw text is not reflected).
3. Assert the body carries the stable `{"code": "INTERNAL_ERROR"}` shape.

Pick an endpoint whose function is easy to patch (e.g. one behind a repository
call). If the auth dependency blocks the client, reuse the auth-override fixture
that the existing socials router tests use.

**Verify**: `cd TRR-Backend && .venv/bin/python -m pytest tests/api/routers/test_socials_error_detail.py -q` → all pass.

## Test plan

- New `tests/api/routers/test_socials_error_detail.py` — the no-sentinel-leak
  assertion is mandatory. Placed in the blocking `tests/api` lane so a regression
  fails at merge.
- Also run the golden shape test to prove no route signature changed.

## Done criteria

- [ ] `cd TRR-Backend && .venv/bin/python -c "import api.main"` exits 0
- [ ] `grep -nE 'status_code=(500|502), detail=str\(exc\)' TRR-Backend/api/routers/socials/__init__.py` → no matches
- [ ] `_internal_error_response` exists and is used at every former 500/502 leak site
- [ ] `cd TRR-Backend && .venv/bin/python -m pytest tests/api/routers/test_socials_error_detail.py tests/api/routers/test_socials_route_shape.py -q` passes
- [ ] `ruff check ...` exits 0
- [ ] No 400/404/409/503 handlers changed (`git -C TRR-Backend diff` shows only 500/502 lines + helper + test)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:

- The 500/502 pattern differs from `detail=str(exc)` at some sites (e.g. already
  wrapped) — fix only the ones that match; report the rest.
- Changing a site would alter a response the golden shape test asserts (it should
  not — status/detail body is not part of the shape test; if it is, STOP).
- A 500 site is actually re-raising a *sanitized* domain error — leave it; report.
- A test fails twice after a reasonable fix attempt.

## Maintenance notes

- Follow-up (backlog): audit `HTTPException(detail=f"...{e}")` string-interpolation
  sites elsewhere (e.g. `api/routers/surveys.py:315` is public-facing) with the
  same helper.
- A reviewer should confirm no client (the admin app) parses the old raw `detail`
  string for these 500s; the new shape is `{"code","message"}`.
