# TRR Workspace — Quickstart

Canonical cross-repo rules: `AGENTS.md` in this directory.

## One-Command Dev
From `/Users/thomashulihan/Projects/TRR`:
```bash
make bootstrap
make dev
```

Stop services started by `make dev`:
```bash
make stop
```

Tail logs:
```bash
make logs
```

## Default URLs (Workspace Mode)
- TRR-APP: `http://127.0.0.1:3000`
- TRR-Backend: `http://127.0.0.1:8000` (FastAPI, routes under `/api/v1/*`)
- screenalytics API: `http://127.0.0.1:8001`
- screenalytics Streamlit: `http://127.0.0.1:8501`
- screenalytics Web: `http://127.0.0.1:8080`

## How They Connect
- TRR-APP calls TRR-Backend using `TRR_API_URL` (server-only) and normalizes to `/api/v1`.
- TRR-Backend optionally calls screenalytics using `SCREENALYTICS_API_URL` for vision helpers.
- screenalytics can read TRR metadata DB directly via `TRR_DB_URL` (preferred) / `SUPABASE_DB_URL` (legacy).

## Multi-Repo Sessions (Claude/Codex)
From this directory:
```bash
claude --add-dir TRR-Backend --add-dir TRR-APP --add-dir screenalytics
```

If your tool supports it, enable loading multiple `CLAUDE.md` files:
```bash
export CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1
```

## Repo Pointers
- `TRR-Backend/CLAUDE.md` and `TRR-Backend/AGENTS.md`
- `TRR-APP/CLAUDE.md` and `TRR-APP/AGENTS.md`
- `screenalytics/CLAUDE.md` and `screenalytics/AGENTS.md`

## Session Continuity
Update `docs/ai/HANDOFF.md` in each repo you touched before ending a session.
