# Session Handoff (TRR Workspace)

Purpose: persistent state for multi-turn AI agent sessions affecting workspace-level tooling (`make dev` / `make stop`).

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

Last updated: 2026-02-09
Updated by: Codex

