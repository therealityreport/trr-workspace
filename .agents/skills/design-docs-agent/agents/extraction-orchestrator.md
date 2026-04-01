---
identifier: extraction-orchestrator
whenToUse: "Use when running the extraction wave for a Design Docs article ingestion."
model: sonnet
tools: ["Read", "Grep", "Glob", "Bash", "Agent"]
---

# Extraction Orchestrator

Helper agent for the extraction wave only.

## Scope

- Read package `SKILL.md` for the canonical workflow.
- Run only the extraction-phase owned skills that apply to the current article.
- Merge their outputs into the shared extraction payload.

## Execution Order

1. **Resolve source bundle mode and authority split** before any extraction work:
   - Inspect the outer HTML of the supplied file.
     - Normal `<html>` root → Mode A (browser-save). Parse as-is.
     - Outer `<table class="highlight">` → Mode B (view-source). Strip the
       wrapper table before parsing; extract inner HTML from
       `<td class="line-content">` cells.
   - If CSS, JS, manifests, HAR, source maps, or screenshot-backed module trees
     were supplied, record which files provide rendered-source authority and
     which provide component-inventory authority.
   - Check paywall status of `articleUrl`. If paywalled (nytimes.com,
     theathletic.com, wsj.com, ft.com, theatlantic.com, bloomberg.com, or any
     subscription-gated site), confirm a saved file is present. Do NOT fetch
     the live URL. When in doubt, treat as paywall.
   - If image paths in a Mode A file are relative or missing CDN hostnames,
     flag the gap now. Ask the user for a Mode B companion or initiate the
     missing-asset recovery flow in `extract-icons-and-media` before proceeding.
   - For non-paywall embeds (Datawrapper, public GitHub, open-data portals),
     live URL fetching is permitted.
   - Check hydrated-interaction coverage for tabs, drawers, modals, accordions,
     and overlay targets before generation.
   - See `references/source-html-modes.md` for the full paywall list, parsing
     rules, two-source merging pattern, authority split, and sub-agent
     delegation rules.

2. Run `classify-publisher-patterns`.
3. Run the applicable extraction skills in parallel when the host allows it:
   - `extract-css-tokens`
   - `extract-page-structure`
   - `extract-datawrapper-charts`
   - `extract-ai2html-artboards`
   - `extract-quote-components`
   - `extract-birdkit-tables`
   - `extract-icons-and-media`
   - `extract-navigation`
   - `extract-source-component-inventory`
4. Return the merged extraction payload and any warnings.

## Rule

Do not redefine extraction policy here. Detailed execution contracts live in the
subskill `SKILL.md` files and shared references.
