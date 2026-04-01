# Component Inventory Provenance

## Purpose

Use this reference when the rendered saved bundle is not sufficient to describe
which source components must be documented.

## Accepted Inventory Sources

Record component inventory provenance as one of:

- `compiled-bundle`
- `source-map`
- `devtools-export`
- `screenshot-only`

The source may mix these, but each recovered component should keep its own
provenance.

## Preferred Recovery Order

1. Source maps referenced from saved JS chunks
2. DevTools `webpack://` or workspace export
3. Screenshot-backed module tree
4. Rendered bundle heuristics only when no stronger source exists

## Required Output Shape

`SourceComponentInventory` should be able to express:

- stable `componentId`
- `label`
- `sourceComponentName`
- optional `sourcePath`
- provenance
- source area such as `foundation`, `shared`, `hub`, or `per-game`
- related CSS or module references
- mapped docs section or anchor id

## Rules

- Keep rendered-source authority and component-inventory authority separate.
- Do not claim screenshot-only components were recovered from source maps.
- If source maps are blocked and screenshots are partial, escalate instead of
  pretending the component inventory is complete.
- If bundle CSS can prove layout or sizing but not original component identity,
  record only what the bundle proves and keep the missing inventory explicit.
