---
name: integration-test-runner
description: Executable validation skill that runs integration test assertions from test/integration-test.md against the actual ARTICLES array and generated files
---

# Integration Test Runner

## Purpose

Run the executable integration harness for the Design Docs pipeline against the
actual repo-local config and generated files.

## Use When

1. The orchestrator reaches the final verification phase.
2. A Design Docs change needs end-to-end validation beyond typecheck.

## Do Not Use For

1. Raw extraction work.
2. Accessibility auditing.

## Inputs

- optional `articleId`
- repo-local generated files and current `ARTICLES` state

Canonical validators live in:

- `TRR-APP/apps/web/src/lib/admin/design-docs-pipeline-validators.ts`
- `TRR-APP/apps/web/scripts/design-docs/run-integration-checks.mjs`

## Outputs

- test pass or fail status
- categorized failures
- affected articles or files

## Procedure

1. Run the integration checker against the repo-local Design Docs state.
2. Validate article config integrity, chart/data bindings, and brand-section expectations.
3. Validate hosted-media usage, source-size fidelity, interactive specimen
   behavior, and TOC anchor integrity when those contracts are present.
4. Surface any article-specific or cross-article failures with actionable context.

## Validation

1. Failures must reference real config or file problems.
2. Warnings should be distinguished from blocking test failures.
3. If rendered docs media points directly at upstream source URLs, treat that
   as a blocking failure.

## Stop And Escalate If

1. The integration harness cannot run.
2. The failure is outside the Design Docs pipeline scope.

## Completion Contract

Return:

1. `status`
2. `failures`
3. `warnings`
4. `files_checked`
5. `interaction_coverage`
6. `next_step`
