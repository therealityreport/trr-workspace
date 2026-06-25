---
name: extract-site-shell-interactions
description: Extract masthead spacers, shell chrome, storyline rails, drawers, menus, and popup interaction surfaces from saved source bundles.
user-invocable: false
metadata:
  version: 2.0.0
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
- optional rendered browser session from `capture-rendered-source` plus the
  capabilities `browser.snapshot`, `browser.click`, `browser.hover`,
  `browser.evaluate` for stateful interaction capture

Typed outputs land in:

- `TRR-APP/apps/web/src/lib/admin/design-docs-pipeline-types.ts`

## Outputs

- `siteShell`
- `interactionCoverage`
- `statefulInteractionSequences` — ordered open/close capture steps per surface
- `uiPrimitiveRecords` — typed shell/menu/drawer primitives keyed by publisher +
  layout family + role + variant
- reusable-primitive match candidates for shell and storyline surfaces

## Procedure

1. Detect masthead spacers, fixed header shells, storyline rails, and article-adjacent navigation chrome.
2. Detect hydrated menu overlays, search panels, account drawers, and popup/dialog bodies.
3. Capture visible labels, link lists, section groupings, button affordances,
   and coverage booleans for each recovered interaction surface.

### Stateful interaction capture (rendered session)

When a rendered browser session from `capture-rendered-source` is available,
capture each interaction surface in BOTH its closed and open states rather than
only the static initial DOM:

4. For each affordance (hamburger menu, search panel, account drawer,
   share/gift menu, dialog), record the closed-state snapshot, then `browser.click`
   or `browser.hover` to open it and `browser.snapshot` the opened state.
5. For each captured state, harvest the markup, the transition/animation classes,
   and the ARIA state attributes (`aria-expanded`, `aria-hidden`, `role`,
   `aria-modal`) via `browser.evaluate`.
6. Persist these as `statefulInteractionSequences` (ordered open/close steps) and
   `uiPrimitiveRecords` keyed by publisher + layout family + role + variant for
   `extract-reusable-ui-primitives` to consume.

### Match and emit

7. Match recovered shell or storyline surfaces against known reusable
   primitives when publisher, layout family, interaction role, and visible
   structure align.
8. Emit source-backed shell/storyline records only when the saved bundle (or the
   stateful capture) contains enough content to reproduce them safely.

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
3. `stateful_interaction_sequences`
4. `ui_primitive_records`
5. `primitive_matches`
6. `warnings`
