# Workspace startup hardening

Last updated: 2026-03-24

## Handoff Snapshot
```yaml
handoff:
  include: false
  state: archived
  last_updated: 2026-03-24
  current_phase: "archived continuity note"
  next_action: "See newer workspace startup notes if follow-up is needed"
  detail: self
```

- `scripts/dev-workspace.sh` now prunes broken Next.js cache state automatically during startup.
- Policy preflight no longer deep-scans dependency trees unnecessarily.
