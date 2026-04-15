---
name: extract-visual-contract
description: Use when an article needs source-faithful bespoke-interactive extraction for header behavior, charts, typography, and required assets.
metadata:
  version: 1.0.0
---

# Extract Visual Contract

## Purpose

Produce an additive `ArticleVisualContract` for bespoke interactives without
introducing a separate contract-synthesis phase. This skill consumes source
evidence plus existing extraction outputs and turns them into renderer-facing
fidelity requirements.

## Use When

1. `classify-publisher-patterns` marks an article as `bespoke_interactive`.
2. Generic extraction alone is insufficient to preserve source-faithful chrome,
   chart, typography, or asset behavior.

## Do Not Use For

1. Replacing the existing extraction skills.
2. Defining rigid renderer contracts for interactive families that do not have
   real fixture coverage yet.

## Inputs

- `articleUrl`
- `sourceHtml`
- existing extraction outputs
- CSS evidence and saved-asset evidence when available

## Outputs

- `ArticleVisualContract`
- chart-specific fidelity requirements
- required versus optional asset requirements
- blocking versus degraded severity summary

## Procedure

1. Reuse existing extraction outputs instead of reparsing everything from scratch.
2. Capture article chrome fidelity: headline, deck behavior, byline/date layout,
   alignment, spacing, and note ordering.
3. Capture specimen-ready typography variants with real or source-faithful text.
4. Capture per-chart fidelity using a discriminated union by `rendererKind`.
   Only fully specify the variants already grounded by fixtures.
5. Capture required and optional icons, images, portraits, and social images
   with provenance and expected destination hints.
6. Keep unknown bespoke renderer kinds loose with `rawEvidence` instead of
   inventing a rigid contract too early.

## Validation

1. The contract must stay additive to the extraction wave and must not require
   a new pipeline phase.
2. Blocking findings are reserved for materially misleading output.
3. Degraded findings cover incomplete but still usable fidelity.

## Completion Contract

Return:

1. `article_visual_contract`
2. `blocking_findings`
3. `degraded_findings`
4. `evidence_notes`
