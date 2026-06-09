# TRR Monorepo — Findings Remediation Plan

**Source:** `.full-review/05-final-report.md` + `.full-review/_raw-findings.json` (124 findings: 2 Critical, 32 High, 53 Medium, 37 Low; +4 completeness-pass items).
**Date:** 2026-05-29 · **Status:** draft for `plan-architect` refinement → `orchestrate-subagents` execution.

## Summary

Remediate the comprehensive-review findings in priority order, **backend-first**, so the TRR monorepo (TRR-Backend, TRR-APP, workspace tooling) is materially safer and more maintainable. The dominant outcome is to **make existing guardrails enforced** (branch protection, lint/type/test/secret-scan gates), **close confirmed security exposures** (anon DB grants, leaked origins, key storage, cron/Modal ingress), **test the auth-critical code paths**, and **stage** the large structural refactors rather than attempt them in one pass. Irreversible / production-affecting actions are isolated and gated behind explicit human checkpoints and must not be auto-applied by subagents.

## Project Context

- **Repos:** `TRR-Backend/` (Python 3.11 / FastAPI / Supabase / Modal / Render), `TRR-APP/apps/web` (Next.js 16 / React 19 / Firebase / Vercel; secondary `apps/vue-wordle`), workspace tooling (`scripts/`, `profiles/`, `Makefile`, `docs/`, CI).
- **Contracts:** backend-first for schema/API/auth/RLS, with app follow-through in the same logical slice (`CLAUDE.md`). Modal-affecting backend/worker/job changes are sent to Modal on completion. `screenalytics/` is retired and out of scope.
- **Evidence base:** all findings carry `file:line` + evidence in `_raw-findings.json`; Critical/High were adversarially verified (29 confirmed, 1 refuted, 1 uncertain).

## Clarification Answers

No blocking clarifications. User pre-specified: all tiers in scope, backend-first, exclude the refuted finding, flag verify-first items, stage structural refactors, gate irreversible items. The remaining decision — *how much to auto-implement* — is intentionally deferred to the pre-execution checkpoint (see Recommended Handoff).

## Assumptions

1. **Plan covers all tiers; auto-execution is scoped at the checkpoint.** Default recommendation: auto-apply Phase 0 (code/config only) + Phase 1 via subagents; human executes the gated items; Phase 2/3 + structural refactors are scheduled, not force-run.
2. The 1 **refuted** finding (TRR-APP "middleware dead code") is **excluded** — logic lives in `src/proxy.ts` and runs.
3. The 1 **uncertain** finding (migration testing gap) + 4 **unverified** completeness leads are **verify-first** (Workstream V) before any fix.
4. `orchestrate-subagents` executes on `main` without branches; therefore **single-owner files** (the monoliths) must not be edited by two workstreams concurrently — see per-phase Ownership notes.
5. Production DB changes go through additive Supabase migrations (never ad-hoc SQL on live), per repo convention.

---

## Implementation Changes

### Phase 0 — Immediate hardening (Criticals + security quick-wins)

**0-A · Auto-applicable (subagent-executable code/config):**
- **Close cron fail-open (2 routes).** Require `CRON_SECRET` in all envs (fail closed), drop the unauthenticated `GET→POST` alias. Files: `TRR-APP/apps/web/src/app/api/cron/episode-progression/route.ts`, `.../create-survey-runs/route.ts`. (App-only.)
- **Gate the Modal public ingress.** Add `requires_proxy_auth=True` to the `@modal.asgi_app` and require auth on `/metrics`. Files: `TRR-Backend/trr_backend/modal_jobs.py` (~L576-580), `TRR-Backend/api/main.py` (metrics route). **Modal-affecting → redeploy on completion.**

**0-B · Human-gated (IRREVERSIBLE / production — DO NOT auto-apply; prepare artifacts + checkpoint):**
- **🔒 Revoke `anon` write/`TRUNCATE` on all `public` tables** (Critical #1). Prepare a corrective additive migration `TRR-Backend/supabase/migrations/<ts>_revoke_anon_write_grants.sql`; human reviews + applies to live DB; verify with the queries in `docs/workspace/supabase-rls-grants-review.md`.
- **🔒 Enable TRR-APP `main` branch protection** (Critical #2). GitHub repo setting (require `web-tests` + full typecheck). Human action (`gh api`/repo settings) — not a code change.
- **🔒 Remove + rotate `TRR-Backend/keys/*` service-account keys** (High). Move 3 keys out of the repo tree to a secret store; rotate in GCP/Firebase; add a preflight that fails if `keys/` is non-empty.
- **🔒 Reconcile live-DB grant/RLS divergence** (High + Medium): anon write grants existing only in prod; `core.cast_tmdb` RLS enabled only in live, not migrations. Prepare corrective migrations so fresh environments match prod hardening; human applies.

### Phase 1 — High (this sprint, ~30 confirmed)

> **Ownership / parallelization:** W1.1, W1.2, W1.4, W1.6, W1.7 are mostly additive (new files) and parallel-safe. **W1.3 and the perf fixes touch broad/monolith files — serialize them and keep monoliths single-owner.**

- **W1.1 · CI enforcement (backend-first).** Expand `TRR-Backend/.github/workflows/ci.yml` to run the full pytest suite (or risk-tiered subsets) + add `ruff` + `pyright` gates; add a **root `.github/workflows/workspace-tooling.yml`** running the contract/guardrail tests (`scripts/test_*.py`, `check-workspace-contract.sh`, `workspace-env-contract.sh --check`); add **secret scanning to TRR-APP**; pin all actions to commit SHAs; sandbox `repo_map.yml`'s untrusted-PR execution / drop write token. (Resolves: backend CI ~15% coverage, no ruff/pyright CI, no app secret-scan, action pinning, repo_map token.)
- **W1.2 · Auth-critical test coverage.** Add tests: JWT `alg:none`/algorithm-confusion rejection, issuer/project-ref derivation chain, `require_facebank_seed_admin`, the `AUTH_SERVICE_UNAVAILABLE` degraded path; admin allowlist decision (`src/lib/server/auth.ts`); a **behavioral `firestore.rules` harness** (emulator allow/deny asserts wired into `firebase-rules.yml`). **Fix the autouse conftest fixture** that re-enables `service_role` admin promotion across ~39 router tests. Files: `TRR-Backend/tests/**`, `TRR-APP/apps/web/tests/**`.
- **W1.3 · Info-leak hardening (backend-first).** Add a shared error sanitizer in the backend (stop `str(exc)` in `HTTPException.detail` across 111 sites) and stop `TRR_API_URL`/raw cause in the 10 app admin-proxy error bodies. Backend sanitizer lands first; app proxy fix follows. ⚠️ Broad-touch; serialize vs monolith refactors.
- **W1.4 · App robustness.** Add App Router `error.tsx`/`loading.tsx`/`not-found.tsx`/`global-error.tsx` boundaries (root + key admin segments); unify `firebase-admin` to one major version (root vs `apps/web`) and remove the `@firebase/*` hoisting workaround. Files: `TRR-APP/apps/web/src/app/**` (additive), `package.json` + lockfile.
- **W1.5 · Performance hotfixes.** Bound the sync-orchestrator tick (`trr_backend/repositories/social_sync_orchestrator.py`) — replace full-table scans + Python counting with bounded/aggregated queries; remove the 804KB generated `inventory.ts` from the client bundle (move behind a server-only import / dynamic boundary). ⚠️ `inventory.ts` overlaps W1.S* — single-owner.
- **W1.6 · Docs hygiene.** Regenerate or delete the stale `.planning/codebase/` maps (they describe retired `screenalytics/` + a monolith that's now a shim + wrong cross-repo order). Add a regenerator or remove the orphaned artifacts.
- **W1.7 · Workspace tooling.** Fix the dead-on-arrival `make dev-hybrid-bg` pidfile + wire into `make stop`; track the untracked files that committed scripts depend on (or guard their absence). Files: `Makefile`, `scripts/`.
- **W1.S1–S3 · STAGED structural refactors (scaffold only this sprint — do NOT one-shot):**
  - **S1** `api/routers/admin_person_images.py` — extract the 3,912-/3,253-line god functions into named pipeline stages; first safe step = carve out one stage behind tests.
  - **S2** `trr_backend/socials/social_season_analytics_impl.py` (61k) — split by capability (ingestion/mirror/analytics/orchestration); first step = move one platform-ingest module out behind the existing facade.
  - **S3** `TRR-APP/.../admin/trr-shows/[showId]/page.tsx` (16.9k) — split into server loader + focused client sections; first step = extract data-fetch to a server module.
  Each S-stream is its own future plan; single-owner per file; gated behind green tests.

### Phase 2 — Medium (next sprint) — 53 findings

Grouped workstreams (full list in `_raw-findings.json`):
- **Security cluster:** remove hardcoded AWS AppSync key from `nbcumv.py`; remove/replace the two always-on static-shared-secret header gates (require signed internal-admin JWT); apply SSRF guard to `face_crops`/`image_variants` (parity with `s3_mirror`); fix JWT issuer/project-ref silent no-op; add a hard production stop to the dev-admin-bypass; tighten Firestore global game-analytics write rule; add dedup/rate-limit to anon `surveys.submit_response`.
- **Architecture/boundary:** introduce a backend service layer (routers stop owning data access); stop the web app writing `core.*` owned by backend; harden the `/api/v1` auto-append contract; dedupe `is_queue_enabled`.
- **Quality:** remove 954 cargo-cult `# noqa: BLE001`; consolidate `_normalize_text`/`_env_truthy` duplicates; address 71 swallowed exceptions.
- **App best-practices/perf:** caching strategy (replace blanket `cache:'no-store'`); adopt RSC/server-data APIs incrementally; remove `DebugPanel` from prod layout; reduce `as unknown as` double-casts; `optimizePackageImports`.
- **Testing/CI/docs:** de-brittle the 46k social test; raise DB-integration coverage; full app typecheck gate; add observability (Sentry/OTel) baseline; refresh stale `CONCERNS/INTEGRATIONS/TESTING` maps.

### Phase 3 — Low (backlog) — 37 findings

Track in backlog; batch by theme (vue-wordle lockfile, client-bundle leakage of server modules, DI style, async `time.sleep`, coverage `all:true`, stale skipped tests, `env-contract.md` perms, etc.). Reference `04-best-practices.md`/`01-…`/`02-…` for `file:line`.

### Workstream V — Verify-first (before fixing)

Confirm/refute with `file:line` evidence, then fold real ones into the right phase: (1) uncertain — migration testing gap; (2) `requirements.lock.txt` has no `--hash=` integrity pins; (3) TRR-APP has no secret scanning *(promote to W1.1 if confirmed)*; (4) destructive flashback migration archival; (5) no committed Supabase `database.types.ts`.

---

## Data / API Impact

- **DB:** new additive migrations only (grant revokes, RLS reconciliation, optional FK/索引 for the slug-scan fix). No destructive changes without human review.
- **API:** Modal asgi auth + `/metrics` gating change network reachability, not the contract. Error-sanitizer changes error *bodies* (less info) — confirm no client parses error text.
- **Auth:** removing static-shared-secret header gates changes accepted credentials — coordinate cross-repo (backend verify + app/Modal minting) in the same slice.

## Validation

- **Backend:** `cd TRR-Backend && ruff check . && ruff format --check . && pyright && pytest -q` (and the newly-broadened CI subset). Migration dry-run/apply on a branch DB; re-run the grants-review queries.
- **App:** `pnpm -C TRR-APP/apps/web lint && pnpm -C TRR-APP/apps/web typecheck && pnpm -C TRR-APP/apps/web test:ci && pnpm -C TRR-APP/apps/web build`; firestore-rules emulator allow/deny suite green in `firebase-rules.yml`.
- **Workspace:** `make preflight && make workspace-contract-check && bash scripts/test-changed.sh`.
- **Modal:** redeploy backend Modal app; confirm `/metrics` now requires auth and proxy-auth is enforced on the public URL.
- **Per finding:** re-run the exact reproduction/grep in each finding's `evidence` and confirm it no longer matches.

## Acceptance Criteria

- **Phase 0:** both Criticals closed (anon grants revoked + verified; branch protection on `main` with required checks); cron routes fail closed in all envs; Modal ingress + `/metrics` gated; keys removed from repo + rotated.
- **Phase 1:** CI runs full backend tests + ruff + pyright + app secret-scan and **blocks** on failure; all listed auth-critical tests exist and pass; no `TRR_API_URL`/`str(exc)` in client error bodies; App Router boundaries present; sync-orchestrator query bounded; `inventory.ts` out of the client bundle; stale maps regenerated/removed. Structural refactors have an approved staged plan + first step landed behind green tests.
- **Phase 2/3:** scheduled with owners; each finding's evidence check passes after its fix.
- **Global:** every targeted finding's `evidence` reproduction no longer triggers; full validation suite green.

## Risks / Open Questions

- **Irreversibility:** anon-grant revoke / key rotation / branch protection / destructive migrations are human-gated; a wrong revoke could break a legitimate client path — verify which roles legitimately write before revoking.
- **Parallel-edit conflicts:** monolith files are single-owner; `orchestrate-subagents` runs on `main` — a clean tree and serialized monolith work are prerequisites.
- **Auth-credential change** (removing static-secret gates) risks lockout if backend/app/Modal aren't updated together — do in one cross-repo slice with a rollback.
- **Open:** how much to auto-implement now (see Assumption 1) — resolve at checkpoint.

## Recommended Handoff

1. **`plan-architect`** — refine/sequence this plan, sharpen workstream ownership boundaries and the staged-refactor sub-plans, grade for execution-readiness.
2. **Checkpoint (human):** choose auto-execution scope (recommended: Phase 0-A + Phase 1 parallel-safe workstreams). Confirm the Phase 0-B gated items will be executed by a human.
3. **`orchestrate-subagents`** — execute the approved, scoped workstreams from `main` with single-owner file boundaries; exclude all 🔒 gated items; backend-first within each slice; send Modal-affecting changes to Modal on completion.

## Ready For Execution

**Plan: ready for `plan-architect` refinement.** Direct code execution is **gated** on (a) the scope checkpoint and (b) human handling of the 🔒 irreversible items. Phase 0-A and the parallel-safe Phase 1 workstreams are execution-ready once scope is confirmed.

**saved_path:** `/Users/thomashulihan/Projects/TRR/.full-review/REMEDIATION_PLAN.md`
