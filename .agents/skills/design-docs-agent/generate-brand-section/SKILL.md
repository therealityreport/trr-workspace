---
name: generate-brand-section
description: Generate a complete Brand page component from extracted design tokens.
user-invocable: false
metadata:
  version: 1.0.0
---

# Generate Brand Section

## Purpose

Generate or scaffold the brand-level Design Docs section files that surface the
shared 15-section taxonomy for a brand.

## Use When

1. The orchestrator is in `create-brand` mode.
2. A brand section must be scaffolded or materially refreshed from merged extraction data.

## Do Not Use For

1. Single-article config generation.
2. Shared routing or sidebar wiring.

## Inputs

- merged extraction payload
- `brandSlug`
- `mode`
- existing brand-section state when present

See `references/taxonomy.md` and `references/rendering-contracts.md`.

## Outputs

- generated or updated brand section files
- scaffold decisions for the 15 tabs
- aggregation notes for follow-up sync

## Procedure

1. Resolve the target brand section and current file state.
2. In `create-brand` mode, scaffold all 15 tab files.
3. Populate the initial brand section surfaces from merged extraction data and shared aggregation patterns.
4. Use shared brand chrome variables for page chrome while preserving extracted specimen values.
5. When source evidence exists, generate interactive specimens for drawers,
   tabs, accordions, modals, and expand/collapse controls rather than static
   mockups.
6. Register stable section anchors and page-section metadata whenever the page
   needs TOC or overlay behavior.
7. When viewport-specific specimens are generated, keep the layout driven by a
   shared `mobile | desktop` page state rather than rendering both variants at
   once.
8. Return the files created or updated and any sync notes needed by `sync-brand-page`.

## Validation

1. Brand-section output must aggregate from shared article data, not hardcoded article content.
2. `create-brand` mode must scaffold all 15 top-level tabs.
3. Empty tabs should preserve the standard placeholder contract.
4. Page-level TOC, overlay, and viewport controls must be driven by typed
   section and asset metadata rather than page-specific hacks.

## Stop And Escalate If

1. The brand section cannot be created without breaking shared aggregation rules.
2. Generation would require article-specific hardcoding in brand tab files.

## Completion Contract

Return:

1. `files_created_or_updated`
2. `tab_scaffolding_summary`
3. `aggregation_notes`
4. `validation_notes`
5. `warnings`
