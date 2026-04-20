---
name: extract-reusable-ui-primitives
description: Normalize repeated publisher shell, menu, drawer, popup, storyline, and icon surfaces into reusable Design Docs primitives.
user-invocable: false
metadata:
  version: 1.0.0
---

# Extract Reusable UI Primitives

## Purpose

Normalize repeated, source-backed UI chrome into reusable primitives so future
article generations can reference the same publisher shell, icon, menu, drawer,
popup, or storyline component instead of rebuilding it inline.

## Use When

1. Extraction has recovered repeated shell/icon surfaces from a supported publisher.
2. The generator needs `reusablePrimitives` or primitive match ids for article blocks.

## Do Not Use For

1. One-off content blocks that are truly article-specific.
2. Generic media extraction without a stable UI role.

## Inputs

- extracted shell/icon/media evidence
- `PublisherClassification`
- existing primitive registry state

Primary runtime targets:

- `TRR-APP/apps/web/src/lib/admin/design-docs-ui-primitives.ts`
- `TRR-APP/apps/web/src/lib/admin/design-docs-pipeline-types.ts`

## Outputs

- `reusablePrimitives`
- primitive match decisions
- registry add/update recommendations

## Procedure

1. Group recovered UI evidence by publisher, layout family, role, and structural variant.
2. Identify stable candidates such as logos, masthead icons, share/save/gift
   buttons, close/search/hamburger/account icons, storyline rails, site-header
   shells, menu overlays, search panels, account drawers, and promo list cards.
3. Match each candidate against existing primitive signatures before creating a new primitive.
4. Reuse an existing primitive when publisher, layout family, DOM role,
   interaction contract, and visible structure are materially the same.
5. Create a new primitive only when the new source-backed variant differs in a
   way that would make reuse misleading.
6. Keep article-specific copy, links, and asset URLs out of the primitive
   definition unless they are part of the stable reused surface.

## Validation

1. Primitive ids must be keyed by publisher plus layout family plus role plus variant.
2. Do not create article-slug-specific primitive ids for reusable chrome.
3. Do not collapse materially different shell variants into one primitive.
4. Preserve provenance so validators can confirm why a primitive was reused or created.

## Stop And Escalate If

1. The source evidence is too partial to tell whether a surface is reusable.
2. A proposed primitive would mix stable chrome with article-specific content in a non-reusable way.

## Completion Contract

Return:

1. `reusable_primitives`
2. `primitive_matches`
3. `registry_actions`
4. `warnings`
