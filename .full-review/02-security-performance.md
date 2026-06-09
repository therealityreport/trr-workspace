# Phase 2: Security & Performance Review

**Findings in this phase:** 1 Critical, 6 High, 16 Medium, 8 Low.

## Security — Backend  (`be-security`)

**Summary.** TRR-Backend's core auth is solid: Supabase JWT verification uses an explicit HS256 algorithm allowlist with required signature+exp (api/security/jwt.py), internal-admin JWTs enforce iss/aud/sub/exp/scope (security/internal_admin.py), all 37 routers gate every endpoint with an auth dependency, dev-only bypass flags default off, CORS avoids the wildcard+credentials trap, and the SQL layer is uniformly parameterized (psycopg2 %s) with dynamic identifiers sourced from hardcoded platform-keyed maps rather than user input. The real exposures are secret-at-rest and consistency gaps: three live GCP/Firebase service-account private-key JSONs sit unencrypted on disk in keys/ (gitignored, never committed, but the Firebase Admin key grants full project control), a third-party AWS AppSync API key is hardcoded in trr_backend/integrations/nbcumv.py, the SSRF guard that protects s3_mirror is not applied to face_crops/image_variants fetches, the JWT issuer/ref checks silently no-op when project ref can't be derived, and two always-on admin paths accept a raw static shared-secret header. The 'startup auto-derives local shared secrets' lead is CONFIRMED (deterministic sha256-based TRR_INTERNAL_ADMIN_SHARED_SECRET for local dev); the getty_local_server path-traversal lead is REFUTED (no file-serving, shared-secret-gated /scrape only).

<details><summary>Coverage / blind spots</summary>

READ IN FULL: api/auth.py, api/screenalytics_auth.py, api/deps.py, trr_backend/security/jwt.py, trr_backend/security/internal_admin.py, api/main.py CORS + _validate_startup_config + get_cors_origins, api/routers/ws.py auth/DM-membership, scripts/dev-workspace.sh secret-derivation function. SAMPLED: api/main.py router registration (all 37 include_router lines), all admin_*.py routers via route-count-vs-auth-dependency-count diff (verified the '_: InternalAdminUser = None' default is benign under FastAPI Annotated/Depends), social_season_analytics_impl.py dynamic-SQL sites (lines ~16470-16500, 17820-17860, 40921), repositories/{cast_screentime,screenalytics_runs,face_references,covered_shows,admin_reddit_reads}.py SQL builders, trr_backend/db/pg.py execute layer, trr_backend/media/{s3_mirror,face_crops,image_variants,user_uploads}.py fetch paths + _public_media_url_error SSRF guard, subprocess sites in socials scrapers (tiktok/youtube), keys/ contents, git history for committed private keys (none found), .gitleaks.toml. SKIPPED / BLIND SPOTS: did not exhaustively trace every one of the 327 endpoints' object-level authz (BOLA/IDOR) beyond DM membership and the cast-screentime ownership asserts — per-row ownership on admin mutate endpoints relies on admin-role trust + DB RLS, which I did not validate against supabase/migrations RLS policies; did not deep-read the 61k-line socials monolith in full (sampled grep hits only); did not audit Modal dispatch token handling (trr_backend/modal_dispatch.py, job_plane.py) or the realtime broker/Redis auth; did not verify runtime env values, only committed defaults.

</details>

#### 1. [High] Live GCP and Firebase Admin service-account private keys stored unencrypted in keys/
**Status:** ✅ verified (high confidence) · _OWASP A02:2021 Cryptographic Failures / Secrets Management_  
**Location:** `TRR-Backend/keys/trr-web-25d2e-38499515994a.json (also trr-backend-b56c41e733c6.json, trr-backend-df2c438612e1.json) : n/a (file contents)`  

keys/ contains three service_account JSON files each containing a private_key. trr-web-25d2e-38499515994a.json is a Firebase Admin SDK key (client_email firebase-adminsdk-fbsvc@trr-web-25d2e.iam.gserviceaccount.com) which grants full administrative control over the trr-web-25d2e Firebase project (Auth user impersonation, Firestore full read/write bypassing security rules). The other two are GCP service-account keys for project trr-backend. They are gitignored (.gitignore line 74 'keys/') and git history contains no BEGIN PRIVATE KEY for these (verified via git log -S and grep -c), so this is NOT a repo leak, but the active private keys sit unencrypted on the developer/host filesystem. Notably, no Python code references keys/ at all (grep for 'keys/' and GOOGLE_APPLICATION_CREDENTIALS in trr_backend/api returned nothing) — they appear to be orphaned/legacy key material that nonetheless remains valid and exfiltratable from disk.

**Fix:** Rotate all three service-account keys (especially the Firebase Admin key) in GCP/Firebase console. Delete the orphaned JSONs from keys/ if unused; if used, load credentials from a secret manager (Render/Modal env or GCP Secret Manager) and pass via GOOGLE_APPLICATION_CREDENTIALS at runtime rather than committing key files to the working tree. Confirm no deploy artifact bundles keys/.

**Evidence:**
```
git ls-files keys/ -> empty (untracked); git check-ignore -> IGNORED; python json load -> 'type: service_account | has_private_key: True | client_email: firebase-adminsdk-fbsvc@trr-web-25d2e.iam.gserviceaccount.com'. grep -rn 'keys/|GOOGLE_APPLICATION_CREDENTIALS' trr_backend api -> no matches.
```


---

#### 2. [Medium] Two always-on admin gates accept a raw static shared-secret header, bypassing the signed internal-admin JWT
**Status:** • unverified · _OWASP A07:2021 Identification and Authentication Failures_  
**Location:** `TRR-Backend/api/auth.py : 281-284 (require_cast_screentime_admin) and 317-321 (require_facebank_seed_admin)`  

require_cast_screentime_admin and require_facebank_seed_admin grant admin access to any caller presenting a service_role JWT plus a matching X-TRR-Internal-Admin-Secret header (_internal_admin_secret_matches). Unlike the dev-only raw fallback in require_internal_admin (gated behind TRR_INTERNAL_ADMIN_ALLOW_RAW_SECRET_FALLBACK and off by default), this path is ALWAYS ON. It contradicts the function's own docstring ('call backend routes with a signed internal admin JWT') and accepts a long-lived static secret with no expiry, audience, issuer, or replay protection — a strictly weaker credential than the verify_internal_admin_token path used elsewhere. Exploitation requires also holding a valid service_role JWT (itself a top-tier Supabase secret with full DB access), so this is not a clean privilege escalation, but it widens the accepted-credential set for these admin surfaces (cast-screentime admin and facebank seeding) and means leakage of the static shared secret alone is more impactful than the rest of the JWT-based design implies.

**Fix:** Remove the unconditional _internal_admin_secret_matches acceptance from both functions and require the signed internal-admin JWT (verify_internal_admin_token) for service-to-service callers, matching require_internal_admin. If a raw-secret path is genuinely needed, gate it behind the same dev-only flag and log it.

**Evidence:**
```
if role == 'service_role':\n    if _internal_admin_secret_matches(request):\n        return current_user  (auth.py:281-283). _internal_admin_secret_matches compares request header X-TRR-Internal-Admin-Secret to env TRR_INTERNAL_ADMIN_SHARED_SECRET via hmac.compare_digest (auth.py:61-64).
```


---

#### 3. [Medium] Hardcoded third-party AWS AppSync API key committed in source
**Status:** • unverified · _OWASP A05:2021 Security Misconfiguration / Hardcoded Secret_  
**Location:** `TRR-Backend/trr_backend/integrations/nbcumv.py : 21`  

DEFAULT_APPSYNC_API_KEY = "da2-rmy4cbtcevfwrdadqabta7ezl4" is a committed AWS AppSync API key used as the default for the NBCUMV GraphQL endpoint (APPSYNC_API_KEY = os.environ.get('NBCUMV_APPSYNC_API_KEY', DEFAULT_APPSYNC_API_KEY)). It is git-tracked (git ls-files confirms) and additionally allowlisted in .gitleaks.toml:78, indicating the team has consciously accepted it. Impact is bounded because it is a third-party press-photo API credential (NBCUniversal media GraphQL) rather than a TRR-owned secret, but committing a working API key to source means anyone with repo read access can use it (quota abuse / rate-limit exhaustion against TRR's account with NBCUMV) and it cannot be rotated without a code change.

**Fix:** Move the key out of source: require NBCUMV_APPSYNC_API_KEY at runtime and drop the hardcoded default (raise if unset, or fall back to disabling the integration). Rotate the key if NBC supports it. Keep the gitleaks allowlist only if you accept the residual exposure.

**Evidence:**
```
trr_backend/integrations/nbcumv.py:21: DEFAULT_APPSYNC_API_KEY = "da2-rmy4cbtcevfwrdadqabta7ezl4"; git grep found same literal in .gitleaks.toml:78 (allowlisted) and docs/ai/local-status/getty-nbcumv-person-gallery-bucket-normalization.md:58.
```


---

#### 4. [Medium] SSRF guard applied to s3_mirror downloads is not applied to face_crops and image_variants URL fetches
**Status:** • unverified · _OWASP A10:2021 Server-Side Request Forgery_  
**Location:** `TRR-Backend/trr_backend/media/face_crops.py (line 104) and trr_backend/media/image_variants.py (lines 108, 125)`  

trr_backend/media/s3_mirror.py:download_image validates URLs with _public_media_url_error (s3_mirror.py:147) before fetching — it rejects non-http(s) schemes, localhost/.local/.localhost, and any hostname whose resolved addresses are non-global (checks ALL resolved IPs, mitigating DNS-rebinding at fetch time). This is a strong guard. However face_crops._download_image_bytes (requests.get(image_url, ...) at line 104) and image_variants._load_image_bytes/_load_cast_photo_image_bytes (requests.get(hosted_url, ...) at lines 108 and 125) perform server-side fetches with NO equivalent guard. In these two modules the URLs come from stored asset/photo rows (admin-curated, already-mirrored assets), so attacker influence is indirect and the risk is lower than a request-body URL — but the inconsistency means a poisoned hosted_url/image_url DB value (e.g. http://169.254.169.254/ or http://localhost:6379/) would be fetched against the backend's internal network/cloud-metadata endpoint with no validation.

**Fix:** Route all outbound media fetches through the existing _public_media_url_error check (or a shared helper) before requests.get in face_crops and image_variants, mirroring s3_mirror.download_image. Centralize the guard so future fetch sites inherit it.

**Evidence:**
```
s3_mirror.py:790 url_error = _public_media_url_error(source_url) then raise; _public_media_url_error rejects non-global IPs and localhost (s3_mirror.py:147-172). face_crops.py:104 response = requests.get(image_url, timeout=(5, 40), stream=True) — no preceding validation. image_variants.py:108/125 resp = requests.get(hosted_url, timeout=45) — no preceding validation.
```


---

#### 5. [Medium] Supabase JWT issuer and project-ref checks silently become no-ops when project ref cannot be derived
**Status:** • unverified · _OWASP A07:2021 Identification and Authentication Failures_  
**Location:** `TRR-Backend/trr_backend/security/jwt.py : 167-176 (verify_jwt_token) with derivation at 48-87`  

verify_jwt_token enforces the issuer check only 'if expected_issuer and token_issuer' and the project-ref check only 'if expected_project_ref and token_project_ref'. expected_supabase_issuer/expected_supabase_project_ref return None when no SUPABASE_PROJECT_REF/SUPABASE_JWT_ISSUER is set and none can be parsed from the configured Supabase/DB URLs. In that case both defense-in-depth checks are skipped and only the HS256 signature + exp are enforced. Startup only logs a warning for this condition (main.py:382 via describe_supabase_jwt_context) rather than failing. Consequence: if the SUPABASE_JWT_SECRET were ever shared or reused across projects/environments, a JWT minted by a different project signed with the same secret would be accepted because the issuer/ref binding is not mandatory. The signature check is the real gate, so this is defense-in-depth rather than a direct break, but the intended issuer pinning is conditionally disabled.

**Fix:** In deployed runtimes, require a derivable/explicit project ref+issuer and fail startup (not just warn) if absent, so the issuer/ref checks are always enforced. Alternatively make verify_jwt_token reject tokens whose iss/ref are present but cannot be validated against a known-expected value.

**Evidence:**
```
options = { 'verify_aud': False, 'verify_iss': False, ... } then manual: if expected_issuer and token_issuer and token_issuer != expected_issuer: raise (jwt.py:143-171). describe_supabase_jwt_context emits 'Unable to derive a Supabase project ref...' as a warning; main.py logs it at WARNING, does not raise.
```


---

#### 6. [Low] Internal-admin shared secret is auto-derived deterministically by the dev workspace launcher
**Status:** • unverified · _OWASP A02:2021 / A05:2021 Predictable Secret_  
**Location:** `scripts/dev-workspace.sh : 169-184 (workspace_local_auth_secret) and 1281-1282 / 1403`  

CONFIRMS the 'startup auto-derives local shared secrets' lead. When TRR_INTERNAL_ADMIN_SHARED_SECRET is unset, dev-workspace.sh derives it as 'trr-local-dev-internal-admin-' + sha256("${ROOT}:${USER}:internal-admin") and injects it into the locally-launched backend (lines 1281-1282, 1403). The value is fully deterministic from the repo root path and OS username, so it is predictable to anyone who knows those two strings. It is explicitly namespaced 'trr-local-dev-' and the injected backend processes bind to loopback service URLs (the script comment at line 390 notes 'loopback service URLs'), so blast radius is local-dev only. The risk is that this convenience secret is auth-bypass-grade (it backs require_internal_admin and the raw-secret fallback) and would be dangerous if this launcher were ever pointed at a non-loopback or shared host, or if the derived value were copied into a deployed env.

**Fix:** Keep the derived secret strictly local-only: assert loopback binding when using it, and document that it must never be reused for deployed runtimes. Consider generating a random per-run secret (openssl rand) instead of a path/username-deterministic one so it is not guessable, even locally.

**Evidence:**
```
workspace_local_auth_secret(): seed="$(printf '%s' "${ROOT}:${USER}:${label}" | shasum -a 256 ...)"; printf 'trr-local-dev-%s-%s' "$label" "$seed" (dev-workspace.sh:169-181). WORKSPACE_TRR_INTERNAL_ADMIN_SHARED_SECRET="${TRR_INTERNAL_ADMIN_SHARED_SECRET:-$(workspace_local_auth_secret internal-admin)}" (line 184).
```


---

#### 7. [Low] Dev-only raw-shared-secret fallback grants full internal-admin with no token expiry/replay protection
**Status:** • unverified · _OWASP A07:2021 Identification and Authentication Failures_  
**Location:** `TRR-Backend/api/auth.py : 67-73 (_raw_internal_admin_fallback_matches) and 218-227`  

When TRR_INTERNAL_ADMIN_ALLOW_RAW_SECRET_FALLBACK is truthy, require_internal_admin accepts a bare X-TRR-Internal-Admin-Secret header and returns a synthetic internal_admin identity ('internal-admin:shared-secret') with no JWT, no expiry, no audience/issuer binding, and no replay protection. This is correctly gated off by default, logs a warning when engaged ('raw-secret-fallback engaged; dev-only flag ... is enabled'), and is not enabled in any committed profiles/*.env (grep found no occurrences). It is reported as Low because it is a documented dev escape hatch that is safe in the default configuration; the risk is purely operational — if the flag is ever set in a deployed environment, a single static header value yields full admin.

**Fix:** Add a runtime assertion that refuses to honor this flag unless _is_local_or_dev_runtime() is true, so it cannot be activated in a deployed runtime even by misconfiguration. Keep the warning log.

**Evidence:**
```
_raw_internal_admin_fallback_matches: if not _env_flag_strict('TRR_INTERNAL_ADMIN_ALLOW_RAW_SECRET_FALLBACK', False): return False; logger.warning('[auth] raw-secret-fallback engaged ...'); return _internal_admin_secret_matches(request) (auth.py:67-73). Accepted identity built at auth.py:218-227. grep of profiles/ for the flag -> no matches (off by default).
```


---

#### 8. [Low] Dynamic-column UPDATE builders interpolate dict keys into SQL (currently safe, fragile pattern)
**Status:** • unverified · _OWASP A03:2021 Injection (defense-in-depth)_  
**Location:** `TRR-Backend/trr_backend/repositories/cast_screentime.py (lines 88-99, 702-715) and trr_backend/repositories/screenalytics_runs.py (196-208)`  

update_media_upload_session, update_run (cast_screentime) and update_run (screenalytics_runs) build the SET clause by interpolating dict keys directly: for key,value in payload.items(): assignments.append(f"{key} = %s"). Values are parameterized (%s), but the column identifiers come from the payload dict keys. I traced every caller (api/routers/admin_cast_screentime.py lines 924-2142, screenalytics_runs callers) and ALL of them construct the payload with hardcoded literal keys derived from Pydantic request models (e.g. {'status': ..., 'error_message': ...}) — no caller forwards a raw request body or model_dump() whose keys the client controls. So this is NOT currently exploitable. It is reported Low because the pattern has no column allowlist: a future caller that passes through client-controlled keys (e.g. update_run(id, request.model_dump())) would introduce SQL injection via the SET clause, which f-string column interpolation cannot prevent.

**Fix:** Add an explicit allowlist of permitted column names in each update_* function (intersect payload.keys() with a frozenset of known columns and raise/ignore others), or quote identifiers via psycopg2.sql.Identifier. This makes the safety property local to the repository rather than dependent on every caller using hardcoded keys.

**Evidence:**
```
cast_screentime.py:705-708 for key, value in payload.items(): assignments.append(f"{key} = %s") ... f"UPDATE ml.screentime_runs SET {', '.join(assignments)} WHERE id = %s RETURNING *". All call sites verified hardcoded-key, e.g. admin_cast_screentime.py:2042-2054 payload = {'status': request.status, 'error_message': request.error_message, ...}; update_run(str(run_id), payload).
```


---

## Security — Database / Supabase  (`db-security`)

**Summary.** The Supabase data layer has been through several advisor-driven hardening passes that are genuinely effective: RLS is enabled on every table in exposed schemas (admin/core/public/social), views are set to security_invoker, dangerous SECURITY DEFINER RPCs (merge_shows, upsert_*, get_or_create_direct_conversation) have had EXECUTE revoked from anon/authenticated and search_path pinned, and a dynamic default-deny sweep adds restrictive using(false) policies to RLS-enabled tables lacking policies. However, the live-DB snapshot (docs/workspace/supabase-rls-grants-review.md, generated by rls_grants_snapshot.py) reveals that the `anon` role holds full INSERT/UPDATE/DELETE/TRUNCATE/TRIGGER/REFERENCES privileges on every table in the `public` schema (15 tables incl. survey response tables and surveys) — grants that exist in NO migration and have NO corrective revoke. Because TRUNCATE is gated only by table privilege and is never filtered by RLS row policies, any holder of the public anon key can truncate these tables, a data-loss/DoS hole that RLS does not mitigate; several migration-vs-live drifts (e.g. cast_tmdb RLS) also mean a freshly-built environment would be less safe than production.

<details><summary>Coverage / blind spots</summary>

Read: full migration inventory listing (280 files); both security-hardening migrations in full (20260417130000_supabase_security_advisor_hardening.sql, 20260511195828_supabase_security_advisor_default_deny_and_search_path.sql); 20260428111000_advisor_rls_policy_cleanup.sql; 20260428110000_security_hotfix_public_migrations_rpc_exec.sql; 0090_survey_submit_response_rpc.sql; 20260330190000_create_flashback_tables.sql; 20260428113000_remove_flashback_gameplay_write_path.sql; 0086_create_pipeline_schema.sql; 20260428114333_social_post_canonical_foundation.sql; 0044_create_cast_tmdb.sql; 20260518005750_social_internal_tables_enable_rls.sql; and the entire live snapshot doc supabase-rls-grants-review.md (RLS Inventory + Role Grants, ~1569 lines). Grepped all 280 migrations for: enable/disable/force row level security, using(true)/with check(true), grant/revoke by role (anon/authenticated/service_role/public), security definer + set search_path, grant usage on schema, alter default privileges, on all tables in schema. Correlated granted-to-anon tables vs RLS-enabled tables vs security_invoker views programmatically. Deliberately SKIPPED: reading the full bodies of every SECURITY DEFINER function (verified the two hardening migrations sweep-pin search_path for all non-extension core/public/social functions, so only out-of-sweep schemas were spot-checked); the giant socials/test files (out of scope for SQL layer); the actual runtime PostgREST db-schemas config (not in repo — inferred exposure of core/social/surveys from the advisor having flagged those tables). BLIND SPOTS: I could not execute SQL against the live DB to confirm whether the public-schema anon TRUNCATE is reachable through PostgREST specifically (depends on runtime exposed-schema config) — assessment relies on the live introspection snapshot the team committed; and I could not confirm whether the dynamic default-deny sweep in 20260511195828 actually executed successfully in production for every survey response table (the snapshot does not enumerate policies, only grants and rls flags).

</details>

#### 1. [Critical] anon role holds TRUNCATE/INSERT/UPDATE/DELETE on every public-schema table in the live DB (TRUNCATE bypasses RLS → data loss / DoS)
**Status:** ✅ verified (high confidence) · **verifier-adjusted severity: High** · _Excessive privilege / RLS bypass_  
**Location:** `docs/workspace/supabase-rls-grants-review.md : 711-1011 (e.g. 716 'public | flashback_events | anon | TRUNCATE', 989 'public | survey_x_responses | anon | TRUNCATE', 1010 'public | surveys | anon | TRUNCATE')`  

The live-database snapshot shows the `anon` PostgREST role has been granted DELETE, INSERT, UPDATE, TRUNCATE, TRIGGER and REFERENCES on ALL 15 tables in the `public` schema: flashback_quizzes, flashback_events, show_icons, site_typography_assignments, site_typography_sets, surveys, survey_cast, survey_episodes, survey_show_seasons, survey_shows, survey_show_palette_library, and the survey response tables survey_global_profile_responses / survey_rhop_s10_responses / survey_rhoslc_s6_responses / survey_x_responses. RLS is enabled on these tables and DML row-policies (mostly service_role-only or restrictive default-deny) block anon INSERT/UPDATE/DELETE at the row level. BUT Postgres TRUNCATE is gated ONLY by the table-level TRUNCATE privilege and is never evaluated against RLS row-security policies. Therefore any party in possession of the project's public anon key can issue TRUNCATE against these tables (directly via SQL over a pooled anon connection, or anywhere PostgREST/RPC permits it), destroying all survey responses, flashback data, typography, and show-icon rows. This is an unauthenticated data-loss / availability hole that the otherwise-good RLS work does not mitigate.

**Fix:** Add a migration that explicitly strips write privileges from anon/authenticated on the public schema and re-establishes least privilege: `REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public FROM anon, authenticated;` then `GRANT SELECT` only where a public read is actually intended (e.g. flashback_quizzes/events, show_icons, typography). Also fix the source of the drift: `ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon, authenticated;` so newly created public tables do not inherit anon writes. Re-run scripts/db/rls_grants_snapshot.py to confirm anon retains at most SELECT.

**Evidence:**
```
docs/workspace/supabase-rls-grants-review.md lines 984-990: '| public | survey_x_responses | anon | DELETE |','| ... | INSERT |','| ... | TRUNCATE |','| ... | UPDATE |' — repeated for all 15 public tables (count check: 6 write-privilege rows x 15 tables). No migration grants these (grep 'on all tables in schema' returns only service_role targets), and no migration revokes them.
```


---

#### 2. [High] Live database grants diverge from migrations with no corrective migration (anon write grants exist only in production)
**Status:** ✅ verified (high confidence) · _Configuration drift / reproducibility_  
**Location:** `TRR-Backend/supabase/migrations/20260330190000_create_flashback_tables.sql : 63-64 (`grant select on public.flashback_quizzes to anon, authenticated, service_role;` — SELECT only, yet live DB shows anon with INSERT/UPDATE/DELETE/TRUNCATE)`  

The anon write/TRUNCATE privileges in finding #1 are present in the live database but are declared by NO migration. The flashback creation migration grants only SELECT to anon; survey response tables (survey_x_responses, survey_global_profile_responses, etc.) have no CREATE TABLE in migrations at all and first appear only in 20260417130000_supabase_security_advisor_hardening.sql (which merely enables RLS on already-existing tables). This means: (a) the production grant state was set out-of-band (Supabase SQL editor / dashboard, where the executing role's default privileges leak to anon), and (b) the migrations are not the source of truth for grants. A consequence is that environments built purely from migrations and the live environment have different, inconsistent security postures, and the only thing catching the drift is the manually-run snapshot script — there is no enforcement and no remediation migration. This undermines the entire advisor-hardening effort because the next dashboard table-create re-introduces the hole.

**Fix:** Treat grants as code: add migrations that REVOKE the drifted anon/authenticated privileges and pin intended grants explicitly (see #1). Add a CI check (extend scripts/db/rls_grants_snapshot.py or a new test) that fails if anon/authenticated holds anything beyond an allowlisted SELECT set on exposed schemas. Forbid table creation via the dashboard for these schemas, or always follow with an explicit REVOKE/GRANT migration.

**Evidence:**
```
grep across all 280 migrations for 'on all tables in schema' and 'alter default privileges' returns only `to service_role` targets (0001_init.sql:341-343, 0002_social.sql:78, 0086:78); grep for any 'revoke ... (insert|update|delete|truncate|all) ... from anon' on survey_/flashback_/typography tables returns nothing. Yet docs/workspace/supabase-rls-grants-review.md (live snapshot) lines 711-1011 show those very privileges held by anon.
```


---

#### 3. [Medium] core.cast_tmdb RLS is enabled only in the live DB, never in migrations — fresh environments expose person social IDs to authenticated users
**Status:** • unverified · _Configuration drift / missing RLS in source_  
**Location:** `TRR-Backend/supabase/migrations/0044_create_cast_tmdb.sql : 71 (`GRANT SELECT ON core.cast_tmdb TO authenticated;`) with no `alter table core.cast_tmdb enable row level security` anywhere in migrations`  

core.cast_tmdb is a real table (CREATE TABLE at 0044:4) containing person identity columns including instagram_id, twitter_id, imdb_id, tmdb_id (indexes at 0044:49-53). The migration grants SELECT to `authenticated`. No migration ever enables RLS on it, and it is not named in any CREATE POLICY. The live snapshot shows it currently has rls_enabled=yes (doc line 39) — i.e. RLS was turned on out-of-band, and the dynamic default-deny sweep (20260511195828) then covers it (RLS-on + no policy => restrictive deny) so production is currently protected. However, because the RLS-enable is NOT in migrations, any environment provisioned from the migration set (staging, a new project, disaster-recovery rebuild) will have cast_tmdb with RLS OFF and `GRANT SELECT TO authenticated`, making the full table readable by any logged-in user via PostgREST in the `core` schema (which is granted USAGE to authenticated at 0001_init.sql:310).

**Fix:** Add `alter table core.cast_tmdb enable row level security;` (plus an explicit restrictive or scoped policy) to a migration so the protection is reproducible, matching the pattern used in 20260417130000 for the other core tables. Audit for any other table that is rls_enabled=yes in the snapshot but has no enable-RLS statement in migrations.

**Evidence:**
```
0044_create_cast_tmdb.sql:71 'GRANT SELECT ON core.cast_tmdb TO authenticated;'; grep 'cast_tmdb' across migrations shows zero 'enable row level security' and zero 'policy' hits; doc snapshot line 39 '| core | cast_tmdb | yes | no |' and line 300 '| core | cast_tmdb | authenticated | SELECT |'.
```


---

#### 4. [Medium] Public SECURITY DEFINER surveys.submit_response allows unauthenticated (anon) submissions with no dedup or rate limiting
**Status:** • unverified · _SECURITY DEFINER abuse surface_  
**Location:** `TRR-Backend/supabase/migrations/0090_survey_submit_response_rpc.sql : 39-46 (dedup guarded by `IF v_user_id IS NOT NULL`) and 72 (`GRANT EXECUTE ... TO anon`)`  

surveys.submit_response is the one public SECURITY DEFINER function the hardening migrations intentionally left exposed to anon (it is the 'documented exception'). The function itself is well written — search_path is pinned (SET search_path = surveys, auth, public), it derives the user from auth.uid() rather than trusting a client-supplied id, and it validates survey status. However, it is GRANTed EXECUTE to `anon` and the duplicate-submission guard only runs when a user is authenticated (`IF v_user_id IS NOT NULL THEN ... EXISTS ... RAISE`). For anonymous callers v_user_id is NULL, so the dedup is skipped entirely and the function will INSERT an unbounded number of response+answer rows for the same published survey on every call. With the public anon key, this is a cheap unauthenticated write amplification / ballot-stuffing / storage-exhaustion vector against surveys.responses and surveys.answers (which run as the definer/owner, bypassing those tables' RLS).

**Fix:** Either require authentication for submission (drop the anon GRANT and gate the client through an authenticated/backend path), or add server-side abuse controls for the anonymous path: a per-survey rate limit, a captcha/turnstile check enforced before the RPC, or a dedup key (e.g. hashed IP / device token) so anonymous submissions cannot be replayed indefinitely. At minimum cap the number of answers per call and the payload size.

**Evidence:**
```
0090_survey_submit_response_rpc.sql lines 38-46: 'IF v_user_id IS NOT NULL THEN / IF EXISTS (SELECT 1 FROM surveys.responses WHERE survey_id = p_survey_id AND user_id = v_user_id) THEN / RAISE EXCEPTION ...' (no else branch for anon); line 72 'GRANT EXECUTE ON FUNCTION surveys.submit_response(uuid, jsonb) TO anon;'.
```


---

#### 5. [Low] Survey response PII tables are protected only by the dynamic default-deny sweep, not by any named explicit policy — fragile to future permissive-policy mistakes
**Status:** • unverified · _Defense-in-depth / fragile RLS_  
**Location:** `TRR-Backend/supabase/migrations/20260511195828_supabase_security_advisor_default_deny_and_search_path.sql : 20-60 (DO-block that adds restrictive `using(false)` only to RLS-enabled tables that currently have zero policies)`  

Tables holding survey response data (public.survey_global_profile_responses, survey_rhop_s10_responses, survey_rhoslc_s6_responses, survey_x_responses) have anon holding SELECT plus full writes in the live DB (finding #1), and have NO explicitly named CREATE POLICY anywhere in migrations. Their SELECT/INSERT/UPDATE/DELETE protection depends entirely on the runtime DO-block sweep in 20260511195828, which only adds a restrictive deny policy to a table IF that table currently has no policy at all. The moment anyone adds a single permissive SELECT policy to one of these tables (e.g. for a public aggregate), the dynamic deny would not be re-applied, and because anon already holds the table-level SELECT grant, response-level PII would become world-readable via PostgREST. The protection is therefore implicit and order/condition-dependent rather than declared per table.

**Fix:** Add explicit, named restrictive deny policies (or scoped owner-only policies) directly in a migration for each survey response table, and remove the anon SELECT grant on them entirely (responses should never be readable by anon). Keep the dynamic sweep as a backstop, not the primary control. Re-run rls_grants_snapshot.py and annotate the 'Review Notes' section of the doc (currently an empty template at line 1565) to record which public reads are intentional.

**Evidence:**
```
20260511195828 lines 24-31 condition: 'where c.relkind in (...) and c.relrowsecurity and n.nspname in (...) and not exists (select 1 from pg_policy pol where pol.polrelid = c.oid)'; doc lines 858-864/984-990 show anon SELECT+writes on survey_*_responses; grep for 'policy ... survey_x_responses' across migrations returns nothing; doc 'Review Notes' (line 1565-1568) is an unfilled stub.
```


---

## Security — App (web) — TRR-APP/apps/web  (`app-security`)

**Summary.** Server authZ is broadly solid: 327 route handlers nearly all funnel through requireAdmin/requireUser or admin-proxy factories that call requireAdmin internally, postgres.ts uses parameterized queries throughout (no SQL injection), and the app never fetches user-supplied URLs itself (proxies them to TRR-Backend, so app-layer SSRF is refuted). The confirmed real issues are: (1) the prior lead is TRUE — TRR_API_URL backend origin leaks into client-facing error detail across the central admin proxy and ~10 routes; (2) a cron mutation endpoint fails OPEN when CRON_SECRET is unset in production; (3) the dev-admin-bypass grants full admin with no allowlist check behind a fragile multi-condition gate that has no hard production stop; (4) Firestore global analytics docs are writable with arbitrary content by any authenticated user. NEXT_PUBLIC_* "secret-like" vars are all legitimately public keys (Firebase web API key, Supabase anon/publishable) — refuted.

<details><summary>Coverage / blind spots</summary>

READ IN FULL: firestore.rules; src/lib/server/auth.ts (admin/user gating, allowlists, host isolation, dev-bypass); src/lib/firebaseAdmin.ts; src/lib/server/trr-api/internal-admin-auth.ts (HS256 internal-admin JWT minting/verification, timingSafeEqual); backend.ts; admin-backend-proxy-route.ts (central proxy); social-profile-route-factory.ts; sse-proxy.ts; session/login + logout routes; both cron routes; scrape/preview route; _catalog-run-action.ts. SAMPLED: postgres.ts (query/withAuthTransaction/queryWithAuth ~lines 561-659 + SSL/conn classify), social-admin-proxy.ts error mapping (~300-389), admin-read-proxy.ts error path (~220-280), normalized-survey-admin-repository.ts dynamic UPDATE construction, realitease/manager.ts global-analytics writes. GREP SWEEPS: all 327 route.ts for auth-helper references (313 referenced a gate; the 14 "ungated" were all proxy-factory or cron routes, manually confirmed gated except cron); TRR_API_URL in error/response payloads (whole src); SQL template-literal interpolation in .query() calls (whole src — only fixed table-name/field constants, never user input); NEXT_PUBLIC_*(KEY|SECRET|TOKEN|...) across TRR-APP + profiles; console.* secret-logging sweep (none found); TRR_DEV_ADMIN_BYPASS/ADMIN_ENFORCE_HOST in profiles/env. DELIBERATELY SKIPPED / BLIND SPOTS: did not exhaustively read all 327 handlers (sampled the security-relevant clusters: admin proxies, social, cast-photos, media-assets, people, shows, cron, session); did not deep-read the 206KB trr-shows-repository.ts or 28KB social-admin-proxy.ts in full; did not audit TRR-Backend's own SSRF handling of forwarded URLs (out of app scope); did not runtime-test the dev-bypass Host-spoofing path against a live Vercel deployment (analysis is static); did not review firestore.rules emulator/test overrides; client-side components (PersonPageClient etc.) only spot-checked for analytics writes.

</details>

#### 1. [High] Cron endpoint /api/cron/episode-progression fails OPEN when CRON_SECRET is unset in production
**Status:** ✅ verified (high confidence) · _OWASP A01 Broken Access Control / A05 Security Misconfiguration_  
**Location:** `TRR-APP/apps/web/src/app/api/cron/episode-progression/route.ts : 19-30, 123-125`  

The auth guard is `if (process.env.NODE_ENV === "production" && cronSecret) { ...reject unless Bearer matches... }`. If CRON_SECRET is NOT set in production, the entire condition is false and the check is skipped, so the endpoint runs the mutation (auto-progresses survey episodes via progressToNextEpisode) for ANY unauthenticated caller. The sibling cron route create-survey-runs/route.ts:31-35 handles this correctly by returning HTTP 500 when NODE_ENV===production and !cronSecret (fails closed). Additionally GET(request) simply calls POST(request) (line 123-125), so the state-changing job is triggerable with a plain GET. This route is registered in vercel.json so it is a live public path.

**Fix:** Mirror the fail-closed pattern from create-survey-runs: in production, return 500 if CRON_SECRET is unset, then reject when the Authorization Bearer does not match — never skip the check based on cronSecret being falsy. Consider removing the GET alias or gating it behind the same secret. Evidence-backed fix is a 4-line change to invert the guard.

**Evidence:**
```
if (process.env.NODE_ENV === "production" && cronSecret) {
  if (authHeader !== `Bearer ${cronSecret}`) { return 401 }
}  // <- if cronSecret is unset in prod, NO auth check runs at all
...
export async function GET(request) { return POST(request); }
```


---

#### 2. [Medium] Backend origin (TRR_API_URL) disclosed to clients in admin-proxy error responses
**Status:** • unverified · _OWASP A01/A05 Information Disclosure_  
**Location:** `TRR-APP/apps/web/src/lib/server/trr-api/admin-backend-proxy-route.ts : 182-190`  

CONFIRMS prior lead #4. buildBackendFetchFailedPayload embeds the literal TRR_API_URL value into the JSON `detail` returned to the client on any backend fetch failure (HTTP 502). This is the centralized proxy used by createAdminBackendProxyRoute (13 routes incl cast-photos/[photoId]/mirror, media-assets/[assetId]/replace-from-url, reverse-image-search). The same leak is hand-rolled in ~10 more routes: people/[personId]/refresh-images/route.ts:153, shows/[showId]/google-news/sync/route.ts:38 (and /[jobId]:37), shows/[showId]/news/route.ts:32, networks-streaming/sync/route.ts:173, shows/sync-from-lists/route.ts:86, shows/[showId]/refresh/route.ts:94, .../retry/route.ts:103, auto-count-images/route.ts:98, bravo/videos/sync-thumbnails/route.ts:31, cast-matrix/sync/route.ts:75. All are requireAdmin-gated, so this exposes the internal backend hostname (e.g. a Render/Modal origin or private URL) only to authenticated admins and to any browser error-tracking/log sink — not to anonymous users — hence Medium. Notably the newer proxies social-admin-proxy.ts:325/348 and admin-read-proxy.ts:250 already do this correctly (generic 'Confirm TRR_API_URL is set' hint with NO URL value), showing the intended pattern.

**Fix:** Stop interpolating process.env.TRR_API_URL into client-visible error payloads. Log the URL server-side (console.error) and return only a generic detail like the social-admin-proxy/admin-read-proxy hint ('Could not reach TRR-Backend; confirm it is running and TRR_API_URL is correct'). Fix buildBackendFetchFailedPayload first (covers the 13 factory routes), then sweep the ~10 hand-rolled occurrences via the grep `TRR_API_URL=${`.

**Evidence:**
```
const buildBackendFetchFailedPayload = (error) => {
  ...
  return { error: "Backend fetch failed",
    detail: `${baseDetail}${causeDetail} (TRR_API_URL=${process.env.TRR_API_URL ?? "unset"})` };
};
```


---

#### 3. [Medium] Dev-admin-bypass grants full admin with no allowlist check behind a fragile gate with no hard production stop
**Status:** • unverified · _OWASP A01 Broken Access Control / A07 Identification & Authentication Failures_  
**Location:** `TRR-APP/apps/web/src/lib/server/auth.ts : 570-580, 740-747`  

In requireAdmin, when isDevAdminBypassEnabled(request) is true, the function returns `existingUser ?? buildDevBypassUser()` (line 746) WITHOUT consulting the email/uid/displayName allowlists — i.e. it grants admin to whatever token is present, or a synthetic admin if none. isDevAdminBypassEnabled is true when bypassEnabled (TRR_DEV_ADMIN_BYPASS truthy, OR defaults to NODE_ENV===development) AND the request Host resolves to localhost/.localhost/loopback. Defense-in-depth currently holds in production because (a) isRequestHostAllowedForAdmin runs first (line 731) and host enforcement defaults ON, and (b) Vercel sets the Host header to the deployment domain, not localhost. However there is no explicit production hard-stop: if TRR_DEV_ADMIN_BYPASS is ever set truthy in a prod/preview env, OR host enforcement is disabled (ADMIN_ENFORCE_HOST=false) while a request presents a spoofed/forwarded localhost Host, the bypass yields unauthenticated admin. Note there is no middleware.ts anymore (the historical host-enforcement middleware was removed per docs/ai/archive/HANDOFF-legacy-2026-03-16.md:9653), so all host isolation now rests solely on this per-route check.

**Fix:** Hard-disable the bypass whenever NODE_ENV==='production' regardless of TRR_DEV_ADMIN_BYPASS (early `if (process.env.NODE_ENV === 'production') return false` in isDevAdminBypassEnabled). Even in dev, require the explicit literal token 'dev-admin-bypass' rather than silently minting a bypass user from `existingUser ?? buildDevBypassUser()`. Add a startup assertion that fails boot if TRR_DEV_ADMIN_BYPASS is truthy in production.

**Evidence:**
```
if (isDevAdminBypassEnabled(request)) {
  const parsed = parseTokenFromRequest(request);
  if (parsed?.token.trim() === "dev-admin-bypass") { return buildDevBypassUser(); }
  const existingUser = await getUserFromRequest(request);
  return existingUser ?? buildDevBypassUser();  // <- admin with NO allowlist check
}
```


---

#### 4. [Medium] Firestore: global game-analytics documents writable with arbitrary content by any authenticated user
**Status:** • unverified · _OWASP A01 Broken Access Control / data integrity_  
**Location:** `TRR-APP/firestore.rules : 50-58`  

realitease_analytics/{docId} and bravodle_analytics/{docId} use `allow write: if isAuthenticated()` with NO field/shape validation and NO ownership constraint. These are GLOBAL aggregate docs keyed by puzzle date (realitease/manager.ts:644, written transactionally as { puzzleDate, totalAttempts, totalWins, averageGuesses, guessDistribution }). Any signed-in user can use the client Firestore SDK to overwrite these global stats with arbitrary values (e.g. set totalWins to 0, corrupt guessDistribution, poison averageGuesses) — bypassing the server-side transactional aggregation in manager.ts and affecting all users' displayed leaderboard/distribution data. This is data-integrity tampering, not a confidentiality breach; answer keys are correctly locked (realitease_answerkey/bravodle_answerkey allow write: if false) and user-scoped docs are correctly isOwner-gated, so severity is Medium.

**Fix:** Restrict client writes to global analytics: either (a) move all global-analytics aggregation server-side (Admin SDK / a route handler) and set `allow write: if false` for these collections, or (b) if client writes must stay, add request.resource.data validation that constrains keys, enforces numeric types/ranges, and rejects decreases (counters monotonic). Mirror the strict request.resource.data validation already used for problem_reports (rules:73-90).

**Evidence:**
```
match /realitease_analytics/{docId} {
  allow read: if true;
  allow write: if isAuthenticated();  // <- any logged-in user can overwrite global stats, no field validation
}
match /bravodle_analytics/{docId} { allow read: if true; allow write: if isAuthenticated(); }
```


---

#### 5. [Low] Firebase Admin SDK initializes silently without credentials at runtime (auth verification quietly degrades)
**Status:** • unverified · _OWASP A05 Security Misconfiguration_  
**Location:** `TRR-APP/apps/web/src/lib/firebaseAdmin.ts : 30-38`  

When FIREBASE_SERVICE_ACCOUNT is absent and emulators are off, initAdmin() initializes the Admin app with only a projectId and just console.warn()s 'Some features will be disabled.' Server token verification then routes through verifyFirebaseToken's HAS_SERVICE_ACCOUNT=false branch (auth.ts:214-217), falling back to verifyIdTokenWithoutAdmin which depends on NEXT_PUBLIC_FIREBASE_API_KEY and a remote Identity Toolkit lookup, and session-cookie verification (adminAuth.verifySessionCookie) will fail. This is a fragile failure mode: a missing-secret deploy does not hard-fail; it silently changes the auth verification path. Combined with the requireAdmin allowlist this is not directly exploitable, but it weakens the guarantee that session cookies are cryptographically verified in production.

**Fix:** Fail fast in production: if NODE_ENV==='production' and neither FIREBASE_SERVICE_ACCOUNT nor emulators are configured, throw on init (or have requireUser/requireAdmin refuse to authenticate) rather than degrading to a best-effort fallback. Keep the lenient path strictly for local/CI builds (IS_NEXT_BUILD_PROCESS).

**Evidence:**
```
if (sa) { initializeApp({ credential: cert(creds), ... }); }
else {
  if (!IS_NEXT_BUILD_PROCESS) { console.warn("Firebase Admin SDK: No service account provided. Some features will be disabled."); }
  const projectId = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || "demo-build";
  initializeApp({ projectId });  // <- no credential, runtime auth silently degrades
}
```


---

## Performance — Backend  (`be-perf`)

**Summary.** TRR-Backend's DB connection/pool layer (trr_backend/db/pg.py) and the Postgres-backed social ingest queue are fundamentally well-engineered: ThreadedConnectionPool with double-checked-locking init, FOR UPDATE SKIP LOCKED job claiming, transient-error retry, configurable bulk-upsert batch sizes, and statement/idle timeouts. The dominant performance risk is the social sync-orchestrator tick (tick_sync_orchestrator, fired every 30s for up to 50 sessions per worker) whose per-session _build_completeness_snapshot runs several coverage builders, including _build_avatar_coverage_snapshot which performs multiple UNBOUNDED full-table / full-window scans (entire avatar_registry, all post JSON via to_jsonb, all verified comments) and counts them row-by-row in Python. Secondary issues: unconditional INFO logging on every pooled-connection checkout/return, serial blocking Modal API round-trips inside the dispatch loop, and module-level in-memory caches with lazy-only expiry (unbounded key growth) plus per-call deepcopy on a labelled "hot path".

<details><summary>Coverage / blind spots</summary>

READ in full: trr_backend/db/connection.py (lane resolution), trr_backend/db/session.py (DbSession query builder), trr_backend/job_plane.py, trr_backend/modal_dispatch.py, api/realtime/broker.py. READ strategically (entry points + hot paths): trr_backend/db/pg.py (pool sizing, _get_pool, _get_connection_with_retry, db_connection/db_read_connection, fetch_/execute_ helpers, checkout/return logging), scripts/socials/worker.py (main poll loop + heartbeat), trr_backend/socials/control_plane/dispatch_runtime.py (claim_next_queued_jobs, process_claimed_job, dispatch_due_social_jobs loop, _mark_claimed_runs_running), trr_backend/repositories/social_sync_orchestrator.py (tick_sync_orchestrator, evaluate_sync_session, _build_completeness_snapshot, _build_avatar_coverage_snapshot), api/routers/socials/__init__.py (inline-fallback dispatch, BackgroundTasks usage, _execute_with_timeout, _run_admin_repo_call), trr_backend/observability.py (pool metrics). SAMPLED via grep + targeted reads: trr_backend/socials/social_season_analytics_impl.py (61,116 lines — claim/dispatch constants, get_comments_coverage/get_mirror_coverage delegation, module-level TTL caches), trr_backend/repositories/admin_show_reads.py (137KB — resolve_show_slug/search_global slug CTE scans), trr_backend/repositories/cast_photos.py, admin_operations.py (confirmed grep N+1 hits were mostly retry loops/comprehensions, not per-row queries). DELIBERATELY SKIPPED (blind spots): the bulk of the 61k-line analytics impl beyond sampled functions, so the actual scraper/persist inner loops (execute_run body, media mirroring, comment upsert internals) and per-platform scraper client concurrency were NOT line-audited; vision/media/integrations subpackages; the 280 SQL migrations (no index audit performed, so claims about missing indexes on computed slugs are inferred from query shape, not confirmed against pg_indexes); admin_operations/reddit_refresh repositories beyond grep; no runtime profiling or EXPLAIN was run.

</details>

#### 1. [High] Sync-orchestrator tick runs unbounded full-table scans + Python-side counting on every session evaluation (up to 50x per 30s per worker)
**Status:** ✅ verified (high confidence) · _N+1 / unbounded scan / in-memory accumulation_  
**Location:** `trr_backend/repositories/social_sync_orchestrator.py : 463-543 (also 478-485, 601-617); driven by 2053-2081 and 662-693`  

tick_sync_orchestrator(limit=50) is called every 30s from the worker loop (scripts/socials/worker.py:1052-1062). For each of up to 50 active sync sessions it calls evaluate_sync_session -> _build_completeness_snapshot, which invokes SIX coverage builders. One of them, _build_avatar_coverage_snapshot, executes multiple UNBOUNDED queries: (1) line 478-485 loads the ENTIRE social.avatar_registry table (every 'mirrored'/'unsupported' row across ALL seasons/platforms, no season filter, no LIMIT) into two Python sets; (2) line 533-543, inside `for platform in platforms`, runs `select to_jsonb(p) as post_json from social.<post_table> p where season_id=... and posted_at between ...` with NO LIMIT, pulling the full JSON of every post in the window into memory, then iterates row-by-row in Python (line 546+) to count missing avatars; (3) line 601-617 runs an unbounded instagram_comments JOIN instagram_posts scan. Notably the sibling function _build_missing_detail_target_groups (line 1112-1119, 1166-1295, 1423-1434) DOES cap the same scans at `limit 5000`, so the avatar path is an inconsistent regression. Cost compounds: ~6 builders x ~6 platforms ≈ up to 36 queries/session x 50 sessions = ~1,800 queries every 30s per worker, several pulling unbounded row+JSON volume that grows as posts and avatar_registry grow. This is the single largest recurring DB+CPU+memory load in the backend and will degrade as data accumulates.

**Fix:** Replace the Python-side counting in _build_avatar_coverage_snapshot with SQL aggregation (COUNT/FILTER) that returns only the missing-avatar counts, mirroring how get_comments_coverage/get_mirror_coverage already aggregate. At minimum: (a) add a season/platform filter and `limit` to the avatar_registry load (or convert it to an EXISTS/anti-join against the post scan), and (b) add the same `limit 5000` guard already used by _build_missing_detail_target_groups to the post and verified-comment scans. Longer term, cache the completeness snapshot per (sync_session, run_status) for the tick interval so unchanged sessions are not rescanned every 30s, and ensure social.<post_table>(season_id, posted_at) and social.avatar_registry(status, platform, account_handle) indexes exist.

**Evidence:**
```
L478: completed_avatar_rows = ( pg.fetch_all( """ select platform, account_handle, source_url, status from social.avatar_registry where status in ('mirrored', 'unsupported') """ ) ...  | L533: row = pg.fetch_all(f""" select to_jsonb(p) as post_json from social.{post_table} p where p.season_id = %s::uuid and p.{posted_at_column} >= %s and p.{posted_at_column} <= %s {account_filter} """, params)  [no LIMIT]  | worker.py L1054: orchestrated = tick_sync_orchestrator(limit=50)  | sibling WITH cap, L1119: limit 5000
```


---

#### 2. [Medium] Unconditional INFO logging on every pooled DB connection acquire/checkout/return
**Status:** • unverified · _Hot-path logging overhead_  
**Location:** `trr_backend/db/pg.py : 1023-1029 (acquire_start), 631-643 (_log_checkout), 660-670 (_log_return)`  

Every single connection checkout emits at least three logger.info lines on the request hot path: acquire_start (L1023), checkout (L631), and return (L660). Each also calls _pool_counts(), _backend_pid_or_none() (which calls into the libpq C driver via get_backend_pid), and _transaction_status_name() (another driver call). Because every fetch_one/fetch_all/execute acquires and returns a connection, a single API request doing N queries produces ~3N INFO log lines plus 2N+ driver round-trips purely for logging. There is no level gate or env flag (grep for 'level/env/if' around the logging found none). Under production load this inflates log volume substantially and adds measurable per-query latency, and on a session-pooler maxconn=2 pool it serializes more work behind logging I/O.

**Fix:** Demote the per-checkout/per-return/acquire-start logs to logger.debug (or gate them behind an env flag like TRR_DB_POOL_TRACE), keeping only aggregate Prometheus metrics (record_postgres_pool_state already runs) on the default path. Reserve INFO/WARNING for pool init, retirement, exhaustion, dirty-connection rollback, and statement-timeout events.

**Evidence:**
```
L631: logger.info( "[db-pool] checkout id=%s label=%s acquire_ms=%.1f backend_pid=%s tx_status=%s in_use=%s available=%s", ... )  | L660: logger.info( "[db-pool] return id=%s ..." )  | L1023: logger.info( "[db-pool] acquire_start label=%s attempt=%s acquire_attempt=%s in_use=%s available=%s", ... )
```


---

#### 3. [Medium] Serial blocking Modal API round-trips inside the social dispatch loop
**Status:** • unverified · _Synchronous remote calls / serial fan-out_  
**Location:** `trr_backend/socials/control_plane/dispatch_runtime.py : 376-516 (esp. 399, 516); inspect at trr_backend/modal_dispatch.py:300-376`  

dispatch_due_social_jobs iterates candidate jobs serially. For each candidate that already has a remote_invocation_id it calls legacy._refresh_remote_modal_invocation_state (L399), which resolves to modal_dispatch.inspect_modal_function_call -> modal.FunctionCall.from_id(id).get_call_graph() (a synchronous Modal control-plane HTTP round-trip per job, modal_dispatch.py:329-331). For each job actually dispatched it makes another blocking modal.Function.from_name(...).spawn() call (legacy.dispatch_social_job, L516) plus two _touch_job_dispatch_metadata DB UPDATEs (L499, L518). All of this is sequential in one loop with no concurrency. The dispatched count is capped (SOCIAL_MODAL_DISPATCH_LIMIT default 4, batch max 25), which bounds the worst case, but the per-candidate get_call_graph() inspections run for every candidate with an existing invocation BEFORE the cap is hit, so a backlog of in-flight jobs produces a serial chain of network calls each tick. If Modal is slow or rate-limited (the code even classifies modal_rate_limited), the whole dispatch tick stalls.

**Fix:** Batch/parallelize the Modal invocation-state inspections (e.g., a single get_call_graph per run, or a bounded ThreadPoolExecutor for the per-job inspections) and short-circuit inspection when the lease is still fresh (the _dispatch_request_is_fresh check at L452 already exists but runs after the inspection). Cache invocation status with a short TTL keyed by remote_invocation_id to avoid re-inspecting the same call every tick.

**Evidence:**
```
L376: for job in candidates:  | L399: inspection = legacy._refresh_remote_modal_invocation_state(job, lease_expires_at=refreshed_lease_expires_at)  | L516: dispatch_result = legacy.dispatch_social_job(job_id=job_id, stage=stage)  | modal_dispatch.py L329: function_call = modal.FunctionCall.from_id(normalized_call_id); call_graph = function_call.get_call_graph()
```


---

#### 4. [Medium] Module-level in-memory caches grow unbounded (lazy-only expiry, no size cap) and deepcopy on every hot-path access
**Status:** • unverified · _Memory growth / CPU on hot path_  
**Location:** `trr_backend/socials/social_season_analytics_impl.py : 78-85 (cache dicts), 2492-2515 (_get/_set_social_hot_path_cache), 29435-29575 (profile snapshot cache)`  

Several process-global dict caches keyed by (season_id, account, ...) tuples are used on read paths: _SOCIAL_PROFILE_TOTAL_POSTS_CACHE, _SOCIAL_PROFILE_SNAPSHOT_CACHE, _SOCIAL_HOT_PATH_CACHE, _INSTAGRAM_COMMENTS_TARGET_PREVIEW_CACHE. Entries expire ONLY when the same key is read again after its TTL (lazy expiry, L2499-2500); there is no max size and no background sweep. In a long-lived API/worker process serving many distinct seasons/accounts, keys for entities that are never re-accessed remain resident forever, so memory grows monotonically with the cardinality of distinct keys seen. The hot-path cache TTL is just 5s (L2290), which maximizes key churn — many distinct short-lived entries are created and abandoned. Additionally _set/_get deepcopy the payload on every call (L2502, L2509), adding CPU cost on a path explicitly named 'hot_path'.

**Fix:** Bound these caches with an LRU (e.g., cachetools.TTLCache(maxsize=N, ttl=...) or functools.lru_cache where keys are hashable) so total entries are capped and expiry is enforced, and add a periodic sweep or use a structure that evicts on insert. Consider returning immutable/read-only payloads or shallow copies instead of full deepcopy where callers do not mutate, or store pre-serialized values.

**Evidence:**
```
L82: _SOCIAL_HOT_PATH_CACHE: dict[tuple[Any, ...], tuple[float, Any]] = {}  | L2499: if expires_at <= now: _SOCIAL_HOT_PATH_CACHE.pop(cache_key, None); return None  | L2507: _SOCIAL_HOT_PATH_CACHE[cache_key] = ( time_module.monotonic() + _SOCIAL_HOT_PATH_CACHE_TTL_SECONDS, copy.deepcopy(payload), )  [no maxsize; only _clear_* clears all]
```


---

#### 5. [Medium] Public show-slug resolution runs a full-table CTE scan with per-row regexp slug computation on every request
**Status:** • unverified · _Unindexable full-table scan on read path_  
**Location:** `trr_backend/repositories/admin_show_reads.py : 2027-2118 (resolve_show_slug), same pattern at 2110+ (search_global) and get_show_detail`  

resolve_show_slug computes a derived slug for EVERY row in core.shows on each call via a CTE (`FROM core.shows AS s` applying nested regexp_replace per row in SHOW_SLUG_SQL) plus a window function `COUNT(*) OVER (PARTITION BY effective_slug)`, then filters by the requested slug. Because the match column is a runtime-computed expression, no index can be used — it is always a sequential scan + per-row regexp over the whole shows table. The function loops over slug candidates (_build_show_slug_candidates, bounded to ~2: with/without leading 'the-') and breaks on first hit, so worst case is 2 full-table CTE scans per request. The identical computed-slug CTE pattern appears in search_global and get_show_detail. core.shows is presumably moderate in size, but this is on user-facing show-page resolution and recomputes the entire table's slugs on every request with no caching.

**Fix:** Materialize the canonical/effective slug as a stored, indexed column on core.shows (populated via trigger or a generated column) so lookups become an index seek, or maintain a slug->show_id mapping table. Alternatively cache resolve_show_slug results (slug is stable) with a short TTL. Avoid recomputing slugs for the full table on every read.

**Evidence:**
```
L2032: for base_slug in _build_show_slug_candidates(raw_base):  L2034: rows = pg.fetch_all(f""" WITH shows_with_slug AS ( SELECT s.id::text AS id, ..., {SHOW_SLUG_SQL} AS computed_slug, COALESCE(... {SHOW_SLUG_SQL}) AS effective_slug FROM core.shows AS s ) SELECT ..., COUNT(*) OVER (PARTITION BY s.effective_slug) ... FROM shows_with_slug AS s WHERE s.effective_slug = %s OR s.computed_slug = %s OR EXISTS (...) """)
```


---

#### 6. [Medium] Heavy inline social-ingest runs occupy shared anyio threadpool via FastAPI BackgroundTasks (dev/local-gated)
**Status:** • unverified · _Synchronous heavy work on shared worker resources_  
**Location:** `api/routers/socials/__init__.py : 1755-1756, 3208-3271, 494-523 (_execute_with_timeout), 489-491 (_run_admin_repo_call)`  

When the queue is not enabled (queue_enabled False), season/instagram ingest is executed via background_tasks.add_task(execute_run, ...) (L1756) and background_tasks.add_task(_run_sync) (L3271). These are SYNCHRONOUS, long-running functions (real scraping/ingest; the inline timeout is configurable up to 7200s, L485). FastAPI runs sync background-task callables in the shared anyio threadpool (default 40 threads) — the same pool that backs every run_in_threadpool call used by sync route handlers (the codebase correctly routes sync repo work through run_in_threadpool via _run_admin_repo_call, L489-491). A few concurrent inline ingest runs can therefore pin threadpool threads for minutes and starve unrelated sync endpoints. This is well-gated: the inline path is only reachable when not is_remote_job_plane_enabled() and (dev/local or allow_inline_dev_fallback) (L1684-1722), and in production with TRR_JOB_PLANE_MODE=remote it returns 503 instead. The confirmed lead 'heavy work runs sync in-process on fallback' is real but scoped to dev/local/non-enforced environments, not the enforced production runtime.

**Fix:** Keep inline execution strictly dev-only (already mostly enforced). For any shared/staging environment, run inline ingest in a dedicated executor/process rather than the default request threadpool, or cap the number of concurrent inline runs, so background ingest cannot exhaust the threads serving interactive endpoints. Document that allow_inline_dev_fallback must never be enabled on shared deployments.

**Evidence:**
```
L1755: if not queue_enabled: background_tasks.add_task(execute_run, run_id, worker_id="api-background:instagram", platform="instagram")  | L3271: background_tasks.add_task(_run_sync)  | L3211: timeout = _inline_execution_timeout_seconds()  | L485: maximum=7200  | gate L1692: if request.allow_inline_dev_fallback and _is_local_or_dev_runtime() and not remote_plane_enforced:
```


---

#### 7. [Low] InMemoryBroker fan-out and per-run status update loop are sequential (minor)
**Status:** • unverified · _Serial iteration_  
**Location:** `api/realtime/broker.py : 110-117 (InMemoryBroker.publish); also dispatch_runtime.py:638-641 (_mark_claimed_runs_running)`  

Two small serial loops. (1) InMemoryBroker.publish awaits each subscriber callback one-at-a-time (L113-117) rather than via asyncio.gather; for a room with many WebSocket subscribers a slow callback blocks delivery to the rest. The in-memory broker is explicitly the single-instance/dev fallback (RedisBroker is used when REDIS_URL is set), so production impact is limited. (2) _mark_claimed_runs_running issues one _set_run_status UPDATE per distinct run_id in a loop (L640-641); since a claim batch typically shares one run_id this is near-constant, but a multi-run claim batch produces one round-trip per run. Note the related Redis KEYS concern (get_keys_by_pattern) is NOT live: grep found no callers of get_keys_by_pattern anywhere in api/ or trr_backend/.

**Fix:** For InMemoryBroker.publish, dispatch callbacks with asyncio.gather(*[cb(event) for cb in subscribers], return_exceptions=True) so one slow/erroring subscriber does not delay others. For _mark_claimed_runs_running, collapse to a single `update ... where run_id = any(%s)` when more than one run_id is present. Both are low priority.

**Evidence:**
```
broker.py L112: subscribers = list(self._subscribers.get(room, {}).values())  L113: for callback in subscribers: L115: await callback(event)  | dispatch_runtime.py L640: for run_id in run_ids: L641: legacy._set_run_status(run_id, "running")
```


---

## Performance — App (web)  (`app-perf`)

**Summary.** The TRR-APP web app has a few high-impact, structural performance problems concentrated in the admin surface. The single biggest issue: the 804KB / 23k-line generated API-reference inventory is imported transitively from a "use client" component, so the entire dataset is serialized into the client JS bundle for that route. More broadly, the heaviest pages (showId, personId) are giant full-client monoliths (PersonPageClient.tsx is 485KB with 117 useState / 39 useEffect / 20 fetch) that ship no server-rendered data and have no loading.tsx or Suspense boundaries, producing a blank screen followed by a client-side fetch waterfall. Caching is effectively disabled app-wide (cache:'no-store' appears 183x; force-cache once; no React Query/SWR), and next.config.ts lacks optimizePackageImports for radix-ui/lucide-react.

<details><summary>Coverage / blind spots</summary>

READ IN FULL: next.config.ts, vercel.json, both cron routes (episode-progression, create-survey-runs), src/lib/server/trr-api/backend.ts, src/app/admin/api-references/page.tsx, AdminApiReferencesLibraryContent.tsx (head + grep), catalog.ts (head). SAMPLED via head/tail/grep (per monolith guidance): generated/inventory.ts (804KB), [showId]/page.tsx (16.9k lines), PersonPageClient.tsx (485KB), reddit-sources-manager.tsx, season-social-analytics-section.tsx, postgres.ts (pool config). MEASURED: file sizes, hook counts (useState/useEffect/useMemo/useCallback), fetch counts, cache directive counts, Image/sizes usage, Promise.all counts, Suspense/loading.tsx presence, package import styles. DELIBERATELY SKIPPED (blind spots): actual runtime bundle analysis (no `next build` / @next/bundle-analyzer run — bundle-inclusion claims are inferred from the module graph + "use client" boundaries, which is reliable for RSC but not byte-measured); the games routes (realitease/bravodle play pages ~2k lines each) beyond confirming they import firebase client-side; design-docs component tree; the backend repository SQL itself (out of area — App only); WeekDetailPageView.tsx and SocialAccountProfilePage.tsx internals beyond size. I did not run Lighthouse or Chrome DevTools traces.

</details>

#### 1. [High] 804KB generated API-reference inventory is bundled into client JS via a "use client" import chain
**Status:** ✅ verified (high confidence) · _Bundle size / code-splitting_  
**Location:** `src/lib/admin/api-references/generated/inventory.ts : 1-23299 (imported at catalog.ts:1; consumed at AdminApiReferencesLibraryContent.tsx:5)`  

GENERATED_ADMIN_API_REFERENCE_INVENTORY (804KB / 23,299 lines, 560 nodes) is exported from inventory.ts, imported by catalog.ts (no server-only directive), which is imported by AdminApiReferencesLibraryContent.tsx — a component whose first line is "use client". In the Next.js App Router, any module pulled into a client component graph is bundled into the browser JS for that route. So the full 804KB JSON literal ships to the client for /admin/api-references, even though the page itself (page.tsx) is a Server Component that renders the client component with no props. The data is static at build time and the graph build (buildInventoryGraph) and filtering are pure functions that could run on the server. Impact: ~800KB of extra parse+download (likely 150-250KB gzipped) on this route, inflating TTI; the JSON is also re-parsed by JS engine on every load. It additionally bloats typecheck/editor latency for anyone touching the api-references tree.

**Fix:** Make page.tsx (already a Server Component) compute the inventory-derived data server-side and pass only the needed, already-filtered/serialized slices into a smaller client component, OR add `import 'server-only'` to catalog.ts and move buildInventoryGraph + filtering to the server, passing graph results down as props. Alternatively, fetch the inventory via a route handler with `cache: 'force-cache'` and lazy-load it only when the references page mounts. The current AdminApiReferencesLibraryContent already accepts an optional `inventory?` prop (line 24), so the cleanest fix is to compute on the server and pass it in, and drop the module-level import from the client component.

**Evidence:**
```
AdminApiReferencesLibraryContent.tsx:1 `"use client";` then line 5 `ADMIN_API_REFERENCE_INVENTORY` from catalog; catalog.ts:1 `import { GENERATED_ADMIN_API_REFERENCE_INVENTORY } from "@/lib/admin/api-references/generated/inventory";` (no server-only); `du -h inventory.ts` => 804K; summary totalNodes:560. page.tsx:3-4 `return <AdminApiReferencesLibraryContent />;` (Server Component, passes no props).
```


---

#### 2. [High] Heaviest admin routes are full-client monoliths with no SSR data, no loading.tsx, and no Suspense
**Status:** ✅ verified (high confidence) · _Server vs Client Components / request waterfall_  
**Location:** `src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx : 1 ("use client"); server wrapper [[...personTab]]/page.tsx:1 `export { default } from "../PersonPageClient"``  

PersonPageClient.tsx is 485KB with 117 useState, 39 useEffect, 20 fetch() calls, 61 useMemo, 69 useCallback. Its server route page is literally `export { default } from "../PersonPageClient"` — there is no server-side data fetch, no generateMetadata-time data, and no streamed HTML for content. The sibling [showId]/page.tsx is the same shape: "use client" at line 1, 51 useEffect, all data loaded after mount. Neither route tree has a loading.tsx (find returned none) nor any <Suspense> (grep count 0). Result: the browser downloads a very large client bundle, hydrates, and only then fires dozens of effect-driven fetches. The user sees a blank/guard screen until JS parses and the first fetch round-trips resolve. With 39 effects in PersonPageClient and multi-phase dependencies, this is a multi-stage client waterfall (only partially mitigated by 5 Promise.all batches). This is the dominant LCP/TTI cost on the two most-used admin detail pages.

**Fix:** Move the initial above-the-fold data load (person identity, core show data) into the Server Component page so it streams as RSC payload, and hydrate the interactive client shell with that data as props (eliminating the first fetch round-trip and the blank screen). Add loading.tsx for /admin/trr-shows/[showId] and /people/[personId] to stream a skeleton immediately. Split PersonPageClient into per-tab dynamic() chunks (the showId page already does this for its tabs at page.tsx:917-932 via next/dynamic — apply the same pattern to the person tabs so only the active tab's code/effects load).

**Evidence:**
```
PersonPageClient.tsx:1 `"use client";`; counts: useState=117, useEffect=39, fetch(=20; [[...personTab]]/page.tsx:1 `export { default } from "../PersonPageClient";`; [showId]/page.tsx:1 `"use client";`, useEffect=51; `find src/app/admin/trr-shows -name loading.tsx` => none; `grep -c <Suspense` in both files => 0.
```


---

#### 3. [Medium] App-wide caching is effectively disabled: 183 `cache: 'no-store'` fetches, no data-cache or React Query layer
**Status:** • unverified · _Data fetching / caching strategy_  
**Location:** `src/app (cross-cutting; trr-api proxy routes under src/app/api/admin) : 183 matches for `cache: 'no-store'` vs 1 for `force-cache`; 3 `revalidate``  

Across src, `cache: 'no-store'` appears 183 times while `cache: 'force-cache'` appears once and `revalidate` 3 times. There is no client data-cache library: react-query/@tanstack/swr appear in the codebase only as detection strings inside the api-references generator (generator.ts:63), not as runtime dependencies. So every admin proxy fetch and every client fetch hits the backend (which then hits Postgres) on every navigation/poll with zero memoization or request de-duplication. Combined with the client-waterfall pages above, navigating between admin tabs re-fetches the same backend data repeatedly. 98 admin proxy route files call getBackendApiUrl/fetchBackend, fanning out to the backend with no shared cache. While `no-store` is correct for mutations and truly live data, blanket use on read endpoints (lists, identity, config) forgoes Next's Data Cache and any dedupe.

**Fix:** Audit the 183 `no-store` sites and switch read-only GET proxies for slow-changing data (show/person identity, config, networks/streaming overrides) to `next: { revalidate: N }` or tag-based revalidation. Introduce a client cache (TanStack Query or SWR) for the big client pages so repeated tab switches reuse in-flight/recent responses instead of re-fetching. Even a small staleTime on identity/list queries would cut redundant backend+Postgres load substantially.

**Evidence:**
```
`grep -rc cache:'no-store'` => 183; `force-cache` => 1; `export const revalidate|revalidate:` => 3; `grep react-query|@tanstack|useSWR` in src returns only generator.ts:63 `const UI_QUERY_HOOKS = ["useSWR", "useQuery", "useInfiniteQuery"];` (a detection list, not usage); 98 admin route files reference getBackendApiUrl/fetchBackend.
```


---

#### 4. [Medium] next.config.ts missing optimizePackageImports for radix-ui barrel and lucide-react
**Status:** • unverified · _Bundle size / tree-shaking_  
**Location:** `src/app/admin/.../next.config.ts is at apps/web/next.config.ts : 54-63 (experimental block has no optimizePackageImports)`  

next.config.ts sets `experimental` only conditionally for build CPU counts (lines 58-63) and never configures `optimizePackageImports` or `modularizeImports`. The app imports the unified `radix-ui` package via barrel destructuring (e.g. `import { Tooltip as TooltipPrimitive } from "radix-ui"` in ui/tooltip.tsx:4, plus popover/progress/avatar/dialog — 8 files) and `lucide-react` (10 files). Both the unified radix-ui meta-package and lucide-react are large barrels that, without optimizePackageImports, can pull substantial dead code into client chunks (lucide-react in particular ships thousands of icon modules). This is a low-effort config win that reduces per-route client JS across the whole admin UI.

**Fix:** Add `experimental.optimizePackageImports: ['lucide-react', 'radix-ui', 'framer-motion', '@dnd-kit/core', '@dnd-kit/sortable']` to next.config.ts (merging with the existing conditional experimental block rather than overwriting it). Verify with `next build` bundle output before/after. Next 16 supports this and applies an automatic barrel-optimization, but explicit listing guarantees coverage for the unified radix-ui package.

**Evidence:**
```
next.config.ts:58-63 experimental only sets `cpus`/`staticGenerationMaxConcurrency`; no `optimizePackageImports`. ui/tooltip.tsx:4 `import { Tooltip as TooltipPrimitive } from "radix-ui"`; 8 files import from "radix-ui", 10 from "lucide-react".
```


---

#### 5. [Low] next/image: optimization disabled in dev and only 50% of <Image> usages set `sizes`
**Status:** • unverified · _Image optimization_  
**Location:** `src/app/.../next.config.ts (apps/web/next.config.ts) : 82-109 (images config)`  

Two sub-issues. (1) `images.unoptimized: IS_DEV` (line 86) globally disables image optimization in development to work around a reported /_next/image hang; this is a documented dev-only workaround but means devs never see real optimized-image behavior and any image-perf regressions only surface in prod. (2) Only 56 of 112 `<Image>` usages pass a `sizes` prop. For responsive/`fill` images without `sizes`, Next defaults to 100vw, causing the browser to request and the optimizer to generate larger-than-needed variants (wasted bandwidth + slower LCP on image-heavy admin galleries like ImageLightbox.tsx). remotePatterns (5 hosts) and lack of explicit `formats`/`deviceSizes` are acceptable (Next defaults include AVIF/WebP negotiation), so the main lever is `sizes` coverage.

**Fix:** Add explicit `sizes` to the ~56 <Image> usages that lack it, especially gallery/thumbnail grids and any `fill` images (ImageLightbox.tsx, person/show asset grids), so the optimizer serves appropriately sized variants. Optionally set `images.formats: ['image/avif','image/webp']` explicitly for clarity. Keep the dev `unoptimized` workaround but track the upstream /_next/image hang so it can be removed.

**Evidence:**
```
next.config.ts:86 `unoptimized: IS_DEV`; `grep -rc sizes=` => 56 vs `grep -rc <Image` => 112; ImageLightbox.tsx uses multiple <Image> (lines 1440, 2220, 2392, 2498).
```


---

#### 6. [Low] Episode-progression cron progresses surveys sequentially in a loop (await inside for)
**Status:** • unverified · _Cron / serial I/O_  
**Location:** `src/app/api/cron/episode-progression/route.ts : 44-104 (for-loop with `await progressToNextEpisode(survey.key)` at line 87)`  

The hourly episode-progression cron iterates surveys with auto-progress and calls `await progressToNextEpisode(survey.key)` one-at-a-time inside a `for` loop (line 87). Each call is a DB round-trip; total latency scales linearly with the number of auto-progress surveys. On Vercel, a long-running cron can approach the function timeout as the survey count grows, and serial execution wastes the available concurrency. The set is currently bounded (only surveys with auto-progress + within the 1-hour air window actually progress), so impact is low today, but it will degrade as more shows enable auto-progression. The cron correctly exports GET (line 123) which Vercel Cron invokes, so there is no method-mismatch issue.

**Fix:** Batch the per-survey progression with a bounded-concurrency Promise.all (e.g. process in chunks of 5-10 via Promise.allSettled) so independent surveys progress in parallel, and use allSettled so one failing survey doesn't abort the batch. Add a guard/limit and structured logging of duration to catch timeout risk early.

**Evidence:**
```
route.ts:44 `for (const survey of surveys) {` ... line 87 `const nextEpisode = await progressToNextEpisode(survey.key);` inside the loop; line 123 `export async function GET(request: NextRequest) { return POST(request); }` confirms Vercel-triggerable.
```


---
