---
name: generate-article-page
description: Generate ARTICLES config entry and chart data constants from extraction data.
metadata:
  version: 1.0.0
---

# Generate Article Page

## Purpose

Generate the article-level Design Docs config and any supporting chart-data
constants from the merged extraction payload.

## Use When

1. The extraction wave has completed and produced the merged payload.
2. The orchestrator is ready to add or update the article entry.

## Do Not Use For

1. Raw source extraction.
2. Router or sidebar wiring.

## Inputs

- merged extraction payload
- resolved mode
- current Design Docs config state

Primary touched files:

- `TRR-APP/apps/web/src/lib/admin/design-docs-config.ts`
- `TRR-APP/apps/web/src/components/admin/design-docs/chart-data.ts`

When an article has a large player/item dataset (filter-card-tracker, data
table with 20+ rows, etc.), also produce:

- `TRR-APP/apps/web/src/components/admin/design-docs/<slug>-data.ts`

See `references/rendering-contracts.md`, `references/taxonomy.md`, and
`references/preflight-checklist.md`.

## Outputs

- article config entry edits
- chart-data constant edits when needed
- `crossPopulationCandidates` for brand sync

## Procedure

1. Derive stable article identifiers, slug fields, and mode-specific update targets.
2. Build the article config entry from the merged extraction payload.
3. Populate `contentBlocks` from extracted source order and supported renderers.
4. Populate `architecture.publicAssets.socialImages` whenever multiple
   source-backed share variants are recoverable.
5. Emit `site-header-shell`, `storyline`, and related interactive chrome blocks
   from extracted shell evidence when the saved bundle is complete enough.
6. Reuse known publisher primitives by `primitiveId` when a matching shell,
   icon set, popup, drawer, or storyline already exists.
7. Emit chart and table metadata plus renderer-ready constant bindings for interactive artifacts.
8. When source evidence requires page-level anchors, TOC controls, or viewport
   toggles, emit the supporting metadata rather than page-specific JSX hacks.
9. Emit `crossPopulationCandidates` describing which brand taxonomy sections should update.

### Export Naming (mandatory)

When generating a standalone data file (e.g., `<slug>-data.ts`):

- Derive the export constant name from the article `id` in `design-docs-config.ts`.
- Convert the `id` to SCREAMING_SNAKE_CASE and append the year when present.
  Example: `nfl-free-agent-tracker-2026` → `NFL_FREE_AGENTS_2026`.
- The import in `ArticleDetailPage.tsx` and the export name in the data file
  must match exactly. Verify before writing.

### Data Verification (mandatory)

After writing any standalone data file:

1. Read back the first and last entries from the written file.
2. Confirm rank 1 and rank N match the expected entries from the source HTML.
3. If they do not match, the sub-agent likely used the wrong source (e.g.,
   navigated to a live URL). Discard the file and re-extract from the saved
   source. See `references/source-html-modes.md`.

### SVG Shape Extraction

When a component uses shaped headers, diagonal dividers, or non-rectangular
decorative elements:

1. Inspect the source HTML for `<svg>`, `<polygon>`, and `<polyline>` elements.
2. Extract the exact `points` attribute values.
3. Replicate them in the generated component with the same coordinates.
4. Do NOT approximate SVG shapes with CSS gradients, `clip-path`, or
   `background: linear-gradient`. The exact polygon points are required for
   visual fidelity.

### Page Container Width

When the article contains a `filter-card-tracker`, wide data table, or any
`contentBlock` that requires a wide layout:

- The `ArticleDetailPage` outer container must use `maxWidth: "100%"`.
- Never use a fixed pixel `maxWidth` (e.g., `600`) on the outer page wrapper
  when a wide component is present.
- Apply the 1150px (or content-appropriate) width constraint inside the
  component itself, not on the page wrapper.

## Validation

1. `contentBlocks` must preserve document order.
2. Every interactive artifact must have both metadata and a renderer-ready data path.
3. Fonts, colors, and URL fields must be grounded in the current article data.
4. Do not introduce article-specific rendering logic outside data config.
5. Prefer primitive references over inline repeated publisher chrome when a
   matching primitive already exists.
6. Export name in the data file matches the import in `ArticleDetailPage.tsx`.
7. First and last entries in any data file are verified against the source.
8. SVG shape elements are replicated from actual source `points` attributes —
   not approximated with CSS.
9. Page container `maxWidth` is `"100%"` when any wide component is present.
10. Page-level anchors or TOC metadata, when emitted, are stable and grounded in
   the extracted source structure.

## Stop And Escalate If

1. The merged payload cannot produce a trustworthy article entry.
2. A required interactive artifact lacks renderer-ready data.
3. The generated article data would depend on copied styles or guessed values.

## Completion Contract

Return:

1. `article_config_changes`
2. `chart_data_changes`
3. `cross_population_candidates`
4. `validation_notes`
5. `warnings`
