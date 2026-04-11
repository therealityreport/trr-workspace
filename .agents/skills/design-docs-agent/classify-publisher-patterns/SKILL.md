---
name: classify-publisher-patterns
description: Detect publisher technology stack and classify layout patterns into the 15-section brand taxonomy
metadata:
  version: 1.0.0
---

# Classify Publisher Patterns

## Purpose

Classify the source article before extraction so the orchestrator knows which
publisher family it is dealing with, which extraction hints to apply, and which
taxonomy sections are likely to receive data.

## Use When

1. The orchestrator begins pre-extraction classification.
2. A new publisher or unfamiliar article structure needs routing hints.

## Do Not Use For

1. Detailed block extraction.
2. Generation or wiring work.

## Inputs

- `articleUrl`
- `sourceHtml`

Output shapes are defined in:

- `TRR-APP/apps/web/src/lib/admin/design-docs-pipeline-types.ts`

## Outputs

- `PublisherClassification`
- `TechInventory`
- taxonomy routing hints for the 15-section system

## Procedure

1. Scan HTML for framework markers, scripts, stylesheets, analytics, and SSR markers.
2. Build a technology inventory from the detected signals.
3. Classify the publisher layout family from article structure and tech markers.
4. Produce taxonomy hints for likely sections and sub-pages.
5. Default to a conservative generic classification when evidence is mixed.

## Validation

1. Classification should be evidence-based and derived from source HTML.
2. Tech detection should not fabricate tools that are not present in source.

## Stop And Escalate If

1. Source HTML is missing or truncated.
2. Classification evidence is too weak to distinguish between generic and specialized handling.

## Completion Contract

Return:

1. `publisher_classification`
2. `tech_inventory`
3. `taxonomy_hints`
4. `confidence_notes`
5. `follow_up_extractors`
