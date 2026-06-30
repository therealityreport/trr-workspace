# TRR Codebase Map Index

Generated: 2026-06-23

Scope: live mapping of `/Users/thomashulihan/Projects/TRR`, including the root workspace, nested `TRR-Backend`, and nested `TRR-APP`.

## Documents

- [TRR workspace map](trr-workspace.md) - root orchestration, shared contracts, nested repo boundaries, workspace commands, and MCP/browser policy.
- [TRR-Backend map](trr-backend.md) - FastAPI, shared backend libraries, Supabase/schema ownership, Modal/job runtime, social scraping, and validation.
- [TRR-APP map](trr-app.md) - pnpm/Next.js workspace, app routes, admin surfaces, API proxy/auth seams, generated contracts, env projection, and build safety.

## Provenance

- Skill invoked: `get-shit-done:gsd-map-codebase`.
- Installed skill file: `/Users/thomashulihan/.codex/plugins/cache/local-plugins/get-shit-done/0.1.0/skills/gsd-map-codebase/SKILL.md`.
- Adapter file read: `/Users/thomashulihan/.codex/plugins/cache/local-plugins/get-shit-done/0.1.0/references/codex-adapter.md`.
- The installed skill references `../../.cache/upstream/skills/gsd-map-codebase.md`, but that upstream archive path is absent in this plugin install. The map therefore uses the installed mapper-agent contract plus live repository evidence.
- Older `.planning/codebase/*.md` files were not treated as authoritative for this run.

## Top-Level Ownership Summary

- The root workspace owns orchestration, policy, and cross-repo contracts through `AGENTS.md`, `.codex/rules/trr-project.md`, the root `Makefile`, `scripts/`, `profiles/`, and `docs/workspace/`.
- `TRR-Backend` owns schema, migrations, backend APIs, DB access, job execution, Modal deployment/runtime surfaces, and social scraping/runtime code.
- `TRR-APP` owns the Next.js user/admin app, route grammar, app-local API proxy routes, auth/session surfaces, generated admin API reference inventory, and app validation/build wrappers.

## Validation Notes

- This mapping run was documentation-only.
- No backend/API implementation changed.
- No SQL ownership changed.
- No Modal-affecting implementation changed.
- No browser verification was required.
- A full TRR-APP production build was not run because this was a docs-only map and no current-chat approval for a full build was requested.
