---
name: sync-brand-page
description: Sync article data to parent brand tab pages — ensures fonts, colors, components, and charts are reflected in the brand landing tabs
metadata:
  version: 1.1.0
---

# Sync Brand Page

## Purpose

Sync article extraction and generation output into the matching brand tabs so
the brand page reflects shared data through aggregation from `ARTICLES`.

## Use When

1. `generate-article-page` and wiring have completed.
2. A new or updated article needs to update brand-tab surfaces.

## Do Not Use For

1. Initial source extraction.
2. Router or sidebar registration.

## Inputs

- `articleId`
- `brandSlug`
- `mode`
- `crossPopulationCandidates`

See `references/taxonomy.md` for the 15-section rules.

## Outputs

- created or updated brand-tab files
- sync delta describing what changed
- placeholder or lazy-creation decisions

## Procedure

1. Resolve the target brand and current tab-file state.
2. In `create-brand` mode, ensure all 15 tab files exist.
3. In other modes, update existing tabs and create newly qualifying sub-pages lazily.
4. Aggregate article data into the right taxonomy sections through shared data flow.
5. Ensure bespoke typography variants and article asset categories flow into
   brand tabs through aggregation rather than manual article-specific edits.
6. Report what was created, updated, or left unchanged.

## Validation

1. Brand tabs must aggregate from shared article data rather than hardcoded article-specific JSX.
2. Empty tabs should preserve the standard placeholder behavior.

## Stop And Escalate If

1. The target brand cannot be resolved from the current repo state.
2. Sync would require non-aggregated article-specific hacks to succeed.

## Completion Contract

Return:

1. `tabs_created_or_updated`
2. `aggregation_changes`
3. `placeholder_changes`
4. `warnings`
5. `next_step`
