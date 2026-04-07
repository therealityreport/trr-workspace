# Birdkit Component Taxonomy

Birdkit is The New York Times' interactive presentation layer built on top of
Svelte and publisher-specific wrapper conventions. For Design Docs extraction,
the semantic structure lives in Birdkit's `g-*` classes and CSS custom
properties, not in Svelte's generated class hashes.

Use this reference when recovering structure, style tokens, and data from NYT
interactive SSR HTML.

## Semantic Wrapper Hierarchy

### `figure.g-wrapper`

Outer figure wrapper for a Birdkit module.

- Owns article-level block spacing through `--g-wrapper_margin-block` and
  related margin variables.
- Often carries accessibility metadata such as `aria-label`.
- May include helper classes such as `g-needs-margin-block` or
  `g-overflow-visible`.

### `div.g-block`

Generic content block inside the wrapper.

- Usually separates the main content specimen from meta content.
- Often paired with `g-block-margin` and `g-margin-inline`.
- Treat each `g-block` as a structural section rather than a presentational
  fragment.

### `div.g-block-width`

Width-constraining container.

- Commonly paired with `g-max-width-body` or `g-max-width-wide`.
- Maps Birdkit width tokens such as `--g-width-body` and `--g-width-wide` into
  a concrete max-width constraint.

### `div.g-wrapper_main-content`

Main specimen container.

- Controls overflow behavior for charts and graphics.
- Common host for interactive content, ai2html artboards, or Birdkit charts.

### `div.g-wrapper_main_content_slot`

Primary content slot.

- Usually holds the rendered chart, ai2html output, or interactive module.
- Treat this as the content-bearing descendant for renderer parity.

### `div.g-wrapper_meta`

Metadata slot for source, note, and credit content.

- Most often contains `.g-source`, `.g-note`, and `.g-credit`.
- Parse this block separately from the main content so metadata is preserved in
  generated docs.

## Ignore Svelte Hash Classes

Ignore classes that match `svelte-XXXXXXX` during semantic extraction.

- These classes are auto-generated scoped-style hashes from Svelte.
- Their meaning is derived from component style content, not from the class name
  itself.
- Per Svelte's scoped-style behavior, they add a specificity bump of `0-1-0`.
- They are stable enough to identify that Svelte styling exists, but they are
  not a reliable semantic signal for structure recovery.

Use them only as evidence that the source came from a Svelte-rendered component.
Do not treat them as component taxonomy.

## Birdkit CSS Custom Property Dictionary

### Typography

- `--g-franklin`: sans-serif UI and chart label family
- `--g-imperial`: serif body-text family
- `--g-chelt`: Cheltenham headline family
- `--g-chelt-cond`: condensed Cheltenham display family

### Color

- `--g-color-copy`: primary body copy color
- `--g-color-anchor`: inline anchor/link color
- `--g-color-caption`: caption and note color
- `--g-color-credit`: credit color
- `--g-color-graphic-credit`: graphic footer credit color
- `--g-color-overlay-caption`: overlay caption text on dark imagery
- `--g-color-overlay-credit`: overlay credit text on dark imagery

### Layout

- `--g-width-body`: standard body-column width, commonly `600px`
- `--g-width-wide`: wide-column width, commonly `1050px`
- `--g-margin-left`: left article gutter
- `--g-margin-right`: right article gutter
- `--g-margin-inline`: computed inline gutter shorthand
- `--g-margin-top`: top block spacing
- `--g-margin-bottom`: bottom block spacing
- `--g-margin-block`: computed block spacing shorthand

### Body Text System

- `--g-body-font-family`: article body family, usually resolves to imperial
- `--g-body-font-weight`: article body weight
- `--g-body-font-size`: body font size, often `1.25rem`
- `--g-body-line-height`: body line height, often `1.5`
- `--g-body-color`: resolved body copy color
- `--g-body-background-color`: resolved article background

### Article-Specific Extension Variables

Birdkit articles may add ad hoc custom properties for figure-specific palettes.

Pattern:

- `--gXxxColor`
- `--gSomeArticleSpecificToken`

Example:

- `--gTariffKeyColor: #bc6c14`

When these exist, extract them into article-specific token groups instead of
discarding them as one-off inline values.

## Component Family Signatures

### Arrow Comparison Charts

Typical markers:

- `.g-arrow-chart`
- `.g-arrow-row`
- positioned stem or bar elements with inline percentage styles
- screen-reader summaries with prior and after values

Use for charts that compare a baseline value against a projected or new value.

### Tables

Typical markers:

- `.g-table`
- `.g-table-row`
- Birdkit `CTable` or `CTableDouble` output

Often includes status circles, medal dots, placeholder rows, or variant/dropdown
states rendered server-side.

### Headers

Typical markers:

- `.g-header`
- `.g-heading`
- `.g-leadin`

Use these for figure-level titling and contextual lead-in text.

### Figure Containers

Typical markers:

- `figure.g-wrapper`
- `.g-needs-margin-block`

Treat this as the semantic root of a Birdkit figure.

### ai2html Graphics

Typical markers:

- `.g-media`
- ai2html containers or `.g-artboard`

Birdkit commonly wraps ai2html output inside `g-media` while keeping source,
note, and credit in a separate Birdkit metadata block.

### Subheads

Typical markers:

- `.g-subhed`

Used for Birdkit-native section subheadings inside an article.

### Body Text

Typical markers:

- `.g-text`

Used for Birdkit-managed body paragraphs or explanatory copy.

### Share Tools

Typical markers:

- `.g-sharetools`

Represents Birdkit-wrapped social/share chrome. Treat backend-dependent states
separately from static structure.

## Screen-Reader Text Mining

Prefer `.g-screenreader-only` text as the most reliable structured data source
when it is present near a Birdkit chart or table.

Why:

- It often contains the full prose description of the chart's numeric meaning.
- It can preserve values even when visible labels are abbreviated or positioned
  with inline geometry.
- It is less brittle than recovering values from `left:` and `width:` styles
  alone.

Extraction rule:

- Use screen-reader prose as the primary data source.
- Use visible row/label markup and inline geometry as a validation or fallback
  path.
- If screen-reader text and visible SSR values disagree, flag a warning rather
  than silently choosing one.

## Inline Percentage Decoding

Birdkit charts often encode layout using inline percentage styles.

Common patterns:

- `left: X%`
- `width: Y%`
- `right: Z%`

Interpretation guidance:

- `left` typically indicates the visual start position of a marker or bar
  relative to the chart scale.
- `width` typically indicates the span from baseline to projected value.
- For paired-value charts, `newValue` is often implied by `priorValue + delta`
  or by a second visible label.
- Geometry alone is not sufficient to infer the original numbers unless the
  chart scale or companion labels are also recoverable.

Priority order:

1. Screen-reader prose
2. Explicit numeric labels in visible SSR text
3. Inline percentage geometry with a recoverable scale

If only geometry exists and the scale cannot be resolved, stop at a fidelity
warning instead of fabricating values.
