---
name: design-docs
description: "Design Docs agent — ingest articles, extract design tokens, generate pages, sync brand tabs. Invoke with /design-docs <articleUrl>"
argument-hint: "<articleUrl> [saved source bundle path or sourceHtml path]"
user-invocable: true
---

# Design Docs Entry

User entry wrapper for the shared Design Docs package.

## Use When

1. A caller wants to run the shared Design Docs ingestion flow from a command surface.
2. The caller has an article URL plus optional saved source bundle inputs for a TRR design-docs update.

## Do Not Use For

1. Direct subskill invocation when the caller already knows the exact internal step.
2. Free-form article analysis with no intent to update TRR design docs.

## Inputs

- `articleUrl`
- optional saved source bundle input, saved HTML path, or equivalent caller-supplied `sourceBundle`

## NYT Source Capture Profile

For `nytimes.com` article acquisition, use the Chrome profile signed in as
`admin@thereality.report` when saving page source or complete page files.

- Chrome user data root: `/Users/thomashulihan/Library/Application Support/Google/Chrome`
- Profile directory: `Profile 11`
- Preferences file: `/Users/thomashulihan/Library/Application Support/Google/Chrome/Profile 11/Preferences`

When a Profile 11 window is already open and the Codex Chrome Extension is
connected, reuse that existing window or tab first. Do not open an additional
Chrome window unless the Chrome extension recovery flow requires it or the user
explicitly approves opening one.

When using the Codex Chrome extension profile selector for NYT capture, set:

```bash
CODEX_CHROME_PREFERENCES_PATH="/Users/thomashulihan/Library/Application Support/Google/Chrome/Profile 11/Preferences"
```

When using DevTools/CDP capture, attach to a browser using the same Chrome user
data root plus `--profile-directory="Profile 11"` if it is safe to do so, or
use a temporary copy for capture and delete it after the source bundle is saved.
Save complete evidence where available: rendered HTML, MHTML/Page.captureSnapshot,
desktop screenshot, resource tree/assets, and the source-bundle manifest.

## Procedure

1. Resolve the caller's `articleUrl` and source bundle input.
2. Load the canonical orchestrator at `design-docs-agent/SKILL.md`.
3. Hand off execution to the orchestrator without restating workflow rules.
4. Return the orchestrator completion contract.

## Coverage Floor

For NYT article work, do not stop after headline, typography, and a single
visible chart. The generated article page must include a source-backed or
explicitly degraded entry for every observed section, sticky header state,
menu/search/account shell, action icon group, body/ad/related/footer section,
and every chart/graph/table/media component. When exact source extraction is
blocked, preserve the component slot with a warning rather than omitting it.

Carry over the NYT/internal visualization tags used by comparable pages. If a
source or prior design-doc page identifies a visualization article with
`vis-design`, `data-vis`, or an equivalent data-visualization tag, add those
tags to the generated article instead of treating them as article-specific
topics.

For standard NYT story pages, the header capture must preserve the full
source-observed story header, not only the H1/deck. Capture and render the
section brand bar or section SVG, sponsor/support slot, headline, summary,
audio/listen module, share/gift/save/comment/more controls, byline, author
headshot, timestamp/date, and the CSS class/test-id evidence for those pieces.
When the source has a header like `header.css-1qv3lay`, recreate that structure
as a visible design-doc component.

Every generated article must include a body outline that shows the first
sentence or lead text for each source paragraph/section/chart lead-in. Do not
copy full article body text into the design docs; keep the outline to lead
sentences and component-level labels.

Every generated article must save and display an asset inventory. At minimum,
mirror or manifest all source-observed images, inline SVG icons, linked
favicons/app icons, audio/narration sources, Open Graph/Twitter images,
stylesheets, scripts, figures, and screenshots. If an asset cannot be mirrored,
record the original URL, role, dimensions, and failure reason in the manifest
and display the manifest count/details in the article page.

## Editable Chart Requirement

For NYT/Datawrapper chart work, do not leave the design-doc page as iframe-only
when chart data can be recovered. Match the interactive chart pattern used by
the Trump economy page: recreate charts as local React/SVG primitives backed by
editable config data.

For each recovered chart, capture and store:

1. Original embed id, version, iframe URL, source id, and public `data.csv`
   endpoint when available.
2. Editable chart spec: title, subtitle/leadin, chart mode, dimensions, axes,
   ticks, series or bar rows, colors, hover behavior, annotations/callouts,
   notes, source, credit, and original URL.
3. A source-backed warning only when a chart cannot be converted. Iframe-only
   rendering is acceptable as a fallback, not as the target state.

Every chart element that a future TRR chart author would naturally change must
live in config rather than inside an opaque iframe: marks, labels, scales,
colors, source/credit lines, notes, and annotations.

## Validation

1. Confirm `articleUrl` is present.
2. Confirm saved source input is supplied or can be resolved from the caller input.
3. Do not invent a parallel pipeline here; the orchestrator owns workflow policy.

## Stop And Escalate If

1. The caller provides no `articleUrl`.
2. The caller requests behavior that conflicts with the canonical orchestrator.

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
