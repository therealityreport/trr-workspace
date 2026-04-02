# Figma Console dual-MCP rollout

Last updated: 2026-03-26

## Handoff Snapshot
```yaml
handoff:
  include: false
  state: archived
  last_updated: 2026-03-26
  current_phase: "complete"
  next_action: "None"
  detail: self
```

## Status
- Complete.
- Historical only. `figma-console` is no longer part of the active expected MCP baseline for TRR.

## What changed
- Added a new user-global `figma-console` MCP registration alongside the existing `figma` and `figma-desktop` servers.
- Added a Keychain-backed launcher at `/Users/thomashulihan/Projects/TRR/scripts/codex-figma-console-mcp.sh` so the Figma Console PAT is resolved from macOS Keychain service `codex-figma-console` or, if needed, inherited `FIGMA_ACCESS_TOKEN`.
- Updated the global bootstrap and validation flow so `figma-console` was part of the expected global MCP set at the time of rollout.
- Upgraded the global `figma` skill and related aliases to treat official Figma MCP and `figma-console` as complementary tools with explicit capability routing.
- Updated the relevant TRR MCP inventory and skill-governance docs to document the dual-Figma workflow.

## Validation
- Passed: `bash scripts/codex-config-sync.sh bootstrap`
- Passed: `bash scripts/codex-config-sync.sh validate`
- Passed: `bash scripts/check-codex.sh`
- Passed: `codex mcp list --json`
- Passed: `codex mcp get figma-console`
- Passed: missing-secret wrapper smoke test with an invalid Keychain service override
- Passed: direct `figma-console` launcher smoke test using the Keychain-backed token path

## Notes
- 2026-03-26:
  - archived from the active handoff surface; keep this file as historical context only
- The PAT was added to macOS Keychain service `codex-figma-console` for the current macOS user.
- The PAT was pasted into chat history before setup, so it should be rotated after confirming the new MCP path is working.
