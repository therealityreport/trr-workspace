# Codex Skills Governance Matrix

Use TRR-local canonical skills first. This file is the routing summary, not a full inventory.

## Routing Order
1. Repo-local skills in the touched repo
2. Workspace-local skills in `/Users/thomashulihan/Projects/TRR/skills/`
3. Globally canonical skills in `~/.codex/skills/`
4. Compatibility shims or generic specialists only when no canonical owner fits

## Canonical Repo-Local Owners
- `TRR-Backend/skills/senior-backend/SKILL.md` — backend contracts, schema, persistence, and security-sensitive API behavior
- `TRR-Backend/skills/database-designer/SKILL.md` — backend database design specialist
- `TRR-APP/skills/senior-frontend/SKILL.md` — Next.js app-router implementation and frontend contract follow-through
- `TRR-APP/skills/figma-frontend-design-engineer/SKILL.md` — Figma-driven frontend work
- `screenalytics/.claude/skills/*` — screenalytics-native pipeline, ML, and UI specialists

## Canonical Workspace-Local Owners
- `skills/senior-fullstack/SKILL.md` — cross-repo implementation ownership
- `skills/senior-architect/SKILL.md` — architecture and ADR decisions
- `skills/senior-devops/SKILL.md` — release, rollback, and observability gates
- `skills/senior-qa/SKILL.md` — regression prevention and validation
- `skills/code-reviewer/SKILL.md` — review findings and post-change risk audit
- `skills/social-ingestion-reliability/SKILL.md` — social-ingestion runtime and reliability work
- `skills/skillcreator/SKILL.md` — TRR-local skill authoring and maintenance

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
- For cross-repo implementation, start execution with `orchestrate-plan-execution` after plan approval, then add the smallest set of local owners needed for the touched surfaces.
- Prefer one canonical owner per surface instead of stacking overlapping generic skills.
- Treat global vendored specialists as references, not TRR owners, unless this file explicitly promotes them.
