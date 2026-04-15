# Workspace Make Dev Startup Hardening

Last updated: 2026-04-14

## Handoff Snapshot
```yaml
handoff:
  include: false
  state: recent
  last_updated: 2026-04-14
  current_phase: "implementation complete"
  next_action: "Fix any remaining malformed handoff source notes separately if a clean handoff-check baseline is required."
  detail: self
```

## Summary

- Default local `make preflight` / `make dev` now warns and continues when handoff sync fails because a canonical source note is malformed.
- `make preflight-strict` and `make handoff-check` still fail on malformed handoff notes.
- The workspace backend watchdog now uses backend liveness (`/health/live`) for restart decisions while startup readiness and status reporting keep using the DB-aware readiness signal (`/health`).
- `make status` now exposes backend readiness and liveness separately.

## Validation

- `python3.11 -m pytest -q scripts/test_preflight_handoff_policy.py scripts/test_workspace_health.py scripts/test_sync_handoffs.py`
- `cd TRR-Backend && pytest -q tests/api/test_health.py`
- `bash -n scripts/preflight.sh`
- `bash -n scripts/dev-workspace.sh`
- `bash -n scripts/status-workspace.sh`
- `bash -n scripts/check-policy.sh`
- `make preflight`
- `make preflight-strict`
- `make handoff-check`

## Notes

- The workspace still contains a pre-existing malformed canonical status note at `docs/ai/local-status/trr-app-debate-speaking-time-fidelity-pass-2026-04-13.md` with `state: completed`. That file intentionally remains the blocking case for strict handoff validation.
