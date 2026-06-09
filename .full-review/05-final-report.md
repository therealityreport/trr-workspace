# Comprehensive Code Review Report — TRR Monorepo

**Generated:** 2026-05-29 · **Run mode:** Workflow (multi-agent, adversarial verification) · **Run ID:** `wf_79819782-d9a`

## Review Target

The entire TRR monorepo: **TRR-Backend** (Python 3.11 / FastAPI / Supabase / Modal / Render), **TRR-APP** (`apps/web` — Next.js 16 / React 19 / Firebase / Vercel; plus `apps/vue-wordle`), and the **workspace tooling layer** (`scripts/`, `profiles/`, `Makefile`, `docs/`, CI). The retired `screenalytics/` repo was excluded (removed 2026-05-28; only compatibility shims remain in the live repos).

## Methodology (why these findings are trustworthy)

16 specialist finders covered 8 dimensions × the relevant repo areas. **Every Critical/High finding was handed to an independent adversarial verifier** (Sonnet) that had to confirm it against the real `file:line` or mark it refuted. A completeness critic then swept for missed surfaces, and its three highest-stakes leads were verified in a dedicated follow-up pass. Medium/Low findings are single-pass (finder-reported, not independently verified); the backend best-practices dimension (`be-bestprac`) is single-pass throughout.

- **Verification outcome (Critical/High):** 29 **confirmed**, 1 **refuted**, 1 **uncertain**.
- The one **refuted** High ("host-isolation middleware is dead code") was wrong — the logic lives in `src/proxy.ts`, which Next.js *does* run. It is excluded from the action list below.

## Executive Summary

The codebase is **functionally mature and, at the data layer, more secure than it looks** (app-level auth is consistently enforced per-route; RLS is broadly applied). The health problems are **structural and process-level, not deep logic bugs**: a handful of extreme monoliths concentrate enormous change-risk, CI enforces only a thin slice of the safety nets that exist, and the most security-critical code (JWT verification, admin allowlists, Firestore rules) is the *least* tested. Two issues are genuinely Critical and cheap to fix. The single most consequential theme is **"guardrails exist but nothing forces them to run"** — branch protection, lint/type/test gates, secret scanning, and contract checks are all present somewhere but not enforced on merge.

| Severity | Count | Notes |
|---|---|---|
| **Critical (P0)** | 2 | both confirmed; both fixable in <1 day |
| **High (P1)** | 32 | 30 active (1 refuted, 1 uncertain) |
| **Medium (P2)** | 53 | single-pass |
| **Low (P3)** | 37 | single-pass |
| **Completeness pass** | +4 | 1 new Medium (Modal ingress), 1 Low–Med (2nd cron), 1 refuted (XSS), + unverified leads |

---

## P0 — Critical (fix immediately)

### 1. `anon` role holds `TRUNCATE`/`INSERT`/`UPDATE`/`DELETE` on every public-schema table in the live DB  ✅ verified
**`db-security`** · evidence in `docs/workspace/supabase-rls-grants-review.md`
The anon role has write + `TRUNCATE` on all public tables in production. **`TRUNCATE` is not subject to RLS** — a leaked/abused anon key (which is, by design, shipped to clients) could wipe tables regardless of row policies. This is a data-loss / DoS exposure.
**Fix:** `REVOKE` write + `TRUNCATE` from `anon` (and `authenticated` where not required) across `public`; encode it as a corrective migration so fresh environments match. Verify with the grants-review doc's own queries.

### 2. TRR-APP `main` has no branch protection — all web CI is advisory  ✅ verified
**`cicd-devops`** · `TRR-APP/.github/workflows/web-tests.yml`
`web-tests.yml` (lint, typecheck, vitest, build) runs but **cannot block a merge** — there is no required-status-check / branch-protection rule on `main`. Any change can land red. This silently undermines every other quality gate in the app repo.
**Fix:** enable branch protection on `main` requiring `web-tests` (and a full typecheck — see P2) to pass before merge.

---

## P1 — High (fix before next release)

Grouped by theme (all ✅ confirmed unless noted). Full detail + evidence in the phase files.

### Structural debt — extreme monoliths (highest change-risk)
- **God functions of 3,912 and 3,253 lines** in `TRR-Backend/api/routers/admin_person_images.py` (353 / 408 branch keywords; 5 routes in 17k lines). `be-quality`
- **61,116-line domain module** `trr_backend/socials/social_season_analytics_impl.py` (1,402 functions, 22 classes). `be-quality`
- **7,878-line socials router with 127 route handlers in one file** (`api/routers/socials/__init__.py`). `be-quality`
- The social control-plane "split" is a **re-export facade over the 61k god module**, not a real decomposition (`trr_backend/socials/analytics/read_models.py`). `be-arch`
- **16,907-line single `"use client"` page** with **199 `useState` + 51 `useEffect`** (`admin/trr-shows/[showId]/page.tsx`); admin components are 8k–17k-line monoliths mixing fetch + normalize + presentation. `app-bestprac`, `app-quality`

### Secrets & auth exposure
- **Live GCP + Firebase Admin service-account private keys stored unencrypted in `TRR-Backend/keys/`** (3 JSON keys). `be-security`
- **Backend origin (`TRR_API_URL`) interpolated into client-facing JSON error bodies across 10 admin routes.** `app-bestprac` (also surfaced by `app-security`, `app-arch`)
- **`/api/cron/episode-progression` fails OPEN when `CRON_SECRET` is unset in production.** `app-security`

### CI / enforcement gaps
- **Backend CI runs only `tests/api` (~15% of suite); 323 of 378 test files never run in any pipeline.** `cicd-devops`
- **No CI runs `ruff` or `pyright` anywhere** (single-pass; corroborated by `cicd-devops` "no lint/type checking" and `tooling-qa` "no root CI"). `be-bestprac`
- **Render production container runs as root** (no `USER` in `Dockerfile`). `cicd-devops`

### Security-critical code is the least tested
- **JWT secret / project-ref derivation chain is untested** (`trr_backend/security/jwt.py`). `be-testing`
- **`verify_jwt_token` has no test rejecting `alg:none` / algorithm-confusion tokens.** `be-testing`
- **`require_facebank_seed_admin` (a live auth dependency) has zero coverage.** `be-testing`
- **No behavioral test for `firestore.rules`** — CI only compiles them, never asserts allow/deny. `app-testing`
- **The core admin allowlist authorization decision is never directly tested** (`src/lib/server/auth.ts`). `app-testing`

### Performance
- **Sync-orchestrator tick runs unbounded full-table scans + Python-side counting on every session eval (up to 50× / 30s / worker)** (`trr_backend/repositories/social_sync_orchestrator.py`). `be-perf`
- **804 KB generated API-reference inventory bundled into client JS** via a `"use client"` import chain. `app-perf`
- **Heaviest admin routes are full-client monoliths** with no SSR data, no `loading.tsx`, no Suspense. `app-perf`

### App robustness, inline work, docs & tooling
- **No `error.tsx`/`loading.tsx`/`not-found.tsx`/`global-error.tsx` anywhere across 172 pages.** `app-bestprac`
- **`firebase-admin` major-version split** (root `^13.7.0` vs `apps/web ^12.7.0`) + pinned `@firebase/*` hoisting workaround. `app-bestprac`
- **Heavy scraping orchestration runs inline in the FastAPI worker** when `SOCIAL_QUEUE_ENABLED` is unset, with no dev-only guard. `be-arch`
- **Generated `.planning/codebase/` maps describe the retired `screenalytics/` repo as a live layer across all 7 files**, and document the **wrong cross-repo implementation order**. `docs-review`
- **`make dev-hybrid-bg` records a launcher PID that exits immediately** (dead `.pid`, not wired into `make stop`); **committed test/preflight/contract scripts hard-depend on files still untracked in git**. `tooling-qa`

> **Uncertain (not actioned):** "Migration behavior is effectively untested (1 grep-test covers 2 of 280 migrations)" — the verifier could not conclusively rate it; treat as a real coverage gap to investigate (see also the destructive-migration lead below).

---

## Completeness Pass (post-critic verification)

The completeness critic surfaced surfaces no finder examined. The three highest-stakes leads were verified:

- **🆕 Medium — Full FastAPI app served on a public Modal URL with no network-level auth.** `trr_backend/modal_jobs.py:576-580` (`@modal.asgi_app` re-exports `api.main:app`, no `requires_proxy_auth`). **App-level auth still applies per-route**, so the real exposure is limited to endpoints with *no* app auth: `/`, `/health*`, `/metrics`, and public `shows`/`surveys` reads — reachable with no network gating or rate limit. **Fix:** add `requires_proxy_auth=True` (or front with the Render proxy) and gate `/metrics`.
- **Low–Medium — `/api/cron/create-survey-runs` fails open when `NODE_ENV != production`** (prod fails *closed* with 500). Non-prod/preview deployments can run survey-creation unauthenticated; `GET` proxies to `POST`. **Fix:** require `CRON_SECRET` in all envs; drop the unauthenticated `GET` alias.
- **❌ Refuted — "Stored XSS in design-docs viewer"** (`Ai2htmlArtboard.tsx:139`): `o.text` is hardcoded developer constants in an admin-only viewer, not attacker-controllable. Not a vulnerability (optional DOMPurify hardening only). Also corrected: the realtime Redis broker path is **live**, not dead.

**Unverified critic leads worth a look** (concrete but not independently confirmed): `requirements.lock.txt` pins 191 deps with **zero `--hash=` integrity pins**; **TRR-APP has no secret scanning** (gitleaks runs only in TRR-Backend); a **hard-destruction migration with no archival** (`20260428113000_remove_flashback_gameplay_write_path.sql`); **no committed Supabase `database.types.ts`** (no schema-drift detection on the app side).

---

## P2 — Medium (plan for next sprint) — 53 findings

**Security cluster (review as a group — several arguably underrated):** hardcoded third-party AWS AppSync API key committed in `trr_backend/integrations/nbcumv.py`; two always-on admin gates accept a **raw static shared-secret header**, bypassing the signed internal-admin JWT (`api/auth.py`); SSRF guard applied to `s3_mirror` but **not** to `face_crops`/`image_variants` fetches; Supabase JWT issuer/project-ref checks **silently no-op** when project ref can't be derived; **dev-admin-bypass grants full admin with no production hard-stop** (`src/lib/server/auth.ts`); **Firestore global game-analytics docs writable with arbitrary content by any authenticated user**; **`anon` may call SECURITY DEFINER `surveys.submit_response`** with no dedup/rate-limit; `core.cast_tmdb` RLS enabled only in live DB, not migrations.

**Architecture / boundaries:** absent service layer (routers own data access); web app directly writes `core.*` schema also owned by the backend; fragile `/api/v1` auto-append; duplicate `is_queue_enabled` definitions; function-local imports signalling circular-dependency pressure.

**Backend quality:** 954 cargo-cult `# noqa: BLE001` (suppressing a rule ruff doesn't enable); `_normalize_text ×13` / `_env_truthy ×4` same-name-different-behavior duplication; 111 routes leak raw `str(exc)` to clients; 71 silently-swallowed exceptions.

**App best-practices / perf:** caching effectively disabled (183 `cache:'no-store'`, no React Query); near-zero React 19 / Next 16 server-data API adoption; `DebugPanel` rendered in production root layout; 76 `as unknown as` double-casts; missing `optimizePackageImports`; unbounded in-memory caches + per-call `deepcopy` in the socials monolith; serial blocking Modal round-trips in dispatch.

**Testing:** `AUTH_SERVICE_UNAVAILABLE` degraded-auth path untested; **autouse conftest fixture globally re-enables `service_role` admin promotion**, masking prod hardening across ~39 router test files; 46k-line implementation-coupled social test (384 SQL-substring asserts); near-zero DB-integration coverage by default; E2E runs with dev-admin-bypass (never exercises the real auth gate).

**CI/DevOps & docs:** no lint/type checking in backend CI; app CI runs only `typecheck:fandom` (not full); **zero observability (no Sentry/Datadog/OTel)**; inconsistent action pinning (only `secret-scan.yml` uses SHAs); `repo_map.yml` executes untrusted PR code with a write-scoped token; stale `CONCERNS.md`/`INTEGRATIONS.md`/`TESTING.md` referencing the retired monolith/screenalytics.

## P3 — Low (backlog) — 37 findings

Themes: vue-wordle ships an `npm` lockfile inside the pnpm workspace; server-named modules leaking into client bundles; per-route hardcoded API version with no migration strategy; `time.sleep` in an async twitter scraper; mixed legacy `Depends()` vs `Annotated` DI; Firebase Admin initializes silently without credentials; raw `error.message` in some 500s; coverage configured without `all:true` (overstates real coverage); 8 stale "legacy" skipped backend tests referencing removed schema; `env-contract.md` stored `0600` despite being non-secret; dynamic-column UPDATE builders interpolating dict keys (currently safe, fragile). See phase files for the full list with `file:line`.

---

## Findings by Category (original 16-finder pass)

| Category | Findings | Critical | High |
|---|---:|---:|---:|
| Best Practices (backend + app) | 20 | 0 | 4 |
| Security (backend + db + app) | 18 | 1 | 3 |
| Testing (backend + app) | 18 | 0 | 6 |
| Architecture (backend + app) | 15 | 0 | 2 |
| CI/CD & DevOps | 13 | 1 | 2 |
| Code Quality (backend + app) | 13 | 0 | 4 |
| Performance (backend + app) | 13 | 0 | 3 |
| Documentation | 8 | 0 | 2 |

---

## Recommended Action Plan

**Now (hours, highest ROI):**
1. **Revoke `anon` write/`TRUNCATE` grants** (P0-1) + corrective migration. *(small)*
2. **Enable branch protection on TRR-APP `main`** requiring `web-tests` + full typecheck (P0-2). *(small)*
3. **Move the `keys/` service-account keys out of the repo tree** into a secret store; rotate them; add a preflight that fails if `keys/` is non-empty. *(small)*
4. **Close the cron fail-open** on both `episode-progression` and `create-survey-runs` (require `CRON_SECRET` in all envs, drop `GET`). *(small)*
5. **Add `requires_proxy_auth` to the Modal `asgi_app` and gate `/metrics`** (completeness Medium). *(small)*

**This sprint (process gates — addresses the dominant theme):**
6. **Expand backend CI** to the full pytest suite (or risk-tiered subsets) and **add `ruff` + `pyright` gates**; add a **root workspace-tooling CI** running the contract/guardrail tests. *(medium)*
7. **Add secret scanning to TRR-APP**; pin all GitHub Actions to commit SHAs; sandbox `repo_map.yml`'s untrusted-PR execution. *(small–medium)*
8. **Add the missing test coverage on auth-critical code**: JWT (`alg:none`, issuer/project-ref derivation), admin allowlist, `firestore.rules` behavioral harness, the degraded-auth path; fix the conftest fixture that masks prod auth. *(medium)*
9. **Stop leaking `TRR_API_URL`/`str(exc)`** in client error bodies (backend 111 sites + app 10 routes) behind a shared error-sanitizer. *(medium)*

**Next quarter (structural — high effort, plan deliberately):**
10. **Decompose the monoliths by capability**, starting with `admin_person_images.py` god functions and the 61k social impl (real stage modules, not re-export facades); split the 16.9k admin page into server loaders + focused client sections; shard the generated inventory and keep it out of the client bundle. *(large)*
11. **Introduce a backend service layer**, add App Router error/loading boundaries, adopt React 19/Next 16 server-data APIs, and add baseline observability (Sentry/OTel). *(large)*
12. **Reconcile live-DB grants/RLS with migrations** so fresh environments are not silently less secure, and add destructive-migration archival review. *(medium)*

**Housekeeping:** regenerate or delete the stale `.planning/codebase/` maps (they describe a retired repo and will mislead future agents).

## Review Metadata

- **Phases:** Quality & Architecture · Security & Performance · Testing & Documentation · Best Practices & CI/CD · Verification · Completeness.
- **Agents:** 16 finders + adversarial verifiers + completeness critic + 3-lead verification + 1 gap-fill = ~80 agents across two workflow runs (~4.1M subagent tokens).
- **Output files:** `00-scope.md`, `01-quality-architecture.md`, `02-security-performance.md`, `03-testing-documentation.md`, `04-best-practices.md`, `05-final-report.md`, plus `_raw-findings.json` (all 124 findings + verdicts) and `_be-bestprac.json`.
- **Caveats:** Medium/Low findings and the `be-bestprac` dimension are single-pass (not independently verified). The 4 unverified completeness leads are concrete but unconfirmed. Giant generated files were sampled, not read whole.
