# Codex Config Realignment

Last updated: 2026-03-18

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-18
  current_phase: "workspace Codex config split aligned with trusted-project activation and dual-Figma MCP support"
  next_action: "Restart any older Codex chats, then verify global MCPs load everywhere, including figma-console, and TRR-local MCPs load only inside the trusted TRR workspace"
  detail: self
```

## Status
- TRR now uses a split Codex config model: reusable MCPs live in `~/.codex/config.toml`, while TRR-only defaults and MCPs live in the tracked project-local `.codex/config.toml`.

## What changed
- Kept the tracked `.codex/config.toml` as the TRR-local source of truth for workspace defaults, `chrome-devtools`, and `supabase`.
- Restored reusable MCP registrations in `~/.codex/config.toml` for `figma`, `figma-console`, `figma-desktop`, `github`, and disabled-by-default `playwright`.
- Added a Keychain-backed `figma-console` launcher so the Figma Console PAT stays out of tracked files and plaintext user config.
- Added the trusted-project entry for `/Users/thomashulihan/Projects/TRR` to `~/.codex/config.toml` so Codex activates the TRR-local config only inside this workspace.
- Added `.codex/rules/default.rules` to guard destructive git commands and high-blast-radius Codex admin actions during full-auto sessions.
- Repurposed `scripts/codex-config-sync.sh` from user-config templating into:
  - `bootstrap` for restoring the expected global MCP set plus the TRR trusted-project entry in `~/.codex`
  - `validate` for both the global user config and the tracked TRR-local config
- Updated workspace policy/docs so `AGENTS.md` describes browser and trust policy, while `.codex/config.toml` and wrapper scripts define actual Chrome MCP defaults.
- Aligned the shared Chrome default back to `isolated + headless` and removed the shared-mode drift from validation/status output.
- Added `scripts/check-codex.sh` and `make codex-check` so workspace validation covers the global/project config split, trusted-project activation, rules parsing, and user bootstrap state.
- Removed the AWS MCP family from both the global and project config surfaces.

## Validation
- `bash scripts/codex-config-sync.sh bootstrap`
- `bash scripts/codex-config-sync.sh validate`
- `(cd ~ && codex mcp list --json)`
- `(cd ~ && codex mcp get figma-console)`
- `(cd /Users/thomashulihan/Projects/TRR && codex mcp list --json)`
- `make codex-check`
- `make check-policy`

## Notes
- Existing chats may still reflect older MCP registrations until they are restarted.
- If TRR-local MCPs disappear from a fresh session inside this workspace, check the trusted-project entry in `~/.codex/config.toml` before debugging skills or prompts.
- Shared/headful Chrome remains available as an explicit exception path; the tracked default is isolated/headless.
