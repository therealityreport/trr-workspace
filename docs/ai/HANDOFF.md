# Session Handoff (TRR Workspace)

Purpose: persistent state for multi-turn AI agent sessions affecting workspace-level tooling (`make dev` / `make stop`).

## 2026-03-05 (Codex) — doctor Node 24 nvm auto-switch hardening
- Updated `/Users/thomashulihan/Projects/TRR/scripts/doctor.sh`:
  - retained strict Node baseline (`REQUIRED_NODE_MAJOR=24`),
  - added in-process `nvm` auto-switch path when current Node is below baseline,
  - reads workspace `/.nvmrc` target first, then runs `nvm use --silent <target>`,
  - preserves hard failure if Node is still below 24 and now prints explicit remediation commands.
- Added `/Users/thomashulihan/Projects/TRR/.nvmrc`:
  - pins workspace baseline to `24`.
- Added `/Users/thomashulihan/Projects/TRR/docs/workspace/preflight-doctor.md`:
  - operator note documenting preflight doctor behavior and manual fallback commands.
- Validation executed:
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/doctor.sh /Users/thomashulihan/Projects/TRR/scripts/preflight.sh` (pass)
  - `cd /Users/thomashulihan/Projects/TRR && node -v && bash scripts/doctor.sh` (pass; starts on `v22.18.0`, auto-switches to `v24.14.0`)
  - `cd /Users/thomashulihan/Projects/TRR && make preflight` (pass after `make env-contract`)
  - `cd /Users/thomashulihan/Projects/TRR && WORKSPACE_TRR_JOB_PLANE_MODE=remote WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE=1 WORKSPACE_TRR_REMOTE_WORKERS_ENABLED=1 make dev` (startup/health pass; terminated manually with Ctrl+C)
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/api/routers/test_admin_operations.py tests/repositories/test_admin_operations.py tests/api/routers/test_socials_reddit_refresh_routes.py tests/api/routers/test_admin_show_news.py` (pass; `54 passed`)
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP && pnpm -C apps/web exec vitest --run tests/async-handles.test.ts tests/run-session.test.ts tests/admin-fetch.test.ts tests/networks-streaming-sync-proxy-route.test.ts tests/show-google-news-sync-proxy-route.test.ts tests/show-google-news-sync-status-proxy-route.test.ts tests/reddit-window-posts-page.test.tsx tests/reddit-post-details-page.test.tsx` (pass; `29 passed`)
- default_skill_chain_applied: true
- default_skill_chain_used:
  - `orchestrate-plan-execution`
  - `senior-devops`
  - `senior-qa`
  - `code-reviewer`
- default_skill_chain_exception_reason: ``

## 2026-03-03 (Codex) — workspace PR automation agent (commit/PR/check/revise/merge/sync)
- Updated `/Users/thomashulihan/Projects/TRR/skills/multi-repo-pr-merge-sync/scripts/orchestrate_multi_repo_pr_merge_sync.py`:
  - added bot feedback ingestion from PR reviews + issue comments + review comments,
  - added actionable bot-feedback gating and revision loop handling,
  - added `--revision-command` auto-fix hook with `WORKSPACE_AGENT_*` env context + JSON payload file,
  - added base-branch reconciliation flow (`BEHIND`/`DIRTY` merge-state handling + merge retry path),
  - added conflict-resolution hook via `--revision-command` for merge conflicts,
  - added `--max-revision-cycles` safety bound,
  - added final local branch cleanup enforcement via `--delete-non-main-local-branches`,
  - expanded blocking status taxonomy: `needs_bot_revision`, `conflict_needs_fix`, `revision_cycle_limit`.
- Added `/Users/thomashulihan/Projects/TRR/scripts/workspace-pr-agent.sh`:
  - workspace wrapper for the orchestrator with defaults aligned to TRR repos:
    - `TRR-Backend,screenalytics,TRR-APP`
  - now wires a concrete default revision command:
    - `python3 /Users/thomashulihan/Projects/TRR/scripts/workspace-pr-agent-revision.py`
  - supports env-based overrides for poll/timeout/revision command/dry-run/report path.
- Added `/Users/thomashulihan/Projects/TRR/scripts/workspace-pr-agent-revision.py`:
  - consumes `WORKSPACE_AGENT_*` context from orchestrator callbacks,
  - runs scoped deterministic fixes only on currently touched/conflict files (no repo-wide rewrites),
  - invokes `codex exec --full-auto` for `failing_checks`, `bot_feedback`, and `merge_conflict` events,
  - supports `WORKSPACE_PR_AGENT_REVISION_USE_CODEX=0` to disable Codex assist,
  - supports GitHub MCP-first prompting via:
    - `WORKSPACE_PR_AGENT_REVISION_USE_GITHUB_MCP=1`
    - `WORKSPACE_PR_AGENT_REVISION_REQUIRE_GITHUB_MCP=1` (fail fast when MCP auth is missing).
- Added `/Users/thomashulihan/Projects/TRR/skills/workspace-pr-agent-github-mcp/SKILL.md` (+ `agents/openai.yaml`):
  - companion MCP-first skill for this automation flow.
- Updated `/Users/thomashulihan/Projects/TRR/Makefile`:
  - added `workspace-pr-agent` target.
- Updated `/Users/thomashulihan/Projects/TRR/skills/multi-repo-pr-merge-sync/SKILL.md` and `/Users/thomashulihan/Projects/TRR/skills/multi-repo-pr-merge-sync/agents/openai.yaml`:
  - documented bot-review/conflict revision loop and strict final-branch requirements.
- Validation executed:
  - `python3 -m py_compile /Users/thomashulihan/Projects/TRR/skills/multi-repo-pr-merge-sync/scripts/orchestrate_multi_repo_pr_merge_sync.py` (pass)
  - `python3 -m py_compile /Users/thomashulihan/Projects/TRR/scripts/workspace-pr-agent-revision.py` (pass)
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/workspace-pr-agent.sh` (pass)
  - `WORKSPACE_AGENT_REPO_NAME=TRR-Backend WORKSPACE_AGENT_REPO_PATH=/Users/thomashulihan/Projects/TRR/TRR-Backend WORKSPACE_AGENT_REASON=bot_feedback WORKSPACE_AGENT_CONTEXT_FILE=/tmp/trr_revision_context.json WORKSPACE_PR_AGENT_REVISION_USE_CODEX=0 python3 /Users/thomashulihan/Projects/TRR/scripts/workspace-pr-agent-revision.py` (pass)
  - `WORKSPACE_PR_AGENT_DRY_RUN=1 WORKSPACE_PR_AGENT_REPOS=TRR-Backend bash /Users/thomashulihan/Projects/TRR/scripts/workspace-pr-agent.sh` (pass)
  - `make -C /Users/thomashulihan/Projects/TRR workspace-pr-agent WORKSPACE_PR_AGENT_DRY_RUN=1` (pass; dry-run over TRR-Backend/screenalytics/TRR-APP)
  - `WORKSPACE_PR_AGENT_DRY_RUN=1 WORKSPACE_PR_AGENT_REVISION_REQUIRE_GITHUB_MCP=1 make -C /Users/thomashulihan/Projects/TRR workspace-pr-agent` (pass; dry-run path, MCP requirement flag accepted)
- default_skill_chain_applied: true
- default_skill_chain_used:
  - `orchestrate-plan-execution`
  - `senior-fullstack`
  - `senior-backend`
  - `senior-qa`
  - `code-reviewer`
- default_skill_chain_exception_reason: ``

## 2026-03-03 (Codex) — `make dev` now starts and manages social ingest workers
- Updated `/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh`:
  - added managed `TRR_SOCIAL_WORKER` service startup in workspace dev mode,
  - default pool now starts via `scripts/socials/start_worker_pool.sh` with:
    - `WORKSPACE_SOCIAL_WORKER_POSTS=1`
    - `WORKSPACE_SOCIAL_WORKER_COMMENTS=1`
    - `WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR=0`
    - `WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR=0`
  - added env toggles/validation:
    - `WORKSPACE_SOCIAL_WORKER_ENABLED` (`0|1`)
    - `WORKSPACE_SOCIAL_WORKER_*` counts and interval
  - added worker log rotation/reset (`.logs/workspace/social-worker.log`),
  - persisted worker settings in pidfile metadata.
- Updated `/Users/thomashulihan/Projects/TRR/scripts/stop-workspace.sh`:
  - now stops `TRR_SOCIAL_WORKER` from pidfile state.
- Updated `/Users/thomashulihan/Projects/TRR/scripts/status-workspace.sh`:
  - now reports social worker mode vars and `TRR_SOCIAL_WORKER` process state.
- Updated `/Users/thomashulihan/Projects/TRR/scripts/logs-workspace.sh`:
  - now tails `.logs/workspace/social-worker.log`.
- Updated `/Users/thomashulihan/Projects/TRR/Makefile`:
  - dev docs now state that social worker pool is part of default `make dev`,
  - added worker tuning examples in target comments.
- Validation executed:
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh /Users/thomashulihan/Projects/TRR/scripts/stop-workspace.sh /Users/thomashulihan/Projects/TRR/scripts/status-workspace.sh /Users/thomashulihan/Projects/TRR/scripts/logs-workspace.sh` (pass)
  - `make -C /Users/thomashulihan/Projects/TRR stop` (pass)
  - `WORKSPACE_OPEN_BROWSER=0 make -C /Users/thomashulihan/Projects/TRR dev-lite` (pass; observed `TRR_SOCIAL_WORKER started`)
  - `make -C /Users/thomashulihan/Projects/TRR status` (pass; reported `TRR_SOCIAL_WORKER: running`)
  - `tail -n 120 /Users/thomashulihan/Projects/TRR/.logs/workspace/social-worker.log` (pass; observed worker startup + active processing logs)
- Residual risk / note:
  - In environments where `social.scrape_workers` heartbeat schema is missing, worker heartbeats cannot be recorded and queue-mode ingest can still fail until migration `0130` is applied.
- default_skill_chain_applied: true
- default_skill_chain_used:
  - `orchestrate-plan-execution`
  - `senior-fullstack`
  - `senior-backend`
  - `senior-qa`
  - `code-reviewer`
- default_skill_chain_exception_reason: ``

## 2026-03-01 (Codex) — Refresh Details connect-timeout stabilization via non-reload default + mode/preflight diagnostics
- Updated `/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh`:
  - workspace now defaults `TRR_BACKEND_RELOAD=0` (non-reload) unless explicitly overridden,
  - validates `TRR_BACKEND_RELOAD` (`0|1`) and persists value in pidfile metadata,
  - passes `TRR_BACKEND_RELOAD` through backend launch env,
  - startup URL summary now prints backend mode (`reload` vs `non-reload`).
- Updated `/Users/thomashulihan/Projects/TRR/scripts/status-workspace.sh`:
  - prints `TRR_BACKEND_RELOAD` in status snapshot,
  - adds lightweight reload-churn heuristic warning when reload markers are frequent in recent backend logs.
- Updated `/Users/thomashulihan/Projects/TRR/Makefile`:
  - `dev` comments now document reload opt-in (`TRR_BACKEND_RELOAD=1 make dev`).
- Updated `/Users/thomashulihan/Projects/TRR/TRR-Backend/start-api.sh`:
  - startup now logs backend mode (reload/non-reload) for operator clarity.
- Validation executed:
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh` (pass)
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/status-workspace.sh` (pass)
  - `bash -n /Users/thomashulihan/Projects/TRR/TRR-Backend/start-api.sh` (pass)
  - `make -C /Users/thomashulihan/Projects/TRR status` (pass; reported `TRR_BACKEND_RELOAD: 0 (non-reload)` and healthy backend/app/screenalytics)
- default_skill_chain_applied: true
- default_skill_chain_used:
  - `orchestrate-plan-execution`
  - `senior-fullstack`
  - `senior-backend`
  - `senior-qa`
  - `code-reviewer`
- default_skill_chain_exception_reason: ``

## 2026-02-28 (Codex) — `make dev` default suppresses screenalytics tabs (API startup unchanged)
- Updated `/Users/thomashulihan/Projects/TRR/Makefile`:
  - `dev` now injects `WORKSPACE_OPEN_SCREENALYTICS_TABS="${WORKSPACE_OPEN_SCREENALYTICS_TABS:-0}"` so default `make dev` opens only TRR-APP tab.
  - `dev-lite`, `dev-cloud`, and `dev-full` remain unchanged.
  - usage comments now document `WORKSPACE_OPEN_SCREENALYTICS_TABS=1 make dev` opt-in.
- Updated `/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh`:
  - added `WORKSPACE_OPEN_SCREENALYTICS_TABS` runtime toggle (script default `1`),
  - persisted `WORKSPACE_OPEN_SCREENALYTICS_TABS` in pidfile metadata,
  - browser sync now clears Streamlit/Web tab targets when `WORKSPACE_OPEN_SCREENALYTICS_TABS!=1`,
  - startup paths, `DEV_AUTO_OPEN_BROWSER=0`, and health checks (including `/healthz`) are unchanged.
- Updated `/Users/thomashulihan/Projects/TRR/scripts/status-workspace.sh`:
  - now prints `WORKSPACE_OPEN_SCREENALYTICS_TABS` under workspace modes.
- Updated `/Users/thomashulihan/Projects/TRR/AGENTS.md` and `/Users/thomashulihan/Projects/TRR/CLAUDE.md`:
  - startup tuning docs now include the new opt-in env var for `make dev`.
- Validation executed:
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh` (pass)
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/status-workspace.sh` (pass)
  - `make -C /Users/thomashulihan/Projects/TRR -n dev` (pass; recipe includes defaulted `WORKSPACE_OPEN_SCREENALYTICS_TABS`)
  - `WORKSPACE_OPEN_SCREENALYTICS_TABS=1 make -C /Users/thomashulihan/Projects/TRR -n dev` (pass; opt-in path preserved)
  - `make -C /Users/thomashulihan/Projects/TRR -n dev-cloud` (pass; unchanged)
  - `make -C /Users/thomashulihan/Projects/TRR -n dev-full` (pass; unchanged)
  - `make -C /Users/thomashulihan/Projects/TRR dev` (pass for behavior verification; terminated with Ctrl+C/exit 130 by design)
    - observed: `screenalytics API is up: http://127.0.0.1:8001/healthz`
    - observed: `Screenalytics tab sync disabled (WORKSPACE_OPEN_SCREENALYTICS_TABS=0).`
    - observed browser sync opened only `TRR APP/Admin`
  - `WORKSPACE_OPEN_SCREENALYTICS_TABS=1 make -C /Users/thomashulihan/Projects/TRR dev` (pass for behavior verification; terminated with Ctrl+C/exit 130 by design)
    - observed: `screenalytics API is up: http://127.0.0.1:8001/healthz`
    - observed browser sync opened `TRR APP/Admin`, `screenalytics Streamlit`, and `screenalytics Web`
  - `WORKSPACE_OPEN_BROWSER=0 make -C /Users/thomashulihan/Projects/TRR dev` + `make -C /Users/thomashulihan/Projects/TRR status` (pass)
    - status output includes `WORKSPACE_OPEN_SCREENALYTICS_TABS: 0` from loaded pidfile.
- default_skill_chain_applied: true
- default_skill_chain_used:
  - `orchestrate-plan-execution`
  - `senior-fullstack`
  - `senior-backend`
  - `senior-qa`
  - `code-reviewer`
- default_skill_chain_exception_reason: n/a

## 2026-02-24 (Codex) — admin-host local defaults + tab-refresh collision hardening
- Updated `/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh`:
  - now injects TRR-APP admin host defaults into the launched `next dev` process when unset:
    - `ADMIN_APP_ORIGIN=http://admin.localhost:3000`
    - `ADMIN_APP_HOSTS=admin.localhost,localhost,127.0.0.1,[::1]`
    - `ADMIN_ENFORCE_HOST=true`
    - `ADMIN_STRICT_HOST_ROUTING=false`
  - persists the above values in pidfile metadata.
  - startup URL output now includes canonical admin URL line:
    - `TRR-APP Admin: http://admin.localhost:3000`
- Updated `/Users/thomashulihan/Projects/TRR/scripts/open-or-refresh-browser-tab.sh`:
  - removed broad localhost-family wildcard matching on port `3000`.
  - refresh matching is now limited to:
    - exact target URL/prefix, plus
    - explicit localhost/127 alias pair only.
  - prevents unrelated admin/public localhost tabs from being force-refreshed together.
- Validation executed:
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh` (pass)
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/open-or-refresh-browser-tab.sh` (pass)

## 2026-02-24 (Codex) — runtime hardening pass (endpoint override, health tuning, log archive, compose/runtime polish)
- Updated `/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh`:
  - `SCREENALYTICS_API_URL` now honors env override (default remains local `http://127.0.0.1:${SCREENALYTICS_API_PORT}`),
  - local screenalytics process uses local API base while backend/app receive resolved target URL,
  - health checks now use configurable env vars:
    - `WORKSPACE_HEALTH_CURL_MAX_TIME`
    - `WORKSPACE_HEALTH_TIMEOUT_BACKEND`
    - `WORKSPACE_HEALTH_TIMEOUT_APP`
    - `WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_API`
    - `WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_STREAMLIT`
    - `WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_WEB`,
  - local screenalytics API health checks use local URL explicitly (`SCREENALYTICS_LOCAL_HEALTH_URL`),
  - workspace logs are now archived per run under `.logs/workspace/archive/<timestamp>/` before fresh log files are created.
- Updated `/Users/thomashulihan/Projects/TRR/scripts/open-workspace-dev-window.sh`:
  - if tab-refresh helper fails, script now falls back to default browser open for the target URL.
- Updated `/Users/thomashulihan/Projects/TRR/scripts/status-workspace.sh`:
  - reports screenalytics as `disabled` when `WORKSPACE_SCREENALYTICS=0`,
  - health output now reports `starting/unhealthy` when PID is alive but endpoint is not healthy yet.
- Updated `/Users/thomashulihan/Projects/TRR/scripts/bootstrap.sh`:
  - Python resolution now supports `PYTHON_BIN`, then `python3.11`, `python3`, `python`,
  - enforces Python `>=3.11` on resolved interpreter.
- Updated `/Users/thomashulihan/Projects/TRR/scripts/down-screenalytics-infra.sh`:
  - compose down now includes `--remove-orphans`.
- Updated `/Users/thomashulihan/Projects/TRR/screenalytics/scripts/dev_auto.sh`:
  - default API port changed to `8001` (aligned with workspace),
  - new `SCREENALYTICS_DOCKER_FORCE_RECREATE` flag gates `--force-recreate` on compose up.
- Updated `/Users/thomashulihan/Projects/TRR/AGENTS.md` and `/Users/thomashulihan/Projects/TRR/CLAUDE.md`:
  - documented endpoint override, health-tuning vars, log archive behavior, and `SCREENALYTICS_DOCKER_FORCE_RECREATE`.
- Validation executed:
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh` (pass)
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/open-workspace-dev-window.sh` (pass)
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/status-workspace.sh` (pass)
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/bootstrap.sh` (pass)
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/down-screenalytics-infra.sh` (pass)
  - `bash -n /Users/thomashulihan/Projects/TRR/screenalytics/scripts/dev_auto.sh` (pass)
  - `SCREENALYTICS_API_URL=https://example.invalid WORKSPACE_SCREENALYTICS=0 make -C /Users/thomashulihan/Projects/TRR -n dev` (pass)
  - `make -C /Users/thomashulihan/Projects/TRR status` (pass; app showed `starting/unhealthy` while startup warmed)
  - `WORKSPACE_SCREENALYTICS=0 bash /Users/thomashulihan/Projects/TRR/scripts/status-workspace.sh` with pidfile temporarily moved aside (pass; screenalytics showed `disabled`)
  - `PYTHON_BIN=/bin/echo bash /Users/thomashulihan/Projects/TRR/scripts/bootstrap.sh` (expected fail; exit `1` with Python version error)
  - `PATH=/usr/bin:/bin bash /Users/thomashulihan/Projects/TRR/scripts/down-screenalytics-infra.sh` (pass; graceful no-op)

## 2026-02-24 (Codex) — workspace reliability additions (`make status`, doctor fallback, graceful `make down`)
- Added `/Users/thomashulihan/Projects/TRR/scripts/status-workspace.sh`:
  - reports workspace mode flags from pidfile when available,
  - reports process states for `TRR_APP`, `TRR_BACKEND`, and `SCREENALYTICS`,
  - reports listeners for `3000/8000/8001/8501/8080` (or pidfile overrides),
  - performs best-effort health checks for backend/app/screenalytics API,
  - always exits `0` (informational status command).
- Updated `/Users/thomashulihan/Projects/TRR/Makefile`:
  - added `status` target and `.PHONY` entry (`make status`).
- Updated `/Users/thomashulihan/Projects/TRR/scripts/doctor.sh`:
  - Python interpreter resolution now supports `PYTHON_BIN`, then `python3.11`, `python3`, `python`,
  - enforces Python version `>=3.11` on the resolved interpreter,
  - prints selected Python binary path and version.
- Updated `/Users/thomashulihan/Projects/TRR/scripts/down-screenalytics-infra.sh`:
  - no-op exit when Docker CLI is missing,
  - no-op exit when Docker daemon is not running.
- Updated `/Users/thomashulihan/Projects/TRR/AGENTS.md` and `/Users/thomashulihan/Projects/TRR/CLAUDE.md`:
  - documented `make status`, graceful `make down`, and doctor Python fallback behavior.
- Validation executed:
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/status-workspace.sh` (pass)
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/doctor.sh` (pass)
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/down-screenalytics-infra.sh` (pass)
  - `make -C /Users/thomashulihan/Projects/TRR -n status` (pass)
  - `make -C /Users/thomashulihan/Projects/TRR status` (pass)
  - `PYTHON_BIN=/no/such/python make -C /Users/thomashulihan/Projects/TRR doctor` (warned + fell back, pass)

## 2026-02-24 (Codex) — workspace run UX hardening (cache default, dev modes, browser toggle)
- Updated `/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh`:
  - changed `WORKSPACE_CLEAN_NEXT_CACHE` default from `1` to `0` (cache reuse by default),
  - added `WORKSPACE_OPEN_BROWSER` toggle (default `1`) to gate tab sync/open behavior,
  - persisted `WORKSPACE_OPEN_BROWSER` in workspace pidfile metadata,
  - guarded tab sync call so `WORKSPACE_OPEN_BROWSER=0` skips browser automation.
- Updated `/Users/thomashulihan/Projects/TRR/Makefile`:
  - added `dev-lite`, `dev-cloud`, and `dev-full` targets,
  - expanded usage comments with startup tuning examples (`WORKSPACE_CLEAN_NEXT_CACHE`, `WORKSPACE_OPEN_BROWSER`).
- Updated `/Users/thomashulihan/Projects/TRR/AGENTS.md` and `/Users/thomashulihan/Projects/TRR/CLAUDE.md`:
  - documented new run-mode targets and startup tuning toggles.
- Validation executed:
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh` (pass)
  - `make -C /Users/thomashulihan/Projects/TRR -n dev-lite` (pass)
  - `make -C /Users/thomashulihan/Projects/TRR -n dev-cloud` (pass)
  - `make -C /Users/thomashulihan/Projects/TRR -n dev-full` (pass)

## 2026-02-19 (Codex) — fresh `make dev` browser window orchestration
- Added `scripts/open-workspace-dev-window.sh` to enforce workspace browser behavior:
  - closes existing tabs only for configured TRR-APP and screenalytics Web origins (exact host+port match, path-agnostic),
  - opens a brand-new browser window with fresh tabs for TRR-APP and optional screenalytics Web.
- Updated `scripts/dev-workspace.sh`:
  - disables nested screenalytics browser opens via `DEV_AUTO_OPEN_BROWSER=0` when launched from workspace,
  - replaces single-tab TRR-APP open call with `open-workspace-dev-window.sh`,
  - opens TRR-APP + screenalytics Web (`:8080`) in one fresh window when screenalytics is enabled.

## Changes In This Session (2026-02-09)

- `scripts/dev-workspace.sh`
  - Safe-stale port preflight/cleanup to prevent orphaned processes from blocking ports.
  - macOS-friendly process-group isolation (python `setsid()` fallback when `setsid` is unavailable) so stop can kill full trees.
  - `WORKSPACE_SCREENALYTICS` / `WORKSPACE_STRICT` toggles so `make dev` can keep TRR-Backend + TRR-APP running even if screenalytics fails.
  - Startup health checks so printed URLs reflect actual service readiness.
  - Starts screenalytics via `bash ./scripts/dev_auto.sh` and passes `DEV_AUTO_ALLOW_DB_ERROR=1` by default when `WORKSPACE_STRICT=0` so screenalytics doesn't exit if the DB is unreachable.

- `scripts/stop-workspace.sh`
  - Stops by process group when possible, with recursive descendant-kill fallback.
  - Safe-stale cleanup by port when no pidfile exists.

## How To Run

From `/Users/thomashulihan/Projects/TRR`:

```bash
make stop
make dev
```

## Useful Env Vars

- `WORKSPACE_SCREENALYTICS=0` to skip screenalytics entirely.
- `WORKSPACE_STRICT=1` to fail fast if screenalytics can’t start / docker isn’t available.
- `WORKSPACE_FORCE_KILL_PORT_CONFLICTS=1` to forcibly clear port conflicts (kills all listeners on those ports).

---

Last updated: 2026-02-24
Updated by: Codex (GPT-5)

## 2026-02-17 (Codex) — `make dev` one-tab browser behavior
- Added `/Users/thomashulihan/Projects/TRR/scripts/open-or-refresh-browser-tab.sh` to reuse existing browser tabs for service URLs.
- Wired `scripts/dev-workspace.sh` to open/refresh `TRR-APP` at `http://127.0.0.1:${TRR_APP_PORT}` on each `make dev`.
- Replaced hardcoded `open` calls in `screenalytics/scripts/dev_auto.sh` so Streamlit/Web tabs are reused when present.
- Behavior now prefers Chrome → Safari tab reuse and falls back to opening a new tab if those automation paths are unavailable.


## 2026-02-12 (Codex) — New planning docs added
- Added image optimization implementation plan:
  - `/Users/thomashulihan/Projects/TRR/docs/plans/2026-02-12-image-storage-optimization-plan.md`
- Added admin UX/product suggestions document (10 concrete proposals):
  - `/Users/thomashulihan/Projects/TRR/docs/plans/2026-02-12-admin-page-suggestions.md`

## 2026-02-12 (Codex) — Plan docs finalized
- Finalized both plan docs with implementation status sections and closed checklist items:
  - `/Users/thomashulihan/Projects/TRR/docs/plans/2026-02-12-image-storage-optimization-plan.md`
  - `/Users/thomashulihan/Projects/TRR/docs/plans/2026-02-12-admin-page-suggestions.md`

## 2026-02-12 (Codex) — `make dev` stability fix
- File: `/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh`
- Fixed shutdown crash:
  - handled sparse `PIDS/NAMES` arrays safely in `cleanup()` to prevent `NAMES[$i]: unbound variable`.
  - hardened process-monitor loop against unset/sparse indices.
  - added idempotent cleanup guard to avoid double shutdown output.
- Reduced intermittent Next route-cache startup failures:
  - added `WORKSPACE_CLEAN_NEXT_CACHE` (default `1`) and clear `TRR-APP/apps/web/.next` before starting `next dev`.
  - mitigates stale app-router cache mismatches (e.g. dynamic slug-name conflict after route renames).

## 2026-03-03 (Codex) — managed Chrome isolation for Codex MCP + shared fallback
- Scope: workspace browser orchestration hardening so Codex chats do not contend for one Chrome DevTools endpoint.
- `default_skill_chain_applied`: `true`
- `default_skill_chain_used`: `orchestrate-plan-execution -> senior-fullstack -> senior-backend -> senior-qa -> code-reviewer`
- `default_skill_chain_exception_reason`: `n/a`
- Updated `/Users/thomashulihan/Projects/TRR/scripts/chrome-agent.sh`:
  - switched to port-scoped runtime files:
    - `chrome-agent-${DEBUG_PORT}.pid`
    - `chrome-agent-${DEBUG_PORT}.log`
    - `chrome-agent-${DEBUG_PORT}.env`
  - retained legacy `chrome-agent.pid` write for `9222` compatibility.
- Updated `/Users/thomashulihan/Projects/TRR/scripts/stop-chrome-agent.sh`:
  - port-targeted stop semantics by default,
  - `CHROME_AGENT_STOP_ALL=1` support for full managed-instance cleanup,
  - legacy `9222` pidfile compatibility handling.
- Added `/Users/thomashulihan/Projects/TRR/scripts/codex-chrome-devtools-mcp.sh`:
  - default `CODEX_CHROME_MODE=isolated`,
  - default `CODEX_CHROME_ISOLATED_HEADLESS=1` to avoid visible browser flap during MCP session churn,
  - per-session port allocation from `CODEX_CHROME_PORT_RANGE_START..CODEX_CHROME_PORT_RANGE_END` (defaults `9333..9399`),
  - optional `CODEX_CHROME_PORT` pin,
  - first-run profile seed copy from `CODEX_CHROME_SEED_PROFILE_DIR` (default `~/.chrome-profiles/claude-agent`),
  - shared fallback mode (`CODEX_CHROME_MODE=shared`) targeting `9222`,
  - automatic teardown of isolated Chrome instance on wrapper exit.
- Added `/Users/thomashulihan/Projects/TRR/scripts/chrome-agent-status.sh`.
- Added `/Users/thomashulihan/Projects/TRR/scripts/chrome-agent-seed-sync.sh`.
- Added `/Users/thomashulihan/Projects/TRR/scripts/ensure-managed-chrome.sh` for Claude PreToolUse compatibility bootstrap.
- Updated `/Users/thomashulihan/Projects/TRR/Makefile`:
  - new targets: `chrome-agent-status`, `chrome-agent-stop-all`, `chrome-agent-seed-sync`.
- Updated `/Users/thomashulihan/Projects/TRR/AGENTS.md` and `/Users/thomashulihan/Projects/TRR/CLAUDE.md`:
  - replaced hard single-port mandate with managed-browser policy,
  - documented isolated-per-chat default + shared fallback + troubleshooting commands.
- Updated `/Users/thomashulihan/Projects/TRR/.claude/settings.local.json`:
  - PreToolUse bootstrap now calls `scripts/ensure-managed-chrome.sh` instead of unconditional `make chrome-agent`.
- Updated user-level Codex MCP wiring `/Users/thomashulihan/.codex/config.toml`:
  - `mcp_servers.chrome-devtools.command` now points to `/Users/thomashulihan/Projects/TRR/scripts/codex-chrome-devtools-mcp.sh`.
- Validation executed:
  - `bash -n` on all touched shell scripts (pass).
  - `python -m json.tool /Users/thomashulihan/Projects/TRR/.claude/settings.local.json` (pass).
  - `make -C /Users/thomashulihan/Projects/TRR chrome-agent-status` (pass).
  - Shared fallback check via wrapper: `SHARED_FALLBACK_OK=1` (pass).
  - Direct two-port isolation check (`9500`/`9501`):
    - `9500` saw `chat=one` only,
    - `9501` saw `chat=two` only (pass).
  - Lifecycle stop-one check:
    - stopping `9500` left `9501` running (pass).
  - Wrapper port-exhaustion check (`9600..9601` occupied):
    - non-zero exit + `No free Chrome debug ports` message (pass).
  - Wrapper stale reservation recovery check:
    - stale reservation file did not block allocation; failure reached `Seed profile not found` path as expected (pass).
  - Stop-all check:
    - `CHROME_AGENT_STOP_ALL=1` terminated all managed test instances (pass).

## 2026-03-03 (Codex) — workspace full runtime/tools/models/pip modernization (balanced wave)
- Scope: coordinated runtime/tooling/dependency/model-governance alignment across `TRR-Backend`, `screenalytics`, `TRR-APP`, and workspace scripts/docs.
- `default_skill_chain_applied`: `true`
- `default_skill_chain_used`: `orchestrate-plan-execution -> senior-fullstack -> senior-backend -> senior-qa -> code-reviewer`
- `default_skill_chain_exception_reason`: `n/a`
- Workspace-level updates:
  - added `/Users/thomashulihan/Projects/TRR/docs/ai/MODEL_GOVERNANCE.md`.
  - updated `/Users/thomashulihan/Projects/TRR/scripts/doctor.sh` with Node `24.x` minimum check.
  - updated `/Users/thomashulihan/Projects/TRR/AGENTS.md` and `/Users/thomashulihan/Projects/TRR/CLAUDE.md` runtime baseline sections to Node 24 primary and Python 3.11.9 primary (+ 3.12 canary).
- Cross-repo execution summary:
  - `TRR-Backend`: CI/tooling and container baseline updates, lock freshness verification, model governance doc + handoff update.
  - `screenalytics`: Node 24 tooling baseline for web/dev scripts, CI lock checks + Python canary posture, lock refreshes, model governance doc + handoff update.
  - `TRR-APP`: Node 24 runtime alignment, Python lock-driven flow migration (`requirements.in` + `requirements.lock.txt`), CI/doc alignment, model governance doc + handoff update.
- Validation snapshot:
  - lock freshness checks passed in all three repos.
  - mixed pre-existing test/lint/type failures remain in backend and app suites; tracked as residual baseline issues and not newly introduced by this wave.
  - local machine still on Node `v22.18.0`; Node 24 local baseline checks will remain red until local runtime is switched.
- Deployment note:
  - Vercel Node runtime setting changes require a fresh deployment to take effect.

## Latest Update (2026-03-05) — Workspace remote-social worker controls

- files_changed:
  - `/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh`
- behavior_summary:
  - Added workspace env controls to pass optional remote social ingest worker counts/stages into backend remote worker launcher.
  - Kept local default disabled to protect local CPU; remote social worker groups are opt-in.
- validation_evidence:
  - `bash -n /Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh` (pass)

## Latest Update (2026-03-05) — `make dev` one-command remote-enforced local-lite default

- files_changed:
  - `/Users/thomashulihan/Projects/TRR/Makefile`
  - `/Users/thomashulihan/Projects/TRR/AGENTS.md`
  - `/Users/thomashulihan/Projects/TRR/docs/ai/HANDOFF.md`
- behavior_summary:
  - `make dev` now always runs with `PROFILE=local-lite` unless user explicitly sets `PROFILE`.
  - `make dev` now hard-pins remote long-job enforcement and disables local social/remote worker loops by default:
    - `WORKSPACE_TRR_JOB_PLANE_MODE=remote`
    - `WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE=1`
    - `WORKSPACE_SOCIAL_WORKER_ENABLED=0`
    - `WORKSPACE_TRR_REMOTE_WORKERS_ENABLED=0`
    - `WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=0`
  - Updated AGENTS wording to match this new daily-default behavior.
- validation_evidence:
  - `make -n dev` shows enforced env + `PROFILE=${PROFILE:-local-lite}` (pass)
  - `bash -n scripts/dev-workspace.sh scripts/preflight.sh` (pass)
  - `make -n dev-lite` and `make -n dev-cloud` remain unchanged (pass)
