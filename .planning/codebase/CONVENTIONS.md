# Coding Conventions

**Analysis Date:** 2026-04-07

## Naming Patterns

**Files:**
- Python modules and tests use `snake_case` in `TRR-Backend/` and `screenalytics/`
- React components use `PascalCase.tsx` in `TRR-APP/apps/web/src/components/`
- Next.js routes follow App Router conventions in `TRR-APP/apps/web/src/app/`
- Streamlit pages are ordered with numeric prefixes in `screenalytics/apps/workspace-ui/pages/`
- Tests use `test_*.py`, `*.test.ts`, `*.test.tsx`, and `*.spec.ts`

**Functions and variables:**
- Python uses `snake_case`
- TypeScript uses `camelCase` for functions/helpers and `PascalCase` for components
- Constants and env keys use `UPPER_CASE`

## Style and Quality Tools

- `screenalytics/pyproject.toml` sets Ruff and Black line length to 120 and ignores selected repo-specific rules
- Backend repo validation is command-driven through `TRR-Backend/AGENTS.md` rather than a visible `pyproject.toml`
- App linting is handled by ESLint in `TRR-APP/apps/web/package.json`
- Vitest and Playwright configs are repo-local in `TRR-APP/apps/web/`

## Boundary Patterns

**Backend:**
- Keep routers thin and delegate into repository/service layers under `TRR-Backend/trr_backend/`
- Startup/runtime contract validation belongs near the edge in `TRR-Backend/api/main.py`

**App:**
- Keep server-only code under `TRR-APP/apps/web/src/lib/server/`
- Normalize backend access centrally through `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`
- Prefer Server Components unless client interactivity is required by the page or component

**screenalytics:**
- FastAPI routes delegate into `apps/api/services/`
- Streamlit requires page config boot order discipline in `screenalytics/apps/workspace-ui/streamlit_app.py`
- Heavy tooling often lives in `screenalytics/tools/`, with shared logic gradually extracted into `packages/py-screenalytics/`

## Error Handling

- Validate runtime prerequisites early instead of tolerating partial misconfiguration
- Convert boundary failures into typed or normalized responses close to the edge
- Avoid leaking raw secrets or stack traces across HTTP boundaries
- Preserve service-auth and internal-admin invariants named in `AGENTS.md`

## Logging

- Python services use `logging.getLogger(__name__)` or `LOGGER = logging.getLogger(__name__)`
- Backend observability is centralized in `TRR-Backend/trr_backend/observability.py`
- Screenalytics binds trace/request IDs in `screenalytics/apps/api/main.py`
- App-side logging is targeted and sparse, usually `console.warn` or `console.error` for runtime diagnostics

## Comments and Documentation

- Comments are used for runtime caveats, contract rules, or boot-order constraints, not obvious line-by-line narration
- Python docstrings are common for modules and boundary helpers
- TypeScript relies more on strong typing and targeted inline comments than on broad TSDoc blocks

## Module Design

- Utilities and helpers usually export named functions
- Next.js pages/components generally use default exports where framework conventions expect them
- Barrel files exist selectively; direct imports are more common than blanket barrel usage

## Config and Env Practices

- Treat `.env.example` files and `docs/workspace/env-contract.md` as the reference contract
- Runtime DB precedence is `TRR_DB_URL` then `TRR_DB_FALLBACK_URL`
- Do not invent new runtime dependence on `DATABASE_URL` for shared cross-repo flows
- `TRR_API_URL` and `SCREENALYTICS_API_URL` are shared contracts, not ad hoc local variables
- Shared secrets are named and referenced, never embedded in code

## Agent Workflow Conventions

- Read `AGENTS.md` first, then the repo-local `AGENTS.md`
- Cross-repo order is fixed:
  1. `TRR-Backend`
  2. `screenalytics`
  3. `TRR-APP`
- Multi-phase work should use the handoff lifecycle scripts referenced in `docs/cross-collab/WORKFLOW.md`
- Update canonical status docs, not generated handoff outputs

## Verification Expectations

- Backend: `ruff check . && ruff format --check . && pytest -q`
- App: `pnpm -C apps/web run lint && pnpm -C apps/web exec next build --webpack && pnpm -C apps/web run test:ci`
- Screenalytics: `pytest -q` plus targeted `py_compile` / ML lanes depending on the change
- Browser validation remains required for admin or route behavior changes even when tests pass

---

*Convention analysis refreshed: 2026-04-07*
