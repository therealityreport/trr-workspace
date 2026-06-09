# Phase 3: Testing & Documentation Review

**Findings in this phase:** 0 Critical, 8 High, 11 Medium, 7 Low.

## Testing — Backend  (`be-testing`)

**Summary.** TRR-Backend has a large pytest suite (4,759 test functions across 378 files) with genuinely strong coverage of JWT verification, DB-lane startup validation, and most auth dependencies, but it is severely unbalanced toward mock-heavy unit tests (263 files use monkeypatch vs 45 use TestClient) and almost entirely lacks migration/integration coverage (1 string-grep migration test against 2 of 280 SQL files; only 2 DB-integration tests, both skipped by default). The flagship socials tests are implementation-coupled and brittle: tests/repositories/test_social_season_analytics.py is 46k lines with 874 tests, 384 raw SQL-substring assertions, 1,403 distinct private-symbol calls, and only 5 fixtures, while tests/socials/test_instagram_comments_scrapling_retry.py is 8,392 lines / 174 tests / 0 fixtures / 485 inline monkeypatch.setattr calls. Specific high-value auth branches are untested (require_facebank_seed_admin, require_allowlist_admin, the AUTH_SERVICE_UNAVAILABLE 500 degradation, the JWT secret/project-ref derivation chain, and alg:none rejection), and a router-level autouse fixture globally re-enables service_role admin promotion, weakening what the router tests actually prove.

<details><summary>Coverage / blind spots</summary>

READ FULLY: pytest.ini; api/auth.py (326 lines); trr_backend/security/jwt.py; trr_backend/security/internal_admin.py; trr_backend/job_plane.py; tests/api/test_auth.py (355 lines); tests/security/test_jwt.py; tests/api/test_startup_validation.py (209 lines); tests/api/routers/conftest.py; tests/migrations/test_show_source_metadata_migrations.py; docs/workspace/test-skip-inventory.md. SAMPLED (head/tail + grep, not whole): tests/repositories/test_social_season_analytics.py (46k); tests/socials/test_instagram_comments_scrapling_retry.py (8.4k); tests/test_modal_dispatch.py + tests/test_modal_jobs.py (structure + targeted reads); trr_backend/modal_dispatch.py; trr_backend/repositories/reddit_refresh.py (dispatch region ~4845-4900); api/routers/socials/__init__.py (dispatch region ~2900-2960); trr_backend/vision/people_count_service.py (signatures). GREP-VERIFIED across full tests/ tree: skip/xfail inventory (13 markers), mock density, SQL-assertion counts, fixture counts, TestClient vs monkeypatch ratios, and presence/absence of coverage for specific auth functions and secret-derivation helpers. DELIBERATELY SKIPPED (blind spots): did not execute pytest (no runtime pass/fail or actual coverage % measured — all coverage claims are by static grep of test bodies, so a symbol exercised only indirectly through a higher-level call may be undercounted); did not deep-read the ~37 individual router test files beyond structure/grep; did not audit tests/scripts (71 files) or tests/integrations/imdb depth; did not assess vue-wordle or any TRR-APP tests (out of area). The new workspace-level scripts/test_*.py files (env hygiene, modal billing guardrail, instagram auth freshness) were identified and confirmed to live OUTSIDE the backend testpaths=tests lane, but I did not fully audit their internal assertions.

</details>

#### 1. [High] JWT secret / project-ref derivation chain (_project_ref_from_db_url, _candidate_supabase_project_ref) is untested despite being security-critical issuer-enforcement logic
**Status:** ✅ verified (high confidence) · _Test coverage gap_  
**Location:** `TRR-Backend/trr_backend/security/jwt.py : 34-77`  

verify_jwt_token enforces issuer and project-ref by deriving the expected project ref from a multi-source fallback chain: SUPABASE_PROJECT_REF -> TRR_SUPABASE_PROJECT_REF -> TRR_CORE_SUPABASE_PROJECT_REF -> parse TRR_CORE_SUPABASE_URL/SUPABASE_URL host -> parse postgres.<ref> username or db.<ref>.supabase.co host from TRR_DB_DIRECT_URL/SESSION/URL/FALLBACK. The helpers _project_ref_from_supabase_url, _project_ref_from_db_url, _candidate_supabase_project_ref, expected_supabase_issuer, and expected_supabase_project_ref have NO direct unit tests. test_jwt.py only exercises the path where SUPABASE_PROJECT_REF is set explicitly. A regression in the DB-URL parsing (e.g. wrong prefix stripping) would silently disable cross-project issuer/ref enforcement — exactly the check that stops a JWT from another Supabase project being accepted.

**Fix:** Add tests/security parametrized tests for each derivation source: (1) ref derived from postgres.<ref> username, (2) from db.<ref>.supabase.co host, (3) from SUPABASE_URL host, (4) precedence ordering when multiple sources disagree (explicit wins), (5) None when nothing derivable -> enforcement disabled. Then add an end-to-end verify_jwt_token test that derives ref ONLY from TRR_DB_DIRECT_URL and rejects a token with a mismatched ref.

**Evidence:**
```
`grep -rln "_project_ref_from_db_url|_candidate_supabase_project_ref|_project_ref_from_supabase_url|expected_supabase_issuer|expected_supabase_project_ref" tests/` => no matches (exit 1). test_jwt.py always sets `monkeypatch.setenv("SUPABASE_PROJECT_REF", "project123")`.
```


---

#### 2. [High] verify_jwt_token has no test that an unsigned / alg:none / algorithm-confusion token is rejected
**Status:** ✅ verified (high confidence) · **verifier-adjusted severity: Low** · _Security test gap_  
**Location:** `TRR-Backend/trr_backend/security/jwt.py : 146-176`  

verify_jwt_token pins algorithms=["HS256"], which is the correct defense, but there is no regression test asserting that a token crafted with alg:none (or alg swapped to a different family) is rejected with InvalidTokenError. This is the single most common JWT bypass class. Without a test, a future refactor that widens the algorithms list or that constructs a decode call without the algorithm allowlist would not be caught. test_jwt.py covers bad signature, wrong issuer, and wrong project ref, but not the alg:none / unsigned case.

**Fix:** Add test_verify_jwt_token_rejects_unsigned_token: build a token with `jwt.encode(payload, key=None, algorithm='none')` (or hand-craft the header) and assert verify_jwt_token raises InvalidTokenError. Optionally add an algorithm-confusion case. Same hardening test should be mirrored for verify_internal_admin_token in internal_admin.py.

**Evidence:**
```
`grep -rln "alg.*none|algorithm.*none|unsigned|verify_signature.*False" tests/` => no matches (exit 1). jwt.py line ~158: `jwt.decode(token, secret, algorithms=["HS256"], options=options)`.
```


---

#### 3. [High] require_facebank_seed_admin (a live auth dependency on the face-bank seeding surface) has zero test coverage
**Status:** ✅ verified (high confidence) · _Security test gap_  
**Location:** `TRR-Backend/api/auth.py : 303-326`  

require_facebank_seed_admin is a real FastAPI auth dependency used by api/routers/admin_person_images.py (face-bank seeding, a sensitive identity-data write surface). It has its own logic: allowlist match, then a service_role + X-TRR-Internal-Admin-Secret header check, then delegation to require_internal_admin. None of these branches are tested. Compare with require_internal_admin and require_cast_screentime_admin, which are exercised in tests/api/test_auth.py. A regression that, say, accepted any service_role token without the secret header would not be caught.

**Fix:** Add tests/api/test_auth.py cases mirroring the require_cast_screentime_admin tests: (1) allowlisted user accepted, (2) service_role WITHOUT secret header -> 403, (3) service_role WITH matching secret header -> accepted, (4) plain user -> delegates to internal-admin path -> 403. require_allowlist_admin (lines 292-300) is also untested and should get an allowlist-hit and allowlist-miss test.

**Evidence:**
```
`grep -rln "facebank_seed_admin|FacebankSeedAdmin" tests/` => NONE; same grep over api/ trr_backend/ => api/auth.py and api/routers/admin_person_images.py (so it IS a live surface). `grep -rln "require_allowlist_admin|AllowlistAdminUser" tests/` => NONE.
```


---

#### 4. [Medium] The AUTH_SERVICE_UNAVAILABLE (500) degraded-auth path is implemented in 4 auth dependencies but never tested
**Status:** • unverified · _Test coverage gap_  
**Location:** `TRR-Backend/api/auth.py : 99-105`  

When verify_jwt_token raises RuntimeError (e.g. SUPABASE_JWT_SECRET unset), get_current_user raises HTTP 500 with header x-error-code=AUTH_SERVICE_UNAVAILABLE, and require_internal_admin / require_cast_screentime_admin / require_facebank_seed_admin each contain explicit except-HTTPException handlers that swallow that 500 and fall through to internal-admin/service-role checks (lines 205-210, 270-274, 307-311). This is subtle, security-relevant control flow: a misconfigured JWT secret must NOT silently allow an internal-admin secret-header caller to be treated as a full failure-open. None of it is tested.

**Fix:** Add a test that unsets SUPABASE_JWT_SECRET (forcing the RuntimeError) and asserts: (a) require_user/get_current_user surface returns 500 with x-error-code AUTH_SERVICE_UNAVAILABLE, and (b) require_internal_admin with a valid internal-admin JWT still succeeds while a non-admin request gets 401/403 rather than failing open.

**Evidence:**
```
`grep -rln "AUTH_SERVICE_UNAVAILABLE|Authentication service unavailable" tests/` => NONE. auth.py raises it in get_current_user and re-checks `exc.headers.get("x-error-code") == "AUTH_SERVICE_UNAVAILABLE"` in three downstream dependencies.
```


---

#### 5. [Medium] Router conftest autouse fixture globally re-enables service_role admin promotion, hiding production auth hardening from ~39 router test files
**Status:** • unverified · _Test quality / false confidence_  
**Location:** `TRR-Backend/tests/api/routers/conftest.py : 16-31`  

An autouse fixture _allow_service_role_admin_in_router_tests sets TRR_ADMIN_ALLOW_SERVICE_ROLE=1 and TRR_INTERNAL_ADMIN_ALLOW_SERVICE_ROLE=1 for every test under tests/api/routers/. Production auth (api/auth.py) deliberately rejects service_role for require_admin/require_internal_admin unless these flags are set. The fixture is honestly documented, but the consequence is that all 39 router test files authenticate by minting service_role JWTs through a bypass that is OFF in production. This means the router tests do not prove that the real production auth path (allowlist user or signed internal-admin JWT) actually reaches each admin route — a route accidentally left wired to the wrong dependency, or a real allowlist regression, would pass these tests.

**Fix:** Keep the convenience fixture but add a thin per-router 'auth wiring' assertion lane: for a representative sample of admin routes, run WITHOUT the service_role flags and assert the route still admits a signed internal-admin JWT and rejects an anonymous/plain-user request. This proves the production auth contract on the actual routes without rewriting every test's token minting.

**Evidence:**
```
conftest.py: `monkeypatch.setenv("TRR_ADMIN_ALLOW_SERVICE_ROLE", "1"); monkeypatch.setenv("TRR_INTERNAL_ADMIN_ALLOW_SERVICE_ROLE", "1")` under `@pytest.fixture(autouse=True)`; docstring states tests 'mint service_role JWTs ... as a shortcut for authenticating as admin'. 39 files in tests/api/routers/.
```


---

#### 6. [Medium] tests/repositories/test_social_season_analytics.py is implementation-coupled and brittle: 384 raw SQL-substring assertions and 1,403 distinct private-symbol calls across 46k lines
**Status:** • unverified · _Test quality / brittleness_  
**Location:** `TRR-Backend/tests/repositories/test_social_season_analytics.py : 2121-2193`  

This 46,023-line file (874 tests) asserts exact lowercased SQL fragments against rendered query strings 384 times (e.g. `assert "left join core.shows sh on sh.id = coalesce(p.show_id, s.show_id)" in sql`). These assertions test HOW the query is written, not WHAT it returns, so any harmless SQL refactor (alias rename, join reorder, formatting) breaks dozens of tests while a genuine logic regression that still emits the same substring passes. The file also reaches into 1,403 distinct private (underscore-prefixed) helpers, tightly binding the test to internal structure of the 61k-line social_season_analytics_impl.py. This is the dominant source of future test-maintenance cost.

**Fix:** Convert the highest-value SQL-shape tests into behavior tests that execute the query against an in-memory/seeded fixture dataset and assert returned rows/aggregates, reserving SQL-substring assertions only for security-sensitive clauses (e.g. that a tenant/owner filter is present). Triage the 384 `in sql` assertions: keep the few that guard correctness invariants, delete the formatting-coupled ones. This is a refactor, not new coverage; do it incrementally per query family.

**Evidence:**
```
`wc -l` => 46023; test count 874; `grep -cE 'assert .*(SELECT|FROM|WHERE|JOIN|sql)'` => 384; distinct `_[a-z_]+(` symbols => 1403. Sample lines 2121-2127 assert exact `from social.instagram_posts p`, `p.search_text`, `order by p.posted_at desc nulls last, p.id desc` substrings.
```


---

#### 7. [Medium] Massive fixture sprawl / copy-paste setup: flagship test files use ~6 inline mocks per test with near-zero shared fixtures
**Status:** • unverified · _Test quality / maintainability_  
**Location:** `TRR-Backend/tests/socials/test_instagram_comments_scrapling_retry.py : 1-50`  

The two largest social test files set up state almost entirely with inline per-test monkeypatching and ad-hoc fake objects rather than shared fixtures. test_social_season_analytics.py: 46k lines, 874 tests, 5,317 Mock/patch/monkeypatch references, but only 5 @pytest.fixture definitions and 450 inline _Fake/_make/_build helper definitions. test_instagram_comments_scrapling_retry.py: 8,392 lines, 174 tests, 485 monkeypatch.setattr calls, and ZERO fixtures. The result is enormous duplicated setup that is expensive to read, easy to drift, and makes it hard to change a dependency contract in one place. The heavy patching of internal collaborators also means many tests assert against a fully-mocked world (over-mocking), reducing their power to catch real integration regressions.

**Fix:** Extract shared setup into module/package-level fixtures and small fixture factories (e.g. a fake scrapling-fetcher fixture, a seeded analytics-dataset fixture) so per-test bodies declare only what differs. Prefer constructing the real object with a small number of seam-level fakes over patching dozens of internal symbols. Co-locate common fakes in a tests/socials/conftest.py.

**Evidence:**
```
analytics: `grep -c '@pytest.fixture'` => 5; `class _Fake|def _make|def _build|...` => 450; Mock|patch|monkeypatch => 5317. retry file: `wc -l` 8392, tests 174, `@pytest.fixture` => 0, `monkeypatch.setattr` => 485.
```


---

#### 8. [Medium] DB-integration coverage is near-zero by default: only 2 RUN_DB_TESTS-gated files, both skipped in normal runs
**Status:** • unverified · _Test pyramid imbalance_  
**Location:** `TRR-Backend/tests/repositories/test_credits_integration.py : 22`  

The suite is overwhelmingly mock-based unit tests: 263 of 378 test files import monkeypatch, while only 45 use TestClient and just 2 files are real DB-integration tests (test_credits_integration.py, test_social_account_catalog_backfill_integration.py), both gated behind `pytest.mark.skipif(RUN_DB_TESTS not set)`. Combined with the missing migration-application tests, this means the default CI run never exercises real SQL against a real schema for the repository layer — which is the layer most likely to break from a migration or a Supabase/PostgREST behavior change. The repository tests that DO run mostly assert on hand-built fake cursors/rows, so they validate Python glue but not the SQL contract.

**Fix:** Stand up an ephemeral Postgres in CI (service container) and promote a curated subset of the highest-risk repository reads/writes (social post upserts, dispatch-stage claims, comments coverage queries) into a default-on integration lane that applies migrations first. Keep RUN_DB_TESTS for the heavy/slow seeded suites but make the migration-apply + smoke-query lane non-optional.

**Evidence:**
```
`grep -rln RUN_DB_TESTS tests/` => exactly 2 files, both with module-level `pytestmark = pytest.mark.skipif(...)`. files using monkeypatch=263 vs TestClient=45 (of 378). docs/workspace/test-skip-inventory.md classifies both as 'Intentionally live-only'.
```


---

#### 9. [Low] Eight stale 'legacy' skipped tests in test_tmdb_tv_details_persistence.py reference a removed schema and should be deleted or rewritten, not left as permanent dead skips
**Status:** • unverified · _Test hygiene / stale skips_  
**Location:** `TRR-Backend/tests/integrations/tmdb/test_tmdb_tv_details_persistence.py : 24-58`  

All 8 tests in this file are decorated `@pytest.mark.skip(reason="Legacy test: external_ids JSONB removed in schema normalization")`. They reference a column shape (external_ids JSONB) that no longer exists, so they can never pass and provide zero coverage while masquerading as a test file. The new docs/workspace/test-skip-inventory.md already classifies every one of these as 'Obsolete/delete' (P1). Permanently-skipped tests rot and give a false impression that TMDb persistence is tested. Of the 13 total skip markers in the backend suite, these 8 are the clear-cut removable ones.

**Fix:** Either delete this file outright or rewrite the tests against the current normalized persistence path (core.shows.tmdb_meta and the typed imdb_id/tmdb_id columns) per the inventory's stated next action. Do not leave permanently-failing-by-design skips in the tree; if TMDb detail-fetch failure handling matters, write fresh tests for the current code.

**Evidence:**
```
`grep -rn pytest.mark.skip tests/` shows 6 decorator hits in this file plus parameterized cases; reason string repeated: 'Legacy test: external_ids JSONB removed in schema normalization'. docs/workspace/test-skip-inventory.md lists all 7 scopes here as Disposition=Obsolete/delete, Priority P1.
```


---

#### 10. [Low] Local/sync execution paths for long jobs (reddit refresh execute_refresh_run, people_count local backend) are reachable in production but their dispatch-branch selection is thinly tested vs the remote-503 branches
**Status:** • unverified · _Test coverage gap_  
**Location:** `TRR-Backend/trr_backend/repositories/reddit_refresh.py : 4878-4880`  

Per the known 'heavy work runs synchronously when async infra is absent' concern: job_plane.py defaults execution to 'local', and reddit_refresh.py runs `execute_refresh_run(run_id, ...)` inline when `execution_mode == 'local'` (line ~4879), while api/routers/socials/__init__.py raises 503 when modal is required but not ready. The modal-required failure branches (REDDIT_REMOTE_DISPATCH_UNAVAILABLE / REDDIT_REMOTE_RUNTIME_UNHEALTHY) appear covered, and modal_dispatch unit tests are solid, but I found no test that asserts the LOCAL inline-execution selection is taken (and bounded) when modal is disabled, nor a test of people_count_service's _admin_image_execution_backend() local-vs-modal selection. The risk is a config change silently routing heavy work in-process on the API without a test guarding the boundary.

**Fix:** Add a focused test that, with TRR_MODAL_ENABLED=0 / TRR_JOB_PLANE_MODE=local, asserts the reddit refresh entrypoint selects the local execute path (and that enforce-remote config instead yields the 503/RuntimeError). Add a unit test for trr_backend/vision/people_count_service._admin_image_execution_backend() covering local-dev->local and deployed->modal selection. These are small, high-signal tests on production-reachable branches.

**Evidence:**
```
job_plane.py line 20 default returns 'local'; reddit_refresh.py ~4878: `elif not reused and execution_mode == "local": execute_refresh_run(run_id, ...)`. people_count_service.py line ~305-307 returns 'local' if _is_local_or_dev_runtime() else 'modal'. `grep -nE 'modal_ready|sync|inline|fallback' tests/repositories/test_reddit_refresh.py` shows only request_payload mode='sync_*' strings, not dispatch-branch selection assertions.
```


---

<details><summary>Refuted / unconfirmed by verifier (1)</summary>

#### 1. [High] Migration behavior is effectively untested: 1 string-grep test covers 2 of 280 migration files; no test applies migrations, checks idempotency, or validates rollback
**Status:** ⚠️ uncertain (high confidence) · **verifier-adjusted severity: Medium** · _Test coverage gap_  
**Location:** `TRR-Backend/tests/migrations/test_show_source_metadata_migrations.py : 1-28`  

supabase/migrations/ contains 280 SQL files, but the entire migrations test directory is a single 28-line file with two tests that only do substring assertions (e.g. `assert column in sql`) against migrations 0047/0048/0049. There is no test that applies the migration chain to a throwaway Postgres, verifies migrations are idempotent / re-runnable, checks that DOWN/rollback paths work, or asserts the resulting schema matches what repositories query. The only DB-backed coverage that could catch a broken migration is gated behind RUN_DB_TESTS (see separate finding) and is skipped by default. A malformed or out-of-order migration would ship undetected by CI.

**Fix:** Add a migration-application integration test (lane-gated, e.g. RUN_DB_TESTS=1) that spins up an ephemeral Postgres/Supabase, applies all supabase/migrations/*.sql in order, and asserts success; add an idempotency check that re-applying is safe where intended. At minimum, add a fast structural test that parses every migration filename for monotonic ordering / no duplicate numeric prefixes so drift is caught without a DB. Place under tests/migrations/.

**Evidence:**
```
`ls supabase/migrations/*.sql | wc -l` => 280. Entire tests/migrations/ = test_show_source_metadata_migrations.py (28 lines); its assertions are `for column in (...): assert column in sql` reading `0047_add_show_source_metadata.sql`. No test in tests/ matches `apply_migration|run_migration|alembic|supabase db`.
```


**Verifier reasoning:** The finding is partially true but materially mischaracterizes the scope and overstates the isolation of the gap.

TRUE elements:
- `tests/migrations/` contains exactly one file (`test_show_source_metadata_migrations.py`, 28 lines, 2 tests) that covers migrations 0047/0048/0049 via substring assertions. This is confirmed by direct file read.
- 280 SQL files exist in `supabase/migrations/`. Confirmed by `ls ... | wc -l`.
- No test applies migrations to a real Postgres instance, checks idempotency, or validates rollback. No match for `apply_migration|run_migration|alembic|supabase db reset` in test code.
- `RUN_DB_TESTS` integration tests (repositories/) are skipped by default. Confirmed.

FALSE/MISLEADING elements:
- The finding says "2 of 280 migration files" are covered and implies the only migration test code is the 28-line file. This ignores `tests/db/`, which contains at least 4 additional test files that read and assert against specific migration SQL files from `supabase/migrations/`:
  - `test_instagram_queryable_schema.py` (480 lines) covers 3 migration files with table-body regex extraction and deep structural assertions.
  - `test_social_post_canonical_schema.py` covers 1 m

---

</details>

## Testing — App (web)  (`app-testing`)

**Summary.** TRR-APP/apps/web has a large, generally healthy unit/integration suite (445 vitest files via vitest.config.mts; setup at tests/setup.ts) with strong coverage of proxy error paths (timeout, problem-detail passthrough, retryable backoff) and surprisingly thorough auth host-enforcement and provider/shadow tests in server-auth-adapter.test.ts. The biggest gaps are behavioral: (1) firestore.rules has real authZ logic but NO rules-unit-testing harness — the firebase-rules.yml CI only compiles rules ("echo Rules loaded"), never asserting allow/deny; (2) the core admin allowlist authorization decision (reject an authenticated-but-non-allowlisted email/uid/displayName) is never tested — every requireAdmin success/forbidden case is host-driven; and (3) the admin-api-references generator test only proves self-consistency, not parity with the live backend. E2E is thin (8 specs, all admin-UI smoke) and runs with NEXT_PUBLIC_DEV_ADMIN_BYPASS=true so it never exercises the real auth gate.

<details><summary>Coverage / blind spots</summary>

READ IN FULL: vitest.config.mts, playwright.config.ts, package.json test scripts, firestore.rules, .github/workflows/firebase-rules.yml + web-tests.yml, tests/admin-api-references-generator.test.ts, tests/public-route-boundary.test.ts, tests/dev-admin-bypass.test.ts, src/lib/server/auth.ts (requireAdmin/requireAdminContext/toVerifiedAdminContext bodies, lines 623-769), src/lib/server/trr-api/admin-read-proxy.ts error-handling (lines 156-300). SAMPLED (grep + targeted sed): tests/server-auth-adapter.test.ts (all it() titles + host-block bodies lines 317-490), tests/admin-backend-proxy-route.test.ts (error-path bodies lines 187-282), tests/admin-fetch.test.ts, tests/admin-client-auth.test.ts, tests/session-login-route.test.ts, tests/internal-admin-auth.test.ts, tests/auth-cutover-readiness.test.ts, all 8 tests/e2e/*.spec.ts (test titles). QUANTIFIED: 329 route.ts handlers (312 under api/admin, 295 gate on requireAdmin) vs 138 *-route.test.ts files; 250 components vs 99 *.test.tsx. COUNTED flakiness signals (real setTimeout=7 files, Date.now/new Date=7, Math.random=1, fake/real timers usage=16). DELIBERATELY SKIPPED (blind spots): did not read the 23k-line generated inventory.ts, did not run the suite or measure actual line/branch coverage % (v8 coverage has no all:true so reported % only reflects imported files), did not deep-read each of the 445 test bodies, did not audit Firestore Storage rules, did not inspect every individual route test's auth-mock fidelity beyond the sampled representatives.

</details>

#### 1. [High] No behavioral test harness for firestore.rules — CI only compiles rules, never asserts allow/deny
**Status:** ✅ verified (high confidence) · _Security test gap_  
**Location:** `TRR-APP/.github/workflows/firebase-rules.yml : 29-38`  

firestore.rules (TRR-APP/firestore.rules) contains non-trivial authorization logic: isOwner(userId) gating on user_analytics/{userId} read+write, answer-key collections (realitease_answerkey, bravodle_answerkey) that must be allow write:false, analytics writes gated on isAuthenticated(), and problem_reports create restricted to the authenticated user with a strict keys().hasOnly([...]) shape and category validation. None of this is tested behaviorally. The firebase-rules.yml CI 'validate' job runs `firebase emulators:exec --only firestore -- bash -lc "echo Rules loaded"`, which only confirms the rules file PARSES — it asserts nothing about who can read/write. A grep for 'rules-unit-testing' / '@firebase/rules' across the whole web app returns zero hits, and no test under tests/ imports the firestore rules emulator. A regression that loosens isOwner or flips an answerkey write to true would pass CI silently.

**Fix:** Add a @firebase/rules-unit-testing harness (e.g. tests/firestore-rules/*.test.ts run against the Firestore emulator, or a separate `firebase emulators:exec -- vitest run tests/firestore-rules` step in firebase-rules.yml). Cover at minimum: (a) user A cannot read/write user_analytics/{userB}; (b) owner can read/write own user_analytics and subcollections; (c) answerkey collections reject all client writes and require auth to read; (d) problem_reports create is rejected when unauthenticated, when userId != auth.uid, when extra keys are present, and when category is invalid; (e) public read of realitease_talent / *_analytics works while talent writes are denied.

**Evidence:**
```
firebase-rules.yml: `firebase emulators:exec --only firestore -- bash -lc "echo Rules loaded"`  +  firestore.rules: `function isOwner(userId){return isAuthenticated() && request.auth.uid==userId} ... match /realitease_answerkey/{docId}{allow read: if isAuthenticated(); allow write: if false;}`  +  `grep -rl 'rules-unit-testing|@firebase/rules' .` => (no matches)
```


---

#### 2. [High] Core admin allowlist authorization decision is never directly tested
**Status:** ✅ verified (high confidence) · _Security test gap_  
**Location:** `TRR-APP/apps/web/src/lib/server/auth.ts : 730-761`  

requireAdmin() makes the central authZ decision via `isAllowed = emailAllowed || uidAllowed || displayNameAllowed` over three env-derived allowlists (ADMIN_EMAIL_ALLOWLIST/NEXT_PUBLIC_ADMIN_EMAILS, ADMIN_UID_ALLOWLIST/NEXT_PUBLIC_ADMIN_UIDS, ADMIN_DISPLAYNAME_ALLOWLIST/NEXT_PUBLIC_ADMIN_DISPLAY_NAMES) and throws 'forbidden' otherwise. server-auth-adapter.test.ts exercises requireAdmin heavily, but EVERY case authenticates an already-allowlisted user (email 'admin@example.com'); all 'rejects.toThrow(forbidden)' assertions in that file are driven by HOST enforcement (non-allowlisted host), not by the allowlist decision. There is no test that authenticates a valid Firebase user whose email/uid/displayName is NOT on any allowlist and asserts 403, nor one that confirms uid-only or displayName-only allow paths grant access. The ~295 admin route handlers that call requireAdmin all mock it out (e.g. requireAdminMock.mockResolvedValue(...)), so the authZ gate's correctness rests entirely on this one untested function.

**Fix:** Add focused tests in tests/server-auth-adapter.test.ts (or a new tests/require-admin-allowlist.test.ts): hold host enforcement constant/allowed, then assert (a) authenticated user with non-allowlisted email AND non-allowlisted uid AND non-allowlisted displayName => rejects 'forbidden'; (b) email-only match grants; (c) uid-only match grants; (d) displayName-only match grants; (e) case-insensitivity of email/displayName normalization. This locks down the actual authorization boundary independent of host gating.

**Evidence:**
```
auth.ts: `const isAllowed = emailAllowed || uidAllowed || displayNameAllowed; if (!isAllowed) { throw new Error("forbidden"); }`  +  server-auth-adapter.test.ts every requireAdmin case sets `process.env.ADMIN_EMAIL_ALLOWLIST="admin@example.com"` with `verifyIdTokenMock.mockResolvedValue({email:"admin@example.com"})`; forbidden cases use a non-allowlisted HOST (`http://example.test/...`) not a non-allowlisted user.
```


---

#### 3. [Medium] admin-api-references generator test proves self-consistency only, not parity with live backend (explicit drift gap)
**Status:** • unverified · _Contract test gap_  
**Location:** `TRR-APP/apps/web/tests/admin-api-references-generator.test.ts : 8-19`  

The generator test re-renders the inventory module and asserts `renderGeneratedAdminApiReferenceInventoryModule(...) === artifactSource`, plus that certain edges exist with verificationStatus 'unverified_manual' and basis 'static_scan:createAdminBackendProxyRoute'. This guarantees the checked-in artifact (src/lib/admin/api-references/generated/inventory.ts) matches the generator's static scan of the App's own routes — but it performs NO call against the live TRR-Backend OpenAPI/route surface. The artifact's own schema literally marks manual backend mappings as 'unverified_manual'. If the backend adds/renames/removes an /api/v1/admin/... endpoint, this test stays green and the admin API-reference UI silently drifts. No live-drift/contract test exists (grep for 'openapi'/'live backend'/'drift' across the generator/library/route-audit tests => none).

**Fix:** Either (a) add a CI job that fetches the backend OpenAPI spec (TRR-Backend FastAPI exposes /openapi.json) and diffs the set of /api/v1/admin/* operations against GENERATED_ADMIN_API_REFERENCE_INVENTORY.edges targeting backend:* , failing on unmatched edges; or (b) if a live backend is unavailable in CI, commit a periodically-refreshed backend openapi snapshot and diff against it. Document clearly in the test that the existing generator test is self-consistency only.

**Evidence:**
```
tests/admin-api-references-generator.test.ts: `expect(renderGeneratedAdminApiReferenceInventoryModule(projectRoot,{generatedAt,sourceCommitSha})).toBe(artifactSource);` and asserts edges with `verificationStatus === "unverified_manual"`; grep 'openapi|live backend|drift' over generator/library/route-audit tests => none.
```


---

#### 4. [Medium] E2E suite never exercises the real auth gate (runs with dev-admin-bypass) and covers only admin-UI smoke flows
**Status:** • unverified · _E2E coverage gap_  
**Location:** `TRR-APP/apps/web/playwright.config.ts : 33`  

The Playwright webServer launches Next with `NEXT_PUBLIC_DEV_ADMIN_BYPASS=true` and `ADMIN_APP_HOSTS=127.0.0.1,localhost,admin.localhost`, so all 8 e2e specs run as a bypassed admin. No e2e test verifies that an unauthenticated/non-admin browser session is redirected/blocked from /admin, that login flows produce a valid session, or that authZ is enforced end-to-end. The 8 specs (admin-breadcrumbs, admin-cast-tabs-smoke/live, admin-dashboard-utility-copy, admin-global-header-menu, admin-modal-keyboard, admin-show-tabs-deeplink, homepage-visual-smoke) are all admin-UI smoke/layout/keyboard checks. Critical user-facing flows are essentially absent from e2e: the public games (bravodle/realitease) play->finish flow, survey play/continue, and the register/login auth flows (these exist only as jsdom component tests register.flow.test.tsx / finish.flow.test.tsx, not browser e2e).

**Fix:** Add at least one e2e spec that runs WITHOUT dev bypass and asserts an unauthenticated visit to an /admin route is redirected to login (and that a non-allowlisted authenticated user is denied). Add e2e smoke for the highest-value public flows: a games play-through to finish, and the register/login happy path producing a __session cookie. Keep these in a separate Playwright project/env so the bypassed admin-smoke lane stays fast.

**Evidence:**
```
playwright.config.ts webServer command: `ADMIN_APP_ORIGIN=... ADMIN_APP_HOSTS=127.0.0.1,localhost,admin.localhost NEXT_PUBLIC_DEV_ADMIN_BYPASS=true NEXT_DIST_DIR=.next-e2e pnpm exec next dev --webpack`; all tests/e2e/*.spec.ts describe blocks are admin-* or homepage-visual-smoke.
```


---

#### 5. [Medium] public-route-boundary test is static-source only — does not verify runtime authZ on public routes
**Status:** • unverified · _Security test gap_  
**Location:** `TRR-APP/apps/web/tests/public-route-boundary.test.ts : 33-46`  

This test reads each public route source file and asserts it does NOT contain admin-only import strings / useAdminGuard / redirect('/admin/...'). It is a lint-style regex guard over source text, not a behavioral test: it never renders a route or issues a request to confirm that public routes are actually reachable without admin and that admin routes actually reject non-admins at runtime. A public route could import an admin-only server helper through an alias the regex doesn't match, or an admin route could fail to call requireAdmin, and this test would not catch it. It is useful as a tripwire but is mislabeled as a 'boundary' guarantee.

**Fix:** Complement it with runtime tests: for a representative sample of admin route handlers, import the handler and assert it returns 401/403 when requireAdmin throws 'unauthorized'/'forbidden' (verifying the route actually calls the gate rather than mocking it to success); and for public routes, assert a no-auth request returns 200. Pair this with buildAdminProxyErrorResponse (admin-read-proxy.ts) to confirm unauthorized->401 / forbidden->403 mapping is wired in real routes.

**Evidence:**
```
public-route-boundary.test.ts: `const source = fs.readFileSync(filePath,'utf8'); expect(source).not.toMatch(/@\/app\/admin\//); expect(source).not.toMatch(/useAdminGuard/);` (pure source-string assertions).
```


---

#### 6. [Low] GET read-proxy generic-failure branch passes raw error.message to a 500 response (no scrubbing) — and that branch is untested
**Status:** • unverified · _Error-path test gap_  
**Location:** `TRR-APP/apps/web/src/lib/server/trr-api/admin-read-proxy.ts : 255-258`  

fetchAdminBackendJson handles two error cases explicitly (timeout/abort, and 'fetch failed' => a sanitized 'Could not reach TRR-Backend. Confirm TRR-Backend is running and TRR_API_URL is correct.' with code BACKEND_UNREACHABLE — note this is a static hint, it does NOT interpolate the TRR_API_URL value, refuting the prior leak lead). But the final fallback throws `new AdminReadProxyError(error instanceof Error ? error.message : 'failed', 500, {code:'BACKEND_PROXY_FAILED'})`, surfacing the raw underlying error message to the client via buildAdminProxyErrorResponse. The admin proxy POST helper's equivalent paths ARE well tested (admin-backend-proxy-route.test.ts covers 504 timeout and 503 problem-detail passthrough), but I found no test asserting the read-proxy's network-failure -> 502 sanitized message, nor the generic 500 fallback's message handling. This is the one proxy error branch where unsanitized internal text can reach clients.

**Fix:** Add tests for fetchAdminBackendJson/buildAdminProxyErrorResponse: (a) simulate a non-abort 'fetch failed' rejection and assert 502 + code BACKEND_UNREACHABLE + the fixed message (and that it contains no live origin); (b) simulate a generic Error and assert the 500 BACKEND_PROXY_FAILED path, and consider scrubbing/replacing error.message with a static string for the 500 fallback so internal exception text isn't returned to clients.

**Evidence:**
```
admin-read-proxy.ts: `if (error instanceof Error && error.message.toLowerCase().includes('fetch failed')) { throw new AdminReadProxyError('Could not reach TRR-Backend. Confirm TRR-Backend is running and TRR_API_URL is correct.',502,...) } throw new AdminReadProxyError(error instanceof Error ? error.message : 'failed',500,{code:'BACKEND_PROXY_FAILED'})` — grep for an admin-read-proxy network-failure/502 test => not present.
```


---

#### 7. [Low] v8 coverage configured without all:true — reported coverage overstates real coverage of untested route handlers/components
**Status:** • unverified · _Coverage measurement_  
**Location:** `TRR-APP/apps/web/vitest.config.mts : 20-26`  

Coverage uses provider 'v8' with reporters and `exclude:['tests/**']`, but no `all: true` and no explicit `include`. v8 coverage without all:true only reports files that were imported by at least one test, so files never touched by any test are omitted from the denominator, inflating the headline percentage. With only 138 *-route.test.ts files for 329 route handlers (and 312 admin handlers), and 99 *.test.tsx for 250 components, a large fraction of route/component source is likely uninstrumented entirely. The web-tests.yml CI uploads the coverage artifact but does not enforce any threshold, so coverage cannot regression-gate.

**Fix:** Set `coverage.all: true` with an explicit `include: ['src/**/*.{ts,tsx}']` (and sensible excludes for generated/types) so untested files count as 0%, giving an honest baseline. Then add modest per-metric thresholds (e.g. start at current honest numbers) in vitest.config.mts and surface them in web-tests.yml so coverage can't silently drop. Prioritize raising route-handler and security-helper coverage first.

**Evidence:**
```
vitest.config.mts: `coverage:{provider:'v8',reporter:coverageReporters,reportsDirectory:'coverage',exclude:['tests/**']}` (no all:true / no include); counts: 329 route.ts vs 138 *-route.test.ts; 250 components vs 99 *.test.tsx; web-tests.yml uploads coverage artifact with no threshold gate.
```


---

## Documentation — Workspace + repos  (`docs-review`)

**Summary.** The seven generated .planning/codebase/ maps (STRUCTURE, STACK, ARCHITECTURE, INTEGRATIONS, CONCERNS, TESTING, CONVENTIONS, all dated 2026-04-09) are pervasively stale: they still describe the retired screenalytics/ repo as a live runtime layer, document the wrong cross-repo implementation order, present a 52,805-line monolith that is now a 9-line shim, and reference a backend internal-admin/service-token secret contract that AGENTS.md no longer carries. These maps are orphaned (no doc, script, Makefile, or CI workflow references or regenerates them) and have been superseded by newer, accurate maps (backend-map.md, app-map.md, workspace-map.md, the two screenalytics retirement docs) dated 2026-05-27/28. By contrast, the env-contract docs, the four new untracked workspace docs, and both READMEs are accurate and verify cleanly against live code.

<details><summary>Coverage / blind spots</summary>

READ IN FULL: all 7 uppercase .planning/codebase/ maps (STRUCTURE/STACK/ARCHITECTURE/INTEGRATIONS/CONCERNS/TESTING/CONVENTIONS); all 4 new untracked docs (instagram-scrapling-runtime-canary.md, scrapling-transport-migration-guide.md, modal-safe-backend-deploy-set.md, workspace-hygiene.md); env-contract.md header+lead tables; env-deprecations.md header+sample; env-contract-inventory.md header; workspace-hygiene/retirement docs. SAMPLED: backend-map.md, app-map.md, screenalytics-retirement-migration-plan.md, screenalytics-map-and-cleanup.md (heads + screenalytics greps). VERIFIED AGAINST LIVE TREE: screenalytics/ and apps/web root stub are absent; trr_backend/clients/screenalytics.py (53-line shim) and repositories/social_season_analytics.py (9-line shim) exist; social_season_analytics_impl.py = 61,116 lines; 37 routers, 329 app route.ts, 280 migrations; Node pinned to 24; scrapling_transport.py + cited builders, platform packages, and test files exist; modal-safe deploy-set file refs + make targets + scripts (modal-billing-guardrail.sh) exist; env-deprecations citations (postgres.ts:219, _db_url.py:53) match; live test-fast.sh/test.sh/dev-workspace.sh/AGENTS.md have ZERO screenalytics refs; SCREENALYTICS_SERVICE_TOKEN absent from live backend code and AGENTS.md. DELIBERATELY SKIPPED (blind spots): per-endpoint API documentation completeness for all 37 routers / 329 routes (no OpenAPI/doc artifact found to diff; only spot-checked); exhaustive row-by-row validation of env-contract.md's ~100+ variables against every code site; shared-env-manifest.json deep internal consistency; the large body of older docs/workspace runbooks (supabase-*, instagram-*-runbook, shows-*) outside the Documentation-accuracy focus; giant generated files were intentionally not read whole.

</details>

#### 1. [High] Generated .planning/codebase/ maps describe the retired screenalytics/ repo as a live runtime layer across all 7 files
**Status:** ✅ verified (high confidence) · **verifier-adjusted severity: Medium** · _Stale documentation_  
**Location:** `.planning/codebase/STRUCTURE.md, .planning/codebase/ARCHITECTURE.md, .planning/codebase/STACK.md, .planning/codebase/INTEGRATIONS.md, .planning/codebase/CONCERNS.md, .planning/codebase/TESTING.md, .planning/codebase/CONVENTIONS.md : STRUCTURE.md:9-11,45-73,116-119,156-159; ARCHITECTURE.md:11,37-49,68-73,113-116,140-148; STACK.md:8-9,41-46,57,131-135`  

screenalytics/ was retired 2026-05-28 and the directory does not exist (verified: `ls -d screenalytics` -> No such file or directory). All seven 2026-04-09 maps still treat it as a first-class runtime. STRUCTURE.md line 11 lists `screenalytics/` in the directory tree and devotes ~8 directory-purpose blocks plus entry points (`screenalytics/apps/api/main.py`, `screenalytics/apps/workspace-ui/streamlit_app.py`, `screenalytics/scripts/dev.sh`) to it. ARCHITECTURE.md defines a 'Screenalytics API and Pipeline Layer' and 'Screenalytics Operator UI Layer' (lines 37-49) and a 'Screenalytics Metadata Sync Flow' (68-73). STACK.md documents Celery+Redis, Streamlit, torch/insightface, and `screenalytics/web/` Next.js as live (41-46,57,86-90). Live test-fast.sh, test.sh, dev-workspace.sh, and AGENTS.md contain ZERO screenalytics references; the Makefile only carries a retirement note ('local screenalytics infra is retired; nothing to tear down', Makefile:260).

**Fix:** Regenerate or delete the seven uppercase maps. Since nothing references or regenerates them (see separate orphaned-artifact finding), the lowest-effort correct action is to remove them and rely on the newer backend-map.md/app-map.md/workspace-map.md, or regenerate them from the live tree with screenalytics excised.

**Evidence:**
```
STRUCTURE.md:11 `├── `screenalytics/`     # ML pipeline, Screenalytics API, operator UIs...`; `ls -d screenalytics` -> `No such file or directory`; `grep -c screenalytics scripts/dev-workspace.sh` -> 0
```


---

#### 2. [High] Generated maps document the wrong cross-repo implementation order (TRR-Backend -> screenalytics -> TRR-APP)
**Status:** ✅ verified (high confidence) · **verifier-adjusted severity: Medium** · _Contradictory documentation_  
**Location:** `.planning/codebase/CONVENTIONS.md, .planning/codebase/ARCHITECTURE.md : CONVENTIONS.md:115; ARCHITECTURE.md:177`  

CONVENTIONS.md line 115 instructs: 'Land cross-repo contract work in this order: TRR-Backend first, screenalytics second, TRR-APP last.' ARCHITECTURE.md line 177 repeats it. The authoritative AGENTS.md now defines only a two-repo order: 'Backend-first for schema, API, auth, and shared contract changes' and 'App follow-through happens in the same session after backend contract changes land' (AGENTS.md:9-11) — there is no screenalytics step. This is a directly contradictory process instruction that would mislead an agent or contributor following the maps.

**Fix:** Remove the 'screenalytics second' step from both maps to match AGENTS.md's backend-first / app-follow-through order, or regenerate.

**Evidence:**
```
CONVENTIONS.md:115 `Land cross-repo contract work in this order: TRR-Backend first, screenalytics second, TRR-APP last.`; AGENTS.md:9-11 `## Cross-Repo Implementation Order / - Backend-first ... / - App follow-through happens in the same session`
```


---

#### 3. [Medium] CONCERNS.md presents the social_season_analytics monolith (52,805 lines) that is now a 9-line compatibility shim
**Status:** • unverified · _Stale documentation_  
**Location:** `.planning/codebase/CONCERNS.md : 8-11, 90`  

CONCERNS.md's lead tech-debt item describes `TRR-Backend/trr_backend/repositories/social_season_analytics.py` as 'a Legacy social control-plane monolith ... 52,805 lines with roughly 1,030 top-level defs' and the Scaling Limits section (line 90) says it 'maintains many queue, heartbeat, stale-recovery, and batch-size constants in code.' Live, that path is a 9-line shim that re-exports `trr_backend.socials.social_season_analytics_impl` via `sys.modules` aliasing; the real implementation moved to socials/social_season_analytics_impl.py (61,116 lines). Anyone acting on this doc would edit/refactor the wrong file or mis-estimate the debt location.

**Fix:** Update the file path to socials/social_season_analytics_impl.py and refresh the line count (61,116), or regenerate CONCERNS.md. Note the repositories/ path is now only a thin alias.

**Evidence:**
```
CONCERNS.md:8 `...social_season_analytics.py identifies itself as a "Legacy social control-plane monolith..." and is 52,805 lines...`; `wc -l TRR-Backend/trr_backend/repositories/social_season_analytics.py` -> 9 (`_sys.modules[__name__] = _impl`); `wc -l .../socials/social_season_analytics_impl.py` -> 61116
```


---

#### 4. [Medium] INTEGRATIONS.md documents a screenalytics service-token secret contract that AGENTS.md and live backend code no longer carry
**Status:** • unverified · _Stale documentation_  
**Location:** `.planning/codebase/INTEGRATIONS.md : 107-115, 167, 178-187`  

INTEGRATIONS.md states (lines 112-115) that `SCREENALYTICS_SERVICE_TOKEN` 'remains as transitional fallback for Screenalytics service auth' with 'Workspace policy: AGENTS.md' and 'Backend verification: TRR-Backend/api/screenalytics_auth.py', and lists `SCREENALYTICS_API_URL` (167) and a full 'Screenalytics core' required-env block (178-187: REDIS_URL, CELERY_BROKER_URL, STORAGE_BACKEND, etc.). Live: `grep SCREENALYTICS_SERVICE_TOKEN` returns nothing in TRR-Backend/api or trr_backend, and AGENTS.md contains no shared-secret / SCREENALYTICS_SERVICE_TOKEN section at all. The doc cites AGENTS.md as the source of truth for a secret AGENTS.md no longer documents.

**Fix:** Drop the SCREENALYTICS_SERVICE_TOKEN, SCREENALYTICS_API_URL, and Screenalytics-core env blocks from INTEGRATIONS.md, and re-derive the internal-admin secret section from the current AGENTS.md.

**Evidence:**
```
INTEGRATIONS.md:112 `- SCREENALYTICS_SERVICE_TOKEN remains as transitional fallback...`; `grep -rl SCREENALYTICS_SERVICE_TOKEN TRR-Backend/api TRR-Backend/trr_backend` -> (no output); `grep -niE 'SCREENALYTICS_SERVICE_TOKEN|shared secret' AGENTS.md` -> (no output)
```


---

#### 5. [Medium] TESTING.md run/verification commands reference a non-existent screenalytics test lane
**Status:** • unverified · _Stale documentation_  
**Location:** `.planning/codebase/TESTING.md : 9,27-29,41,131-135,159-171,206-224`  

TESTING.md's Run Commands block tells contributors to run `cd screenalytics && python -m py_compile <touched_files>`, `cd screenalytics && pytest tests/unit/ -v`, and `RUN_ML_TESTS=1 pytest tests/ml/ -v` (lines 27-29), and the 'Verification Commands Used In Practice' section (206-224) claims `scripts/test-fast.sh` runs screenalytics py_compile + `tests/api/test_trr_health.py` and `scripts/test.sh` runs screenalytics py_compile. The live scripts contain no screenalytics references (`grep -i screenalytics scripts/test-fast.sh scripts/test.sh` -> empty), and the screenalytics/ tree does not exist, so every screenalytics command in this doc fails. It also documents screenalytics-only bugs/gaps (MCP placeholder server, audio queue fallbacks) as current.

**Fix:** Remove the screenalytics test lanes and the screenalytics rows from the verification-commands and coverage-gaps sections; regenerate from the current test-fast.sh/test.sh.

**Evidence:**
```
TESTING.md:27 `cd screenalytics && python -m py_compile <touched_files>`; TESTING.md:211 `screenalytics: py_compile on two entrypoints and optional tests/api/test_trr_health.py`; `grep -i screenalytics scripts/test-fast.sh scripts/test.sh` -> (no output)
```


---

#### 6. [Low] Stale .planning/codebase/ maps are orphaned generated artifacts with no consumer or regenerator
**Status:** • unverified · _Documentation maintenance_  
**Location:** `.planning/codebase/STRUCTURE.md (and the other 6 uppercase maps) : STRUCTURE.md:234-237`  

The seven 2026-04-09 maps self-describe as 'generated codebase maps used by GSD planning and execution' (STRUCTURE.md:234-237) but nothing in the workspace references or regenerates them: grep for `.planning/codebase/(STRUCTURE|STACK|ARCHITECTURE|...)` across AGENTS.md, docs/, scripts/, Makefile, and .codex/ returns nothing, and neither TRR-Backend nor TRR-APP .github/workflows mention `.planning`. They have effectively been replaced by the newer, accurate maps (backend-map.md 2026-05-27, app-map.md, workspace-map.md, screenalytics-retirement-migration-plan.md 2026-05-28). This caps the blast radius of the staleness (no automation consumes them) but they remain a trap for any human/agent who opens them, and the retirement docs do not flag them for cleanup.

**Fix:** Either delete the seven uppercase maps as superseded, or add a one-line banner at the top of each pointing to the dated 2026-05 maps and noting screenalytics retirement. Add a line to screenalytics-retirement-migration-plan.md naming these maps as remaining stale artifacts to migrate/remove.

**Evidence:**
```
`grep -rniE '\.planning/codebase/(STRUCTURE|STACK|ARCHITECTURE|INTEGRATIONS|CONCERNS|TESTING|CONVENTIONS)' AGENTS.md docs scripts Makefile .codex` -> (no output); retirement plan only references screenalytics' own old `ARCHITECTURE.md`, not the workspace maps
```


---

#### 7. [Low] STACK.md / INTEGRATIONS.md document screenalytics-only CI workflows that no longer apply
**Status:** • unverified · _Stale documentation_  
**Location:** `.planning/codebase/STACK.md, .planning/codebase/INTEGRATIONS.md : STACK.md:158; INTEGRATIONS.md:145-146`  

STACK.md line 158 lists `screenalytics/.github/workflows/ci.yml, codex-manual.yml, codex-review.yml, on-push-doc-sync.yml, repo_map.yml` as live CI, and INTEGRATIONS.md (145-146) lists `screenalytics/.github/workflows/` as a detected CI surface. With screenalytics/ retired, these workflow paths no longer exist in the workspace. The accurate CI surface is the assignment's verified set: TRR-Backend/.github/workflows (ci.yml, secret-scan.yml, mirror-media-assets.yml, repo_map.yml, codex-review.yml) and TRR-APP/.github/workflows (web-tests.yml, firebase-rules.yml, codex-review.yml, repo_map.yml).

**Fix:** Remove the screenalytics workflow lines from STACK.md and INTEGRATIONS.md when regenerating.

**Evidence:**
```
STACK.md:158 `screenalytics/.github/workflows/ci.yml, codex-manual.yml, codex-review.yml, on-push-doc-sync.yml, and repo_map.yml cover Screenalytics automation.`
```


---

#### 8. [Low] env-contract.md is stored with 0600 permissions despite being generated, non-secret content
**Status:** • unverified · _Documentation hygiene_  
**Location:** `docs/workspace/env-contract.md : 1-3`  

docs/workspace/env-contract.md is mode 0600 (`-rw-------`), unlike its sibling generated docs (env-deprecations.md, env-contract-inventory.md, shared-env-manifest.json are 0644). The file's own header states it is generated by `scripts/workspace-env-contract.sh` and it deliberately documents only env names/defaults, never secret values ('Do not use secret-bearing values as application names'). The restrictive mode is harmless to readers on this machine but is inconsistent with the other generated contract docs and can cause confusing access behavior in CI or for other tools/users; a regeneration that does not reset perms will perpetuate the drift.

**Fix:** Normalize to 0644 to match the other generated docs/workspace contract files, and have scripts/workspace-env-contract.sh write the file with consistent permissions on regeneration.

**Evidence:**
```
`ls -l docs/workspace/env-contract.md` -> `-rw-------  ... env-contract.md`; sibling: `-rw-r--r--@ ... env-deprecations.md`; header: 'This file is generated by `scripts/workspace-env-contract.sh`.'
```


---
