---
name: verify-source-fidelity
description: Use when verification must compare generated Design Docs output against bespoke source-fidelity requirements.
user-invocable: false
metadata:
  version: 1.1.0
---

# Verify Source Fidelity

## Purpose

Run the fidelity gate after generation and wiring so bespoke interactive
articles are checked against their `ArticleVisualContract` or fixture-backed
fallback requirements.

## Use When

1. Verification reaches the fidelity gate for a bespoke interactive article.
2. An article fixture such as `debate-speaking-time` must be protected from
   structural-but-wrong regressions.

## Do Not Use For

1. Replacing typecheck or structural config validation.
2. Turning every incomplete bundle into a hard failure in v1.

## Inputs

- `articleId`
- generated article config state
- optional `ArticleVisualContract`
- optional fixture expectations

## Outputs

- `SourceFidelityResult`
- `blockingFindings`
- `degradedFindings`
- `legacyMode`

## Procedure

1. Resolve the target article and any provided visual contract.
2. If no contract exists for an older article, enter `legacyMode` instead of
   failing automatically.
3. Check chrome, chart, typography, and asset fidelity expectations.
4. For NYT article pages, compare generated coverage against the complete
   article inventory:
   - sticky/global header and site shell
   - menu, search, account, subscribe/login, and action-icon surfaces
   - every body, ad, related, newsletter/promo, author, footer, and correction
     section observed in source
   - every chart, graph, table, static image, SVG, canvas, sticky chart state,
     chart label, source, credit, and mobile variant
   - production stack evidence from source scripts, stylesheets, extension
     inventories, and framework/runtime markers
5. Treat a missing whole section or missing whole chart as blocking for a newly
   generated or actively revised article. Treat missing exact copy, exact
   coordinates, or blocked source-map provenance as degraded when the component
   slot is still represented honestly.
6. For every degraded chart slot, verify that `chartExtractionAttempt` or
   `chart_extraction_attempts` names the detector path and extractor that ran.
   Missing attempt evidence is blocking, because it means the chart-specific
   skills were skipped.
7. Fail only on blocking findings.
8. Surface degraded findings clearly so users can decide whether to supplement
   the bundle or accept the result.

## Validation

1. Blocking findings must map to materially wrong or visibly misleading output.
2. Degraded findings must not fail the pipeline on their own.
3. Fixture-backed checks should remain narrow and evidence-based.

## Completion Contract

Return:

1. `status`
2. `blocking_findings`
3. `degraded_findings`
4. `legacy_mode`
