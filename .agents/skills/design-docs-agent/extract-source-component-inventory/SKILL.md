---
name: extract-source-component-inventory
description: Use when Design Docs coverage depends on source maps, webpack trees, DevTools exports, or screenshot-backed module inventories beyond compiled HTML.
user-invocable: false
metadata:
  version: 1.0.0
---

# Extract Source Component Inventory

## Purpose

Recover the source-component inventory that should be documented when the
rendered saved bundle does not fully describe which source modules or component
families exist.

## Use When

1. The extraction wave needs component coverage from source maps, DevTools
   `webpack://` trees, or screenshot-backed module trees.
2. The docs must record source component provenance separately from rendered
   HTML or CSS evidence.

## Do Not Use For

1. Media URL extraction or hosted-media mirroring.
2. Layout sizing that can already be resolved from saved CSS.

## Inputs

- `sourceBundle`
- optional source-map file paths
- optional exported source-tree paths
- optional screenshots showing module names or folder trees

See `references/source-html-modes.md` and
`references/component-inventory-provenance.md`.

## Outputs

- `SourceComponentInventory`
- grouped component summary by source area
- provenance summary
- docs section or anchor mapping hints

## Procedure

1. Inspect source maps referenced from saved JS chunks first.
2. If source maps are unavailable, inspect exported DevTools source trees.
3. If exported source trees are unavailable, enumerate screenshot-backed module
   names and mark them as `screenshot-only`.
4. Group recovered components by source area such as `foundation`, `shared`,
   `hub`, and `per-game`.
5. Record provenance and any related CSS or module references for each entry.
6. Map recovered components to docs section or anchor targets when the target
   page structure is known.

## Validation

1. Keep rendered-source authority separate from component-inventory authority.
2. Do not present screenshot-only entries as if they came from source maps.
3. If component coverage is materially incomplete, report the gap instead of
   inventing unnamed modules.

## Stop And Escalate If

1. Source maps are referenced but blocked or unrecoverable and the missing
   modules materially affect docs coverage.
2. Screenshot-backed module trees are too partial to define coverage safely.
3. The source bundle proves layout behavior but cannot support a trustworthy
   source-component inventory.

## Completion Contract

Return:

1. `source_component_inventory`
2. `grouped_component_summary`
3. `provenance_summary`
4. `section_mapping_hints`
5. `warnings`
