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

## Rule

Codex should consume the canonical shared package directly and should not rely
on a duplicated implementation. Preserve the shared package rules for saved
bundles, component-inventory provenance, interactive coverage, overlay layers,
and hosted-media validation rather than redefining them in the plugin wrapper.
