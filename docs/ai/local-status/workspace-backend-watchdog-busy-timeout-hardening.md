# Workspace Backend Watchdog Busy-Timeout Hardening

Last updated: 2026-03-30

## Handoff Snapshot
```yaml
handoff:
  include: false
  state: archived
  last_updated: 2026-03-30
  current_phase: "archived continuity note"
  next_action: "Refer to newer status notes if follow-up work resumes on this thread."
  detail: self
```

## Summary

- Investigated the Reddit admin page stall that surfaced as `Loading reddit communities...` during `make dev`.
- Root cause was the workspace backend watchdog, not the Reddit communities API route itself.
- Under active local traffic, `/health` curl probes could time out with `rc=28`, and the watchdog still escalated those busy timeouts into backend restarts even when `WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_IGNORE=1`.
- Fixed the watchdog so active-traffic busy timeouts now log warnings and suppress auto-restart instead of contributing to a forced recycle loop.

## Evidence

- App route logs showed repeated successful community loads from `TRR-APP/apps/web/src/app/api/admin/reddit/communities/route.ts` while the backend was stable.
- Workspace logs showed repeated restart cycles triggered by:
  - `TRR-Backend health probe timed out with active connections`
  - followed by `Restarting TRR-Backend after repeated health failures...`
- Live smoke after the patch kept the workspace stable with `restart_count: 0`.

## Files Changed

- `scripts/dev-workspace.sh`
  - Busy-timeout ignore mode now suppresses restart escalation under active connections.
- `scripts/workspace-env-contract.sh`
  - Added explicit descriptions for backend watchdog variables.
- `docs/workspace/env-contract.md`
  - Regenerated after contract-description updates.
- `Makefile`
  - Updated startup comment to reflect that backend auto-restart is enabled by the default profile and can be disabled explicitly.

## Validation

- `bash -n /Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh`
- `bash /Users/thomashulihan/Projects/TRR/scripts/workspace-env-contract.sh --generate`
- Live smoke:
  - `make dev`
  - `make status`
  - repeated local `curl` probes against `http://127.0.0.1:8000/health`
  - repeated local probes against `http://127.0.0.1:3000/api/admin/reddit/communities?include_assigned_threads=0`

## Result

- The workspace now stays up under the default cloud-backed profile instead of thrashing the backend during active traffic.
- The Reddit admin community screen should no longer get stranded behind watchdog-induced backend restarts during startup/bootstrap.
