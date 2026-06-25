---
name: capture-rendered-source
description: Acquire a rendered-DOM saved source bundle from an article URL using Chrome DevTools, capturing the live-rendered page, computed styles, and resource tree before validation.
user-invocable: false
metadata:
  version: 1.0.0
---

# Capture Rendered Source

## Purpose

Acquire a high-fidelity saved source bundle from a live `articleUrl` by loading
the page in a real browser engine and serializing the **rendered** DOM, computed
styles, and resource tree. This is the primary acquisition path for modern
article pages (NYT, The Athletic, NY Magazine) whose layout, shells, and charts
are rendered client-side and are therefore invisible to a plain `curl` fetch.

This skill owns rendered live acquisition only. It does not perform extraction,
generation, or routing work. It produces the same `sourceBundle` shape as
`fetch-source-bundle` so downstream skills are unchanged.

## Use When

1. The orchestrator is in the `validation` phase.
2. A caller provided `articleUrl` but omitted `sourceBundle`.
3. Chrome DevTools browser capabilities are available on the host.

## Do Not Use For

1. Extraction after a valid bundle already exists.
2. Replacing an explicitly supplied saved bundle.
3. Static-only acquisition on hosts without a browser — that is the `curl`
   fallback owned by `fetch-source-bundle`.
4. Inventing content when live acquisition cannot recover trustworthy markup.

## Acquisition Ladder Position

This skill is **tier 1** of the acquisition ladder owned jointly with
`fetch-source-bundle`:

1. `capture-rendered-source` (this skill) — rendered DOM via Chrome DevTools.
2. `fetch-source-bundle` `curl` path — static HTML fallback when no browser is
   available or rendered capture fails its trust gate.
3. `scrapling.stealthy_fetch` — WAF/Cloudflare/Turnstile/paywall fallback when
   both tiers above are blocked.

When Chrome DevTools capabilities are absent, skip directly to tier 2 and record
`captureMethod: "curl"`; do not hard-fail.

## Inputs

- `articleUrl`
- `contracts/source-bundle.schema.json`
- `contracts/acquisition-report.schema.json`
- `contracts/publisher-policy.yaml`
- `scripts/fetch_source_bundle.py` (invoked with `--capture-method rendered`
  and `--rendered-html-file`)
- canonical browser capabilities from `agents/openai.yaml`:
  `browser.navigate`, `browser.snapshot`, `browser.evaluate`,
  `browser.network.list`, `browser.network.get`, `browser.screenshot`,
  `browser.resize`

## Outputs

One of:

1. `sourceBundle` that conforms to `contracts/source-bundle.schema.json`, with
   `captureMethod: "rendered"` and a `captureMetadata` record (engine, viewport,
   wait strategy, overlay removals, timestamps).
2. A fall-through signal to tier 2 (`captureMethod: "curl"`) when rendered
   capture is unavailable or fails the trust gate.
3. An acquisition report from `contracts/acquisition-report.schema.json` only
   after every ladder tier has been exhausted.

This skill also produces, in the same browser session, the inputs consumed by
its sibling capture skills:

- `capture-golden-screenshots` reuses this navigated session for fixed-viewport
  full-page screenshots.
- `harvest-network-assets` reuses this session's network log for the asset and
  webfont manifest.

## Procedure

1. If the caller already supplied `sourceBundle`, return it unchanged.
2. Confirm browser capabilities are available. If not, record
   `captureMethod: "curl"` and hand off to `fetch-source-bundle` tier 2.
3. For `nytimes.com`, select the `admin@thereality.report` Chrome profile
   (`Profile 11`), reusing an already-open Profile 11 window or matching article
   tab before opening a new one. See `adapters/codex.md` for the
   `CODEX_CHROME_PREFERENCES_PATH` value.
4. `browser.navigate` to `articleUrl`.
5. Wait for the page to settle: prefer a network-idle wait
   (`browser.wait_for` / equivalent), then a short DOM-settle pause so
   client-rendered shells, charts, and lazy media mount.
6. Inspect visible structure and blocking overlays with `browser.snapshot`.
   Remove obvious login/subscribe overlays **only** when the underlying article
   or interactive content is already present in the DOM.
7. Harvest computed styles for fidelity: with `browser.evaluate`, run
   `getComputedStyle` over the structural nodes (shell, header, headline/deck,
   body sections, every chart/figure/table container, footer) and serialize the
   exact font-family, font-size, line-height, weight, color, background,
   spacing, and stacking values to `computed-styles.json`.
8. Serialize `document.documentElement.outerHTML` to a local temporary file
   after overlay removal.
9. Capture a complete MHTML snapshot when DevTools supports `Page.captureSnapshot`,
   and save the recoverable CSS, JS, media, and resource-tree files alongside
   the rendered HTML.
10. Trigger the sibling capture skills against the same session:
    `capture-golden-screenshots` (fixed viewports) and `harvest-network-assets`
    (network-driven asset/webfont manifest).
11. Re-run the helper to assemble and validate the bundle:

    ```bash
    python .agents/skills/design-docs-agent/scripts/fetch_source_bundle.py \
      --article-url "$ARTICLE_URL" \
      --capture-method rendered \
      --rendered-html-file "$RENDERED_HTML_FILE" \
      --browser-screenshot "$DESKTOP_SCREENSHOT"
    ```

12. If the helper returns `status: "ok"`, pass the returned `sourceBundle` to
    `validate-inputs`.
13. If the rendered bundle fails the trust gate, fall to tier 2
    (`fetch-source-bundle` `curl`), then tier 3 (`scrapling.stealthy_fetch`).
    Only return an acquisition report after all tiers fail.

## Trustworthiness Gate

Apply the same canonical trust heuristics as `fetch-source-bundle` (HTML size,
article/interactive markers, substantial visible text, no dominant blocking
copy). For rendered capture, evaluate visible text and blocking copy **after**
overlay removal, not against the pre-removal DOM. Record `captureMethod` and the
tier reached in the bundle so the Complete Article Coverage Gate can reason about
acquisition completeness.

## Persistence Rules

Persist recovered artifacts under the same layout as `fetch-source-bundle`:

- `.agents/skills/design-docs-agent/source-bundles/<slug>/index.html`
- `.agents/skills/design-docs-agent/source-bundles/<slug>/page.mhtml`
- `.agents/skills/design-docs-agent/source-bundles/<slug>/computed-styles.json`
- `.agents/skills/design-docs-agent/source-bundles/<slug>/assets/css/`
- `.agents/skills/design-docs-agent/source-bundles/<slug>/assets/js/`
- `.agents/skills/design-docs-agent/source-bundles/<slug>/assets/media/`
- `.agents/skills/design-docs-agent/source-bundles/<slug>/screenshots/`
- `.agents/skills/design-docs-agent/source-bundles/<slug>/source-bundle.json`

The returned `sourceBundle` must use local saved-artifact paths, not inline file
contents.

## Rule

The rendered source is the authority. Capture what the browser actually
rendered; never fabricate structure, styles, or assets. If rendered capture and
every fallback tier fail to recover trustworthy content, return the acquisition
report and ask the user for a manual upload rather than degrading silently.
