---
name: extract-css-tokens
description: Extract design tokens from CSS stylesheets
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
- `sourceHtml`

See `references/rendering-contracts.md`, `references/lessons-learned.md`, and
`references/preflight-checklist.md`.

## Outputs

- normalized token map
- typography specimens with parseable `usedIn` values
- article-specific color palette
- dark-mode token notes when present

## Procedure

1. Parse stylesheets and inline styles in document order.
2. Extract design tokens such as fonts, colors, spacing, radii, and shadows where present.
3. Extract actual article typography specimens for headline, subheads, body text, and chart or table labels.
4. Capture article-specific chart or interactive palettes rather than copying prior article values.
5. When trusted computed-style evidence is available, cross-check key elements against the extracted payload.

## Validation

1. Fonts and colors must come from the current article, not an existing article.
2. `usedIn` values must be parseable and grounded in extracted values.
3. Treat identical `h2` and `h3` results as suspicious and re-check the source when evidence suggests they differ.

## Stop And Escalate If

1. Key article styles cannot be resolved from source CSS or trusted computed-style evidence.
2. Typography extraction would require assumptions instead of extracted values.

## Completion Contract

Return:

1. `tokens`
2. `typography_specimens`
3. `color_summary`
4. `computed_style_notes`
5. `warnings`
