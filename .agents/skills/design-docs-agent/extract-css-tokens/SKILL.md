---
name: extract-css-tokens
description: Extract design tokens from CSS stylesheets
user-invocable: false
metadata:
  version: 1.2.0
---

# Extract CSS Tokens

## Purpose

Extract article-specific typography, color, spacing, and other design tokens
from source CSS and source HTML. This skill owns the per-article style payload.

## Use When

1. The extraction wave needs fonts, colors, or computed text-style specimens.
2. The orchestrator needs a normalized token payload for article or brand generation.

## Do Not Use For

1. Full article structure extraction.
2. Brand page generation.

## Inputs

- discovered stylesheet URLs
- inline `<style>` blocks from `sourceHtml`
- optional computed-style evidence when trusted browser access is available
  (including `computed-styles.json` from `capture-rendered-source`)
- optional Figma read-only capabilities `figma.search_design_system` and
  `figma.get_variable_defs` (no `/figma-use` preload required)
- `sourceHtml`

See `references/rendering-contracts.md`, `references/lessons-learned.md`, and
`references/preflight-checklist.md`. For Birdkit-specific variable recovery, see
`references/birdkit-component-taxonomy.md`.

## Outputs

- normalized token map
- typography specimens with parseable `usedIn` values
- `typographyFidelityRequirements`
- article-specific color palette
- dark-mode token notes when present
- `figmaTokenCrossref` and `figmaVariableDefinitions` when the Figma MCP was used

## Procedure

1. Parse stylesheets and inline styles in document order.
2. Extract design tokens such as fonts, colors, spacing, radii, and shadows where present.
3. Extract actual article typography specimens for headline, subheads, body
   text, and chart or table labels.
4. Emit specimen-ready typography fidelity requirements with real article copy
   or source-faithful sample text for each distinct style combination.
5. Capture article-specific chart or interactive palettes rather than copying prior article values.
6. When trusted computed-style evidence is available, cross-check key elements against the extracted payload.
7. When the Figma MCP is available, cross-reference the extracted tokens against
   the TRR/publisher Figma design system (read-only, no `/figma-use` preload):
   - `search_design_system` to locate matching components and styles
   - `get_variable_defs` to read canonical color/font/spacing variable values
   - record matches and divergences in `figma_token_crossref` plus the raw
     `figma_variable_definitions`. Source CSS values remain authoritative on
     conflict; the cross-reference annotates, it does not overwrite.
8. When Birdkit `g-*` structures are present, extract `--g-*` custom properties
   from `:root`, article wrapper scope, or Birdkit body scope and map them into
   token groups:
   - typography
   - colors
   - layout
   - body text system
   - article-specific variables
   Use `references/birdkit-component-taxonomy.md` for the variable dictionary
   and article-specific extension pattern.

## Validation

1. Fonts and colors must come from the current article, not an existing article.
2. `usedIn` values must be parseable and grounded in extracted values.
3. Treat identical `h2` and `h3` results as suspicious and re-check the source when evidence suggests they differ.
4. When Birdkit `--g-*` variables are present, capture them as tokens rather
   than leaving them implicit in inline styles only.

## Stop And Escalate If

1. Key article styles cannot be resolved from source CSS or trusted computed-style evidence.
2. Typography extraction would require assumptions instead of extracted values.

## Completion Contract

Return:

1. `tokens`
2. `typography_specimens`
3. `color_summary`
4. `computed_style_notes`
5. `figma_token_crossref`
6. `figma_variable_definitions`
7. `warnings`
