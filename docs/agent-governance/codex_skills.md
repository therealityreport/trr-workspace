# Codex Skills Governance Matrix

Use TRR-local canonical skills first. This file is the routing summary, not a full inventory.

## Routing Order
1. Workspace-local skills in `/Users/thomashulihan/Projects/TRR/.agents/skills/`
2. Globally canonical skills in `~/.codex/skills/`
3. Compatibility shims or generic specialists only when no canonical owner fits

## Canonical Workspace-Local Owners
- `.agents/skills/senior-fullstack/SKILL.md` — cross-repo implementation ownership
- `.agents/skills/senior-architect/SKILL.md` — architecture and ADR decisions
- `.agents/skills/senior-devops/SKILL.md` — release, rollback, and observability gates
- `.agents/skills/senior-qa/SKILL.md` — regression prevention and validation
- `.agents/skills/code-reviewer/SKILL.md` — review findings and post-change risk audit
- `.agents/skills/social-ingestion-reliability/SKILL.md` — social-ingestion runtime and reliability work
- `.agents/skills/skillcreator/SKILL.md` — TRR-local skill authoring and maintenance

## Additional Checked-In Workspace Skills
- `.agents/skills/crawl4ai/SKILL.md`
- `.agents/skills/font-sync/SKILL.md`
- `.agents/skills/multi-repo-pr-merge-sync/SKILL.md`
- `.agents/skills/workspace-pr-agent-github-mcp/SKILL.md`

## Repo-Local Skill Trees
- Repo-local `.agents/skills/` trees may remain for direct repo sessions.
- They are not part of the default workspace routing surface because TRR work is initiated from the workspace root.

## Canonical Global Skills
- `write-plan-codex` — first-draft, execution-ready planning sessions
- `plan-enhancer` — critique and refinement of an existing plan before execution
- `orchestrate-plan-execution` — plan-aligned execution for non-trivial mutation sessions
- `tdd-guide` — test-first delivery when the task calls for it
- `tech-stack-evaluator` — stack/tool comparison
- `figma` — dual-MCP Figma workflow owner for official Figma MCP plus `figma-console`
- `chatgpt-apps`, `git-feature-implementer`, `.system/skill-creator`, `.system/skill-installer` — keep global ownership

## Defaults
- If no plan exists yet, start with `write-plan-codex`.
- If a plan exists but needs stronger scope, sequencing, or optional-feature discovery, use `plan-enhancer` as the default middle refinement step. Users may explicitly skip it.
- For cross-repo implementation, start execution with `orchestrate-plan-execution` after plan approval, then add the smallest set of workspace-local owners needed for the touched surfaces.
- Prefer one canonical owner per surface instead of stacking overlapping generic skills.
- Treat global vendored specialists as references, not TRR owners, unless this file explicitly promotes them.
- Disable deprecated global TRR alias skills in `~/.codex/config.toml` with `[[skills.config]]` so Codex surfaces the checked-in local canonicals only once.
