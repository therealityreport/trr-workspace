# Skill Routing Governance Matrix

Canonical source is the **user-level skill**: `~/.claude/skills/skill-routing/SKILL.md`

This project-level file exists for:
1. `AGENTS.md` line 48 reference (workspace policy pointer)
2. `scripts/check-policy.sh` validation target
3. Companion file co-location with `claude_skill_overlap.md` and `mcp_inventory.md`

The user-level skill is authoritative. Do not duplicate routing rules here — read the skill directly.

Companion rule for Codex/TRR config: routing decides which skill owns a surface, but workspace policy should not disable unrelated user-level or system-level skills just because a local canonical exists.

## Companion Files

| File | Purpose |
|------|---------|
| `claude_skill_overlap.md` | Absorption/demotion records for global skills absorbed into workspace canonicals |
| `mcp_inventory.md` | MCP server registration and invocation guidance |
