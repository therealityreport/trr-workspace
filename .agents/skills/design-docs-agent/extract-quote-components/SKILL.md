---
name: extract-quote-components
description: Extract styled quote blocks with CSS specifications.
user-invocable: false
metadata:
  version: 1.0.0
---

# Extract Quote Components

## Purpose

Extract structured quote or callout components, including status-style quote
sections, so downstream generation can recreate them accurately.

## Use When

1. The source article contains quote, promise, or callout blocks.
2. The extraction wave needs structured quote-component data.

## Do Not Use For

1. Generic paragraph extraction.
2. Standalone CSS token extraction.

## Inputs

- `sourceHtml`
- optional CSS or page-structure hints

## Outputs

- structured quote records
- styling hints for quote renderers
- article-section mapping when applicable

## Procedure

1. Locate quote or callout containers in source order.
2. Extract visible text, attribution, badge or status text, and supporting structure.
3. Capture styling hints needed for faithful reconstruction.
4. Map extracted quotes back to article sections when the structure supports it.

## Validation

1. Keep quote content grounded in source HTML.
2. Return an empty collection when the article has no qualifying quote blocks.

## Stop And Escalate If

1. Quote rendering depends on missing source data that would force fabrication.

## Completion Contract

Return:

1. `quotes`
2. `style_hints`
3. `section_mapping`
4. `warnings`
5. `next_step`
