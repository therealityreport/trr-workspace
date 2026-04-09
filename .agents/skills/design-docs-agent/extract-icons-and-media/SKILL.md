---
name: extract-icons-and-media
description: Extract SVG icons, logos, avatars, and embedded media from saved source bundles for design system documentation
---

# Extract Icons And Media

## Purpose

Extract icon and media assets from saved source bundles so the Design Docs
system can document brand assets and media usage without relying on a live DOM.

## Use When

1. The extraction wave needs icons, logos, avatars, favicons, embedded images,
   or CSS background assets.
2. A source article includes SVG or image assets relevant to brand docs.

## Do Not Use For

1. Live-browser-only asset inspection when the same asset is absent from the supplied saved sources.
2. ai2html, Birdkit, or Datawrapper-specific extraction.

## Inputs

- `sourceBundle`
- optional article or brand context

## Outputs

- structured asset manifest
- classification by asset type and usage class
- deduped SVG, image, and CSS asset references
- source inventory and mirroring follow-up tasks when needed

## Procedure

1. Parse saved HTML for SVGs, logos, avatars, favicons, embedded images, and
   source URLs present in inline JSON.
2. Parse saved CSS for `url(...)` references and normalize relative asset paths
   into absolute upstream URLs when the bundle provides enough evidence.
3. Classify assets by usage class: nav/page icons, card illustrations,
   promo/banner assets, progress states, and utility icons.
4. Deduplicate repeated SVG, image, and CSS asset references without collapsing
   distinct usage classes into one record.
5. Record source URLs, embedded payloads, or CSS provenance needed for
   follow-up hosted-media mirroring.
6. Feed reusable SVG and icon findings into the reusable-primitive layer rather
   than leaving header, search, close, account, or menu icons as loose assets only.
7. Return a normalized asset manifest and typed source inventory for downstream
   documentation.

## Validation

1. Work only from supplied saved sources unless the caller explicitly provides
   extra asset input.
2. Do not fabricate asset labels or brand roles that are not evidenced in source.
3. Do not silently reuse the wrong asset class for a missing slot-specific
   source asset.
4. Preserve enough provenance for downstream hosted-media mirroring and docs
   display metadata.
5. Distinguish loose media assets from reusable shell/icon primitives so future
   article generations can reuse source-backed UI chrome.

## Missing Asset Recovery

When key assets (headshots, player photos, team logos, CDN images) cannot be
resolved from the supplied saved sources, work through these steps in order
before escalating:

### 1. Check embedded JSON blobs

Scan `<script>` tags for `window.__NEXT_DATA__`, `window.__STATE__`, or any
inline JSON. Athletic, NYT, and similar publishers often embed all player photo
URLs in a JSON payload in the page. Extract image URLs from there.

### 2. Check for a companion view-source file

If the caller supplied a browser-save (Mode A) and image paths are relative,
ask:

> "Some image URLs in the saved page are relative paths rather than absolute
> CDN URLs. Can you open the article in Chrome, press ⌘+Option+U (or
> Ctrl+U) to open View Source, and save that page as a new file? Paste the
> file path here and I'll extract the absolute CDN URLs from it."

### 3. Ask for a DevTools Elements copy

If a view-source companion is not available, ask:

> "Can you open Chrome DevTools (F12 or ⌘+Option+I), find the section in
> the Elements panel that contains the player cards (or the relevant component),
> right-click the parent element, and choose **Copy > Copy outer HTML**?
> Paste it here and I'll extract the image URLs from it."

### 4. Ask for a DevTools Network HAR

If image URLs are loaded dynamically after the initial page render, ask:

> "In Chrome DevTools, open the **Network** tab, reload the article page,
> filter requests by **Img**, then right-click any request and choose
> **Save all as HAR with content**. Send me that HAR file path and I'll
> pull the exact CDN image URLs from it."

### 5. Proceed without images

If the user cannot supply any of the above, proceed with empty/placeholder
image URLs and add a clear entry to `warnings_or_follow_up` listing which
assets are missing and which recovery step the user should try.

**Do not fabricate CDN URLs or guess at image paths.**

## Stop And Escalate If

1. Key assets are referenced but cannot be resolved from the supplied saved sources AND all
   recovery steps above have been offered and the user cannot provide the files.
2. Asset classification would depend on guesswork rather than source evidence.

## Completion Contract

Return:

1. `assets`
2. `classification_summary`
3. `dedupe_summary`
4. `source_inventory`
5. `follow_up_tasks`
6. `warnings`
