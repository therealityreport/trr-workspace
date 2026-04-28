# MCP Inventory (Workspace)

Reusable MCP registrations live in `~/.codex/config.toml`. TRR-local MCPs live in `.codex/config.toml` and activate only when `/Users/thomashulihan/Projects/TRR` is trusted in the global config. User-level and system-level MCPs are inherited by default in TRR; the project-local config only adds TRR-specific defaults and servers. If shared MCPs disappear in TRR, check the trusted-project entry first; this is a config activation issue, not a skill-routing issue.

| MCP Server | Config Owner | Invocation Guidance |
|---|---|---|
| `chrome-devtools` | user-global `~/.codex/config.toml` | Browser navigation, inspection, and authenticated web automation. Default is isolated headless; shared/headful are opt-in exceptions. |
| `figma` | user-global `~/.codex/config.toml` | Official Figma cloud design context, screenshots, variables, and code connect. |
| `figma-desktop` | user-global `~/.codex/config.toml` | Local desktop Figma workflows when enabled. |
| `github` | user-global `~/.codex/config.toml` | GitHub metadata and MCP-hosted remote operations with `GITHUB_PAT`. |
| `context7` | user-global `~/.codex/config.toml` | Library and framework documentation lookup for implementation and review flows. |
| `supabase` | trusted project-local `.codex/config.toml` | Supabase DB, schema, function, storage, and project operations for the TRR project only. Uses `TRR_SUPABASE_ACCESS_TOKEN`, not the generic `SUPABASE_ACCESS_TOKEN`. |

Project-scoped custom agents under `.codex/agents/` may declare narrower MCP surfaces for their own runs. Those agent-local overrides do not replace the user-global or project-global MCP inventory; they narrow access for the spawned agent. The same inheritance rule applies to user-global plugins and skills: TRR routing may prefer local canonicals, but it must not suppress unrelated user-owned capabilities.

If Supabase MCP returns `MCP error -32600`, run `make supabase-mcp-access`. A `403` means the active TRR token cannot access project `vwxfvzutyufrkhfgoeaa`; replace `TRR_SUPABASE_ACCESS_TOKEN` with a Supabase personal access token from the account or org that can access TRR core, then restart Codex.
