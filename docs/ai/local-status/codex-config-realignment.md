# Codex Config Realignment

Last updated: 2026-04-21

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-04-21
  current_phase: "workspace Codex config split remains the active baseline with inherited user/global skills preserved while plugin state stays user-managed"
  next_action: "Keep the split user/project Codex config model in place and avoid repo-managed skill disablement in ~/.codex; only reopen this lane if bootstrap or validation regresses"
  detail: self
```

## Status
- TRR now uses a split Codex config model: reusable MCPs live in `~/.codex/config.toml`, while TRR-only defaults and MCPs live in the tracked project-local `.codex/config.toml`.

## What changed
- Kept the tracked `.codex/config.toml` as the TRR-local source of truth for workspace defaults, `chrome-devtools`, and `supabase`.
- Restored reusable MCP registrations in `~/.codex/config.toml` for `figma`, `figma-desktop`, `github`, and disabled-by-default `playwright`.
- Added the trusted-project entry for `/Users/thomashulihan/Projects/TRR` to `~/.codex/config.toml` so Codex activates the TRR-local config only inside this workspace.
- Added `.codex/rules/default.rules` to guard destructive git commands and high-blast-radius Codex admin actions during full-auto sessions.
- Repurposed `scripts/codex-config-sync.sh` from user-config templating into:
  - `bootstrap` for restoring the expected global MCP set plus the TRR trusted-project entry in `~/.codex`
  - `validate` for both the global user config and the tracked TRR-local config
- Keep user/global skill inheritance intact; bootstrap and validation should not inject or require repo-managed disabled skill rows in `~/.codex/config.toml`.
- Removed plugin-state enforcement from the user bootstrap and validation paths so user-level plugin choices no longer fail TRR preflight.
- Updated workspace policy/docs so `AGENTS.md` describes browser and trust policy, while `.codex/config.toml` and wrapper scripts define actual Chrome MCP defaults.
- Kept the global Chrome default aligned on `shared + headless + auto-launch` so bootstrap, validation, and the tracked TRR comments all describe the same launcher behavior.
- Added `scripts/check-codex.sh` and `make codex-check` so workspace validation covers the global/project config split, trusted-project activation, rules parsing, and user bootstrap state.
- Removed the AWS MCP family from both the global and project config surfaces.

## Validation
- `bash scripts/codex-config-sync.sh bootstrap`
- `bash scripts/codex-config-sync.sh validate`
- `bash scripts/check-policy.sh`
- `(cd ~ && codex mcp list --json)`
- `(cd /Users/thomashulihan/Projects/TRR && codex mcp list --json)`
- `make codex-check`
- `make check-policy`

## Notes
- 2026-04-21 follow-up:
  - removed stale TRR-managed disabled-skill enforcement from the user bootstrap/validation path so workspace preflight aligns with the current global-inheritance policy
- 2026-04-02 follow-up:
  - user plugin enablement is now left untouched by `scripts/codex-config-sync.sh`; bootstrap and validation no longer require specific plugin states
- 2026-04-01 follow-up:
  - `figma-console` is no longer part of the active expected global MCP baseline for TRR
- Existing chats may still reflect older MCP registrations until they are restarted.
- If TRR-local MCPs disappear from a fresh session inside this workspace, check the trusted-project entry in `~/.codex/config.toml` before debugging skills or prompts.
- Shared/headful Chrome remains available as an explicit exception path; the tracked default is isolated/headless.
