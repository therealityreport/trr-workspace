---
name: extract-social-share-assets
description: Extract named social/share image slots and dimensions from saved source bundles for Design Docs articles.
metadata:
  version: 1.1.0
---

# Extract Social Share Assets

## Purpose

Recover full social/share image sets from saved source bundles so Design Docs
pages can document the publisher's actual share-art coverage instead of falling
back to a single `ogImage`.

## Use When

1. The source bundle contains meta tags, JSON-LD, inline state, manifests, or
   HAR evidence with multiple share image variants.
2. The generator needs `architecture.publicAssets.socialImages`.

## Do Not Use For

1. Generic media extraction that does not need slot-aware share coverage.
2. Live scraping of paywalled pages.

## Inputs

- `articleUrl`
- `sourceBundle.html`
- optional local CSS, JS, manifests, or HAR files

Typed outputs land in:

- `TRR-APP/apps/web/src/lib/admin/design-docs-pipeline-types.ts`

## Outputs

- `socialShareAssets`
- slot names, dimensions, and aspect-ratio metadata
- provenance summary for each recovered asset

## Procedure

1. Scan meta tags for `og:image`, `twitter:image`, and publisher-specific share fields.
2. Scan inline JSON, JSON-LD, `__NEXT_DATA__`, and equivalent state blobs for
   image arrays or slot-specific asset references.
3. Inspect manifests, JS chunks, or HAR records when saved HTML alone is
   incomplete but the source bundle still contains explicit asset URLs.
4. Normalize recovered assets into named slots such as `facebookJumbo`,
   `video16x9-3000`, `video16x9-1600`, `google4x3`, and `square3x` when the
   source naming supports that mapping.
5. Preserve dimensions and ratios when recoverable from filenames, metadata, or
   explicit source fields.
6. Treat each recoverable share variant as its own asset record rather than
   collapsing everything into one fallback OG image.
7. Return a deduped, ordered social image set rather than a loose image list.

## Validation

1. Prefer explicit slot-specific evidence over generic `og:image` fallback.
2. Do not fabricate missing slot names or dimensions.
3. If only one fallback image is recoverable, label it as fallback rather than
   pretending a full slot set exists.
4. Preserve provenance strongly enough for validators to distinguish full share
   coverage from a single fallback asset.

## Stop And Escalate If

1. The saved bundle clearly references share art but strips all usable URLs.
2. Slot naming would depend on guesswork rather than source-backed filename or metadata evidence.

## Completion Contract

Return:

1. `social_share_assets`
2. `slot_coverage_summary`
3. `provenance_notes`
4. `warnings`
