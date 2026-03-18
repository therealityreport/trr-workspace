# Chrome MCP Isolated Tab Cap

Last updated: 2026-03-16

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-16
  current_phase: "workspace Chrome isolated default + tab-cap enforcement"
  next_action: "Restart active Codex chats so they pick up the isolated headful default and verify per-session tab trimming in a fresh chat"
  detail: self
```

## Status
- Workspace-level Chrome policy and wrapper behavior now default to isolated headful sessions with a per-chat tab cap.

## What changed
- Switched the repo-managed Codex Chrome MCP default from `shared + headful` to `isolated + headful`.
- Added isolated-session tab-cap enforcement in the Chrome wrapper path:
  - target: `1` working tab
  - hard cap: `3` tabs per isolated chat/session
  - trims older disposable tabs first
- Added a dedicated isolated-session tab manager script for watch/trim operations.
- Updated workspace policy in `/Users/thomashulihan/Projects/TRR/AGENTS.md` to make the one-tab target and three-tab cap explicit for all future chats.
- Hardened `scripts/codex-config-sync.sh` so validation/install can find a Python interpreter with `tomllib` support without requiring a manual PATH override.

## Validation
- Pending fresh-chat verification:
  - `make chrome-devtools-mcp-status` should report `isolated` as the effective default mode.
  - a fresh Codex chat should expose `chrome-devtools` with isolated headful Chrome and session-local tab counts.
- Manual operational cleanup of already-open shared chats is best-effort only; those chats still need a restart to adopt the new default.

## Notes
- Shared Chrome remains supported as an explicit override, but hard per-chat tab enforcement applies only to isolated sessions.
- Existing already-open chats cannot retroactively switch their MCP/browser binding; restart is expected.
