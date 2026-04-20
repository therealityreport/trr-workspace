---
name: extract-datawrapper-charts
description: Extract chart data from Datawrapper embeds and generate TypeScript constants.
user-invocable: false
metadata:
  version: 1.0.0
---

# Extract Datawrapper Charts

## Purpose

Extract Datawrapper metadata and renderer-ready datasets from discovered
Datawrapper embeds so generated article pages can render working visualizations.

## Use When

1. The extraction wave finds one or more Datawrapper embeds.
2. The orchestrator needs chart metadata and data constants for generation.

## Do Not Use For

1. Non-Datawrapper chart extraction.
2. Article config generation.

## Inputs

- discovered Datawrapper embed URLs
- optional brand or article context

See `references/rendering-contracts.md` and `references/lessons-learned.md`.

## Outputs

- chart metadata for `chartTypes`
- renderer-ready dataset payloads
- mapping from embed to TRR renderer shape

## Procedure

1. Resolve each embed and inspect the available Datawrapper payloads.
2. Recover the dataset from the embed HTML or a supported fallback path.
3. Classify the visualization type, including table-style embeds when applicable.
4. Normalize the recovered data into the TRR renderer contract.
5. Return a payload that generation can turn into chart-data constants.

## Validation

1. Every recovered Datawrapper artifact should produce both metadata and renderer-ready data.
2. Table-type embeds must be treated as tables, not forced into chart renderers.

## Stop And Escalate If

1. A required Datawrapper embed cannot produce renderer-ready data.
2. The embed can be identified but the recovered payload is too incomplete to power a trustworthy renderer.

## Completion Contract

Return:

1. `charts`
2. `chart_type_summary`
3. `dataset_summary`
4. `renderer_mappings`
5. `warnings`
