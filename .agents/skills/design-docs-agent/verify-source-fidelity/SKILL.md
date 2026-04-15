---
name: verify-source-fidelity
description: Use when verification must compare generated Design Docs output against bespoke source-fidelity requirements.
metadata:
  version: 1.0.0
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
4. Fail only on blocking findings.
5. Surface degraded findings clearly so users can decide whether to supplement
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
