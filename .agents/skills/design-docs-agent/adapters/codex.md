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
| `browser.resize` | Codex viewport resize/emulation |
| `browser.click` | Codex element click for stateful capture |
| `browser.hover` | Codex element hover for stateful capture |
| `figma.create_file` | Figma MCP `create_new_file` (preload `/figma-create-new-file`) |
| `figma.generate_design` | Figma MCP `generate_figma_design` HTML/URL-to-Figma capture |
| `figma.use` | Figma MCP `use_figma` write API (preload `/figma-use`) |
| `figma.search_design_system` | Figma MCP `search_design_system` (read-only) |
| `figma.get_variable_defs` | Figma MCP `get_variable_defs` token read (read-only) |
| `figma.get_design_context` | Figma MCP `get_design_context` round-trip (read-only) |
| `scrapling.stealthy_fetch` | Scrapling MCP `stealthy_fetch` for WAF/paywall fallback |
| `scrapling.screenshot` | Scrapling MCP full-page screenshot fallback |
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
