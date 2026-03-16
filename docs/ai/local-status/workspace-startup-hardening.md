# Workspace startup hardening

Last updated: 2026-03-16

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-16
  current_phase: "complete"
  next_action: "Monitor only; make dev now prunes broken Next cache automatically and policy preflight no longer deep-scans dependency trees"
  detail: self
```

- `scripts/dev-workspace.sh` now prunes broken Next.js cache state automatically during startup.
- Policy preflight no longer deep-scans dependency trees unnecessarily.
