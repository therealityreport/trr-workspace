# Codebase Concerns

**Analysis Date:** 2026-04-07

## Tech Debt

**Planning-state drift at the workspace root:**
- `.planning/active-workstream` exists, but there is no root `.planning/STATE.md`, and some older workflow assumptions still reference that missing file
- Relevant paths: `.planning/active-workstream`, `.planning/workstreams/`, `.planning/PROJECT.md`
- Impact: resume or scaffolding flows can target archived or missing state shapes

**Workspace automation is concentrated in a small number of large scripts:**
- `scripts/dev-workspace.sh`, `scripts/preflight.sh`, `scripts/status-workspace.sh`, and browser wrappers carry a lot of branching logic
- Impact: runtime/debugging regressions are operationally expensive to localize

**Cross-repo env compatibility remains partially standardized and partially quarantined:**
- Runtime policy is clearly `TRR_DB_URL` then `TRR_DB_FALLBACK_URL`
- Tooling and compatibility paths still create room for confusion during incident or migration work

## Known Incomplete / Partial Areas

**screenalytics cast sync remains partial:**
- `screenalytics/apps/api/routers/episodes.py` still contains an explicit TODO for full sync wiring to TRR cast tables

**Audio queue/smart-split paths are not fully realized:**
- `screenalytics/apps/api/routers/audio.py` still carries TODOs for NeMo/TitaNet-based embedding extraction and a Celery `diarize_only` task path

**MCP surface in screenalytics is still skeletal:**
- `screenalytics/mcps/screenalytics/server.py` contains TODO-backed placeholder behavior rather than a production-grade DB-backed tool surface

**Backend pipeline sync stub remains open:**
- `TRR-Backend/trr_backend/pipeline/stages/sync_screenalytics.py` is still explicitly marked TODO

## Security Considerations

**Managed browser sessions are shared operational infrastructure:**
- State leakage or stale ownership bugs in the Chrome wrapper/reaper scripts would affect multiple workflows at once
- Relevant paths: `scripts/codex-chrome-devtools-mcp.sh`, related Chrome helpers, and `docs/workspace/chrome-devtools.md`

**Local shared-secret generation is convenient but easy to misunderstand:**
- Workspace startup can derive local dev secrets when envs are unset
- Relevant contract: `AGENTS.md` and `docs/workspace/env-contract.md`
- Risk: those values must never be mistaken for deployable secrets

## Performance Hotspots

**Screenalytics pipeline monolith:**
- `screenalytics/tools/episode_run.py` remains extremely large and is imported by other runtime paths
- Impact: heavy import surface, slower reasoning/debugging, and more side-effect risk across API and tooling boundaries

**Large Next.js admin pages:**
- `TRR-APP/apps/web/src/app/admin/trr-shows/...` contains expansive page-level orchestration and state
- Impact: harder reviewability and more client-side orchestration concentrated in single files

**Backend large-domain modules:**
- Backend still has oversized repository and social pipeline areas that combine dispatch, caching, and domain logic
- Impact: higher regression risk for seemingly local changes

## Fragile Boundaries

**Cross-repo API and env seams:**
- `TRR_API_URL` normalization in the app, backend auth/DB lane rules, and screenalytics service-token flows must stay aligned
- Changes here require the documented repo order from `AGENTS.md`

**Legacy compatibility inside screenalytics routers:**
- `screenalytics/apps/api/routers/episodes.py` and related router surfaces preserve old aliases and fallback behaviors in large modules
- Impact: removing one fallback can break an untested downstream caller

**Workspace handoff/doc sync depends on exact document shape:**
- `scripts/handoff-lifecycle.sh` and related docs/sync tooling depend on strict formatting contracts
- Impact: scaffolding drift creates operational failures rather than graceful degradation

## Scaling Limits

**Deliberately small session-pool posture:**
- Backend and app server DB access are intentionally conservative for shared session-pool safety
- Impact: admin fan-out or job bursts can hit contention before raw DB capacity is reached

**screenalytics direct DB connections:**
- Screenalytics still leans on direct `psycopg2` connection behavior rather than a visibly shared pool abstraction
- Impact: higher connection churn under sustained API throughput

## Test Coverage Gaps

**Workspace shell flows:**
- Startup, browser ownership, and handoff lifecycle scripts are less directly tested than the product repos

**Largest app admin flows:**
- Large admin page orchestration is not covered as comprehensively as smaller helpers and route handlers

**Screenalytics Streamlit/operator flows:**
- Stateful review/run-control behavior remains comparatively under-tested relative to the size of `screenalytics/apps/workspace-ui/`

**MCP behavior:**
- The screenalytics MCP path lacks meaningful production-like behavioral coverage

## Overall Risk Summary

- The workspace is structurally coherent and policy-rich, but operational complexity is concentrated in a few places:
  - root orchestration scripts
  - cross-repo env/auth seams
  - large screenalytics and admin modules
- The most important practical rule remains the repo order from `AGENTS.md`: backend first, screenalytics second, app last.

---

*Concerns analysis refreshed: 2026-04-07*
