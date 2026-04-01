---
name: audit-responsive-accessibility
description: Post-generation quality gate for heading hierarchy, WCAG contrast, keyboard accessibility, responsive overflow, and alt text
---

# Audit Responsive Accessibility

## Purpose

Run the post-generation accessibility and responsive-design gate for generated
article and brand-tab output.

## Use When

1. Article pages and related brand tabs have been generated or updated.
2. The orchestrator reaches the verification phase.

## Do Not Use For

1. Config integrity checks.
2. Raw extraction from source HTML.

## Inputs

- `articleId`
- `brandSlug`
- list of generated or touched files

Canonical validators live in:

- `TRR-APP/apps/web/src/lib/admin/design-docs-pipeline-validators.ts`
- `TRR-APP/apps/web/scripts/design-docs/run-accessibility-audit.mjs`

## Outputs

- severity-ranked findings
- pass or fail status
- files checked

## Procedure

1. Run the responsive accessibility audit for the target article and brand.
2. Check heading hierarchy and skipped heading levels.
3. Check WCAG contrast coverage for generated output.
4. Check keyboard accessibility and missing labels where applicable.
5. Check overflow and layout breakage at mobile breakpoints.
6. Check overlay panels, TOC popups, drawers, and phone-frame previews for
   clipping, focus traps, and keyboard reachability when they are generated.

## Validation

1. Every blocking issue should include a concrete file or article reference.
2. Warnings must distinguish between missing data and styling problems.

## Stop And Escalate If

1. The audit runner cannot execute.
2. Required generated files are missing.
3. Blocking accessibility issues remain unresolved at closeout.

## Completion Contract

Return:

1. `status`
2. `findings`
3. `files_checked`
4. `blocking_issues`
5. `next_step`
