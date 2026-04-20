---
name: extract-navigation
description: Extract header, footer, sidebar, breadcrumb, tab, drawer, and overlay navigation patterns from saved source bundles
user-invocable: false
metadata:
  version: 1.0.0
---

# Extract Navigation

## Purpose

Extract publisher navigation patterns from saved source bundles so Section 4 of the
brand taxonomy can be populated from structured data.

## Use When

1. The extraction wave needs header, footer, breadcrumb, tab, sidebar, filter,
   drawer, accordion, or overlay patterns.
2. The caller needs a `NavigationData` payload for brand section generation.

## Do Not Use For

1. Full article content extraction.
2. Layout-family classification or tech detection.
3. Publisher-specific shell facsimile ownership when a dedicated shell
   extraction skill is available.

## Inputs

- `sourceBundle`

Output shapes are defined in:

- `TRR-APP/apps/web/src/lib/admin/design-docs-pipeline-types.ts`

## Outputs

- `NavigationData`
- extracted navigation-pattern summary
- page anchor candidates when navigation or TOC generation is needed

## Procedure

1. Scan the source for header, footer, sidebar, breadcrumbs, tabs, pagination,
   filters, drawers, accordions, modals, portal targets, and overlay mounts.
2. Normalize repeated navigation items into structured pattern records.
3. Capture labels, hrefs, state markers, hierarchy, open/closed states, and
   active/inactive states where available.
4. Capture drawer groups, collapsible items, modal triggers, and anchor or TOC
   candidates when they are visible in source.
5. Map the extracted navigation patterns to the shared taxonomy surfaces.
6. Leave reusable page-shell normalization to the dedicated reusable-primitives
   and site-shell extraction skills; keep `NavigationData` generic.

## Validation

1. Preserve navigation hierarchy when it is visible in source.
2. Do not infer hidden navigation structures that are not present in HTML.
3. Keep overlay mounts and page-anchor candidates explicit when generated docs
   need interactive chrome or TOC behavior.

## Stop And Escalate If

1. HTML is too incomplete to distinguish navigation from article-body content.

## Completion Contract

Return:

1. `navigation_data`
2. `patterns_found`
3. `taxonomy_targets`
4. `warnings`
5. `next_step`
