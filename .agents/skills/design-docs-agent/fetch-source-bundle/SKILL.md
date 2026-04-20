---
name: fetch-source-bundle
description: Acquire a schema-compliant saved source bundle from an article URL before validation when the caller did not supply one.
user-invocable: false
metadata:
  version: 1.0.0
---

# Fetch Source Bundle

## Purpose

Acquire a trustworthy saved source bundle from a live `articleUrl` so the
shared Design Docs package can proceed even when the caller did not manually
upload a bundle.

This skill owns live acquisition only. It does not perform extraction,
generation, or routing work.

## Use When

1. The orchestrator is in the `validation` phase.
2. A caller provided `articleUrl` but omitted `sourceBundle`.

## Do Not Use For

1. Extraction after a valid bundle already exists.
2. Replacing an explicitly supplied saved bundle.
3. Inventing content when live acquisition cannot recover trustworthy article
   or interactive markup.

## Inputs

- `articleUrl`
- optional `sourceBundle`
- `contracts/source-bundle.schema.json`
- `contracts/acquisition-report.schema.json`
- `contracts/publisher-policy.yaml`
- `scripts/fetch_source_bundle.py`

## Outputs

One of:

1. `sourceBundle` that conforms to `contracts/source-bundle.schema.json`
2. acquisition report that conforms to `contracts/acquisition-report.schema.json`

## Procedure

1. If the caller already supplied `sourceBundle`, return it unchanged and do not
   acquire anything.
2. Run the helper:

   ```bash
   python .agents/skills/design-docs-agent/scripts/fetch_source_bundle.py \
     --article-url "$ARTICLE_URL"
   ```

3. If the helper returns `status: "ok"`, pass the returned `sourceBundle` to
   `validate-inputs`.
4. If the helper returns `needs-manual-bundle` and browser tooling is
   available, attempt browser fallback with the declared capabilities from
   `agents/openai.yaml`:
   - `browser.navigate`
   - `browser.snapshot`
   - `browser.evaluate`
   - `browser.screenshot`
5. Browser fallback must:
   - open the article URL
   - wait for DOM settle
   - inspect visible page structure and blocking overlays
   - remove obvious login or subscribe overlays only when the underlying
     article or interactive content is already present in the DOM
   - serialize `document.documentElement.outerHTML` to a local temporary file
   - optionally capture one desktop screenshot
6. Re-run the helper with the browser-captured HTML:

   ```bash
   python .agents/skills/design-docs-agent/scripts/fetch_source_bundle.py \
     --article-url "$ARTICLE_URL" \
     --browser-html-file "$BROWSER_HTML_FILE" \
     --browser-screenshot "$DESKTOP_SCREENSHOT"
   ```

7. If browser fallback still returns `needs-manual-bundle`, stop before
   extraction and return the acquisition report plus manual upload instructions.

## Trustworthiness Gate

The helper is the canonical implementation of the acquisition heuristics. A
bundle is trustworthy only when all of these hold:

1. The recovered HTML is at least 10 KB.
2. The document contains article or interactive markers such as `<article>`,
   `<h1>`, JSON-LD `NewsArticle` / `Article`, or interactive SVG / canvas /
   chart markup.
3. Visible recovered text is substantial.
   - Prefer 1,500 non-whitespace visible characters.
   - If article markers are present and visible text is borderline but clearly
     non-empty, record a warning instead of hard-failing on character count
     alone.
4. Blocking copy such as “subscribe to read” or “sign in to continue” does not
   dominate the visible content.
   - Evaluate this against visible text only.
   - For browser capture, evaluate after overlay removal, not against the raw
     pre-removal DOM.

## Persistence Rules

Persist recovered artifacts under:

- `.agents/skills/design-docs-agent/source-bundles/<slug>/index.html`
- `.agents/skills/design-docs-agent/source-bundles/<slug>/assets/css/`
- `.agents/skills/design-docs-agent/source-bundles/<slug>/assets/js/`
- `.agents/skills/design-docs-agent/source-bundles/<slug>/screenshots/`

The returned `sourceBundle` must use local saved-artifact paths, not inline
file contents.

## Rule

Do not keep partial success hidden. If acquisition cannot recover trustworthy
article or interactive content, return the acquisition report and ask the user
for a manual upload.
