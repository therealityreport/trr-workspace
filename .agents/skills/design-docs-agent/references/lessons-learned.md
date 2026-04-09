# Lessons Learned

## Per-Article Extraction

- Fonts and colors must be extracted independently for each article.
- If a generated article has byte-identical font or color payloads to another
  article, treat that as a likely extraction failure and re-check the source.
- Heading levels, especially `h2` and `h3`, must be extracted independently.

## Datawrapper

- Some Datawrapper embeds render as tables rather than charts.
- Recover both metadata and renderer-ready data wherever possible.
- If the dataset cannot be recovered for a required renderer, stop and report
  the gap instead of fabricating output.

## Birdkit

- Birdkit tables render their datasets server-side in SSR HTML.
- Preserve dropdown-driven data variants and stable row counts.

## ai2html

- Desktop and mobile artboards often differ materially.
- Overlay positioning depends on responsive width conversion and baseline offset.

## Brand Sync

- Brand tabs aggregate from `ARTICLES`.
- New article additions should update or create matching brand tab surfaces
  through shared aggregation rules, not one-off edits.

## Source HTML Modes

- Chrome's "Save Page As" (browser-save, Mode A) produces a full `<html>`
  document with relative image paths. Content is correct; CDN image URLs may
  not be.
- Chrome's view-source page saved to disk (Mode B) wraps all HTML in
  `<table class="highlight"><td class="line-content">` rows. Strip this wrapper
  before parsing. View-source preserves absolute CDN URLs exactly.
- When in doubt about which mode a file is, check the first tag in the file. If
  it is `<table` or `<html` determines the mode.

## Two-Source Merging For Athletic/NYT Articles

- The Athletic and NYT embed headshot and logo URLs as absolute CDN paths that
  only survive in the view-source file.
- The browser-save has complete text content (scouting notes, stats, contract
  values) but image URLs may be relative or missing.
- Merge strategy: extract all text content from the browser-save; extract CDN
  image URLs (matching hostnames like `cdn-headshots.theathletic.com`,
  `static01.nyt.com`) from the view-source companion and substitute them for
  relative paths in the output data.

## Sub-Agent Source Discipline

- Background sub-agents must receive the exact saved file path in their prompt.
  They cannot be trusted to locate the correct file on their own.
- A sub-agent that receives only an article URL may navigate to the live site
  and return data from the wrong year or wrong article entirely.
- Always include "Do NOT navigate to any live URL" verbatim in any sub-agent
  prompt that involves data extraction from a paywalled article.
- After a sub-agent writes a data file, verify the first and last entries
  before proceeding. A wrong first entry (e.g., Milton Williams instead of
  Trey Hendrickson) indicates the sub-agent used the wrong source.

## SVG Shape Replication

- Some publisher components use SVG `<polygon>` and `<polyline>` elements with
  precise `points` coordinates to create diagonal or parallelogram shapes (e.g.,
  Athletic filter card headers).
- Approximating these with CSS `clip-path`, `transform: skew()`, or
  `linear-gradient` will not match the original visual fidelity.
- Always extract the exact `points` attribute values from the source HTML and
  replicate them verbatim in the generated component.

## Wide Component Page Container Width

- The `ArticleDetailPage` outer container defaults to a narrow `maxWidth`. This
  breaks any component that needs the full viewport width (trackers, tables,
  large charts).
- When adding a `filter-card-tracker`, wide chart, or any full-bleed component,
  set `maxWidth: "100%"` on the page container in `ArticleDetailPage.tsx`.
- Apply the component-level max-width constraint (e.g., 1150px) inside the
  component component itself, not on the page wrapper.

## Saved Bundles Versus Source Trees

- A browser "Save Page As" bundle is often enough for rendered layout, CSS
  sizing, media URLs, and overlay mounts, but it does not guarantee the
  original source-component inventory.
- When the docs must enumerate source components, recover the inventory from
  source maps, DevTools `webpack://` exports, or screenshot-backed module trees
  and keep provenance explicit.
- Treat rendered-source authority and component-inventory authority as separate
  inputs. Do not let one silently stand in for the other.

## Hosted Media And Asset Classes

- Source-backed docs media should always render from mirrored hosted URLs, not
  directly from publisher URLs.
- Nav icons, card art, banner assets, progress states, and utility icons are
  not interchangeable. Reusing the wrong asset class causes obvious fidelity
  failures even when the file technically renders.
- If a slot-specific icon is missing, record the gap and escalate rather than
  reusing a different class of asset.

## Overlay And Interaction Fidelity

- If the source shows drawers, tabs, accordions, or popup affordances, the docs
  specimen should be interactive by default when the saved bundle contains the
  required hydrated markup.
- Overlay specimens must render in a top-level overlay layer above the specimen
  container. Otherwise menus, popups, and TOC panels get clipped and the docs
  stop being useful.
- When the saved bundle lacks the hydrated popup or drawer body, stop and ask
  for a better source capture instead of inventing the missing content.

## Reusable Publisher Primitives

- Once a source-backed publisher primitive exists, future article generations
  should instantiate it rather than rebuilding the same shell or icon cluster.
- NYT interactive headers, storyline rails, menu overlays, search panels,
  account drawers, and shell icons are stable enough to treat as reusable
  primitives when the saved bundle confirms the structure.
- Article-specific links, copy, and asset URLs should stay instance data layered
  onto the reused primitive, not fork the primitive definition.

## Social Share Image Completeness

- NYT interactive articles often expose multiple slot-specific social images in
  meta tags, JSON-LD, manifests, or saved bundle text.
- If a multi-slot set is recoverable, populate `architecture.publicAssets.socialImages`
  instead of falling back to a single `ogImage`.
- Missing share-slot coverage should be treated as a regression, not a cosmetic
  omission, because it changes both the Images section and the preferred docs
  preview image.
