---
name: design-docs-agent
description: Canonical cross-host Design Docs agent for article ingestion, saved-source bundle extraction, generation, wiring, and brand sync.
---

# Design Docs Agent

Canonical cross-host orchestrator for generating or updating TRR design-docs pages from saved source bundles and source inventories. This package is the single behavioral source of truth for both Claude Code and Codex.

## Ownership Matrix

- `agents/openai.yaml` — canonical roster, status, order, and machine-readable metadata
- package `SKILL.md` — orchestration contract
- each owned subskill `SKILL.md` — execution contract for that skill
- `references/` — non-executable guidance, examples, lessons learned, and checklists
- plugin manifests and host adapters — host integration only, no independent behavioral truth

## Use When

1. A caller provides an `articleUrl` plus saved source bundle inputs and needs the shared Design Docs pipeline to add or update an article or brand.
2. A host needs the canonical extraction, generation, wiring, and verification sequence through one public entry point.

## Do Not Use For

1. Free-form article review with no intention to update TRR design docs.
2. One-off renderer changes unrelated to the Design Docs ingestion pipeline.
3. Live-browser-only scraping of gated articles without saved source inputs.

## Public entry policy

1. This package is the only public Design Docs entry point.
2. Extraction, generation, audit, sync, and wiring skills under this package are internal pipeline modules, not standalone public surfaces.
3. Host wrappers or slash-command adapters may call this package, but they must not redefine workflow policy.

## Inputs

The caller must provide:

```text
articleUrl: string
sourceBundle:
  canonicalSourceUrl: string
  html: string | { modeA?: string; modeB?: string; rendered?: string }
  css?: string[]
  js?: string[]
  manifests?: string[]
  har?: string
  screenshots?: { desktop?: string[]; mobile?: string[] }
  sourceTree?: { exportedPaths?: string[]; sourceMaps?: string[]; screenshots?: string[] }
  authoritativeViewport?: "desktop" | "mobile" | "both"
```

`sourceBundle.html` may be:
- A single browser-save HTML file path (Mode A)
- A single view-source HTML file path (Mode B)
- An object with both paths for two-source merging
- A rendered HTML capture accompanied by CSS, JS, or manifest files

The orchestrator may also use:

- discovered stylesheet URLs from `sourceBundle`
- discovered Datawrapper embeds, ai2html assets, and Birdkit containers
- discovered Birdkit arrow-chart containers
- optional screenshot-backed or source-map-backed component inventory evidence
- repo-local Design Docs config and pipeline types in `TRR-APP/apps/web`

See `references/source-html-modes.md` for paywall policy, parsing rules, two-source merging, saved-bundle rules, component-inventory provenance, and sub-agent delegation rules.

## Shared Capabilities

Use capability names inside this package. Host-specific mappings live in:

- `adapters/claude.md`
- `adapters/codex.md`

Capabilities:

- `browser.navigate`
- `browser.snapshot`
- `browser.evaluate`
- `browser.network.list`
- `browser.network.get`
- `browser.screenshot`
- `delegate.parallel`
- `fs.edit`
- `check.typecheck`

## Procedure

### 1. Validate Inputs And Detect Mode

1. Require both `articleUrl` and `sourceBundle`.
2. Read `TRR-APP/apps/web/src/lib/admin/design-docs-config.ts`.
3. Resolve one mode:
   - `add-article`
   - `add-first-article`
   - `create-brand`
   - `update-article`

### 1.5. Resolve Source HTML Mode And Paywall Policy

Before any extraction work, determine the source mode per `references/source-html-modes.md`.

1. Check paywall rules and require saved files for gated sources.
2. Identify whether supplied HTML is Mode A, Mode B, or a merged bundle.
3. Resolve rendered-vs-source authority for layout and component inventory.
4. Detect missing CDN paths or hydrated markup gaps before generation starts.
5. Allow live URLs only for explicitly allowed public supporting sources.

### 2. Discover Inputs

From `sourceBundle`, detect:

- stylesheet URLs and locally supplied CSS
- locally supplied JS chunks, manifests, and optional source maps
- Datawrapper embeds
- ai2html assets
- Birdkit containers
- scripts and media assets
- exported or screenshot-backed component inventory evidence

### 3. Classify Publisher Before Extraction

Run `classify-publisher-patterns` to produce:

- `PublisherClassification`
- `TechInventory`
- taxonomy routing hints for the 15-section system

### 4. Run The Extraction Wave

Run the extraction modules in parallel when the host supports delegation; otherwise run them sequentially with the same contracts.

### 5. Merge Extraction Outputs

Merge extraction output into the typed pipeline contract in `TRR-APP/apps/web/src/lib/admin/design-docs-pipeline-types.ts`.

### 6. Run The Generation Wave

1. Always run `generate-article-page`.
2. In `create-brand` mode, also run `generate-brand-section`.

### 7. Wire Shared Surfaces

Run `wire-config-and-routing` to update config, imports, and navigation/routing surfaces needed for the new or updated article or brand.

### 8. Run Verification Gates

Run this sequence:

1. `audit-generated-config-integrity`
2. `sync-brand-page`
3. `audit-responsive-accessibility`
4. `integration-test-runner`
5. `check.typecheck`
