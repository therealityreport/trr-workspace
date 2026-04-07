---
name: design-docs-agent
description: Canonical cross-host Design Docs agent for article ingestion, saved-source bundle extraction, generation, wiring, and brand sync.
---

# Design Docs Agent

Canonical cross-host orchestrator for generating or updating TRR design-docs
pages from saved source bundles and source inventories. This package is the
single behavioral source of truth for both Claude Code and Codex.

## Ownership Matrix

- `agents/openai.yaml` — canonical roster, status, order, and machine-readable metadata
- package `SKILL.md` — orchestration contract
- `skills/design-docs/SKILL.md` — user entry wrapper only
- each owned subskill `SKILL.md` — execution contract for that skill
- `references/` — non-executable guidance, examples, lessons learned, and checklists
- plugin manifests and host adapters — host integration only, no independent behavioral truth

## Use When

1. A caller provides an `articleUrl` plus saved source bundle inputs and needs
   the shared Design Docs pipeline to add or update an article or brand.
2. A host wrapper needs the canonical extraction, generation, wiring, and
   verification sequence.

## Do Not Use For

1. Free-form article review with no intention to update TRR design docs.
2. One-off renderer changes unrelated to the Design Docs ingestion pipeline.
3. Live-browser-only scraping of gated articles without saved source inputs.

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

See `references/source-html-modes.md` for paywall policy, parsing rules,
two-source merging, saved-bundle rules, component-inventory provenance, and
sub-agent delegation rules.

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

Before any extraction work, determine the source mode per
`references/source-html-modes.md`:

1. **Check paywall**: If `articleUrl` is from a paywalled domain (nytimes.com,
   theathletic.com, wsj.com, ft.com, theatlantic.com, bloomberg.com, or any
   subscription-gated site), live URL navigation is **prohibited**. Require a
   saved file. When in doubt, treat as paywall.
2. **Identify file mode**: Inspect the outer HTML of the supplied HTML file.
   - Outer `<html>` root → Mode A (browser-save).
   - Outer `<table class="highlight">` → Mode B (view-source); strip wrapper
     before parsing.
3. **Resolve authority split**:
   - Rendered-source authority for layout, sizing, class names, and media usage
     comes from saved HTML/CSS/JS.
   - Component-inventory authority comes from source maps, exported
     `webpack://` trees, or screenshot-backed module trees when present.
4. **Check for two-source need**: If Mode A image URLs are relative or missing
   CDN paths, flag that a Mode B companion is needed. Ask the user before
   proceeding if critical image assets are unresolvable.
5. **Hydrated-interactions coverage**: Check whether drawers, modals, tabs,
   accordions, portal targets, and popup markup are present in the supplied
   bundle. If the source shows an affordance but the saved bundle lacks the
   hydrated markup or state, flag it before generation.
6. **Non-paywall live URLs**: Permitted for Datawrapper embeds, public GitHub
   content, public data portals, and other openly accessible sources.
   See `references/source-html-modes.md` for the allowed list.

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

When delegating any extraction work to a background sub-agent, follow the
sub-agent delegation rules in `references/source-html-modes.md`:
- Pass the exact file path(s) in the prompt.
- Include verbatim: `"Do NOT navigate to any live URL. Use only the file path provided."`
- Include the required export name (derived from the article `id`).
- Include expected first and last entries for verification.
- Specify which source mode the file is.

Run the following in parallel when the host supports delegation; otherwise run
them sequentially with the same contracts:

1. `extract-css-tokens`
2. `extract-page-structure`
3. `extract-datawrapper-charts` when embeds exist
4. `extract-ai2html-artboards` when ai2html assets exist
5. `extract-quote-components` when quote/status sections exist
6. `extract-birdkit-tables` when Birdkit markup exists
7. `extract-birdkit-arrow-charts` when `.g-arrow-chart` or equivalent Birdkit
   arrow-comparison markup exists
8. `extract-icons-and-media`
9. `extract-navigation`
10. `extract-source-component-inventory` when source-tree evidence exists

### 5. Merge Extraction Outputs

Merge extraction output into the typed pipeline contract in
`TRR-APP/apps/web/src/lib/admin/design-docs-pipeline-types.ts`.

The merged payload must include:

- `blockCompleteness`
- `NavigationData`
- `PublisherClassification`
- `TechInventory`
- `SourceComponentInventory`
- renderer-ready data for every interactive artifact
- hosted-media asset metadata and section-anchor metadata when generated output
  requires overlays, TOC controls, or viewport-specific specimens

### 6. Run The Generation Wave

1. Always run `generate-article-page`.
2. In `create-brand` mode, also run `generate-brand-section`.

### 7. Wire Shared Surfaces

Run `wire-config-and-routing` to update config, imports, and navigation/routing
surfaces needed for the new or updated article or brand.

### 8. Run Verification Gates

Run this sequence:

1. `audit-generated-config-integrity`
2. `sync-brand-page`
3. `audit-responsive-accessibility`
4. `integration-test-runner`
5. `check.typecheck`

If any gate fails, fix the workflow output before reporting success.

## Validation

Before closeout, verify:

1. `contentBlocks` preserves document order.
2. `chartTypes` and renderer-ready data exist for every interactive artifact.
3. article fonts and colors are extracted from the current article.
4. brand tabs reflect article data through aggregation rather than article-specific hacks.
5. every mirrored asset used in rendered docs has both source provenance and a
   hosted-media URL.
6. generated files satisfy the repo-local validation commands or any remaining
   failures are explicitly reported.

Use `references/preflight-checklist.md` for the detailed closeout checklist.

## Stop And Escalate If

1. The caller does not provide `sourceBundle`.
2. A required interactive artifact cannot produce renderer-ready data.
3. The article mode cannot be resolved from repo state with reasonable confidence.
4. Verification fails and the remaining issue is outside the Design Docs pipeline scope.
5. The article URL is paywalled and no saved file is supplied — do not attempt
   live URL navigation; stop and ask the user to supply a saved file.
6. A sub-agent or background task navigated to a live URL instead of using the
   supplied saved file — treat any output from that agent as suspect, verify
   first/last data entries, and re-run extraction from the saved file if needed.
7. Screenshot-only component inventory is too partial to define docs coverage
   with confidence.
8. Source maps are referenced but unrecoverable and the missing modules would
   materially affect component coverage.
9. Only partial CSS is available, so source sizing or responsive behavior
   cannot be trusted.
10. Required interactive or overlay content is absent from the supplied saved
   bundle and cannot be recovered from companion sources.

## 22-Skill Structured Skillset

| # | Skill | Section | Notes |
|---|---|---|---|
| 1 | `senior-frontend` | supporting | external canonical owner |
| 2 | `senior-qa` | supporting | external canonical owner |
| 3 | `code-reviewer` | supporting | external canonical owner |
| 4 | `font-sync` | supporting | external canonical owner |
| 5 | `extract-page-structure` | owned | execution contract in `extract-page-structure/SKILL.md` |
| 6 | `extract-css-tokens` | owned | execution contract in `extract-css-tokens/SKILL.md` |
| 7 | `extract-icons-and-media` | owned | execution contract in `extract-icons-and-media/SKILL.md` |
| 8 | `extract-navigation` | owned | execution contract in `extract-navigation/SKILL.md` |
| 9 | `extract-source-component-inventory` | owned | execution contract in `extract-source-component-inventory/SKILL.md` |
| 10 | `classify-publisher-patterns` | owned | execution contract in `classify-publisher-patterns/SKILL.md` |
| 11 | `audit-generated-config-integrity` | owned | execution contract in `audit-generated-config-integrity/SKILL.md` |
| 12 | `extract-datawrapper-charts` | owned | execution contract in `extract-datawrapper-charts/SKILL.md` |
| 13 | `extract-birdkit-tables` | owned | execution contract in `extract-birdkit-tables/SKILL.md` |
| 14 | `extract-birdkit-arrow-charts` | owned | execution contract in `extract-birdkit-arrow-charts/SKILL.md` |
| 15 | `generate-article-page` | owned | execution contract in `generate-article-page/SKILL.md` |
| 16 | `sync-brand-page` | owned | execution contract in `sync-brand-page/SKILL.md` |
| 17 | `extract-ai2html-artboards` | owned | execution contract in `extract-ai2html-artboards/SKILL.md` |
| 18 | `extract-quote-components` | owned | execution contract in `extract-quote-components/SKILL.md` |
| 19 | `wire-config-and-routing` | owned | execution contract in `wire-config-and-routing/SKILL.md` |
| 20 | `generate-brand-section` | owned | execution contract in `generate-brand-section/SKILL.md` |
| 21 | `audit-responsive-accessibility` | owned | execution contract in `audit-responsive-accessibility/SKILL.md` |
| 22 | `integration-test-runner` | owned | execution contract in `integration-test-runner/SKILL.md` |

## References

- `references/README.md`
- `references/taxonomy.md`
- `references/birdkit-component-taxonomy.md`
- `references/rendering-contracts.md`
- `references/component-inventory-provenance.md`
- `references/reference-implementations.md`
- `references/lessons-learned.md`
- `references/preflight-checklist.md`
- `references/source-html-modes.md`

## Completion Contract

Return:

1. `resolved_mode`
2. `source_authority_summary`
3. `source_bundle_inventory_summary`
4. `source_component_inventory_summary`
5. `mirrored_asset_summary`
6. `hydrated_interaction_coverage_summary`
7. `files_changed`
8. `verification_results`
9. `warnings_or_follow_up`
