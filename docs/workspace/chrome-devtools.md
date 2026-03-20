# Managed Chrome and Chrome DevTools MCP

`chrome-devtools` is the browser automation path for workspace browser tasks. Codex inherits the default shared keeper from `~/.codex/config.toml`; the TRR wrapper is opt-in for isolated/debug use.

This document describes browser policy only. Actual MCP defaults live in `~/.codex/config.toml` for Codex and in `~/.claude.json` for Claude.

## Default Behavior
- Default mode for Codex automation is the shared headless keeper on `9422`.
- Claude can use the shared `9422` keeper through `chrome-devtools` or `chrome-devtools-codex-shared`, and the visible/manual `9222` keeper through `chrome-devtools-visible`.
- Reuse the current page instead of spawning tabs.
- Keep one working tab by default and stay under the three-tab cap.
- Do not use ad-hoc browsers for chat-driven browsing.
- The long-lived shared browsers on `9222` and `9422` are managed keepers, not leak signals by themselves.
- The repo-local TRR wrapper is opt-in for isolated/debug scenarios, not the default browser path.

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
Detached Chrome survives by design. The global wrapper launches Chrome with `nohup`, so a browser can outlive the shell that started it. That is intentional for the managed shared keepers on `9222` and `9422`, but it becomes a leak when an isolated browser is detached without matching session state.

`figma-console` had the same problem in a different form. The launcher was a bare `exec npx ...` path with no managed wrapper metadata, no pidfile, and no reaper integration, so old chat-owned trees could reparent to PID 1 and stay alive long after the original chat was gone.

The visible-browser owner file was also tracking the wrapper PID instead of the browser PID. That meant a stale wrapper could make a perfectly healthy shared browser on `9222` look conflicted, while an actual dead browser could be misread as an ownership problem instead of a lifecycle problem.

### Automatic prevention
`make dev` now runs the session reaper on startup, cleaning orphaned Chrome from prior sessions before spawning new ones. If you notice overheating or stale Chrome between `make dev` restarts, run `make mcp-clean` manually.

Use the status command to separate keepers from leaks:
- `9222` is the managed shared headful keeper for visible/manual work.
- `9422` is the managed shared headless keeper for system-wide browser automation.
- `stale-wrapper` means the wrapper died but the browser is still present.
- `stale-browser` means the wrapper metadata exists but the browser itself is gone.
- `bash scripts/mcp-clean.sh --soak` prints pre/post pressure snapshots while repeatedly exercising the cleanup path.
- `Pressure snapshot` and `Pressure verdict` are the two lines to compare across soak runs.

### Random Chrome windows
If Chrome opens randomly while idle, run `make chrome-devtools-mcp-status` first and check for competing non-Codex browser-control clients before restarting anything.
