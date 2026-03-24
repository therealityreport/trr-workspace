# Workspace make dev backend reload default

Last updated: 2026-03-22

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-22
  current_phase: "workspace dev default now uses backend reload mode"
  next_action: "Start a fresh make dev session to pick up the new default"
  detail: self
```

- Changed the workspace `make dev` baseline so TRR-Backend starts in reload mode by default instead of non-reload mode.
- `TRR-APP` was already running through `next dev`, so UI changes continue to refresh without restarting.
- The old behavior is still available with `TRR_BACKEND_RELOAD=0 make dev`.
- Validation:
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh`
