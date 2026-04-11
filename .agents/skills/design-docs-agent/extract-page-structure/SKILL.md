---
name: extract-page-structure
description: Extract content blocks and metadata from HTML source
metadata:
  version: 1.0.0
---

# Extract Page Structure

## Purpose

Extract ordered article metadata, content-bearing blocks, and embedded artifact
references from static source HTML. This skill defines the structural backbone
that downstream generation consumes.

## Use When

1. The extraction wave needs article metadata and ordered content blocks.
2. The orchestrator needs `PageStructure` plus block completeness metrics.

## Do Not Use For

1. CSS token extraction.
2. Datawrapper, Birdkit, or ai2html deep extraction beyond locating and tagging them.

## Inputs

- `articleUrl`
- `sourceHtml`
- optional publisher classification hints

Output shapes are defined in:

- `TRR-APP/apps/web/src/lib/admin/design-docs-pipeline-types.ts`

## Outputs

- `PageStructure`
- article metadata
- ordered block inventory
- embed and asset references
- `blockCompleteness`

## Procedure

1. Parse the document from static source HTML only.
2. Extract article metadata such as headline, deck, byline, date, breadcrumbs, and story links.
3. Walk the article body in source order and classify content-bearing blocks.
4. Record embeds and special containers such as Birdkit, Datawrapper, ai2html, and quote sections.
5. Produce a normalized `PageStructure` payload with stable ordering and block indexes.
6. Compute `blockCompleteness` from matched versus expected content-bearing blocks.

## Validation

1. Preserve source order for every classified block.
2. Return empty arrays rather than fabricated blocks when a component type is absent.
3. Flag likely extraction gaps when `blockCompleteness` indicates missing content.

## Stop And Escalate If

1. Source HTML is incomplete enough that ordering cannot be trusted.
2. More than a small minority of content-bearing blocks remain unclassified without explanation.

## Completion Contract

Return:

1. `page_structure`
2. `metadata_summary`
3. `embed_summary`
4. `block_completeness`
5. `warnings`
