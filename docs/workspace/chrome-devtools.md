# Managed Chrome and Chrome DevTools MCP

`chrome-devtools` is the required browser automation path for workspace browser tasks. Codex uses `scripts/codex-chrome-devtools-mcp.sh`.

## Default Behavior
- Default mode is isolated and headless.
- Each chat gets its own managed Chrome instance.
- Reuse the current page instead of spawning tabs.
- Keep one working tab by default and stay under the three-tab cap.
- Do not use ad-hoc browsers for chat-driven browsing.

## Useful Overrides
- Use isolated headful for visible debugging.
- Use shared headful only when shared auth or state is truly required.
- Restart the session after changing managed-Chrome mode.
- Use `CODEX_CHROME_SKIP_BROWSER_BOOT=1` only for wrapper diagnostics that must not launch Chrome.

## Cleanup and Troubleshooting

### Quick fixes
- `make mcp-clean` — kill stale wrapper trees and clean artifacts
- `make chrome-devtools-mcp-status` — inspect current session state
- `make chrome-devtools-mcp-stop-conflicts` — detect non-Codex browser-control clients

### Deep cleanup
- `bash scripts/codex-mcp-session-reaper.sh diagnose` — full snapshot of all Chrome/MCP state
- `bash scripts/codex-mcp-session-reaper.sh reap` — aggressive orphan kill + artifact purge

### Why zombies accumulate
The wrapper (`codex-chrome-devtools-mcp.sh`) uses a bash `trap EXIT` to kill Chrome when a session ends. But if Codex kills the wrapper with SIGKILL or the parent terminal dies, the trap never fires. Chrome gets reparented to PID 1 and lives forever. The orphan watchdog runs inside the wrapper, so it dies with the wrapper.

### Automatic prevention
`make dev` now runs the session reaper on startup, cleaning orphaned Chrome from prior sessions before spawning new ones. If you notice overheating or stale Chrome between `make dev` restarts, run `make mcp-clean` manually.

### Random Chrome windows
If Chrome opens randomly while idle, run `make chrome-devtools-mcp-status` first and check for competing non-Codex browser-control clients before restarting anything.
