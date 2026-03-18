# Chrome MCP Wrapper Rollback

Last updated: 2026-03-16

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-16
  current_phase: "complete"
  next_action: "Monitor only; make dev preflight now survives stale isolated Chrome session cleanup and only prints summary OK after the wrapper smoke check passes"
  detail: self
```

## Status
- Workspace-level rollback complete.

## What changed
- Restored Codex live config at `/Users/thomashulihan/.codex/config.toml` to the canonical Chrome wrapper:
  - `scripts/codex-chrome-devtools-mcp.sh`
- Restored Claude MCP config at `/Users/thomashulihan/.claude.json` away from the singleton wrapper.
- Kept the singleton script in-repo, but marked it as a non-default manual experiment helper rather than the supported runtime entrypoint.
- Updated `scripts/chrome-devtools-mcp-status.sh` so it reports the supported wrapper readiness directly instead of echoing the misleading raw `codex mcp list` auth column.
- Renamed the wrapper logger in `scripts/codex-chrome-devtools-mcp.sh` to `chrome_mcp_log()` so stale-session cleanup cannot ever fall through to macOS `/usr/bin/log` during wrapper bootstrap.
- Delayed summary-mode success output in `scripts/chrome-devtools-mcp-status.sh` until after the wrapper smoke check succeeds, so preflight no longer prints an `OK` line before a downstream wrapper failure.

## Validation
- Passed: `bash -n scripts/mcp-browser-singleton.sh scripts/chrome-devtools-mcp-status.sh scripts/codex-chrome-devtools-mcp.sh scripts/codex-config-sync.sh`
- Passed: `bash scripts/codex-config-sync.sh validate`
- Passed: `make chrome-devtools-mcp-status`
  - shared `9222` reachable
  - supported wrapper path reported
  - conflict risk `0`
  - smoke check passed
- Passed: `CODEX_CHROME_SKIP_BROWSER_BOOT=1 bash scripts/codex-chrome-devtools-mcp.sh --version`
  - with a fabricated stale `codex-chrome-session-9397.env` pointing at dead wrapper pid `999999`
  - orphan cleanup logged through the wrapper logger and the wrapper still exited `0`
- Passed: `make preflight`
  - browser automation summary output now appears only after the wrapper smoke check completes successfully
- Passed: `make dev`
  - advanced beyond preflight, launched TRR-APP/TRR-Backend/screenalytics, and reached healthy local endpoints before controlled shutdown via `make stop`

## Notes
- This fixes runtime/config drift and cross-session singleton preemption on the supported path.
- A fresh Codex session/thread is still required before an already-open chat can gain the `chrome-devtools` tool binding.
- The original `make dev` failure mode was triggered by stale isolated-session metadata under `.logs/workspace/codex-chrome-session-*.env`.
