# Codex Adapter

Host adapter for invoking the shared `design-docs-agent` package from Codex.

## Scope

This file defines Codex capability mapping and discovery assumptions only.
Workflow policy lives in package `SKILL.md`. The canonical runtime roster and
shared capability list live in `agents/openai.yaml`.

## Entry Surface

- shared skill discovery from `.agents/skills/design-docs-agent`
- OpenAI agent metadata from `agents/openai.yaml`
- saved source bundle inputs, source-map inputs, and screenshot-backed component
  inventory evidence

## Capability Mapping

| Shared capability | Codex behavior |
|---|---|
| `browser.navigate` | Codex Chrome or DevTools navigation |
| `browser.snapshot` | Codex snapshot or accessibility tree read |
| `browser.evaluate` | Codex in-page evaluation |
| `browser.network.list` | Codex network request listing |
| `browser.network.get` | Codex network request inspection |
| `browser.screenshot` | Codex screenshot capture |
| `delegate.parallel` | Codex delegation when useful, otherwise sequential execution |
| `fs.edit` | normal repo editing flow |
| `check.typecheck` | repo validation command via shell |

## NYT Capture Profile

For `nytimes.com` source acquisition, select the Chrome profile signed in as
`admin@thereality.report` before navigating or saving page files:

```bash
CODEX_CHROME_PREFERENCES_PATH="/Users/thomashulihan/Library/Application Support/Google/Chrome/Profile 11/Preferences"
```

When Profile 11 is already open and the Codex Chrome Extension is connected,
reuse the existing Profile 11 window or matching article tab first. Open a new
Profile 11 window only as a recovery step or when the user explicitly approves
it. Save complete page evidence when the site and browser tooling allow it.

## Rule

Codex should consume the canonical shared package directly and should not rely
on a duplicated implementation. Preserve the shared package rules for saved
bundles, component-inventory provenance, interactive coverage, overlay layers,
and hosted-media validation rather than redefining them in the plugin wrapper.
Acquisition behavior is documented once in package `SKILL.md`.
