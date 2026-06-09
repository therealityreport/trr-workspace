# TRR Monorepo — Findings Remediation Plan (Revised)

**Source:** `.full-review/05-final-report.md` + `_raw-findings.json` (124 findings: 2 Critical, 32 High, 53 Medium, 37 Low; +4 completeness items).
**Revised by:** plan-architect (2026-05-29). **Initial snapshot:** `.full-review/plan-architect/INITIAL_PLAN.md`. **Status:** execution-ready for `orchestrate-subagents` (scoped).

## Summary

Remediate the review findings in priority order, **backend-first**, making existing guardrails *enforced*, closing confirmed security exposures, testing auth-critical paths, and **staging** the large refactors. All irreversible / production-affecting actions are isolated, human-gated (🔒), and excluded from subagent auto-execution. Parallel execution is organized into **waves with strict file-ownership boundaries** because `orchestrate-subagents` runs on `main` without branches — two agents must never hold the same file.

## Project Context

- **Repos:** `TRR-Backend/` (Python 3.11 / FastAPI / Supabase / Modal / Render), `TRR-APP/apps/web` (Next.js 16 / React 19 / Firebase / Vercel; `apps/vue-wordle`), workspace tooling. `screenalytics/` retired/out-of-scope.
- **Contracts:** backend-first for schema/API/auth/RLS; app follow-through same slice; Modal-affecting backend/worker/job changes redeployed to Modal on completion.
- **Evidence:** every finding has `file:line` + evidence in `_raw-findings.json`; C/H adversarially verified (29 confirmed, 1 refuted [excluded], 1 uncertain [verify-first]).

## Assumptions

1. Plan covers all tiers; **auto-execution is scoped at the checkpoint** — default = Phase 0-A + Wave 1 parallel-safe workstreams. Phase 0-B is human; Wave 3 refactors are human-scheduled.
2. Refuted finding (TRR-APP "middleware dead code") **excluded** (logic in `src/proxy.ts`).
3. Uncertain finding + 4 unverified completeness leads are **Gate G0 / Workstream V (verify-first)** — fixes scheduled only after confirmation.
4. `orchestrate-subagents` works on `main`, no branches → **single-owner files; commit at each wave boundary; parallelism only across disjoint paths within a wave**.
5. Production DB changes are additive Supabase migrations reviewed by a human; never ad-hoc SQL on live.

---

## Execution Waves & Ownership Matrix  *(plan-architect addition — read before scheduling)*

**Rule:** within a wave, workstreams run in parallel **only if their owned paths are disjoint**. Single-owner files may be touched by exactly one workstream at a time. Commit + validate at each wave boundary before the next starts.

| WS | Workstream | Owned paths (exclusive) | Single-owner / conflict | Wave |
|---|---|---|---|---|
| 0A-cron | Cron fail-open | `TRR-APP/.../api/cron/episode-progression/route.ts`, `.../create-survey-runs/route.ts` | — | **1** |
| 0A-modal | Modal ingress + `/metrics` gate | `TRR-Backend/trr_backend/modal_jobs.py`, `TRR-Backend/api/main.py` (metrics + lifespan block) | `api/main.py` shared with W1.3 → **0A-modal edits main.py first; W1.3 rebases** | **1** |
| W1.1 | CI enforcement | `TRR-Backend/.github/workflows/*`, `TRR-APP/.github/workflows/*`, **new** `/.github/workflows/workspace-tooling.yml` | — | **1** |
| W1.2 | Auth-critical tests | `TRR-Backend/tests/**`, `TRR-APP/apps/web/tests/**` (incl. `tests/api/routers/conftest.py`) | — | **1** |
| W1.4 | App Router robustness | **new** `TRR-APP/apps/web/src/app/**/{error,loading,not-found,global-error}.tsx`; `TRR-APP/apps/web/package.json` + `pnpm-lock.yaml` | package.json/lock = **single dependency owner** | **1** |
| W1.6 | Docs hygiene | `.planning/codebase/**` | — | **1** |
| W1.7 | Workspace tooling | `Makefile`, `scripts/**` | — | **1** |
| W1.3 | Info-leak sanitizer | **new** `TRR-Backend/trr_backend/api_errors.py`; broad `TRR-Backend/api/routers/**`; `TRR-APP/apps/web/src/lib/server/trr-api/**` | `api/routers/**` broad → **conflicts S1/S2; must finish before Wave 3** | **2** |
| W1.5 | Perf hotfixes | `TRR-Backend/trr_backend/repositories/social_sync_orchestrator.py`; TRR-APP `inventory.ts` import boundary | `inventory.ts` single-owner | **2** |
| W1.S1 | Refactor god-functions | `TRR-Backend/api/routers/admin_person_images.py` | single-owner; after W1.3 | **3** |
| W1.S2 | Decompose social monolith | `TRR-Backend/trr_backend/socials/social_season_analytics_impl.py` (+ facade) | single-owner; after W1.3 | **3** |
| W1.S3 | Split admin page | `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx` | single-owner | **3** |
| 0B 🔒 | Irreversible/prod | migrations (new), `TRR-Backend/keys/**`, GitHub settings | **human only** | **Wave 0 (parallel, human)** |
| V | Verify-first gate | read-only investigation | — | **G0 (before its dependents)** |

**Wave summary:**
- **Wave 0 (human, anytime):** 0B 🔒 items.
- **Gate G0 (verify-first):** Workstream V confirms/refutes the 5 leads; confirmed ones promote into Wave 1/2 (e.g. TRR-APP secret-scan → W1.1).
- **Wave 1 (auto, parallel — DEFAULT auto scope):** 0A-cron, 0A-modal, W1.1, W1.2, W1.4, W1.6, W1.7. All disjoint except the `api/main.py` note.
- **Wave 2 (auto, serialized by ownership):** W1.3 then/with W1.5.
- **Wave 3 (human-scheduled, sequential, staged):** W1.S1 → W1.S2 (both after W1.3) ; W1.S3 independent. Each = its own sub-plan, gated behind green tests; **scaffold + first step only**.

---

## Phase 0 — Immediate hardening

**0-A · Auto (Wave 1):**
- **0A-cron:** require `CRON_SECRET` in all envs (fail closed), drop `GET→POST` alias. *Validate:* `pnpm -C TRR-APP/apps/web test:ci`; curl without bearer → 401 in all envs. *Commit:* "fix(app): cron routes fail closed".
- **0A-modal:** add `requires_proxy_auth=True` to `@modal.asgi_app`; require auth on `/metrics`. **Modal-affecting → redeploy on completion.** *Validate:* `pytest -q tests/api`; public Modal URL rejects unauthenticated `/metrics`. *Commit:* "fix(backend): gate Modal ingress + metrics".

**0-B · 🔒 Human-gated (Wave 0 — prepare artifacts, human applies):**
- 🔒 **Revoke `anon` write/`TRUNCATE`** on `public` (Critical #1): prepare `supabase/migrations/<ts>_revoke_anon_write_grants.sql`; human applies + verifies via grants-review queries.
- 🔒 **TRR-APP `main` branch protection** (Critical #2): require `web-tests` + full typecheck; human sets via repo settings/`gh api`.
- 🔒 **Remove + rotate `TRR-Backend/keys/*`** (High): move 3 keys to secret store, rotate in GCP/Firebase, add preflight failing on non-empty `keys/`.
- 🔒 **Reconcile live grant/RLS divergence** (High/Med): corrective migrations for anon-write-only-in-prod and `core.cast_tmdb` RLS-only-in-live; human applies.

## Phase 1 — High (Waves 1–2; refactors scaffolded in Wave 3)

- **W1.1 CI:** full backend pytest + `ruff` + `pyright` gates; root `workspace-tooling.yml`; **secret-scan in TRR-APP**; pin actions to SHAs; sandbox `repo_map.yml`. *Acc:* CI **blocks** on failure for both repos. *Commit per repo.*
- **W1.2 tests:** JWT `alg:none`/issuer/project-ref, admin allowlist, `require_facebank_seed_admin`, degraded-auth path; firestore.rules behavioral harness (emulator allow/deny in `firebase-rules.yml`); fix the autouse `service_role` conftest fixture. *Acc:* new tests fail before fix, pass after; CI runs them.
- **W1.3 sanitizer (Wave 2, backend-first):** shared error util → no `str(exc)` in 111 `HTTPException.detail` sites; then strip `TRR_API_URL`/cause from 10 app admin-proxy error bodies. ⚠️ broad `api/routers/**` — must complete before Wave 3 S-streams. *Acc:* grep for leaked origin/raw exc returns 0 in responses.
- **W1.4 app robustness:** App Router `error/loading/not-found/global-error` boundaries; unify `firebase-admin` major version + drop `@firebase/*` hoist workaround. *Acc:* boundaries render on thrown error; single firebase-admin version resolved.
- **W1.5 perf (Wave 2):** bound the sync-orchestrator tick (aggregate query, no full scans/Python counting); move 804KB `inventory.ts` out of client bundle (server-only/dynamic). *Acc:* orchestrator query plan bounded; `inventory.ts` absent from client chunks (`build` analysis).
- **W1.6 docs:** regenerate or delete stale `.planning/codebase/` maps. *Acc:* no map references retired `screenalytics/`.
- **W1.7 tooling:** fix `make dev-hybrid-bg` pidfile + wire `make stop`; track files committed scripts depend on. *Acc:* `make preflight && make workspace-contract-check` green.
- **W1.S1/S2/S3 (Wave 3, staged):** extract god-functions → pipeline stages; split 61k monolith by capability behind the facade; split 16.9k page → server loader + client sections. **Scaffold + one safe step behind green tests; each is its own future plan.**

## Phase 2 — Medium (next sprint) — 53 findings

Grouped (full list in `_raw-findings.json`). **Cross-repo credential slice (coordinated, backend-first, with rollback):** remove the two always-on static-shared-secret header gates → require signed internal-admin JWT — change backend verify (`api/auth.py`) + app/Modal minting **in one slice**, with a feature flag + rollback, because splitting it risks lockout. Other clusters: security (AWS key removal, SSRF guard parity, JWT issuer no-op, dev-admin-bypass prod stop, Firestore global-writable, anon survey RPC, `cast_tmdb` RLS migration); architecture (service layer, web-writes-`core.*`, `/api/v1` contract, `is_queue_enabled` dedupe); quality (954 `noqa` cleanup, helper dedup, swallowed exceptions); app perf/best-practice (caching, RSC adoption, DebugPanel, double-casts); testing/CI/docs (de-brittle 46k test, DB-integration coverage, full app typecheck gate, observability baseline, stale maps).

## Phase 3 — Low (backlog) — 37 findings

Batch by theme; reference phase files for `file:line`.

## Workstream V — Verify-first gate (G0, read-only)

Confirm/refute, then schedule confirmed fixes: (1) migration-testing gap [uncertain]; (2) no `--hash=` pins in `requirements.lock.txt`; (3) TRR-APP no secret scanning → if confirmed **promote to W1.1**; (4) destructive flashback migration archival; (5) no committed `database.types.ts`.

---

## Data / API / Auth Impact

- **DB:** additive migrations only; destructive/grant/RLS changes human-reviewed.
- **API:** Modal auth + `/metrics` gating change reachability, not contract; sanitizer reduces error-body info (confirm no client parses error text).
- **Auth:** static-secret-gate removal changes accepted credentials → single coordinated cross-repo slice + rollback.

## Validation (run at each wave boundary)

- **Backend:** `cd TRR-Backend && ruff check . && ruff format --check . && pyright && pytest -q`
- **App:** `pnpm -C TRR-APP/apps/web lint && typecheck && test:ci && build`; firestore-rules emulator suite green.
- **Workspace:** `make preflight && make workspace-contract-check && bash scripts/test-changed.sh`
- **Modal:** redeploy backend app; confirm proxy-auth + gated `/metrics`.
- **Per finding:** re-run its `evidence` reproduction → no longer matches.

## Acceptance Criteria

- **Phase 0:** both Criticals closed + verified; cron fail closed; Modal/`/metrics` gated; keys removed+rotated.
- **Phase 1:** CI blocks on full backend tests + ruff + pyright + app secret-scan; auth-critical tests present/passing; no origin/`str(exc)` leakage; App Router boundaries present; orchestrator query bounded; `inventory.ts` out of client bundle; stale maps gone. Refactors have approved staged sub-plans + first step landed.
- **Global:** every targeted finding's evidence reproduction passes; full validation suite green.

## Risks / Open Questions

- Irreversibility (grants/keys/branch-protection/destructive migrations) — human-gated; verify legitimate writers before revoking.
- Parallel-edit conflicts — enforced by the ownership matrix; clean tree required (`orchestrate-subagents` on `main`).
- Auth-credential change — coordinated slice + rollback or risk lockout.
- Open: auto-execution scope — resolved at checkpoint (default = Phase 0-A + Wave 1).

## Recommended Handoff

`plan-architect` → **checkpoint (human: confirm auto-scope + own 🔒 items)** → `orchestrate-subagents` executes Wave 1 (then Wave 2) from `main`, single-owner boundaries, backend-first within slices, Modal redeploy on completion. See `.full-review/plan-architect/HANDOFF.md` for the wave runbook.

## Ready For Execution

**Ready for scoped `orchestrate-subagents` execution of Wave 1 + Wave 2.** Wave 0 (🔒) is human. Wave 3 refactors are human-scheduled sub-plans. Gate G0 (Workstream V) runs first.

**saved_path:** `/Users/thomashulihan/Projects/TRR/.full-review/REMEDIATION_PLAN.md`
