# Skill Routing Governance Matrix

TRR does not own or install project-local skills. Skill discovery and selection come from the maintained user-level, system-level, and plugin registries available to the active agent runtime.

This file is a workspace policy pointer used by `AGENTS.md` and `scripts/check-policy.sh`; it is not a skill package or a duplicate skill registry.

## Routing Rules

1. Select a maintained user-level, system-level, or plugin skill that matches the current task.
2. Use TRR's `AGENTS.md`, `.codex/rules/`, domain documentation, and tests for project-specific context and constraints.
3. Do not treat repository files under `.agents/skills`, `.claude/skills`, or nested repository skill directories as canonical skill sources.
4. Do not disable unrelated inherited capabilities to resolve overlap. Prefer the narrowest maintained capability and follow the active instruction hierarchy.

## Companion Files

| File | Purpose |
|------|---------|
| `claude_skill_overlap.md` | Record of the retired local-skill ownership model and its replacement |
| `mcp_inventory.md` | MCP server registration and invocation guidance |
