---
name: capture-golden-screenshots
description: Capture fixed-viewport full-page screenshots of a rendered article as the immutable pixel-parity baseline for later recreation verification.
user-invocable: false
metadata:
  version: 1.0.0
---

# Capture Golden Screenshots

## Purpose

Produce a falsifiable, fixed-viewport visual baseline ("golden" images) of the
original article as the browser rendered it. Without a golden image captured at
a known viewport and device-pixel-ratio, "pixel-exact" recreation is
unverifiable and the pipeline has no artifact to diff a recreation against.

This skill captures only. The actual parity comparison is owned by
`verify-source-fidelity` (and the pixel-parity gate). Generation never runs here.

## Use When

1. A rendered browser session is active (it runs inside the
   `capture-rendered-source` session, reusing the already-navigated page).
2. The orchestrator is in the `validation` phase and a bundle is being acquired
   via a real browser.

## Do Not Use For

1. Parity verification itself — that is a later verification-phase gate.
2. Acquisition trust decisions — those belong to the trust gate.
3. Hosts without a browser; record `goldenScreenshots: "unavailable"` and
   proceed using the `curl`/static path.

## Inputs

- the active navigated browser session from `capture-rendered-source`
- `articleUrl`
- canonical capabilities from `agents/openai.yaml`: `browser.resize`,
  `browser.screenshot` (plus host viewport emulation)
- the fixed viewport set (below)

## Viewport Set

Capture at these viewports unless the publisher policy overrides them. Record the
device-pixel-ratio used for each so diffs are valid:

| Label | Width x Height | DPR |
|---|---|---|
| desktop | 1440 x 900 | 2 |
| tablet | 768 x 1024 | 2 |
| mobile | 375 x 812 | 3 |

## Outputs

- `screenshots/golden-desktop.png`, `golden-tablet.png`, `golden-mobile.png`
- `screenshots-manifest.json` — per image: `label`, `viewport`, `dpr`,
  `renderedWidth`, `renderedHeight`, `path`, `sha256`, `capturedAt`

These paths are referenced by `references/rendering-contracts.md` as the
canonical parity baseline and consumed by the pixel-parity verification gate.

## Procedure

1. For each viewport in the set:
   1. Set the viewport and DPR via `browser.resize` / host viewport emulation.
   2. Allow a short settle so responsive layout and lazy media re-flow.
   3. Capture a full-page screenshot (`fullPage: true`) via `browser.screenshot`.
   4. Save to `screenshots/golden-<label>.png` and append a manifest entry with
      the rendered vs requested dimensions and a content hash.
2. When Chrome DevTools is unavailable but `scrapling` is, use
   `scrapling.screenshot` (`full_page`) as a secondary baseline and mark the
   manifest entry `source: "scrapling"`.
3. Write `screenshots-manifest.json` into the source bundle.

## Rule

Golden images are immutable baselines. Always capture at the documented
viewports and DPRs and record them in the manifest, so a later recreation can be
diffed against a like-for-like reference instead of a guess.
