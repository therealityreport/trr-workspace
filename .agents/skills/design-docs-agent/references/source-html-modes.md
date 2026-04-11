# Source HTML Modes And Source Authority

## Overview

Every Design Docs ingestion starts from a concrete saved source bundle. The
bundle mode determines how to parse the file, whether a live URL is permitted,
whether two-source merging is needed, how component inventory is recovered, and
what to do when assets or hydrated states are missing.

Always resolve the source mode before running the extraction wave.

Canonical paywall and live-fetch policy data lives in
`contracts/publisher-policy.yaml`. This file explains how to apply that policy;
it is not the canonical domain roster.

Record these fields up front:

- canonical source URL
- authoritative viewport: `desktop`, `mobile`, or `both`
- rendered-source authority inputs: HTML, CSS, JS, manifests, HAR
- component-inventory authority inputs: source maps, exported `webpack://`
  trees, screenshot-backed module trees
- hydrated-interaction coverage status

---

## Mode A: Browser-Save HTML

**How to identify**: The file has a normal `<html>` root. Images may reference a
`_files/` sibling directory or inline `data:` URIs.

**Parsing**: Standard HTML parsing. No wrapper to strip.

**Strengths**: Correct document structure, full text content, CSS class names,
layout hierarchy, portal targets, and runtime-visible interaction affordances.

**Weaknesses**: Image paths are often relative and may not resolve to CDN URLs
needed for production use. Headshots and logos may be missing absolute URLs.

---

## Mode B: View-Source HTML

**How to identify**: The file's outer structure is a `<table class="highlight">`
with rows of `<td class="line-content">` cells. This is Chrome's view-source
page serialized to disk.

**Parsing**: Strip the wrapper table entirely before parsing. Extract the text
content of each `<td class="line-content">` cell, join with newlines, then parse
the resulting HTML.

**Strengths**: Absolute CDN URLs are preserved exactly as they appeared in the
page source. Headshot URLs, logo URLs, script `src` attributes are all intact.

**Weaknesses**: Does not capture JS-rendered content that was not in the initial
server response.

---

## Mode C: Rendered Bundle With Companion Assets

**How to identify**: The caller supplies one or more HTML files plus linked CSS,
JS chunks, asset manifests, or a HAR from the same saved session.

**Parsing**: Treat the HTML as the rendered DOM authority. Resolve CSS and JS
paths relative to the saved bundle. When available, inspect `sourceMappingURL`
entries to recover original source module paths.

**Strengths**: Best source for layout fidelity, media discovery, responsive
breakpoints, overlay mounts, and runtime-injected asset URLs.

**Weaknesses**: The original source tree may still be unavailable if source maps
are stripped or blocked.

---

## Mode D: Live URL (fetch at runtime)

**Permitted for**: Non-paywall, publicly accessible sites only, and never as a
replacement for a required saved paywall bundle.

Examples of **ALLOWED** live URL targets:
- `datawrapper.de` embeds
- Public GitHub raw content
- Public government or open-data portals
- Any source that renders fully without authentication

Examples of **PROHIBITED** live URL targets:
- any host declared paywalled in `contracts/publisher-policy.yaml`
- Any site that requires a login or subscription to view the article

**When in doubt, treat as paywall.** Ask the user for a saved file instead.

---

## Two-Source Merging Pattern

Some paywall articles require two saved files to recover all data:

| Source | Use for |
|--------|---------|
| Browser-save (`Mode A`) | Text content, layout structure, CSS classes, player/data entries |
| View-source (`Mode B`) | Absolute CDN image URLs (headshots, logos, team images) |

**Merge strategy**: Extract content from the browser-save. Then extract absolute
image URLs from the view-source by matching filename patterns (e.g.,
`cdn-headshots.theathletic.com`, `static01.nyt.com`). Substitute relative URLs
in the content with their resolved absolute equivalents.

When the bundle also includes saved CSS or JS, those files outrank browser-save
guesses for media sizing, runtime asset injection, and responsive behavior.

---

## Dual-Authority Rules

Use two separate authorities and keep them explicit in output metadata:

### Rendered-source authority

Use saved HTML, CSS, JS, manifests, and HAR for:

- layout hierarchy
- responsive breakpoints and sizing
- media URLs and CSS `url(...)` references
- overlay containers, portal targets, and rendered affordances
- which viewport or state the saved bundle actually captures

### Component-inventory authority

Use source maps, DevTools `webpack://` exports, or screenshot-backed source
trees for:

- which source components or modules must be documented
- component provenance
- mapping source components to docs sections and anchors

If source maps are unavailable, screenshot-listed modules are an acceptable
minimum inventory, but they must be labeled as `screenshot-only` provenance.

---

## Hydrated-Interaction Coverage

Before generation, check whether the saved bundle contains the hydrated markup
or state for:

- drawers and collapsible groups
- modals or popup content
- tabs and active/inactive states
- accordions and expand/collapse states
- portal or overlay targets

If the source clearly shows the affordance but the saved bundle lacks the
hydrated markup or state needed to reproduce it safely, record the gap and
escalate before generation. Do not invent modal bodies, drawer items, or tab
content.

Treat the following as first-class source authority when present:

- masthead spacers and fixed header chrome
- storyline rails and local recirculation strips
- popup, modal, drawer, and search-panel bodies
- reusable SVG icons and shell glyphs
- slot-specific social/share image sets recovered from HTML, JSON, manifests,
  or HAR evidence

These surfaces are not optional extras. If they are recoverable from the saved
bundle, extraction and generation should preserve them as reusable primitives
or explicit article config data.

---

## Paywall Article Checklist

When the article URL is from a host declared paywalled in
`contracts/publisher-policy.yaml`:

1. Require the caller to supply at least one saved HTML file path.
2. Check whether the file is Mode A or Mode B by inspecting the outer HTML.
3. If image URLs in Mode A are relative or missing, ask for a Mode B companion
   file or use the missing-asset recovery flow below.
4. If responsive behavior, overlays, or asset sizing matter, prefer a saved
   bundle that also includes CSS, JS, or a HAR.
5. Never navigate to the live paywalled URL to supplement missing data.

---

## Missing Asset Recovery

When key assets (headshots, logos, CDN images) cannot be resolved from any
supplied saved file:

### Step 1 — Check embedded JSON and asset manifests

Scan `<script>` tags and `window.__NEXT_DATA__` / `window.__STATE__` blobs in
the saved HTML. Athletic, NYT, and similar publishers often embed player photo
URLs in a JSON payload inside the page. Also inspect local JS chunks and
manifests for source maps, asset tables, or runtime media URLs.

### Step 2 — Ask the user for a view-source companion

Ask:

> "Some image URLs in the browser-save are relative. Can you open the article,
> then choose View Source (⌘+Option+U), and save that page as a new file?
> That file will have the absolute CDN URLs I need."

### Step 3 — Ask the user for a DevTools Elements export

If step 2 is not available, ask:

> "Can you open Chrome DevTools (F12), find the player card section in the
> Elements panel, right-click the parent `<div>`, and choose 'Copy > Copy outer
> HTML'? Paste it here and I'll extract the image URLs from it."

### Step 4 — Ask the user for a DevTools Network export

If image URLs are loaded dynamically after page render, ask:

> "In Chrome DevTools, open the Network tab, reload the page, filter by 'Img',
> and export the requests as a HAR file (right-click > Save all as HAR with
> content). That will give me the exact CDN URLs."

### Step 5 — Ask the user for a DevTools Sources export

If component inventory or original source module names are missing, ask:

> "In Chrome DevTools, open the Sources panel and export the relevant
> `webpack://` / source-map-backed folders or screenshots of the module tree.
> That will let me recover the source component inventory separately from the
> rendered bundle."

### Step 6 — Proceed with explicit gaps if user cannot supply

If the user cannot provide any of the above, proceed without absolute image
URLs or full source-component inventory and note the gap in
`warnings_or_follow_up`.

---

## Sub-Agent Delegation Rules

When delegating data extraction to a background sub-agent:

1. **File path is mandatory.** Always pass the exact saved file path(s) in the
   prompt. Never assume the sub-agent will locate the file independently.
2. **Prohibit live URL navigation.** Include this in the prompt verbatim:
   `"Do NOT navigate to any live URL. Use only the file path provided."`
3. **Export name is mandatory.** Derive the export name from the article `id`
   field in `design-docs-config.ts`. Example: `nfl-free-agent-tracker-2026` →
   `NFL_FREE_AGENTS_2026`. Include the required export name in the prompt.
4. **Verification checkpoints are mandatory.** Include the expected first and
   last entries so the sub-agent can confirm correctness before writing.
5. **Include source mode.** Tell the sub-agent which mode the file is (A or B)
   and whether two-source merging is needed.
6. **Include authority split when relevant.** Tell the sub-agent which files
   provide rendered-source authority and which files provide
   component-inventory authority.

Example sub-agent prompt structure:

```
Task: Extract all player records from the saved HTML and write free-agent-data.ts.

Source file (Mode A, browser-save): /path/to/saved-page.html
Companion file (Mode B, view-source): /path/to/view-source.html
Export name: NFL_FREE_AGENTS_2026
Expected rank 1: Trey Hendrickson (Edge, Bengals → Ravens)
Expected rank 150: Tyrod Taylor (QB)

Rules:
- Do NOT navigate to any live URL.
- Use only the file paths above.
- After writing the file, read back the first and last entries to confirm.
```
