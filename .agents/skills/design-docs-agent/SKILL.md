---
name: design-docs-agent
description: Canonical cross-host Design Docs agent for article ingestion, saved-source bundle extraction, generation, wiring, and brand sync.
metadata:
  version: 1.1.0
---

# Design Docs Agent

Canonical cross-host orchestrator for generating or updating TRR design-docs pages from saved source bundles and source inventories. This package is the single behavioral source of truth for both Claude Code and Codex.

## Ownership Matrix

- `agents/openai.yaml` — canonical runtime roster, phase order, shared capabilities, and per-skill metadata
- package `SKILL.md` — orchestration contract and public entry policy
- `contracts/` — canonical input, policy, and external dependency contracts
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
sourceBundle: contracts/source-bundle.schema.json
```

The orchestrator may also use:

- `contracts/source-bundle.schema.json` for source-bundle shape
- `contracts/publisher-policy.yaml` for paywall and live-fetch policy
- `contracts/external-app-contract.yaml` for the minimum asserted TRR-APP contract
- repo-local Design Docs config and pipeline types in `TRR-APP/apps/web`
- `references/source-html-modes.md` for human-readable parsing and authority guidance

## Shared Capabilities

Use the canonical capability names declared in `agents/openai.yaml`. Host-specific mappings live in `adapters/claude.md` and `adapters/codex.md`.

## Procedure

### 1. Validate Inputs And Detect Mode

Run the active `validation` phase from `agents/openai.yaml`. `validate-inputs` owns:

1. required-input checks for `articleUrl` and `sourceBundle`
2. mode detection for `add-article`, `add-first-article`, `create-brand`, and `update-article`
3. Mode A / Mode B / merged source resolution
4. paywall enforcement and live-supporting-source allowances
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

### 4. Run The Extraction Wave

Resolve the active `extraction` phase from `agents/openai.yaml`. Run those skills in order, in parallel when the host supports delegation and sequentially otherwise.

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

## Version Policy

Per-skill versions use semver:

- patch: wording or non-contract clarifications
- minor: additive input/output fields or additive behavior
- major: breaking input/output contract or behavior changes
