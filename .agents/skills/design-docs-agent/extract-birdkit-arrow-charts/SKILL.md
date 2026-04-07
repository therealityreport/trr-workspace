---
name: extract-birdkit-arrow-charts
description: Extract structured data and metadata from Birdkit arrow comparison charts rendered in NYT SSR HTML
---

# Extract Birdkit Arrow Charts

## Purpose

Extract structured row data, figure metadata, and renderer hints from Birdkit
arrow comparison charts so downstream generation can recreate them without
manual hardcoding.

## Use When

1. The extraction wave finds `.g-arrow-chart`, `.g-arrow-row`, or equivalent
   Birdkit arrow-comparison markup.
2. The orchestrator needs renderer-ready row data for comparison charts in NYT
   interactive articles.

## Do Not Use For

1. Generic SVG, Datawrapper, or ai2html chart extraction.
2. Birdkit tables that are better handled by `extract-birdkit-tables`.
3. Article config generation.

## Inputs

- `sourceHtml`
- optional page-structure hints for Birdkit chart positions

See `references/birdkit-component-taxonomy.md`,
`references/rendering-contracts.md`, and `references/lessons-learned.md`.

## Outputs

- structured Birdkit arrow-chart records
- renderer hints for layout and palette recovery
- fidelity warnings when the source is incomplete

## Procedure

1. Detect Birdkit arrow-chart containers using `.g-arrow-chart`, `.g-arrow-row`,
   or equivalent grouped chart markup.
2. Filter out `svelte-*` classes during structure recovery. Use `g-*` classes as
   the semantic taxonomy. See `references/birdkit-component-taxonomy.md`.
3. Primary extraction path: mine nearby `.g-screenreader-only` prose for row
   data, including label, prior value, and new value.
4. Fallback extraction path:
   - parse inline percentage styles from arrow stems, positioned labels, or
     equivalent Birdkit layout elements
   - decode explicit numeric values from `.g-avg-prior`, `.g-avg-after`, or
     equivalent visible text spans
   - resolve the chart scale only when the source exposes enough information to
     do so without guessing
5. Extract figure metadata from the same Birdkit wrapper:
   - heading
   - lead-in
   - source
   - note when present
   - credit
6. Return normalized chart records, renderer hints, and any fidelity warnings.

## Validation

1. Prefer `.g-screenreader-only` prose over geometry-only inference when both
   are available.
2. Do not fabricate row values when the scale cannot be resolved from SSR text
   or accessible prose.
3. Preserve document-order row sequencing from the source.
4. Cross-check recovered values against visible labels and metadata when both
   are present.

## Stop And Escalate If

1. Birdkit arrow-chart markup is present but neither screen-reader prose nor a
   reliable numeric fallback path exists.
2. Figure metadata cannot be separated cleanly from the chart wrapper.
3. Row values would require guessed scale math rather than extracted evidence.

## Completion Contract

Return:

1. `arrow_charts`
   - array of `{ title, leadin, source, note?, credit, rows: [{ label, priorRate, newRate }] }`
2. `renderer_hints`
3. `warnings`
