# AGENTS — TRR Workspace (Canonical Cross-Repo Rules)

This file defines how agents coordinate work across the TRR workspace. Repo-specific
rules live in each repo’s `AGENTS.md` and must also be followed.

Repos:
- `TRR-Backend/` (FastAPI + Supabase-first pipeline)
- `TRR-APP/` (Next.js + Firebase)
- `screenalytics/` (FastAPI + Streamlit + ML pipeline)

## One-Command Dev (Workspace)
Run from `/Users/thomashulihan/Projects/TRR`:
- `make bootstrap` (one-time installs)
- `make dev` (run everything)
- `make stop` (stop only what `make dev` started)

Default URLs:
- TRR-APP: `http://127.0.0.1:3000`
- TRR-Backend: `http://127.0.0.1:8000` (routes under `/api/v1/*`)
- screenalytics API: `http://127.0.0.1:8001`
- screenalytics Streamlit: `http://127.0.0.1:8501`
- screenalytics Web: `http://127.0.0.1:8080`

## Cross-Repo Workflow (Decision Complete)
Before starting:
1. Read workspace `CLAUDE.md` and the relevant repo `CLAUDE.md`.
2. Check `docs/cross-collab/` in `TRR-Backend/` and `TRR-APP/` (and `screenalytics/docs/cross-collab/`).

Implementation order:
1. `TRR-Backend`: DB/schema + API contract changes first.
2. `screenalytics`: adapt consumers/writers next (if affected).
3. `TRR-APP`: UI/admin routes last.

After changes:
1. Run repo fast checks in each touched repo.
2. Update `docs/ai/HANDOFF.md` in each touched repo before ending the session.

## Shared Contracts (Must Not Drift)
TRR-APP → TRR-Backend:
- API base comes from `TRR_API_URL` and is normalized to `/api/v1` in
  `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts`.
- Never break response shapes without updating TRR-APP consumers immediately.

TRR-Backend ↔ screenalytics:
- TRR-Backend calls screenalytics via `SCREENALYTICS_API_URL`.
- screenalytics may read TRR metadata via `TRR_DB_URL` (preferred) or `SUPABASE_DB_URL` (legacy).
- If schema/views change, change TRR-Backend first, then screenalytics.

Auth shared secrets:
- `TRR_INTERNAL_ADMIN_SHARED_SECRET` is a shared secret between TRR-APP and TRR-Backend (internal admin proxy).
- `SCREENALYTICS_SERVICE_TOKEN` is used for service-to-service access to TRR-Backend `/api/v1/screenalytics/*` endpoints.

## Cross-Collab Task Folder Convention
Cross-repo tasks live under `docs/cross-collab/` in each repo:
- `TRR-Backend/docs/cross-collab/TASK*/`
- `TRR-APP/docs/cross-collab/TASK*/`
- `screenalytics/docs/cross-collab/` (created by this workspace setup)

Keep these files aligned (when present):
- `PLAN.md`
- `OTHER_PROJECTS.md`
- `STATUS.md`
