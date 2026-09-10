# Managed Chrome and Chrome DevTools MCP

## Browser policy and profile identity

- The workspace `AGENTS.md` owns browser choices and account bindings. Use any suitable supported browser tool; follow its current setup documentation.
- Use the friendly `TRR` profile for account-specific TRR work, or `codex` when explicitly requested. Verify identity before first account-specific use and after a profile switch, reconnection, or evidence of an account change.
- The historical `openai-agent` managed clone is not the user's `TRR` or `codex` profile. Do not substitute it for an account-specific request.
- `CODEX_CHROME_PREFERENCES_PATH` is a saved-window recovery hint; it does not select or verify a live connection.
- Follow `docs/workspace/browser-debug.md` for profile selection. A matching requested profile need not be Chrome's last-used profile.
- If a browser tool is unavailable, use another suitable supported tool with the same verified identity. Pause only account-dependent work when identity is missing or ambiguous.

## Optional managed-browser workflow

The remainder of this guide describes the repository's managed Chrome keepers and repair scripts. It is operational reference for that selected workflow, not a required setup, fallback, or cleanup procedure for every browser task. Check live configuration and script behavior before relying on historical defaults. Codex settings live in `~/.codex/config.toml`; Claude settings are separate.

- Reuse relevant tabs where practical and avoid unnecessary browser launches.
- Ports `9222` and `9422` identify managed keepers, not proof of the requested account. Verify identity separately before account-specific actions.
- Inspect status before repair. Read the relevant script before running cleanup or reset operations, preserve active sessions and unrelated work, and follow existing authorization and recoverable-cleanup requirements.
- A broken session does not require adding a repo-tracked fallback MCP configuration. Use another suitable tool when available.

## Useful Overrides
- Use isolated headful for visible debugging.
- Use shared headful only when shared auth or state is truly required.
- Reconnect if a managed-Chrome mode change requires it, then reverify identity. Restart an active app or task only within existing authorization.
- Use `CODEX_CHROME_SKIP_BROWSER_BOOT=1` only for wrapper diagnostics that must not launch Chrome.

## Cleanup and Troubleshooting

### Quick fixes
- `make chrome-repair` — one-command repair for stale MCP state, shared Chrome startup, status, extension readiness, and the MCP reload hint
- `make mcp-clean` — kill stale wrapper trees and clean artifacts
- `make chrome-devtools-mcp-status` — inspect current session state
- `make chrome-devtools-mcp-stop-conflicts` — detect non-Codex browser-control clients

### DevTools stale transport

If `make chrome-repair` reports a healthy shared Chrome runtime but an already-open Codex chat still gets `Transport closed` from `chrome-devtools`, treat it as stale session transport state.

Recovery:
1. Keep the shared Chrome keeper running.
2. Run `make codex-browser-transport-reset` once.
3. Use another suitable available tool if transport remains stale. If a task reload is still required, report that limitation and follow existing restart authorization.
4. Rerun `make chrome-devtools-mcp-status` in the new session.

Do not keep retrying scraper, app, or Instagram workflows while the already-loaded MCP transport is stale. Do not add a repo-local fallback MCP block for one stale chat.

### Viewport/window resize guardrail

Window-bounds resize actions (`resize_page` / `resize_window` / `preview_resize`) must target the **headful** keeper on port `9222`, never the **headless** keeper on `9422`. The headless keeper has no real OS window, so a window-bounds reset waits for a state change that never lands and hits the fixed per-call timeout. Only issue a resize when the active page is idle.

A timed-out resize-reset may indicate a headless-window mismatch or stale transport. Inspect the target and error before applying the stale-transport recovery above; do not retry blindly. As an alternative to resizing, drive against the headful `9222` keeper or skip the resize and use full-page `take_screenshot`.

## Chrome Dock Recents

TRR browser automation can launch `/Applications/Google Chrome.app` for managed Chrome sessions. On macOS, repeated launches can leave duplicate Google Chrome icons in the Dock recent-apps area even when the managed browser process was stopped correctly.

Use this command to remove only Google Chrome entries from Dock recents while preserving pinned Dock apps and unrelated recent apps:

```bash
make chrome-dock-clean
```

For explicit MCP cleanup runs where Dock recents should be cleaned at the same time, opt in with:

```bash
CHROME_AGENT_CLEAN_DOCK_RECENTS=1 make mcp-clean
```

The cleanup is macOS-only and removes only `com.google.Chrome` entries from the Dock `recent-apps` list.

### Readiness states
The status script and workspace preflight now classify browser automation with the same four states:

- `ready` — browser automation is usable and pressure is normal
- `degraded` — browser automation is usable, but local Chrome pressure or stale metadata suggests cleanup may help
- `recoverable` — the shared `9422` keeper is currently stopped, but the shared launcher can still auto-launch Chrome on demand
- `unavailable` — the shared keeper is down and there is no usable recovery path for the current startup contract

Only the `unavailable` state should surface the stronger “shared Chrome is not responding” startup attention. `degraded` remains a cleanup suggestion, and `recoverable` is informational.

Structured status also reports Chrome extension/native-host readiness and `orphaned_chrome_mcp_processes`. Startup attention is recorded when orphaned Chrome MCP process buildup reaches the configured threshold.

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
- `9222` is the managed shared headful keeper for visible/manual work. Do not confuse it with the real Codex Chrome profile.
- `9422` is the managed shared headless keeper for system-wide browser automation.
- `stale-wrapper` means the wrapper died but the browser is still present.
- `stale-browser` means the wrapper metadata exists but the browser itself is gone.
- `bash scripts/mcp-clean.sh --soak` prints pre/post pressure snapshots while repeatedly exercising the cleanup path.
- `Pressure snapshot` and `Pressure verdict` are the two lines to compare across soak runs.
- A missing `9422` listener is only an `unavailable` condition when the shared launcher cannot recover it for fresh sessions. Otherwise the status is `recoverable`.

### Random Chrome windows
If Chrome opens randomly while idle, run `make chrome-devtools-mcp-status` first and check for competing non-Codex browser-control clients before restarting anything.
