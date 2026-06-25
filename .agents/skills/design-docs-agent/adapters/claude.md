# Claude Adapter

Host adapter for invoking the shared `design-docs-agent` package from Claude
Code or Claude slash-command wrappers.

## Scope

This file defines Claude capability mapping and entry surfaces only. Workflow
policy lives in package `SKILL.md`. The canonical runtime roster and shared
capability list live in `agents/openai.yaml`.

## Entry Surface

- `/design-docs`
- `/design-docs-add-article` as a deprecated redirect to `/design-docs`
- saved source bundle inputs, source-map inputs, and screenshot-backed component
  inventory evidence

## Capability Mapping

| Shared capability | Claude behavior |
|---|---|
| `browser.navigate` | Chrome DevTools MCP page navigation |
| `browser.snapshot` | Chrome DevTools MCP snapshot or accessibility tree read |
| `browser.evaluate` | Chrome DevTools MCP script evaluation |
| `browser.network.list` | Chrome DevTools MCP network listing |
| `browser.network.get` | Chrome DevTools MCP network request inspection |
| `browser.screenshot` | Chrome DevTools MCP screenshot capture |
| `browser.resize` | Chrome DevTools MCP viewport resize/emulation |
| `browser.click` | Chrome DevTools MCP element click for stateful capture |
| `browser.hover` | Chrome DevTools MCP element hover for stateful capture |
| `figma.create_file` | Figma MCP `create_new_file` (preload `/figma-create-new-file`) |
| `figma.generate_design` | Figma MCP `generate_figma_design` HTML/URL-to-Figma capture |
| `figma.use` | Figma MCP `use_figma` write API (preload `/figma-use`) |
| `figma.search_design_system` | Figma MCP `search_design_system` (read-only) |
| `figma.get_variable_defs` | Figma MCP `get_variable_defs` token read (read-only) |
| `figma.get_design_context` | Figma MCP `get_design_context` round-trip (read-only) |
| `scrapling.stealthy_fetch` | Scrapling MCP `stealthy_fetch` for WAF/paywall fallback |
| `scrapling.screenshot` | Scrapling MCP full-page screenshot fallback |
| `delegate.parallel` | Claude subagents when available, otherwise sequential execution |
| `fs.edit` | Claude edit flow |
| `check.typecheck` | repo validation command via shell |

## Rule

Point Claude wrappers at the shared package and do not maintain a second full
implementation elsewhere. Preserve the shared package rules for saved bundles,
component-inventory provenance, interactive coverage, overlay layers, and
hosted-media validation rather than rewriting them in Claude-specific wrappers.
Acquisition behavior is documented once in package `SKILL.md`.
