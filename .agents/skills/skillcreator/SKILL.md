---
name: skillcreator
description: Workspace-local canonical owner for TRR checked-in skill authoring, dedupe, trigger boundaries, guardrails, and execution contracts.
---
Use this workspace-local skill when creating or refining checked-in skills for the TRR workspace.

## When to use
1. A new TRR workspace skill is needed.
2. A skill has overlapping ownership, weak boundaries, or stale execution contracts.
3. Governance docs, trigger rules, or skill dedupe need to be updated together.

## When not to use
1. Generic platform-wide skill creation with no TRR coupling.
2. Repo-specific generation workflows that belong only to screenalytics staging automation.

## Ownership boundary
1. This is the TRR-specific skill-authoring owner.
2. Keep `/Users/thomashulihan/.codex/skills/.system/skill-creator/SKILL.md` as the generic owner outside TRR.
3. Prefer concise, durable skills over large process frameworks.

## Creation checklist
1. Define scope, triggers, exclusions, and completion contract.
2. Check overlap against existing TRR local skills and global skills.
3. Decide canonical owner, aliases, and deprecations explicitly.
4. Keep the workspace skill surface concise and cross-repo aware.
5. Update matching governance docs and any relevant `agents/openai.yaml`.

## Imported strengths
1. From `skillcreator-codex`: repeatable phased thinking, explicit anti-patterns, and extension-point thinking.
2. From TRR governance: canonical-owner mapping, overlap control, and short alias-shim patterns.

## Explicit rejections
1. Do not require screenalytics staging paths for non-screenalytics skills.
2. Do not bloat every skill with full generation methodology.

## Completion contract
Return:
1. `skill_scope`
2. `canonical_owner`
3. `overlap_resolution`
4. `files_updated`
5. `governance_updates`
