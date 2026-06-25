# Managed Chrome and Chrome DevTools MCP

`chrome-devtools` is the browser automation path for workspace browser tasks. Codex inherits the default shared headless configuration from `~/.codex/config.toml`; explicit isolated/debug launches are exceptions. The active global wrapper seeds managed Chrome sessions from `~/.chrome-profiles/openai-agent` by default. This managed clone is not the real Codex Chrome profile.

This document describes browser policy only. Actual MCP defaults live in `~/.codex/config.toml` for Codex and in `~/.claude.json` for Claude.

For profile-specific live Chrome work, use the selection rules in `docs/workspace/browser-debug.md`. In short: choose the explicit `TRR` Chrome extension instance for normal TRR/admin work, choose the real Codex profile only when requested, and warn if Chrome attaches to a profile that is not the last-used profile.

## Chrome Profile Identity
Codex and Claude Code agents in the TRR Workspace use the `openai-agent` managed clone for routine browser automation. The real Codex Chrome profile means the saved Chrome profile signed in as `codex@thereality.report` and should be used when the user explicitly asks for the Codex profile. The admin@thereality.report profile (`~/.chrome-profiles/claude-agent`) is reserved for user-authorized tasks only — for example, accessing paywalled sites like NYTimes where the owner's subscription is required. If a site is inaccessible under the routine managed clone, stop and ask the user before switching. Set `CHROME_AGENT_ADMIN_OVERRIDE=1` when the user grants permission; return to the managed clone when the authorized task is complete.

The managed `openai-agent` Chrome user-data directory may contain multiple Chrome subprofiles. Managed launches must pass the detected inner `--profile-directory` in addition to `--user-data-dir`.

Profile 11 admin examples (`TRR` friendly profile, admin account):

```bash
export CODEX_CHROME_PREFERENCES_PATH="/Users/thomashulihan/Library/Application Support/Google/Chrome/Profile 11/Preferences"
```

That preferences path selects the saved admin profile for profile-aware Codex tooling. The managed Chrome launcher uses `CHROME_AGENT_*` variables, so pass the admin managed clone explicitly when a task is approved for the admin profile.

Run the standard repair/status path with the admin managed clone:

```bash
CODEX_CHROME_PREFERENCES_PATH="/Users/thomashulihan/Library/Application Support/Google/Chrome/Profile 11/Preferences" \
CHROME_AGENT_ADMIN_OVERRIDE=1 \
CHROME_AGENT_PROFILE_DIR="$HOME/.chrome-profiles/claude-agent" \
CHROME_AGENT_PROFILE_EMAIL=admin@thereality.report \
CODEX_CHROME_SHARED_PORT=9222 \
  make chrome-repair
```

Start only the visible admin Chrome keeper:

```bash
CHROME_AGENT_ADMIN_OVERRIDE=1 \
CHROME_AGENT_PROFILE_DIR="$HOME/.chrome-profiles/claude-agent" \
CHROME_AGENT_PROFILE_EMAIL=admin@thereality.report \
CHROME_AGENT_DEBUG_PORT=9222 \
CHROME_AGENT_HEADLESS=0 \
scripts/ensure-managed-chrome.sh
```

**Exception:** Claude in Chrome (the Claude desktop app's browser automation) is permitted to use the admin@thereality.report profile. This restriction applies only to Codex and Claude Code agents running within the TRR Workspace context.

## Default Behavior
- Default mode for Codex automation is shared headless, with the shared keeper auto-launched when needed.
- Claude can use the shared `9422` keeper through `chrome-devtools` or `chrome-devtools-codex-shared`, and the visible/manual `9222` keeper through `chrome-devtools-visible`.
- Reuse the current page instead of spawning tabs.
- Keep one working tab by default and stay under the three-tab cap.
- Do not use ad-hoc browsers for chat-driven browsing.
- The long-lived shared browsers on `9222` and `9422` remain managed keepers for exception paths, not leak signals by themselves.
- The repo-local TRR wrapper is opt-in for isolated/debug scenarios, not the default browser path.

## Fallback When MCP Is Unavailable
The canonical path is still a working `chrome-devtools` MCP session. Some Codex threads, however, may not expose that transport even when the managed Chrome runtime is healthy. When that happens:

- Keep browser work on the managed Chrome path.
- Use the workspace scripts instead of changing tracked MCP config:
  - `make chrome-repair` to clean stale browser MCP state, start shared Chrome, check extension/native-host readiness, and print the reload hint
  - `scripts/ensure-managed-chrome.sh` to guarantee a managed browser exists
  - `scripts/open-or-refresh-browser-tab.sh` to reuse or reload the current workspace tab
  - `scripts/chrome-devtools-mcp-status.sh` and `scripts/codex-mcp-session-reaper.sh` for diagnostics and cleanup
- Prefer reusing the existing tab and explicitly reloading it when the test requires reload behavior.
- Do not add a repo-tracked fallback browser MCP block as a workaround for one broken session.

This fallback is for live verification only. Browser defaults still belong in wrapper scripts and user-level config, not in prompt prose or repo-local MCP drift.

## Useful Overrides
- Use isolated headful for visible debugging.
- Use shared headful only when shared auth or state is truly required.
- Restart the session after changing managed-Chrome mode.
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
3. Restart the Codex session or thread if tool calls still use the stale transport.
4. Rerun `make chrome-devtools-mcp-status` in the new session.

Do not keep retrying scraper, app, or Instagram workflows while the already-loaded MCP transport is stale. Do not add a repo-local fallback MCP block for one stale chat.

### Viewport/window resize guardrail

Window-bounds resize actions (`resize_page` / `resize_window` / `preview_resize`) must target the **headful** keeper on port `9222`, never the **headless** keeper on `9422`. The headless keeper has no real OS window, so a window-bounds reset waits for a state change that never lands and hits the fixed per-call timeout. Only issue a resize when the active page is idle.

A timed-out resize-reset is a stale-transport signal. Run `make codex-browser-transport-reset` once and **do not retry**; restart the session or thread if the next call still uses the stale transport. As an alternative to resizing, drive against the headful `9222` keeper or skip the resize and use full-page `take_screenshot`.

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
