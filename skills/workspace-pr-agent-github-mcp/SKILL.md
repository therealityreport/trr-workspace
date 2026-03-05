---
name: workspace-pr-agent-github-mcp
description: Run the TRR workspace PR automation agent in GitHub MCP-first mode (one PR per repo, wait checks, process bot reviews/messages, revise, merge, sync main, and local branch cleanup).
---

# Workspace PR Agent (GitHub MCP)

## When to use
Use this skill when the user wants the workspace PR automation flow and specifically wants GitHub MCP involved in review/check analysis during revision cycles.

## Command
```bash
WORKSPACE_PR_AGENT_REVISION_USE_GITHUB_MCP=1 \
WORKSPACE_PR_AGENT_REVISION_REQUIRE_GITHUB_MCP=1 \
make workspace-pr-agent
```

Dry run:
```bash
WORKSPACE_PR_AGENT_DRY_RUN=1 make workspace-pr-agent
```

## Behavior
- Core PR orchestration still runs through the workspace orchestrator script.
- Revision callbacks run through `scripts/workspace-pr-agent-revision.py`.
- Codex revision assist is prompted to use GitHub MCP (not `gh` CLI) for PR/review/check context.
- If `WORKSPACE_PR_AGENT_REVISION_REQUIRE_GITHUB_MCP=1` and `GITHUB_PAT` is missing, revision assist fails fast.

## Env toggles
- `WORKSPACE_PR_AGENT_REVISION_USE_GITHUB_MCP=1|0`
- `WORKSPACE_PR_AGENT_REVISION_REQUIRE_GITHUB_MCP=1|0`
- `WORKSPACE_PR_AGENT_REVISION_USE_CODEX=1|0`
- `WORKSPACE_PR_AGENT_REVISION_COMMAND=none` to disable revision command entirely

## Notes
- This skill is MCP-first for revision intelligence, with local context fallback when MCP is not required.
- One PR per repo and final sync/cleanup constraints are enforced by the orchestrator.
