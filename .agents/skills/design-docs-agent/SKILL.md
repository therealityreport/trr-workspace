---
name: design-docs-agent
description: Canonical cross-host Design Docs agent for article ingestion, saved-source bundle extraction, generation, wiring, and brand sync.
user-invocable: true
metadata:
  version: 1.4.0
---

# Design Docs Agent

Canonical cross-host orchestrator for generating or updating TRR design-docs pages from article URLs, saved source bundles, and source inventories. This package is the single behavioral source of truth for both Claude Code and Codex.

Acquisition dependency: bespoke-interactive fidelity assumes the acquisition path in `fetch-source-bundle` has already landed. When acquisition is unavailable, the package may still run against a caller-supplied bundle, but fidelity coverage must degrade gracefully instead of fabricating source-faithful output.

## Ownership Matrix

- `agents/openai.yaml` — canonical runtime roster, phase order, shared capabilities, and per-skill metadata
- package `SKILL.md` — orchestration contract and public entry policy
- `contracts/` — canonical input, policy, and external dependency contracts
- each owned subskill `SKILL.md` — execution contract for that skill
- `references/` — non-executable guidance, examples, lessons learned, and checklists
- plugin manifests and host adapters — host integration only, no independent behavioral truth

## Use When

1. A caller provides an `articleUrl` with an optional saved source bundle and needs the shared Design Docs pipeline to add or update an article or brand.
2. A host needs the canonical extraction, generation, wiring, and verification sequence through one public entry point.

## Do Not Use For

1. Free-form article review with no intention to update TRR design docs.
2. One-off renderer changes unrelated to the Design Docs ingestion pipeline.
3. Inventing article content after live acquisition failed to recover a trustworthy bundle.

## Public entry policy

1. This package is the only public Design Docs entry point.
2. `skills/design-docs/SKILL.md` is the only user wrapper surface.
3. Extraction, generation, audit, sync, and wiring skills under this package are internal pipeline modules, not standalone public surfaces.
4. Host wrappers or slash-command adapters may call this package, but they must not redefine workflow policy.

## Inputs

The caller must provide:

```text
articleUrl: string
sourceBundle?: contracts/source-bundle.schema.json
```

The orchestrator may also use:

- `contracts/source-bundle.schema.json` for source-bundle shape
- `contracts/acquisition-report.schema.json` for blocking live-acquisition failures
- `contracts/publisher-policy.yaml` for paywall and live-fetch policy
- `contracts/external-app-contract.yaml` for the minimum asserted TRR-APP contract
- repo-local Design Docs config and pipeline types in `TRR-APP/apps/web`
- `references/source-html-modes.md` for human-readable parsing and authority guidance

## Shared Capabilities

Use the canonical capability names declared in `agents/openai.yaml`. Host-specific mappings live in `adapters/claude.md` and `adapters/codex.md`.

## Acquisition Contract

When `sourceBundle` is absent, `fetch-source-bundle` owns acquisition behavior.

1. Attempt shell acquisition first with `curl` and the package helper script.
2. If shell acquisition is insufficient and browser tooling is available, attempt browser fallback.
   - For `nytimes.com`, browser fallback must use the `admin@thereality.report`
     Chrome profile, resolved on this machine as Chrome `Profile 11` under
     `/Users/thomashulihan/Library/Application Support/Google/Chrome`.
   - Reuse an already-open Profile 11 Chrome window or tab first when the
     Codex Chrome Extension is connected. Open a new Profile 11 window only as
     a recovery step or when the user explicitly approves it.
3. Return a schema-compliant `sourceBundle` on success.
4. Return a blocking acquisition report from `contracts/acquisition-report.schema.json` on failure.

## Complete Article Coverage Gate

Article reconstruction is incomplete unless every source-observed page section,
component family, media item, and interaction surface has a matching Design Docs
entry. A page may degrade on exact values when capture is partial, but it must
not silently omit whole sections.

For NYT articles, the inventory must explicitly cover:

1. global shell: sticky header, masthead, hamburger menu, search panel, account
   drawer, subscribe/login controls, section label, and mobile header variants
2. article header: kicker/section, headline, deck, byline, timestamp, correction
   labels, audio/listen control, and every share/save/comment/gift/more action
3. body structure: every paragraph cluster, subhed, ad slot, newsletter or
   promotional insert, related link, reporting credit, author bio, and article
   footer region observed in the source bundle
4. charts/graphs/tables: every SVG/canvas/image/table/chart container,
   including sticky or scroll-triggered chart states, titles, subtitles, labels,
   sources, credits, annotations, mobile variants, and whether the chart is
   live-rendered or image-backed
5. assets and stack: all content images, social images, icons, CSS files, JS
   chunks, framework/runtime signals, hydration markers, analytics/runtime
   scripts, and extension inventories from Blue Button, CSS Peeper, BuiltWith,
   or Wappalyzer when provided

If browser or extension capture is unavailable, list the missing source
authority in `degraded_findings` and still create placeholder coverage entries
for every known component family instead of treating the page as complete.

## Chart Extraction Routing Gate

Do not jump from "chart present" directly to a generic placeholder. Before
generation, classify every chart/graph/table/media figure by source technology
and run the matching extraction path:

1. Datawrapper embeds (`datawrapper.dwcdn.net`, `iframe[src*="datawrapper"]`,
   Datawrapper bootstrap scripts) -> the Datawrapper chart extractor in the
   extraction roster
2. Birdkit tables or arrow/comparison charts (`g-table`, `g-arrow-chart`,
   `g-arrow-row`, screen-reader chart prose, or equivalent `g-*` chart
   wrappers) -> the Birdkit table or arrow-chart extractor in the extraction
   roster
3. ai2html output (`ai2html`, `g-ai`, artboard wrappers, generated image
   artboards with HTML overlays) -> the ai2html artboard extractor in the
   extraction roster
4. Custom SVG/canvas/div/image charts, including NYT Upshot custom charts ->
   the visual-contract and source-component inventory extraction paths
5. Static chart images -> extract visible title, subtitle, labels, source,
   credit, dimensions, and image URL from saved HTML, screenshots, accessible
   text, or OCR/vision evidence when available

Every chart slot must carry a `chartExtractionAttempt` summary naming the
detectors tried, extractor used, evidence recovered, and remaining gap. A
degraded placeholder is allowed only after this routing gate has run and must
state why renderer-ready data could not be recovered. If the source bundle is
complete enough to run an extractor but the extractor was skipped, treat that
as a blocking finding.

## Procedure

### 1. Validate Inputs And Detect Mode

Run the active `validation` phase from `agents/openai.yaml`.

1. `fetch-source-bundle` runs first when `sourceBundle` is absent.
   - Follow the shared acquisition contract above.
2. `validate-inputs` runs after a bundle exists, whether that bundle came from
   the caller or from `fetch-source-bundle`.

`validate-inputs` owns:

1. required-input checks for `articleUrl` and a resolved bundle
2. mode detection for `add-article`, `add-first-article`, `create-brand`, and `update-article`
3. Mode A / Mode B / merged source resolution
4. validation of local saved-artifact paths in `sourceBundle`
5. preflight assertions against `contracts/external-app-contract.yaml`

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

Run the active `pre-extraction` phase from `agents/openai.yaml`. `classify-publisher-patterns` produces:

- `PublisherClassification`
- `TechInventory`
- taxonomy routing hints for the 15-section system
- bespoke-interactive detection signals and `requiresVisualContract`

### 4. Run The Extraction Wave

Resolve the active `extraction` phase from `agents/openai.yaml`. Run those skills in order, in parallel when the host supports delegation and sequentially otherwise.

Fidelity rule: extraction skills emit their normal payloads plus fidelity evidence. Do not insert a separate contract-synthesis phase. The visual-contract extractor stays additive to the existing extraction wave rather than becoming a new bottleneck phase.

### 5. Merge Extraction Outputs

Merge extraction output into the typed pipeline contract asserted by `contracts/external-app-contract.yaml` and implemented in `TRR-APP/apps/web/src/lib/admin/design-docs-pipeline-types.ts`.

### 6. Run The Generation Wave

Resolve the active `generation` phase from `agents/openai.yaml`.

1. Always run `generate-article-page`.
2. Run `generate-brand-section` only in `create-brand` mode.

### 7. Wire Shared Surfaces

Resolve the active `wiring` phase from `agents/openai.yaml`. `wire-config-and-routing` updates config, imports, and navigation/routing surfaces needed for the new or updated article or brand.

### 8. Run Verification Gates

Resolve the `verification` pipeline members from `agents/openai.yaml` and run them in order. Do not re-enumerate verification skills here.

Verification severity model:

- `blocking` findings stop the pipeline because the generated output would be factually wrong or visibly misleading.
- `degraded` findings warn and proceed so partially recoverable bundles do not fail wholesale in v1.

Legacy handling:

- `ArticleVisualContract` is required for newly ingested or re-ingested bespoke interactives.
- Existing already-generated articles may continue under `legacyFidelityMode` until they are reprocessed.

## Version Policy

Per-skill versions use semver:

- patch: wording or non-contract clarifications
- minor: additive input/output fields or additive behavior
- major: breaking input/output contract or behavior changes
