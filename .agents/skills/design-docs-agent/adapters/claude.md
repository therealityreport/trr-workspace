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
| `delegate.parallel` | Claude subagents when available, otherwise sequential execution |
| `fs.edit` | Claude edit flow |
| `check.typecheck` | repo validation command via shell |

## Rule

Point Claude wrappers at the shared package and do not maintain a second full
implementation elsewhere. Preserve the shared package rules for saved bundles,
component-inventory provenance, interactive coverage, overlay layers, and
hosted-media validation rather than rewriting them in Claude-specific wrappers.
