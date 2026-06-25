---
name: capture-to-figma
description: Push a captured article (rendered HTML, golden screenshots, tokens, component and shell inventory) into a new Figma file as a pixel-faithful layout reference using the official Figma MCP.
user-invocable: false
metadata:
  version: 1.0.0
---

# Capture To Figma

## Purpose

Land a pixel-faithful Figma representation of a captured article so later steps
can reconcile against it and round-trip its tokens/structure back into renderer
code. The "HTML-to-Figma" capability is `generate_figma_design` **inside the
official Figma MCP** — there is no separate html-to-figma server. The
similarly-named `import-claude-design-from-url` is a Vercel tool and must not be
used here.

This skill is additive and optional. It produces a Figma reference layer; it is
never the source of truth (the rendered source always wins).

## Use When

1. The orchestrator is in the post-generation phase and a Figma reference is
   wanted for an article.
2. The Figma MCP is available and authenticated.

## Do Not Use For

1. Hosts where the Figma MCP is unavailable — skip and record
   `figma: { status: "skipped", reason: "figma-mcp-unavailable" }`.
2. Treating the Figma capture as authoritative over the rendered source.
3. `import-claude-design-from-url` (Vercel) — that does not push into Figma.

## Tool-Gating Prerequisites

These are mandatory or runtime Figma calls fail in hard-to-debug ways:

1. Load `/figma-create-new-file` **before** any `create_new_file` call.
2. Load `/figma-use` **before** any `use_figma` call.
3. Read-only tools (`search_design_system`, `get_variable_defs`,
   `get_design_context`) do **not** require a skill preload.
4. Playwright is disabled in this environment. Drive any external-URL capture
   through Chrome DevTools (or the already-saved rendered HTML), not Playwright.

## Inputs

- the captured bundle from `capture-rendered-source` (rendered HTML +
  `computed-styles.json`)
- golden images from `capture-golden-screenshots`
- token/component/shell inventory from the extraction wave
- canonical capabilities from `agents/openai.yaml`: `figma.create_file`,
  `figma.generate_design`, `figma.use`, `figma.search_design_system`,
  `figma.get_variable_defs`
- Figma plan/team key `team::1299838694470312290`

## Outputs

- `figma-reference.json` recorded into the source bundle:
  `fileKey`, `fileUrl`, `captureId`, `nodeId`, `status`, `reconciled`
- consumed downstream by `generate-article-page` via the `get_design_context`
  round-trip (improvement #8)

## Procedure

1. Load `/figma-create-new-file`, then `create_new_file` with
   `planKey: team::1299838694470312290` to obtain a `fileKey` for this article.
2. Load `/figma-use`.
3. Call `generate_figma_design` with that `fileKey` against the saved rendered
   capture (drive external-URL capture through Chrome DevTools, not Playwright).
   Poll the returned `captureId` until `status: completed`. This yields the
   pixel-faithful layout reference.
4. Optional higher-fidelity reconciliation: `use_figma` + `search_design_system`
   to rebuild the captured layout from real components and variables, reconciling
   against the pixel capture; `get_variable_defs` to read back cleaned tokens.
   Mark `reconciled: true` when done.
5. Record `figma-reference.json` (file key, url, capture id, node id, status)
   into the source bundle.

## Graceful Degradation

If the Figma MCP or the required skill preloads are unavailable, skip without
failing the pipeline and record
`figma: { status: "skipped", reason: "<missing-dependency>" }`. The article still
generates from the rendered source; only the Figma reference layer is absent.

## Rule

The Figma capture is a reference layer, not the source of truth. Source HTML and
the rendered capture always win on conflict. Keep `generate_figma_design` output
as a reference; when `use_figma` reconciliation matches it, the reconciled
components become the reusable artifact.
