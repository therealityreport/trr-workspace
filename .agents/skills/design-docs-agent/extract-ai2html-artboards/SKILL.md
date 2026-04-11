---
name: extract-ai2html-artboards
description: Extract ai2html artboard dimensions, images, and text overlays.
metadata:
  version: 1.0.0
---

# Extract ai2html Artboards

## Purpose

Extract structured ai2html artboard data so downstream renderers can recreate
responsive graphics with separate desktop and mobile fidelity.

## Use When

1. `sourceHtml` contains ai2html output.
2. The orchestrator needs artboard images, dimensions, or overlay data.

## Do Not Use For

1. Generic image extraction outside ai2html containers.
2. Datawrapper or Birdkit extraction.

## Inputs

- `sourceHtml`
- optional classification or page-structure hints

See `references/rendering-contracts.md` and `references/lessons-learned.md`
for fidelity rules.

## Outputs

- artboard records for each variant
- responsive image metadata
- overlay text or badge metadata when present

## Procedure

1. Locate ai2html containers and group nodes by artboard.
2. Extract desktop and mobile image sources, dimensions, and container names.
3. Extract overlay text nodes, positions, width hints, and baseline offsets.
4. Classify whether the asset behaves like a report card, flowchart, or other graphic.
5. Normalize overlay measurements for responsive rendering.

## Validation

1. Preserve distinct desktop and mobile variants.
2. Do not convert baked image text into recreated UI badges.
3. Carry baseline offsets and nowrap hints when present in source.

## Stop And Escalate If

1. Artboards are present but image sources cannot be resolved.
2. Overlay extraction is incomplete enough to make renderer output misleading.

## Completion Contract

Return:

1. `artboards`
2. `classification`
3. `overlay_summary`
4. `warnings`
5. `renderer_hints`
