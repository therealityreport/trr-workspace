# Fixes And Patch Directions

This file records implementation directions only. No fixes were applied by this review.

## CR-001 - Admin Dev Bypass Host Trust

Preferred fix:

```ts
function isDevAdminBypassEnabled(_request: NextRequest): boolean {
  const explicitBypass = parseOptionalBoolean(process.env.TRR_DEV_ADMIN_BYPASS);
  const bypassEnabled = explicitBypass ?? process.env.NODE_ENV === "development";
  if (!bypassEnabled) return false;
  return process.env.NODE_ENV === "development" && process.env.TRR_DEV_ADMIN_TRUSTED_LOCAL === "1";
}
```

Also avoid accepting `request.headers.get("host")` as proof of locality in `isRequestHostAllowedForAdmin`.

## HI-001 - Debug-Log Kill Switch

```diff
-function remoteDebugLoggingEnabled(request: NextRequest): boolean {
-  const hostname = request.nextUrl.hostname || new URL(request.url).hostname;
-  if (isLocalDebugHost(hostname)) {
-    return true;
-  }
-  return envFlag("TRR_REMOTE_DEBUG_LOG_ENABLED");
+function remoteDebugLoggingEnabled(_request: NextRequest): boolean {
+  if (process.env.NODE_ENV !== "production") {
+    return true;
+  }
+  return envFlag("TRR_REMOTE_DEBUG_LOG_ENABLED");
 }
```

Add a production-mode spoofed-host test where a remote URL plus `Host: localhost` still returns `404` unless `TRR_REMOTE_DEBUG_LOG_ENABLED=1`.

## HI-002 - Modal Maintenance Owner

Choose one:

- restore Modal singleton schedules as the default owner, or
- enable one API/dedicated-worker owner through runtime config and enforce a lease, or
- fail startup when both owners are disabled in a deploy profile that requires queue maintenance.

Minimum guard:

```py
if not modal_cron_owner_enabled and not api_scheduler_enabled:
    raise RuntimeError("Modal maintenance has no active owner")
```

## HI-003 - Modal Billing Guardrail Source Env

Guard the source used by named-secret rendering:

```bash
source_env="${TRR_MODAL_SOURCE_ENV:-$ROOT/TRR-Backend/.env}"
if [[ -f "$source_env" ]]; then
  source_values="$(python3 scripts/read_env_values.py "$source_env")"
  # check TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED,
  # TRR_MODAL_API_MIN_CONTAINERS, TRR_MODAL_ADMIN_KEEP_WARM
fi
```

In `prepare_named_secrets.py`, force safe defaults unless a break-glass flag is present:

```py
if not _truthy(os.getenv("WORKSPACE_ALLOW_MODAL_ALWAYS_ON_BILLING")):
    merged["TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED"] = "0"
    merged["TRR_MODAL_API_MIN_CONTAINERS"] = "0"
    merged["TRR_MODAL_ADMIN_KEEP_WARM"] = "0"
```

## HI-004 - Comments Progress GET

```diff
         lambda: get_social_account_comments_scrape_run_progress(
             platform=platform,
             account_handle=account_handle,
             run_id=str(run_id),
-            auto_rebalance_slow_shards=True,
+            auto_rebalance_slow_shards=False,
         ),
```

If operator-triggered rebalance is required, add a dedicated `POST /comments/runs/{run_id}/rebalance-slow-shards` route.

## HI-005 - Bravo Social Conflict Link

```diff
         if existing_owner:
             if str(existing_owner.get("person_id") or "") == person_id:
                 stats["canonical_existing"] += 1
             else:
                 stats["canonical_skipped_conflict"] += 1
+                continue
```

Alternative: write a `review_needed` link instead of an approved link. Add a conflict test asserting no approved link is written.

## HI-006 - Explicit Cookie Refresh

Backend route direction:

```diff
 class CookieRefreshRequest(BaseModel):
 ...
-    allow_cookie_refresh: bool = Field(default=False)
+    allow_cookie_refresh: bool = Field(default=True)
```

Frontend direction:

```diff
-allow_cookie_refresh: false,
+allow_cookie_refresh: refreshAction !== "instagram_auth_repair" || Boolean(options.confirmed),
```

Keep the stricter default for catalog auth-repair jobs.

## HI-007 - Supabase Survey RPC

Option A, keep public survey RPC:

```sql
ALTER FUNCTION surveys.submit_response(uuid, jsonb) SET search_path = surveys, auth, pg_temp;
REVOKE ALL ON FUNCTION surveys.submit_response(uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION surveys.submit_response(uuid, jsonb) TO anon, authenticated;
```

Then document why anonymous execution is intentional and validate every table access inside the function.

Option B, remove direct RPC exposure:

```sql
REVOKE EXECUTE ON FUNCTION surveys.submit_response(uuid, jsonb) FROM anon;
REVOKE EXECUTE ON FUNCTION surveys.submit_response(uuid, jsonb) FROM authenticated;
```

Move submission through a backend route or `SECURITY INVOKER` design.

## HI-008 - SocialBlade Error Normalization

```ts
function backendErrorMessage(data: unknown, fallback: string): string {
  if (typeof data === "object" && data !== null) {
    const detail = (data as { detail?: unknown }).detail;
    if (typeof detail === "string") return detail;
    if (typeof detail === "object" && detail !== null) {
      const message = (detail as { message?: unknown }).message;
      const code = (detail as { code?: unknown }).code;
      if (typeof message === "string" && message.trim()) return message;
      if (typeof code === "string" && code.trim()) return code;
    }
    const error = (data as { error?: unknown }).error;
    if (typeof error === "string" && error.trim()) return error;
  }
  return fallback;
}
```

Use this before returning proxy errors, or migrate to the shared admin proxy helper.

## HI-009 - `test-changed` False Green

```diff
 run_workspace_checks() {
   echo "[test-changed] Workspace changes detected; running workspace policy and contract checks."
   bash "$ROOT/scripts/check-policy.sh"
   bash "$ROOT/scripts/check-workspace-contract.sh"
+  python3 -m pytest -q "$ROOT"/scripts/test_*.py
   env CHROME_DEVTOOLS_MCP_STATUS_MODE=summary bash "$ROOT/scripts/chrome-devtools-mcp-status.sh"
```

If the full glob is too broad, centralize an explicit list in one helper script and reuse it from `test.sh`, `test-fast.sh`, and `test-changed.sh`.

## ME-001 - Modal Truthy Parser

```diff
 is_truthy() {
-  case "${1:-}" in
-    1|true|TRUE|yes|YES|on|ON) return 0 ;;
+  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
+    1|true|yes|on) return 0 ;;
     *) return 1 ;;
   esac
 }
```

Add tests for `True`, `Yes`, and `On`.

## ME-002 - Auth Cooldowns

Only write cooldowns for auth and checkpoint failures:

```py
COOLDOWN_FAILURE_REASONS = {
    "manual_checkpoint_required",
    "manual_auth_required",
    "refresh_failed",
}
```

Do not write cooldown for `modal_app_missing`, `missing_named_secrets`, `remote_probe_failed`, or `automated_cookie_refresh_disabled`.

## ME-003 - Bravo Proxy Attribution

Replace bare token forwarding:

```ts
const adminContext = await requireAdminContext(request);
const headers = buildInternalAdminHeaders(adminContext, {
  "Content-Type": "application/json",
});
```

Prefer `createAdminBackendProxyRoute` if streaming semantics allow it.

## ME-004 - SocialBlade Timeouts

Use a shared timeout wrapper:

```ts
const upstream = await timeoutSafeFetch(backendUrl, {
  method: "POST",
  headers,
  body,
  timeoutMs: 30000,
});
```

Return `504` with a readable message when timeout occurs.

## ME-005 - Root Script Test Coverage

Create one maintained script-test command:

```bash
python3 -m pytest -q \
  scripts/test_env_hygiene.py \
  scripts/test_instagram_auth_freshness.py \
  scripts/test_modal_billing_guardrail.py \
  scripts/test_workspace_app_env_projection.py \
  scripts/test_preflight*.py \
  scripts/test_runtime*.py
```

Then call the same command from full, fast, and changed-file lanes.

## ME-006 - Adjacent Screenalytics Env

Remove default scan:

```diff
 "local_secret_adapters": [
   "TRR-APP/apps/web/.env.local",
   "TRR-APP/apps/web/.env.production.local",
-  "TRR-Backend/.env",
-  "screenalytics/.env"
+  "TRR-Backend/.env"
 ]
```

Add an opt-in variable such as `WORKSPACE_ENV_HYGIENE_INCLUDE_ADJACENT=1`.

## ME-007 - Env-Configured Instagram Cookies

```py
def cookie_file_candidates() -> tuple[Path, ...]:
    env_paths = [
        os.getenv("SOCIAL_INSTAGRAM_COOKIES_FILE"),
        os.getenv("INSTAGRAM_COOKIES_FILE"),
    ]
    candidates = [Path(p).expanduser() for p in env_paths if p]
    candidates.extend(DEFAULT_COOKIE_FILES)
    return tuple(dict.fromkeys(candidates))
```

## ME-008 - Safe Turbo Build

```diff
-"build:turbo": "next build --turbopack",
+"build:turbo": "node scripts/safe-next-build.mjs --turbopack",
```

Update `safe-next-build.mjs` to pass through the selected build mode.

## ME-009 - Supabase Advisor Follow-Up

Create a dated migration/review pair:

- `docs/workspace/supabase-advisor-recheck-2026-05-28.md`
- migration for survey RPC grants/search path if owner decision is made
- migration for `admin.set_updated_at` and `firebase_surveys.set_updated_at`
- separate owner review before dropping unused indexes

## LO-001 - `dev-hybrid` Caps Docs

Update `docs/workspace/dev-commands.md`:

```diff
-comments `3`, Instagram posts/comments platform cap `3`
+comments `8`, Instagram posts/comments platform cap `8`
```

## LO-002 - Draft Plan Validation Command

```diff
 cd /Users/thomashulihan/Projects/TRR/TRR-APP
-pnpm -C TRR-APP/apps/web run validate:quick
+pnpm -C apps/web run validate:quick
```
