---
name: harvest-network-assets
description: Enumerate every network-loaded asset and webfont from a rendered article session and mirror them into a categorized asset manifest.
user-invocable: false
metadata:
  version: 1.0.0
---

# Harvest Network Assets

## Purpose

Enumerate every asset the page actually loaded at runtime — images, webfonts,
stylesheets, media, and scripts — from the rendered browser session's network
log, then download and map each to a mirrored local path. This fixes the
`curl` bundle's known relative/missing asset-URL weakness and is what makes the
Mirrored Asset Manifest Rule (`references/rendering-contracts.md`) actually
satisfiable, including the webfonts that drive typographic fidelity.

This skill harvests and mirrors only. It does not classify icons/media into
renderer slots — that remains `extract-icons-and-media`, which consumes this
manifest.

## Use When

1. A rendered browser session is active (runs inside the
   `capture-rendered-source` session).
2. The orchestrator is in the `validation` phase.

## Do Not Use For

1. Icon/media semantic classification (that is `extract-icons-and-media`).
2. Hosts without a browser network log; record
   `networkAssetManifest: "unavailable"` and let `extract-icons-and-media` fall
   back to HTML/CSS URL scraping.

## Inputs

- the active navigated browser session from `capture-rendered-source`
- canonical capabilities from `agents/openai.yaml`: `browser.network.list`,
  `browser.network.get`
- `Bash` `curl` or `scrapling.get` for downloading resolved URLs

## Outputs

- `network-asset-manifest.json` — per asset:
  `absoluteUrl`, `type` (`image` | `font` | `stylesheet` | `media` | `script`),
  `mimeType`, `status`, `bytes`, `localPath`, `mirroredPath`, `role`,
  `failureReason?`
- downloaded asset files under
  `.agents/skills/design-docs-agent/source-bundles/<slug>/assets/`

## Procedure

1. List network requests via `browser.network.list`, filtered to
   `image`, `font`, `stylesheet`, `media`, and `script` resource types.
2. For each request, resolve the fully-qualified absolute URL and read details
   via `browser.network.get` (mime type, status, size).
3. Download each successful resource via `Bash` `curl` (or `scrapling.get` when
   blocked) into the bundle `assets/` subtree, preserving a stable filename.
4. Emit `network-asset-manifest.json` mapping each upstream `absoluteUrl` to its
   `mirroredPath`. When a resource cannot be downloaded, keep the entry and
   record `failureReason` plus the original URL, role, and dimensions.
5. Hand the manifest to `extract-icons-and-media` (Step 0: prefer
   network-captured CDN URLs over HTML/CSS-scraped relative URLs).

## Rule

Every displayed asset must trace to a mirrored local path or a recorded
`failureReason` — never to a live upstream URL in generated output. Webfonts are
first-class assets here: a missing font silently degrades typographic fidelity,
so capture and mirror `font` requests as deliberately as images.
