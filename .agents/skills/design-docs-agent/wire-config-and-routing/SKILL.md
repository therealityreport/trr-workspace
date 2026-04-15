---
name: wire-config-and-routing
description: Register new brand in design docs config, sidebar, and routing.
metadata:
  version: 1.1.0
---

# Wire Config And Routing

## Purpose

Apply the incidental config, import, and routing edits needed for a new or
updated brand or article to become reachable in the Design Docs system.

## Use When

1. Article or brand generation has produced new config or section files.
2. Shared navigation or routing surfaces need to reference the generated output.

## Do Not Use For

1. Source extraction.
2. Brand-tab aggregation logic.

## Inputs

- `mode`
- `brandSlug`
- optional `articleId`
- label and description data when creating a new brand surface

## Outputs

- config edits
- import or route edits
- sidebar or discovery-surface edits

## Procedure

1. Resolve which shared surfaces need edits for the current mode.
2. Apply only the required incidental edits to config, imports, and routing surfaces.
3. Preserve ordering and shared conventions in the touched files.
4. Support article-specific interactive components and data files as first-class
   pipeline outputs when the merged extraction payload requires them.
5. Avoid introducing per-article rendering behavior into shared wiring files.

## Validation

1. The new or updated article or brand should be reachable through the expected shared surfaces.
2. Wiring edits should remain minimal and mode-appropriate.

## Stop And Escalate If

1. The required shared surface cannot be updated without broader architectural changes.
2. Wiring would require article-specific logic in a shared route or sidebar surface.

## Completion Contract

Return:

1. `files_updated`
2. `surfaces_wired`
3. `ordering_notes`
4. `warnings`
5. `next_step`
