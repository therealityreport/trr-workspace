# Legacy Playwright Artifact Note

Workspace policy is Chrome DevTools MCP only for browser automation.

If `.playwright-mcp/` exists in the workspace, treat it as a local legacy artifact and not a policy source.

Removal guidance:
1. Confirm no active scripts or local workflows depend on `.playwright-mcp/`.
2. Remove the directory if unused.
3. Re-run `make check-policy` and `make preflight`.
