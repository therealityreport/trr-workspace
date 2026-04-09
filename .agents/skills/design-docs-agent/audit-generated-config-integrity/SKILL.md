---
name: audit-generated-config-integrity
description: Post-generation validation gate — type-checks config, validates block order, enforces uniqueness and union coverage
---

# Audit Generated Config Integrity

## Purpose

Run the post-generation integrity gate after article generation and wiring, and
before brand sync. This skill validates that the generated config is structurally
correct, ordered, and renderer-complete.

## Use When

1. `generate-article-page` and `wire-config-and-routing` have finished.
2. A Design Docs config edit needs a structural safety check.

## Do Not Use For

1. Raw HTML extraction.
2. Accessibility or responsive layout auditing.

## Inputs

- `articleId`
- optional `brandSlug`
- optional list of touched files

Canonical validators live in:

- `TRR-APP/apps/web/src/lib/admin/design-docs-pipeline-validators.ts`
- `TRR-APP/apps/web/scripts/design-docs/validate-config-integrity.mjs`

## Outputs

- pass or fail status
- issue list with file or article context
- any required blocking fixes before sync continues

## Procedure

1. Run the config integrity validator for the target article.
2. Validate `contentBlocks` ordering against extracted source order.
3. Validate article-level font and color uniqueness expectations.
4. Validate union coverage so every generated block type has a renderer path.
5. Validate reusable primitive coverage for shell/storyline blocks and confirm
   primitive ids resolve to known registry entries.
6. Validate recoverable social/share image coverage so multi-slot share sets are
   not silently dropped back to a single fallback image.
7. Validate article URL and page background contract expectations.
8. Validate that any emitted page-section or TOC metadata is internally
   consistent and free of duplicate section ids.

## Validation

1. Typecheck must pass or any failure must be surfaced as blocking.
2. Every reported issue must map to a concrete config or renderer problem.
3. Hosted-media references and section-anchor metadata must remain data-driven
   rather than encoded as ad hoc component logic.
4. Repeated publisher shell chrome must fail validation if it is inlined instead
   of backed by reusable primitive references.

## Stop And Escalate If

1. The validator cannot resolve the target article.
2. Typecheck fails for reasons outside the Design Docs scope.
3. A generated block type has no renderer path.

## Completion Contract

Return:

1. `status`
2. `issues`
3. `blocking_fixes`
4. `validated_files`
5. `next_step`
