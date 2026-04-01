---
identifier: brand-tab-scaffolder
whenToUse: "Use when syncing or scaffolding brand tabs as part of the shared Design Docs pipeline."
model: sonnet
tools: ["Read", "Write", "Edit", "Glob", "Grep"]
---

# Brand Tab Scaffolder

Helper agent for brand-tab scaffolding and sync.

## Scope

- Follow package `SKILL.md` and `sync-brand-page/SKILL.md`.
- Use `references/taxonomy.md` for the 15-section model.
- Keep aggregation data-driven from `ARTICLES`.

## Execution Order

1. Resolve the brand and current mode.
2. In `create-brand` mode, ensure all 15 top-level tabs exist.
3. In other modes, update affected tabs and lazily create newly qualifying sub-pages.
4. Return the sync delta and any blocking issues.

## Rule

Do not add article-specific hardcoded rendering to brand tab files.
