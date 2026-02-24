# Session Handoff (TRR Workspace)

Purpose: persistent state for multi-turn AI agent sessions affecting workspace-level tooling (`make dev` / `make stop`).

## 2026-02-24 (Codex) — admin-host local defaults + tab-refresh collision hardening
- Updated `/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh`:
  - now injects TRR-APP admin host defaults into the launched `next dev` process when unset:
    - `ADMIN_APP_ORIGIN=http://admin.localhost:3000`
    - `ADMIN_APP_HOSTS=admin.localhost,localhost,127.0.0.1,[::1]`
    - `ADMIN_ENFORCE_HOST=true`
    - `ADMIN_STRICT_HOST_ROUTING=false`
  - persists the above values in pidfile metadata.
  - startup URL output now includes canonical admin URL line:
    - `TRR-APP Admin: http://admin.localhost:3000`
- Updated `/Users/thomashulihan/Projects/TRR/scripts/open-or-refresh-browser-tab.sh`:
  - removed broad localhost-family wildcard matching on port `3000`.
  - refresh matching is now limited to:
    - exact target URL/prefix, plus
    - explicit localhost/127 alias pair only.
  - prevents unrelated admin/public localhost tabs from being force-refreshed together.
- Validation executed:
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh` (pass)
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/open-or-refresh-browser-tab.sh` (pass)

## 2026-02-24 (Codex) — runtime hardening pass (endpoint override, health tuning, log archive, compose/runtime polish)
- Updated `/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh`:
  - `SCREENALYTICS_API_URL` now honors env override (default remains local `http://127.0.0.1:${SCREENALYTICS_API_PORT}`),
  - local screenalytics process uses local API base while backend/app receive resolved target URL,
  - health checks now use configurable env vars:
    - `WORKSPACE_HEALTH_CURL_MAX_TIME`
    - `WORKSPACE_HEALTH_TIMEOUT_BACKEND`
    - `WORKSPACE_HEALTH_TIMEOUT_APP`
    - `WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_API`
    - `WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_STREAMLIT`
    - `WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_WEB`,
  - local screenalytics API health checks use local URL explicitly (`SCREENALYTICS_LOCAL_HEALTH_URL`),
  - workspace logs are now archived per run under `.logs/workspace/archive/<timestamp>/` before fresh log files are created.
- Updated `/Users/thomashulihan/Projects/TRR/scripts/open-workspace-dev-window.sh`:
  - if tab-refresh helper fails, script now falls back to default browser open for the target URL.
- Updated `/Users/thomashulihan/Projects/TRR/scripts/status-workspace.sh`:
  - reports screenalytics as `disabled` when `WORKSPACE_SCREENALYTICS=0`,
  - health output now reports `starting/unhealthy` when PID is alive but endpoint is not healthy yet.
- Updated `/Users/thomashulihan/Projects/TRR/scripts/bootstrap.sh`:
  - Python resolution now supports `PYTHON_BIN`, then `python3.11`, `python3`, `python`,
  - enforces Python `>=3.11` on resolved interpreter.
- Updated `/Users/thomashulihan/Projects/TRR/scripts/down-screenalytics-infra.sh`:
  - compose down now includes `--remove-orphans`.
- Updated `/Users/thomashulihan/Projects/TRR/screenalytics/scripts/dev_auto.sh`:
  - default API port changed to `8001` (aligned with workspace),
  - new `SCREENALYTICS_DOCKER_FORCE_RECREATE` flag gates `--force-recreate` on compose up.
- Updated `/Users/thomashulihan/Projects/TRR/AGENTS.md` and `/Users/thomashulihan/Projects/TRR/CLAUDE.md`:
  - documented endpoint override, health-tuning vars, log archive behavior, and `SCREENALYTICS_DOCKER_FORCE_RECREATE`.
- Validation executed:
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh` (pass)
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/open-workspace-dev-window.sh` (pass)
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/status-workspace.sh` (pass)
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/bootstrap.sh` (pass)
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/down-screenalytics-infra.sh` (pass)
  - `bash -n /Users/thomashulihan/Projects/TRR/screenalytics/scripts/dev_auto.sh` (pass)
  - `SCREENALYTICS_API_URL=https://example.invalid WORKSPACE_SCREENALYTICS=0 make -C /Users/thomashulihan/Projects/TRR -n dev` (pass)
  - `make -C /Users/thomashulihan/Projects/TRR status` (pass; app showed `starting/unhealthy` while startup warmed)
  - `WORKSPACE_SCREENALYTICS=0 bash /Users/thomashulihan/Projects/TRR/scripts/status-workspace.sh` with pidfile temporarily moved aside (pass; screenalytics showed `disabled`)
  - `PYTHON_BIN=/bin/echo bash /Users/thomashulihan/Projects/TRR/scripts/bootstrap.sh` (expected fail; exit `1` with Python version error)
  - `PATH=/usr/bin:/bin bash /Users/thomashulihan/Projects/TRR/scripts/down-screenalytics-infra.sh` (pass; graceful no-op)

## 2026-02-24 (Codex) — workspace reliability additions (`make status`, doctor fallback, graceful `make down`)
- Added `/Users/thomashulihan/Projects/TRR/scripts/status-workspace.sh`:
  - reports workspace mode flags from pidfile when available,
  - reports process states for `TRR_APP`, `TRR_BACKEND`, and `SCREENALYTICS`,
  - reports listeners for `3000/8000/8001/8501/8080` (or pidfile overrides),
  - performs best-effort health checks for backend/app/screenalytics API,
  - always exits `0` (informational status command).
- Updated `/Users/thomashulihan/Projects/TRR/Makefile`:
  - added `status` target and `.PHONY` entry (`make status`).
- Updated `/Users/thomashulihan/Projects/TRR/scripts/doctor.sh`:
  - Python interpreter resolution now supports `PYTHON_BIN`, then `python3.11`, `python3`, `python`,
  - enforces Python version `>=3.11` on the resolved interpreter,
  - prints selected Python binary path and version.
- Updated `/Users/thomashulihan/Projects/TRR/scripts/down-screenalytics-infra.sh`:
  - no-op exit when Docker CLI is missing,
  - no-op exit when Docker daemon is not running.
- Updated `/Users/thomashulihan/Projects/TRR/AGENTS.md` and `/Users/thomashulihan/Projects/TRR/CLAUDE.md`:
  - documented `make status`, graceful `make down`, and doctor Python fallback behavior.
- Validation executed:
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/status-workspace.sh` (pass)
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/doctor.sh` (pass)
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/down-screenalytics-infra.sh` (pass)
  - `make -C /Users/thomashulihan/Projects/TRR -n status` (pass)
  - `make -C /Users/thomashulihan/Projects/TRR status` (pass)
  - `PYTHON_BIN=/no/such/python make -C /Users/thomashulihan/Projects/TRR doctor` (warned + fell back, pass)

## 2026-02-24 (Codex) — workspace run UX hardening (cache default, dev modes, browser toggle)
- Updated `/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh`:
  - changed `WORKSPACE_CLEAN_NEXT_CACHE` default from `1` to `0` (cache reuse by default),
  - added `WORKSPACE_OPEN_BROWSER` toggle (default `1`) to gate tab sync/open behavior,
  - persisted `WORKSPACE_OPEN_BROWSER` in workspace pidfile metadata,
  - guarded tab sync call so `WORKSPACE_OPEN_BROWSER=0` skips browser automation.
- Updated `/Users/thomashulihan/Projects/TRR/Makefile`:
  - added `dev-lite`, `dev-cloud`, and `dev-full` targets,
  - expanded usage comments with startup tuning examples (`WORKSPACE_CLEAN_NEXT_CACHE`, `WORKSPACE_OPEN_BROWSER`).
- Updated `/Users/thomashulihan/Projects/TRR/AGENTS.md` and `/Users/thomashulihan/Projects/TRR/CLAUDE.md`:
  - documented new run-mode targets and startup tuning toggles.
- Validation executed:
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh` (pass)
  - `make -C /Users/thomashulihan/Projects/TRR -n dev-lite` (pass)
  - `make -C /Users/thomashulihan/Projects/TRR -n dev-cloud` (pass)
  - `make -C /Users/thomashulihan/Projects/TRR -n dev-full` (pass)

## 2026-02-19 (Codex) — fresh `make dev` browser window orchestration
- Added `scripts/open-workspace-dev-window.sh` to enforce workspace browser behavior:
  - closes existing tabs only for configured TRR-APP and screenalytics Web origins (exact host+port match, path-agnostic),
  - opens a brand-new browser window with fresh tabs for TRR-APP and optional screenalytics Web.
- Updated `scripts/dev-workspace.sh`:
  - disables nested screenalytics browser opens via `DEV_AUTO_OPEN_BROWSER=0` when launched from workspace,
  - replaces single-tab TRR-APP open call with `open-workspace-dev-window.sh`,
  - opens TRR-APP + screenalytics Web (`:8080`) in one fresh window when screenalytics is enabled.

## Changes In This Session (2026-02-09)

- `scripts/dev-workspace.sh`
  - Safe-stale port preflight/cleanup to prevent orphaned processes from blocking ports.
  - macOS-friendly process-group isolation (python `setsid()` fallback when `setsid` is unavailable) so stop can kill full trees.
  - `WORKSPACE_SCREENALYTICS` / `WORKSPACE_STRICT` toggles so `make dev` can keep TRR-Backend + TRR-APP running even if screenalytics fails.
  - Startup health checks so printed URLs reflect actual service readiness.
  - Starts screenalytics via `bash ./scripts/dev_auto.sh` and passes `DEV_AUTO_ALLOW_DB_ERROR=1` by default when `WORKSPACE_STRICT=0` so screenalytics doesn't exit if the DB is unreachable.

- `scripts/stop-workspace.sh`
  - Stops by process group when possible, with recursive descendant-kill fallback.
  - Safe-stale cleanup by port when no pidfile exists.

## How To Run

From `/Users/thomashulihan/Projects/TRR`:

```bash
make stop
make dev
```

## Useful Env Vars

- `WORKSPACE_SCREENALYTICS=0` to skip screenalytics entirely.
- `WORKSPACE_STRICT=1` to fail fast if screenalytics can’t start / docker isn’t available.
- `WORKSPACE_FORCE_KILL_PORT_CONFLICTS=1` to forcibly clear port conflicts (kills all listeners on those ports).

---

Last updated: 2026-02-24
Updated by: Codex (GPT-5)

## 2026-02-17 (Codex) — `make dev` one-tab browser behavior
- Added `/Users/thomashulihan/Projects/TRR/scripts/open-or-refresh-browser-tab.sh` to reuse existing browser tabs for service URLs.
- Wired `scripts/dev-workspace.sh` to open/refresh `TRR-APP` at `http://127.0.0.1:${TRR_APP_PORT}` on each `make dev`.
- Replaced hardcoded `open` calls in `screenalytics/scripts/dev_auto.sh` so Streamlit/Web tabs are reused when present.
- Behavior now prefers Chrome → Safari tab reuse and falls back to opening a new tab if those automation paths are unavailable.


## 2026-02-12 (Codex) — New planning docs added
- Added image optimization implementation plan:
  - `/Users/thomashulihan/Projects/TRR/docs/plans/2026-02-12-image-storage-optimization-plan.md`
- Added admin UX/product suggestions document (10 concrete proposals):
  - `/Users/thomashulihan/Projects/TRR/docs/plans/2026-02-12-admin-page-suggestions.md`

## 2026-02-12 (Codex) — Plan docs finalized
- Finalized both plan docs with implementation status sections and closed checklist items:
  - `/Users/thomashulihan/Projects/TRR/docs/plans/2026-02-12-image-storage-optimization-plan.md`
  - `/Users/thomashulihan/Projects/TRR/docs/plans/2026-02-12-admin-page-suggestions.md`

## 2026-02-12 (Codex) — `make dev` stability fix
- File: `/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh`
- Fixed shutdown crash:
  - handled sparse `PIDS/NAMES` arrays safely in `cleanup()` to prevent `NAMES[$i]: unbound variable`.
  - hardened process-monitor loop against unset/sparse indices.
  - added idempotent cleanup guard to avoid double shutdown output.
- Reduced intermittent Next route-cache startup failures:
  - added `WORKSPACE_CLEAN_NEXT_CACHE` (default `1`) and clear `TRR-APP/apps/web/.next` before starting `next dev`.
  - mitigates stale app-router cache mismatches (e.g. dynamic slug-name conflict after route renames).
