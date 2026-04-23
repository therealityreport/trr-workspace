---
name: workspace-pr-agent-github-mcp
description: Run the TRR workspace PR automation agent in GitHub MCP + Vercel mode (auto-discover workspace repo + child repos, keep one PR per repo, wait for checks and deployments, process bot reviews/messages, revise, merge, sync main, and clean local branches).
---

# Workspace PR Agent (GitHub MCP + Vercel)

## When to use
Use this skill when the user wants the full workspace PR automation flow and specifically wants GitHub MCP for PR/review/check context plus Vercel deployment context for app-facing repos.

## Command
```bash
WORKSPACE_PR_AGENT_REVISION_USE_GITHUB_MCP=1 \
WORKSPACE_PR_AGENT_REVISION_REQUIRE_GITHUB_MCP=1 \
WORKSPACE_PR_AGENT_REVISION_USE_VERCEL_MCP=1 \
make workspace-pr-agent
```

Dry run:
```bash
WORKSPACE_PR_AGENT_DRY_RUN=1 \
WORKSPACE_PR_AGENT_REVISION_USE_GITHUB_MCP=1 \
WORKSPACE_PR_AGENT_REVISION_USE_VERCEL_MCP=1 \
make workspace-pr-agent
```

Limit scope explicitly:
```bash
WORKSPACE_PR_AGENT_REPOS='TRR-Backend,TRR-APP' make workspace-pr-agent
```

## Behavior
- The wrapper auto-discovers the workspace root repo plus child repos when `WORKSPACE_PR_AGENT_REPOS` is unset.
- Core PR orchestration runs through the workspace orchestrator script.
- Revision callbacks run through `scripts/workspace-pr-agent-revision.py`.
- Codex revision assist is prompted to use GitHub MCP (not `gh` CLI) for PR/review/check context and Vercel tools for preview/build/deployment context when app repos are involved.
- One active PR is reused per repo; follow-up fixes are pushed to the same PR branch.
- The orchestrator waits for checks, processes bot feedback, resolves base-branch conflicts, merges to `main`, syncs local `main` to `origin/main`, and removes non-`main` local branches.
- If `WORKSPACE_PR_AGENT_REVISION_REQUIRE_GITHUB_MCP=1` and `GITHUB_PAT` is missing, revision assist fails fast.

## Env toggles
- `WORKSPACE_PR_AGENT_REPOS='<comma-separated repos>'` to override auto-discovery
- `WORKSPACE_PR_AGENT_REVISION_USE_GITHUB_MCP=1|0`
- `WORKSPACE_PR_AGENT_REVISION_REQUIRE_GITHUB_MCP=1|0`
- `WORKSPACE_PR_AGENT_REVISION_USE_VERCEL_MCP=1|0`
- `WORKSPACE_PR_AGENT_REVISION_USE_CODEX=1|0`
- `WORKSPACE_PR_AGENT_REVISION_COMMAND=none` to disable revision command entirely
- `WORKSPACE_PR_AGENT_CREATE_NOOP_PR_FOR_CLEAN=true|false`

## Notes
- If the workspace root is a git repo, auto-discovery includes it as its own repo/PR when applicable.
- GitHub MCP remains the primary PR/review/check source, with local context fallback when MCP is optional.
- Vercel context is used to interpret preview/build/deployment failures for deployment-facing repos.
- One PR per repo and final sync/cleanup constraints are enforced by the orchestrator.
