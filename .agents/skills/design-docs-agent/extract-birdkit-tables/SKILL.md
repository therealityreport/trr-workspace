---
name: extract-birdkit-tables
description: Extract structured data from Birdkit CTableDouble and CTable Svelte components rendered in NYT article SSR HTML and produce typed constants for interactive table recreation
---

# Extract Birdkit Tables

## Purpose

Extract the full SSR dataset and interaction variants from Birdkit table
components so downstream generation can recreate them with working TRR renderers.

## Use When

1. The extraction wave finds Birdkit `CTableDouble` or `CTable` markup.
2. The orchestrator needs structured table data and renderer hints.

## Do Not Use For

1. Generic HTML table extraction outside Birdkit structures.
2. Article config generation.

## Inputs

- `sourceHtml`
- optional page-structure hints for Birdkit block positions

See `references/rendering-contracts.md`, `references/lessons-learned.md`, and
`references/birdkit-component-taxonomy.md`.

## Outputs

- structured Birdkit table records
- dropdown or variant data
- renderer hints for table recreation

## Procedure

1. Detect Birdkit table containers and identify the component family.
2. Filter `svelte-*` class hashes during structure recovery. Treat `g-*`
   classes as the semantic structure. See
   `references/birdkit-component-taxonomy.md`.
3. Extract the full SSR dataset rather than only the initially visible rows.
4. Capture dropdown or variant states for interactive tables.
5. When `.g-screenreader-only` content exists near the table, extract its text
   as a validation source and compare counts and values against the SSR table
   rows.
6. Preserve semantics needed for headers, medal circles, or other specialized
   table UI.
7. Return normalized table records and renderer hints.

## Validation

1. Keep the full SSR dataset when it is present in HTML.
2. Preserve stable row-count expectations for interactive variants.
3. Do not fabricate missing variants that are not present in source.
4. If screen-reader content is present, use it as a cross-check rather than
   ignoring it.

## Stop And Escalate If

1. Birdkit markup is present but the data needed for renderer parity is missing.
2. The extracted table would require guessed rows or columns to render.

## Completion Contract

Return:

1. `tables`
2. `variant_summary`
3. `renderer_hints`
4. `style_hints`
5. `warnings`
