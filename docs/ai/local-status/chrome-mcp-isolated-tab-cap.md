# Chrome MCP Isolated Tab Cap

Last updated: 2026-03-24

## Handoff Snapshot
```yaml
handoff:
  include: false
  state: archived
  last_updated: 2026-03-24
  current_phase: "archived continuity note"
  next_action: "See newer workspace Chrome status notes if this policy needs follow-up"
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
- Archived from active handoff rotation on 2026-03-24 so workspace policy checks stop treating this completed rollout as a fresh continuity item.
