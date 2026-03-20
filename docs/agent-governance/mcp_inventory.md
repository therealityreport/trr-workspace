# MCP Inventory (Codex Config)

Reusable MCP registrations live in `~/.codex/config.toml`. TRR-local MCPs live in `.codex/config.toml` and activate only when `/Users/thomashulihan/Projects/TRR` is trusted in the global config. If shared MCPs disappear in TRR, check the trusted-project entry first; this is a config activation issue, not a skill-routing issue.

| MCP Server | Config Owner | Invocation Guidance |
|---|---|---|
| `chrome-devtools` | trusted project-local `.codex/config.toml` | Browser navigation, inspection, and authenticated web automation in managed Chrome via the TRR wrapper. |
| `figma` | user-global `~/.codex/config.toml` | Official Figma cloud design context, screenshots, variables, and code connect. |
| `figma-console` | user-global `~/.codex/config.toml` | Figma Console MCP for write actions, Desktop Bridge workflows, plugin debugging, and live monitoring. |
| `figma-desktop` | user-global `~/.codex/config.toml` | Local desktop Figma workflows when enabled. |
| `github` | user-global `~/.codex/config.toml` | GitHub metadata and MCP-hosted remote operations with `GITHUB_PAT`. |
| `supabase` | trusted project-local `.codex/config.toml` | Supabase DB, schema, function, storage, and project operations for the TRR project only. |
