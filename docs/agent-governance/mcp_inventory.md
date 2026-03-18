# MCP Inventory (Codex Config)

Remote MCP servers are bridged via `scripts/codex-mcp-http-bridge.sh` (stdio→HTTP via `mcp-remote`) because Codex CLI 0.98.x has a broken Streamable HTTP transport. Remove the bridge when Codex ships a fix. Track: https://github.com/openai/codex/issues/11284

| MCP Server | Config Type | Invocation Guidance |
|---|---|---|
| `chrome-devtools` | `command` (stdio) | Browser navigation/inspection and authenticated web automation in managed Chrome. Enabled for all chats in this workspace and documented as a mandatory always-on capability. |
| `figma` | `command` (bridged) | Figma cloud design context, screenshots, variables, code connect. Bridged from `https://mcp.figma.com/mcp`. |
| `figma-desktop` | `command` (bridged) | Local desktop Figma workflows when enabled. Bridged from `http://127.0.0.1:3845/mcp`. |
| `github` | `command` (bridged) | GitHub metadata and MCP-hosted remote operations. Bridged from `https://api.githubcopilot.com/mcp` with `GITHUB_PAT`. |
| `supabase` | `command` (bridged) | Supabase DB/schema/functions/storage/log operations. Bridged from `https://mcp.supabase.com/mcp` with `SUPABASE_ACCESS_TOKEN`. |
