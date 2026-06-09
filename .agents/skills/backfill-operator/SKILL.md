---
name: backfill-operator
description: Workspace-local canonical operator for running, launching, monitoring, pacing, and troubleshooting Instagram Backfill Posts / catalog runs on the dev-hybrid lane. Use when starting or operating a backfill, watching proxy pacing, tuning posts/comments/media concurrency, or diagnosing cursor errors, 401/403, checkpoint blocks, and auth/proxy issues. Triggers: backfill, Backfill Posts, catalog run, Instagram posts, post discovery, dev-hybrid, social-safe, cursor errors, instagram_graphql_cursor_unauthorized, instagram_graphql_cursor_forbidden, 401, 403, checkpoint, checkpoint_required, auth repair, proxy pacing, proxy_pacing, lock_wait_ms.
---
Use this workspace-local skill to operate an Instagram Backfill Posts / catalog run end to end: preflight auth, launch the dev-hybrid lane, watch pacing and stop rules, and escalate concurrency only when health is clean. Source of truth: `/Users/thomashulihan/Projects/TRR/docs/workspace/instagram-backfill-runbook.md`.

## When to use
1. Starting, launching, or resuming an Instagram Backfill Posts / catalog (post discovery) run.
2. Watching, pacing, or tuning concurrency for an in-flight social backfill.
3. Triaging cursor errors, 401/403, checkpoint blocks, or proxy/auth failures during a run.

## When not to use
1. Local-only app/backend work with no Modal/remote social dispatch (use `make dev`).
2. General Modal platform setup unrelated to the Instagram backfill lane.
3. Schema/migration or non-social backend work.

## Startup lane (Backfill Posts)
Run from the workspace root:
```bash
cd /Users/thomashulihan/Projects/TRR && make dev-hybrid
```
`make dev-hybrid` is the Backfill Posts lane (local app/backend on the direct DB lane, Modal/remote social workers on the session/pooler lane). `make dev-hybrid-social-safe` is a compatibility alias for the same path.

Social-safe knobs applied by the lane:
```bash
WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=1 \
WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=8 \
WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=8 \
WORKSPACE_TRR_REMOTE_SOCIAL_POSTS=1 \
WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS=8 \
SOCIAL_POSTS_COMMENTS_PLATFORM_CAP_INSTAGRAM=8 \
SOCIAL_PLATFORM_CAP_PER_ACCOUNT_SCALING=false \
WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR=1 \
WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR=1 \
make dev-hybrid
```

## Concurrency rules
1. Keep `WORKSPACE_TRR_REMOTE_SOCIAL_POSTS=1` for full-history or single-account catalog/post discovery. Hold it at `1` unless a prior run is clean and account/session health is known good.
2. Raise comments/media before posts: increase `WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS` when saved post targets exist and comment jobs drain without auth/cursor errors; increase `WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR` when media-mirror jobs are pending but post discovery is already stable.
3. Set `SOCIAL_INSTAGRAM_COMMENTS_PER_POST_CONCURRENCY=4` only for a controlled comments validation run, and only after clean auth, proxy, and active-job checks. Leave it at `1` for default serial fetch/persist.
4. More posts workers increases cursor pressure and can make the run slower if Instagram starts rejecting pages. Keep post discovery serialized.

## Stop rules (pause new runs + inspect)
Pause new runs and inspect the current run before raising any cap when any of these appear:
1. `401`
2. `403`
3. `checkpoint` or `checkpoint_required`
4. `instagram_graphql_cursor_unauthorized`
5. `instagram_graphql_cursor_forbidden`
6. repeated initial GraphQL failures

Treat `checkpoint` / `checkpoint_required` as an account/session blocker. Proxy or Modal changes do NOT clear a checkpoint by themselves — it needs account/session repair.

## Posts pacing metrics (`proxy_pacing` in fetcher metadata)
The Instagram posts fetcher separates reservation time from sleep time under `proxy_pacing`:
1. `lock_wait_ms` — time waiting to acquire the advisory/file lock.
2. `lock_held_ms` — time reserving the next request slot while the lock is held.
3. `scheduled_sleep_ms` — time slept after the lock was released.
4. `scheduled_at` — monotonic reserved request-start timestamp.
5. `reservation_lag_ms` — gap between reservation and the current request-start slot.

Healthy reserve-then-sleep behavior has low `lock_held_ms` even when `scheduled_sleep_ms` is high. Stop raising worker or per-post concurrency if `lock_wait_ms` climbs, auth failures appear, or request starts bunch around the same proxy/session key.

## Status and auth checks
```bash
make status
make instagram-backfill-preflight ACCOUNT_HANDLE=<handle>
make modal-instagram-auth-repair            # add DRY_RUN=1 to plan without applying
```
1. `make status` — workspace health and PID snapshot (local process health).
2. `make instagram-backfill-preflight ACCOUNT_HANDLE=<handle>` — Modal readiness plus separate posts-auth and comments-auth probes. Posts auth failure blocks Backfill Posts launch; comments-only failure blocks comments follow-up, not posts listing.
3. `make modal-instagram-auth-repair` — auth repair; use `DRY_RUN=1` first to plan the repair.

## Preferred run-watching tooling
1. Modal ops MCP (server `modal-ops`) — use `modal_readiness`, `probe_remote_auth`, `tail_logs`, `list_recent_runs`, `list_active_jobs`, `list_active_cooldowns`, and `backfill_health`.
2. Backfill Health is live through `modal-ops backfill_health`. The app route `/admin/social/backfill-health` is not wired in this slice; do not send operators there until the backend HTTP route and app proxy exist.
3. Smoke and benchmark helpers:
```bash
make instagram-posts-smoke ACCOUNT_HANDLE=<handle> MAX_PAGES=1
make instagram-posts-benchmark ACCOUNT_HANDLE=<handle> MODE=listing-only MAX_PAGES=3
```

## Operator flow
1. Preflight auth: `make status`, then `make instagram-backfill-preflight ACCOUNT_HANDLE=<handle>`. If posts auth is unhealthy, run `make modal-instagram-auth-repair DRY_RUN=1 ACCOUNT_HANDLE=<handle>` to plan, then repair before launching.
2. Launch: `cd /Users/thomashulihan/Projects/TRR && make dev-hybrid` with `WORKSPACE_TRR_REMOTE_SOCIAL_POSTS=1`.
3. Watch: track `proxy_pacing` (low `lock_held_ms`, watch `lock_wait_ms`) and the stop rules via `modal-ops backfill_health`, `list_active_jobs`, and `list_active_cooldowns`. On any stop-rule signal, pause new runs and inspect; treat checkpoint as an account/session blocker.
4. Escalate only when clean: raise comments/media first; set `SOCIAL_INSTAGRAM_COMMENTS_PER_POST_CONCURRENCY=4` for a controlled validation run only after clean auth/proxy/active-job checks. Keep `POSTS=1`.

## Completion contract
Return:
1. `lane_started` (dev-hybrid)
2. `posts_concurrency`
3. `auth_probe_result`
4. `pacing_health` (lock_wait_ms / lock_held_ms trend)
5. `stop_rules_triggered`
6. `concurrency_changes`
7. `residual_risk`
