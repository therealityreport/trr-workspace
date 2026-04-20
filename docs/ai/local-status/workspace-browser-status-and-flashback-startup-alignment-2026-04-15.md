# Workspace Browser Status And Flashback Startup Alignment

Last updated: 2026-04-15

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-04-15
  current_phase: "implementation complete"
  next_action: "Use the new structured browser readiness output when adjusting workspace startup warnings or Chrome diagnostics."
  detail: self
```

## Summary

- Removed the stale `make dev` startup attention about missing Flashback browser envs.
- Workspace startup now treats Flashback gameplay as intentionally disabled: `/flashback`, `/flashback/cover`, and `/flashback/play` redirect to `/hub`, so those browser envs are not part of the normal startup contract.
- `scripts/chrome-devtools-mcp-status.sh` now exposes a structured readiness path and `scripts/preflight.sh` consumes that instead of scraping human warning text.
- Browser automation attention is now derived from explicit states: `ready`, `degraded`, `recoverable`, and `unavailable`.

## Contract changes

- `degraded` means browser automation still works and startup should only suggest `make mcp-clean`.
- `recoverable` means the shared `9422` keeper is stopped but the shared launcher can still auto-launch it; startup should not present this as an unavailable runtime.
- `unavailable` is reserved for cases where the shared runtime cannot be reached and no usable recovery path remains.

## Validation

- `python3.11 -m pytest -q scripts/test_workspace_terminal.py scripts/test_chrome_devtools_status.py`
- `bash -n scripts/preflight.sh scripts/dev-workspace.sh scripts/chrome-devtools-mcp-status.sh scripts/workspace-env-contract.sh`

## Notes

- `make preflight` now asks the status script for structured output, so future wording tweaks in the human summary path should not silently change startup attention behavior.
