---
name: fetch-source-bundle
description: Acquire a schema-compliant saved source bundle from an article URL before validation when the caller did not supply one.
user-invocable: false
metadata:
  version: 2.0.0
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
3. Tier-1 rendered capture (`capture-rendered-source`) is unavailable on the
   host or failed its trust gate, so static/stealth fallback acquisition is
   needed.

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
- `scripts/fetch_source_bundle.py` (supports `--capture-method`,
  `--rendered-html-file`, `--browser-html-file`, `--browser-screenshot`)
- canonical capability `scrapling.stealthy_fetch` for tier-3 WAF/paywall
  fallback (degrade gracefully when the scrapling MCP is absent)

## Outputs

One of:

1. `sourceBundle` that conforms to `contracts/source-bundle.schema.json`
2. acquisition report that conforms to `contracts/acquisition-report.schema.json`

## Procedure

`fetch-source-bundle` owns acquisition **tiers 2 and 3**. Tier 1 (rendered-DOM
capture via Chrome DevTools) is owned by `capture-rendered-source`, which calls
this same helper with `--rendered-html-file`. Run this skill when tier 1 is
unavailable or failed its trust gate.

1. If the caller already supplied `sourceBundle`, return it unchanged.

2. **Tier 2 — static fetch.** Run the helper:

   ```bash
   python .agents/skills/design-docs-agent/scripts/fetch_source_bundle.py \
     --article-url "$ARTICLE_URL"
   ```

   On `status: "ok"`, pass the returned `sourceBundle` (with
   `captureMethod: "curl"`) to `validate-inputs`.

3. **Tier 2 browser fallback** — if the helper returns `needs-manual-bundle` and
   browser tooling is available, capture rendered HTML the same way
   `capture-rendered-source` does, then re-run the helper with
   `--rendered-html-file` (preferred) or `--browser-html-file`. Declared
   capabilities from `agents/openai.yaml`: `browser.navigate`,
   `browser.snapshot`, `browser.evaluate`, `browser.screenshot`,
   `browser.resize`. Browser fallback must:
   - for `nytimes.com`, use the `admin@thereality.report` Chrome profile
     (`Profile 11`,
     `/Users/thomashulihan/Library/Application Support/Google/Chrome/Profile 11/Preferences`);
     reuse an already-open Profile 11 window or matching article tab before
     opening a new one; set `CODEX_CHROME_PREFERENCES_PATH` to that path when
     using the Codex Chrome extension selector
   - open the URL, wait for DOM settle, inspect overlays, and remove obvious
     login/subscribe overlays only when the underlying content is already present
   - serialize `document.documentElement.outerHTML`, capture MHTML when
     `Page.captureSnapshot` is supported, save recoverable CSS/JS/media, and
     optionally one desktop screenshot

   ```bash
   python .agents/skills/design-docs-agent/scripts/fetch_source_bundle.py \
     --article-url "$ARTICLE_URL" \
     --rendered-html-file "$RENDERED_HTML_FILE" \
     --browser-screenshot "$DESKTOP_SCREENSHOT"
   ```

4. **Tier 3 — stealth fallback.** When the tiers above are blocked by
   WAF/Cloudflare/Turnstile/paywall challenges, acquire rendered HTML via
   `scrapling.stealthy_fetch` and a parity-backup screenshot via
   `scrapling.screenshot` (`full_page`), then re-run the helper with
   `--rendered-html-file` pointing at the scrapling-rendered HTML. Degrade
   gracefully (skip this tier) when the scrapling MCP is absent.

5. If every tier still returns `needs-manual-bundle`, stop before extraction and
   return the acquisition report plus manual upload instructions.

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

Record the `captureMethod` (`rendered` | `curl` | `browser` | `stealth`) and the
acquisition tier reached on the returned bundle so the Complete Article Coverage
Gate can reason about how complete acquisition was.

## Persistence Rules

Persist recovered artifacts under:

- `.agents/skills/design-docs-agent/source-bundles/<slug>/index.html`
- `.agents/skills/design-docs-agent/source-bundles/<slug>/page.mhtml`
- `.agents/skills/design-docs-agent/source-bundles/<slug>/assets/css/`
- `.agents/skills/design-docs-agent/source-bundles/<slug>/assets/js/`
- `.agents/skills/design-docs-agent/source-bundles/<slug>/assets/media/`
- `.agents/skills/design-docs-agent/source-bundles/<slug>/screenshots/`
- `.agents/skills/design-docs-agent/source-bundles/<slug>/source-bundle.json`

The returned `sourceBundle` must use local saved-artifact paths, not inline
file contents.

## Rule

Do not keep partial success hidden. If acquisition cannot recover trustworthy
article or interactive content, return the acquisition report and ask the user
for a manual upload.
