# TRR Workspace Structure Map

Updated from workspace scan on 2026-04-07.

## Workspace Root

Key root locations:

- Policy and workspace guidance: `AGENTS.md`, `docs/workspace/`, `docs/cross-collab/`
- Planning artifacts: `.planning/`
- Shared scripts: `scripts/`
- Primary repos:
  - `TRR-Backend/`
  - `TRR-APP/`
  - `screenalytics/`

The root is a coordination workspace, not a single-product source tree.

## TRR-Backend Layout

Top-level structure:

- `TRR-Backend/api/` - FastAPI entrypoints, routers, realtime broker
- `TRR-Backend/trr_backend/` - reusable backend package code
- `TRR-Backend/supabase/` - config, migrations, generated schema docs
- `TRR-Backend/tests/` - Python test suites organized by domain
- `TRR-Backend/scripts/` - operational scripts grouped by concern
- `TRR-Backend/docs/` - backend-specific docs, runbooks, architecture references

Important subtrees in `trr_backend/`:

- `trr_backend/db/`
- `trr_backend/repositories/`
- `trr_backend/services/`
- `trr_backend/integrations/`
- `trr_backend/media/`
- `trr_backend/ingestion/`
- `trr_backend/socials/`
- `trr_backend/security/`
- `trr_backend/pipeline/`

Naming pattern:

- routers are feature-named, often `admin_*`
- repository modules are noun or capability oriented
- ingestion/integration modules are provider-oriented

## TRR-APP Layout

Top-level structure:

- `TRR-APP/apps/web/` - main Next.js app
- `TRR-APP/apps/vue-wordle/` - secondary Vue/Vite app
- `TRR-APP/scripts/` - deployment and operational scripts
- `TRR-APP/docs/` - app docs and epics

Important Next app subtrees:

- `TRR-APP/apps/web/src/app/` - route tree
- `TRR-APP/apps/web/src/components/` - React components
- `TRR-APP/apps/web/src/hooks/` - custom hooks
- `TRR-APP/apps/web/src/lib/` - shared utilities and domain logic
- `TRR-APP/apps/web/src/lib/server/` - privileged server-only modules
- `TRR-APP/apps/web/src/types/` - shared types
- `TRR-APP/apps/web/tests/` - Vitest and Playwright tests

Notable route clusters under `src/app/`:

- `src/app/admin/` - large admin surface
- `src/app/api/` - Next route handlers
- `src/app/[showId]/` and `src/app/shows/` - public show pages
- `src/app/brands/`, `src/app/design-system/`, `src/app/fonts/` - editorial/design system surfaces
- `src/app/bravodle/`, `src/app/flashback/`, `src/app/realitease/` - games/features

Naming pattern:

- app route segments are descriptive and often mirror product tabs
- server modules use suffixes such as `-repository.ts`, `-service.ts`, `-cache.ts`, `-proxy.ts`
- alias imports use `@/*` from `tsconfig.json`

## screenalytics Layout

Top-level structure:

- `screenalytics/apps/api/` - FastAPI API service
- `screenalytics/apps/workspace-ui/` - Streamlit UI
- `screenalytics/packages/py-screenalytics/` - reusable Python package
- `screenalytics/tests/` - broad Python test suite
- `screenalytics/config/` - pipeline configs
- `screenalytics/tools/` - CLI and batch jobs
- `screenalytics/docs/` - architecture, reference, ops docs

Important `apps/api/` subtrees:

- `apps/api/routers/`
- `apps/api/services/`
- `apps/api/config/`
- `apps/api/schemas/`

Important `apps/workspace-ui/` subtrees:

- `apps/workspace-ui/pages/`
- `apps/workspace-ui/components/`
- `apps/workspace-ui/tests/`

Important reusable package location:

- `screenalytics/packages/py-screenalytics/src/py_screenalytics/`

## Documentation and Generated Assets

- Backend schema reference is generated under `TRR-Backend/supabase/schema_docs/`
- Backend repo-map output appears under `TRR-Backend/docs/Repository/generated/`
- screenalytics also carries repository/architecture docs under `screenalytics/docs/`
- TRR-APP has design-docs and design-system-related generated artifacts under:
  - `TRR-APP/apps/web/src/lib/fonts/generated/`
  - `TRR-APP/apps/web/src/lib/admin/api-references/generated/`

## Test Tree Shape

- Backend test domains: `tests/api/`, `tests/repositories/`, `tests/integrations/`, `tests/media/`, `tests/scripts/`, `tests/pipeline/`
- App tests are mostly flat under `TRR-APP/apps/web/tests/` with `tests/e2e/` for Playwright
- screenalytics tests span:
  - `tests/api/`
  - `tests/audio/`
  - `tests/facebank/`
  - `tests/tools/`
  - `tests/mcps/`
  - `apps/workspace-ui/tests/`

## Operational Script Conventions

- Backend script buckets by concern:
  - `TRR-Backend/scripts/socials/`
  - `TRR-Backend/scripts/media/`
  - `TRR-Backend/scripts/supabase/`
  - `TRR-Backend/scripts/workers/`
- screenalytics uses `tools/` for heavy operational flows and `scripts/` for setup/utility work
- workspace root `scripts/` holds cross-repo and browser tooling referenced by root policy

## Structural Takeaways

- The workspace is intentionally organized by repo ownership first, not by shared packages
- Shared contracts are documented centrally, but code is not centralized into one monorepo package graph
- The heaviest growth zones are `TRR-APP/apps/web/src/app/admin/`, `TRR-Backend/api/routers/`, and `screenalytics/apps/api/services/`
