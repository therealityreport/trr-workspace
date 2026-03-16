# Workspace Modal social throughput controls

Last updated: 2026-03-16

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-16
  current_phase: "complete"
  next_action: "Use the new workspace Modal social knobs when tuning backlog fanout and verify queue behavior under load"
  detail: self
```

- Added explicit workspace tuning knobs for Modal social dispatch limit and Modal social job concurrency.
- Clarified that `WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS` remains an enable/disable flag, not a worker count.
- Updated workspace startup and status output to report Modal social lane state, dispatch limit, max concurrency, and stage caps.
- Wired workspace runtime values into backend Modal dispatch envs and added targeted backend tests for dispatch limit, stage caps, and Modal concurrency.
