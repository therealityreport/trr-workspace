# Rendering Contracts

## ArticleDetailPage

`ArticleDetailPage` is data-driven. The generated article config controls what
renders. Do not add article-specific conditional logic to the component.

Repeated publisher chrome must be implemented as generic reusable components or
primitive-backed block renderers, not copied into one-off article branches.

## `contentBlocks`

- `contentBlocks` is the single source of truth for rendered article sections.
- Preserve document order from source HTML.
- Every content-bearing source block that can be mapped to a supported renderer
  should appear in `contentBlocks`.
- If a new renderer is required, add a generic block type and generic renderer.
- If a repeated publisher shell or icon family is required, add it to the
  reusable primitive registry and render it through a generic lookup path.

## Interactive Artifact Rule

Every interactive artifact must produce both:

- metadata for `chartTypes`
- data or constants that power a working renderer

This applies to Birdkit tables, Datawrapper embeds, ai2html report cards, and
other structured visual blocks.

When the source shows interaction affordances, generated docs specimens should
be interactive by default. This includes:

- tabs with active and inactive states
- accordions and expand/collapse controls
- drawers and collapsible groups
- modals or popup specimens
- page-level TOC overlays when a page registers multiple anchored sections

## CSS And Brand Chrome Rule

- Page chrome uses brand CSS variables such as `--dd-brand-accent`.
- Specimen values that document the article's actual palette remain concrete
  extracted values.
- Shared docs chrome may add viewport toggles, TOC triggers, and overlay layers,
  but these must remain data-driven and source-backed when documenting an
  existing publisher surface.

## Mirrored Asset Manifest Rule

All displayed media must render from the mirrored hosted-media manifest, never
directly from upstream source URLs.

Each asset record should preserve:

- source provenance
- hosted URL
- asset kind or usage class
- usage-scoped display metadata

At minimum, display metadata must support:

- `slot`
- `desktop.width`
- `desktop.height`
- optional `desktop.backgroundSize`
- optional `desktop.backgroundPosition`
- optional `desktop.objectFit`
- optional `mobile` with the same fields

If one hosted file is reused in multiple surfaces, allow separate usage-scoped
records rather than forcing one display size across all surfaces.

## Asset-Class Rule

Do not silently reuse the wrong asset class when a slot-specific source asset is
missing. Keep these classes separate:

- nav or page icons
- card illustrations
- promo or banner assets
- progress states
- utility icons such as print or share

## `usedIn` Rule

The `usedIn` field for typography specimens must be parseable and should record
actual extracted values, not assumptions. Keep the formatting consistent across
article generations.

## Page Section And TOC Rule

If a page documents multiple components or sections, register them through a
typed page-section index rather than ad hoc anchors.

Each section record should carry:

- stable `id`
- visible `label`
- optional `sourceComponentName`
- optional provenance

If a TOC control is rendered, every TOC item must resolve to one of these
registered section anchors.

## Overlay Layer Rule

Generated docs must render overlay specimens such as drawers, popups, and TOC
panels in a top-level overlay layer that is not clipped by the specimen card or
phone-frame container.

## Reusable Primitive Rule

When the source-backed page repeats a stable publisher surface such as a header,
menu overlay, search panel, account drawer, storyline rail, or icon set:

- create or reuse a primitive keyed by publisher, layout family, role, and variant
- keep article-specific copy, links, and asset URLs as instance data
- do not duplicate the full shell structure inline across multiple article
  config entries

## ai2html Fidelity Rules

- Preserve separate desktop and mobile overlay data.
- Convert overlay widths to percentage values for responsive rendering.
- Carry `marginTop` where present for baseline alignment.
- Treat baked-text images as baked content; do not recreate them with badge UI.

## Birdkit Fidelity Rules

- Extract the full SSR dataset, not just visible rows.
- Interactive table variants should preserve a stable row count and use
  placeholder rows when a selected option has fewer entries.
