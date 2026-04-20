---
name: extract-site-shell-interactions
description: Extract masthead spacers, shell chrome, storyline rails, drawers, menus, and popup interaction surfaces from saved source bundles.
user-invocable: false
metadata:
  version: 1.0.0
---

# Extract Site Shell Interactions

## Purpose

Recover publisher shell chrome and hydrated interaction surfaces from saved
source bundles so article docs can reproduce source-backed headers, menus,
search panels, storyline rails, and account drawers.

## Use When

1. The saved bundle includes shell chrome, storyline rails, popup bodies, or
   other hydrated interaction surfaces.
2. The generator needs `siteShell` and `interactionCoverage`.

## Do Not Use For

1. Generic `NavigationData` extraction for brand taxonomy only.
2. Rebuilding shell markup from memory when the saved bundle lacks the body.

## Inputs

- `articleUrl`
- `sourceBundle.html`
- optional `PublisherClassification`

Typed outputs land in:

- `TRR-APP/apps/web/src/lib/admin/design-docs-pipeline-types.ts`

## Outputs

- `siteShell`
- `interactionCoverage`
- reusable-primitive match candidates for shell and storyline surfaces

## Procedure

1. Detect masthead spacers, fixed header shells, storyline rails, and article-adjacent navigation chrome.
2. Detect hydrated menu overlays, search panels, account drawers, and popup/dialog bodies.
3. Capture visible labels, link lists, section groupings, button affordances,
   and coverage booleans for each recovered interaction surface.
4. Match recovered shell or storyline surfaces against known reusable
   primitives when publisher, layout family, interaction role, and visible
   structure align.
5. Emit source-backed shell/storyline records only when the saved bundle
   contains enough content to reproduce them safely.

## Validation

1. Do not invent popup or drawer bodies that are absent from the saved bundle.
2. Preserve source order so shell blocks can render before article content when appropriate.
3. Reusable primitive matches must be evidence-based, not article-slug-specific.
4. If the affordance exists but the hydrated body is missing, record the gap in
   `interactionCoverage` and escalate instead of guessing.

## Stop And Escalate If

1. The saved bundle exposes a shell affordance but not the corresponding body content.
2. Matching a reusable primitive would require ignoring material structural differences.

## Completion Contract

Return:

1. `site_shell`
2. `interaction_coverage`
3. `primitive_matches`
4. `warnings`
