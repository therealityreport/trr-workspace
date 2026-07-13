# TRR Workspace — Advisor Recon

Written by `/improve-more` (deep audit), 2026-07-06, against workspace-root commit `fb76b5b`.
This file is a cache, not an authority — current files win on any conflict.

Reconciled on 2026-07-07. Root remains `fb76b5b`; nested repo HEADs remain
TRR-Backend `8ea7aa1a` and TRR-APP `83778e5c`, with dirty worktrees in both
nested repos and the workspace root. Plan drift checks for `plans/001-006`
resolved cleanly at the committed-head level.

## Layout

- `/Users/thomashulihan/Projects/TRR` — **workspace root repo** (`therealityreport/trr-workspace`): Makefile orchestration (~36KB), `scripts/` (~112 entries), `docs/` (contracts, governance, runbooks). Contains two **independent nested git repos** (not submodules — intentional; root `git status` is false-clean for nested files):
  - `TRR-Backend/` — Python 3.11 FastAPI (`api/`) + pipeline library (`trr_backend/`), Supabase Postgres, Modal cloud jobs. ~432 py files in api+trr_backend, 447 test files.
  - `TRR-APP/` — pnpm workspace (`pnpm@11.5.2`, Node 24). Main app `apps/web`: Next.js 16.2.9, React 19.2.7, TypeScript 5.9, vitest, Playwright, Sentry, Firebase + Supabase. 467 test files. `apps/vue-wordle` excluded from workspace.
- Nested repo HEADs at audit time: TRR-Backend `8ea7aa1a`, TRR-APP `83778e5c`. Both trees dirty (active cast-screentime + social-analytics work).

## Verified build / test / lint commands

Backend (run from `TRR-Backend/`, venv at `.venv/`):
- Import gate: `.venv/bin/python -c "import api.main"` — **verified locally, passes** (latest: 2026-07-07).
- Blocking test gate (CI): `.venv/bin/python -m pytest tests/api -q` — **verified locally, passes** (latest: 2026-07-07, `1104 passed, 12 warnings`; CI contract in `TRR-Backend/.github/workflows/ci.yml`).
- Lint: `ruff check <files>` (CI lints changed files only, forward-only).
- Lock freshness (CI): `uv pip compile requirements.in --python-version 3.11 -o requirements.lock.txt` then diff.
- **Known**: full `pytest` has ~18 cross-test-pollution failures that pass in isolation; only `tests/api` blocks merge. Re-run failures in isolation before attributing them to a change.
- Test markers: `browser`, `vision`, `live` excluded from lean CI lane (`pytest.ini`).

App (run from `TRR-APP/`):
- Typecheck: `pnpm -C apps/web run typecheck` (tsc --noEmit) — **verified locally, passes** (2026-07-06, dirty tree).
- Unit tests: `pnpm -C apps/web run test` (vitest; CI uses `test:ci`).
- Lint: `pnpm -C apps/web run lint` (eslint, 8GB heap).
- Quick gate: `pnpm -C apps/web run validate:quick` (generated:check + 3 vitest files) — **verified locally, passes** (latest: 2026-07-07 via `make app-validate-quick`).
- Build: `pnpm -C apps/web run build` (`scripts/safe-next-build.mjs`).
- CI: `TRR-APP/.github/workflows/web-tests.yml`, `TRR-APP/.github/workflows/firebase-rules.yml`.

Workspace root: `make git-branch-report` before branch-ref changes; `make dev-hybrid` needs sudo (Portless 443) — don't start it headless.

## Conventions

- Backend: ruff py311, line 120, double quotes, isort via ruff; FastAPI routers in `api/routers/` (exemplar: `api/routers/admin_show_reads.py`); repositories in `trr_backend/repositories/`; tests mirror layout under `tests/`.
- App: admin UI in `apps/web/src/components/admin/`, server data access in `apps/web/src/lib/server/admin/*-repository.ts`, admin API proxy routes under `apps/web/src/app/api/admin/`, tests in `apps/web/tests/` (exemplar: `apps/web/tests/social-landing-repository.test.ts`).
- Cross-repo rule (AGENTS.md): backend first for schema/API/auth/shared contracts.
- Generated artifacts checked in: `apps/web/src/lib/admin/api-references/generated/`, backend `supabase/schema_docs`, `docs/Repository/generated/` — regenerate via scripts, never hand-edit.

## Intent docs

- `TRR-Backend/CONTEXT.md` — domain language for Instagram/social ingestion (complete-post-snapshot, lane budgets, partial-success-with-retry-queue, source-unavailable evidence). Use this vocabulary in plans.
- `TRR-Backend/docs/adr/0001-adaptive-instagram-scrape-control-plane.md` — **decided**: scrape pressure centralized in a shared adaptive control plane publishing lane budgets; lanes enforce budgets lane-specifically. Not a finding.
- AGENTS.md (root + per-repo): Portless clean URLs (`https://admin.trr.localhost` etc.) are the documented dev URLs; five-label triage vocabulary; GitHub Issues on `therealityreport/trr-workspace`.

## Audit scope skips

Skipped everywhere: `node_modules`, `.venv`, `.next`, `__pycache__`, `.git`, `TRR-Backend/{debug_html,out,logs,data,keys(content — location noted for security),.pytest_cache}`, root `{.playwright-mcp,.plan-grader,.plan-work,.planning,.tmp,.logs,.loom-backup,.full-review,.impeccable,.codex-tmp,output,artifacts,reviews,profiles,tool-finder-*,BRAVOTV}`, `TRR-APP/apps/vue-wordle`.

## 2026-07-08 social-focus deep-audit refresh

Run scope: social-media pipeline only (`/improve-more deep`, plans written for the
Codex executor). Heads at this run: root `fb76b5b`, Backend
`8ea7aa1a`, App `83778e5c`; both nested trees still dirty (plans 001-024 landed
locally, uncommitted) — **working tree is authoritative**. Backend import gate
re-verified 2026-07-08 (`.venv/bin/python -c "import api.main"` → ok).

Social surface map (measured 2026-07-08):

- `TRR-Backend/trr_backend/socials/` — instagram/ 55 files 44.9K lines; pipelines/
  12.4K; control_plane/ 7.4K; tiktok/ 6.5K; twitter/ 6.1K; youtube/ 6.0K; threads/
  4.7K; socialblade/ 4.4K; analytics/ 3.9K; read_models/ 3.4K; facebook/ 3.2K;
  crawlee_runtime/ 1.0K; account_catalog/ 110 lines; plus root modules
  (scrapling_transport.py 486, browser_cookie_refresh.py 723, decodo_usage.py 298,
  media_url_safety.py 236, account_browser_sessions.py 319, _retry.py 113,
  rollout_flags.py 35) and `social_season_analytics_impl.py` 68.7K (known god
  module; first slice extracted by plan 017).
- `trr_backend/modal_jobs.py` 2.0K; `modal_dispatch.py` 825.
- `api/routers/socials/` — `__init__.py` 9.4K (known god router), analytics
  caches, analytics_read, reddit, season_ingest, worker_health, legacy_scrape;
  plus `admin_social_posts.py`, `admin_socialblade.py`, `admin_reddit_reads.py`.
- `scripts/modal/` — 15 ops scripts (deploy, canary, secret prep, cookie
  refresh/repair, IG auth verify, readiness).
- `supabase/migrations/` — social rollups (instagram 20260610190000, tiktok
  20260625172000, youtube 20260702181000), rate pace 20260625161000, proxy budget
  ledger 20260629140000, rollup/rate-pace security 20260702184229, index drop
  wave 20260702185000.
- `tests/socials/` — 143 test files.
- App: `apps/web/src/app/admin/social/**`, 88 route dirs under
  `api/admin/trr-api/social*`, `lib/server/admin/social-landing-repository.ts`.

Intent docs for this scope: `TRR-Backend/CONTEXT.md` (Instagram ingestion
vocabulary — quote it in plans), `docs/adr/0001-adaptive-instagram-scrape-control-plane.md`
(settled design). No `CONTEXT-MAP.md` at root. `.plan-work/` throughput notes from
June no longer exist at their remembered paths — treated as gone.

## Rejection list (considered and rejected)

See `plans/README.md` → "Findings considered and rejected" for full rationale. Summary:
- Dockerfile `COPY . .` baking `.env`/`keys/` — FALSE POSITIVE (`.dockerignore` already excludes them; `keys/` untracked + gitignored).
- "No CI exists" (backend) — INCORRECT (`TRR-Backend/.github/workflows/ci.yml` has 5 jobs incl. py312 canary).
- `InternalAdminUser = None` as auth bypass — REJECTED (FastAPI always runs `Annotated[...,Depends()]`; default is dead code, not a bypass).
- Core-table open-read RLS — BY DESIGN (public read-only browse; admin writes bypass RLS via direct SQL).
- Adaptive scrape control-plane design — SETTLED by docs/adr/0001 (only impl bugs are findings).
- Rollup trigger / posts-pacing advisory lock — already applied to DB.

## 2026-07-08 social deep audit #3 spot-check

Third `/improve-more deep` run, scoped to everything social (workers, scrapers,
app UI, socials core, secrets-at-rest). Heads at this run: root `ba70326`,
TRR-Backend `8ea7aa1a`, TRR-APP `83778e5c`; nested trees still dirty and
**authoritative** (audit read on-disk files, not HEAD). Wrote plans 035–041.

Commands re-verified this run:
- Backend import gate `.venv/bin/python -c "import api.main"` → **passes**.
- Focused-test targets confirmed to exist for every plan:
  `tests/socials/test_media_url_safety.py`, `tests/socials/test_avatar_ssrf_guard.py`
  (035); `tests/repositories/test_reddit_refresh.py` (036);
  `tests/scripts/test_social_worker.py` (037);
  `tests/socials/threads/posts_scrapling/test_{fetcher,job_runner}.py` (038);
  `tests/socials/youtube/test_scraper.py` (039); `tests/scripts` retire/cleanup
  (040); `tests/socials/test_cookie_refresh_flows.py` (041).
- Repo visibility: all three repos PUBLIC (unchanged). Security plans
  035/040/041 are remediation-focused, no secrets/exploit strings; 041 confirmed
  nothing under `data/`/`keys/`/`.locks/` is tracked (`git ls-files` empty).

New coverage this run vs. the prior two: `scripts/socials/**` + `scripts/workers/**`
(worker fleet), the Reddit lane end-to-end, YouTube+SocialBlade, Twitter/Threads/
Facebook, app-side social UI, and the socials core subpackages `media_url_safety`,
`account_catalog`, `analytics`, `api`, `ops`, `pipelines`, `read_models`,
`platforms`/`source_scopes`. Not re-audited (prior runs): `modal_jobs.py`,
`social_season_analytics_impl.py`, `api/routers/socials/**`, instagram/tiktok
scraper lanes, `browser_cookie_refresh.py` (except its reused private-file
helpers), control_plane lifecycle/dispatch, `inline_ingest.py`, decodo usage.

## 2026-07-08 `execute 035-041` — all seven DONE (GPT-5.5 via Codex)

All seven social deep-audit #3 plans executed + advisor-reviewed + APPROVED, then
archived to `plans/archive/`. Branches (off `8ea7aa1a`): 035 `f4a87c76`, 036
`fd07a1a2`, 037 `7e5a9a28`, 038 `14ff1913`, 039 `a8bb0640`, 040 `95a7d067`, 041
`acafaf33`. Consolidated `advisor/social-batch-035-041` (24 files) verified:
worker imports + **178 touched-area tests pass** + `bash -n` clean. Lands
conflict-free on the active dirty backend branch (035–040 files clean there; 041's
only overlaps with the integrated 029 change are byte-identical ruff wraps that
auto-merge + additive code). Nothing merged to the user's branch — merge is the
user's call. Codex dispatch harness lives at the session scratchpad
(`dispatch.sh` + `preamble.txt`); resume note: `codex exec resume <id>` does NOT
accept `-C`/`-s` (set sandbox via `-c sandbox_mode=...`, run from the worktree cwd).
Operator follow-up (041): complete the credential rotation and permission
verification described in plan 041's maintenance notes.

## 2026-07-08 `execute 042-047` — five more DONE (GPT-5.5 via Codex)

Promoted 5 confirmed backlog findings (C27/C26/C43/C31/C36) to plans 042-045,047
(046 reserved — needs an FB SSR fixture), executed + reviewed + APPROVED (no
revisions), archived to `plans/archive/`. Branches off `8ea7aa1a`: 042 `730480cd`,
043 `51732723`, 044 `56b51201`, 045 `c2f713db`, 047 `4a9afb35`. Consolidated
`advisor/social-batch-042-047` (11 files) verified: import OK + 137 touched-area
tests pass. Lands conflict-free on the active dirty tree (only 042's 1-line
`_pg_upsert` change overlaps a dirty file, on an unmodified line → clean 3-way).
New follow-up C50: the youtube like-count parser (`scraper.py:4220`) has the same
dead-`runs`-fallback bug 044 fixed for view counts.
