# DebugPro Bug Report: Instagram Post Backfill Browser Run

Date: 2026-06-09
Scope: `@Browser` runtime control, TRR Instagram Post Backfill admin pipeline, startup/runtime evidence
Target page: `http://admin.localhost:3000/social/instagram/thetraitorsus`
Status: blocked for true `@Browser` proof; partial pipeline evidence collected through fallback runtime

## Remediation Update

Updated: 2026-06-09

- Browser transport: global Codex MCP config now enables `chrome-devtools`; `make chrome-devtools-mcp-status` passes config/wrapper/smoke checks. `make codex-browser-transport-reset` cleaned orphan browser-control process trees, but the active in-app Browser `node_repl` session still returns `Transport closed`, so the already-open Browser pane requires a Codex Desktop/session refresh before true `@Browser` control is restored.
- Startup preflight: `TRR-APP/apps/web/package.json` now declares `ajv` and `yaml` so the design-docs-agent package validator can resolve both modules from the app package context.
- Auth wording: the Instagram pipeline truth panel now treats blocked/unverified Modal posts auth as `Action needed` and separates post/details, local cookie, and comments auth status.
- Modal runtime ownership: route execution now blocks implicit local inline fallback when the requested catalog/comments lane requires the Modal executor. The explicit `execution_preference=prefer_local_inline` operator override remains intentional.
- Cancel messaging: catalog cancel responses now return cancelled-job and claimed-job counts plus a best-effort message; the UI keeps that message visible even when local reconciliation succeeds.
- Runtime follow-through: `make preflight-hybrid` passed after runtime reconciliation and redeployed Modal (`modal=redeployed`).

## Executive Summary

`@Browser` could not control the already-open in-app browser. The Browser sidebar existed and Codex Desktop reported Browser availability, but tool calls failed at the MCP transport boundary before any page interaction could occur.

The Instagram Post Backfill pipeline was still partially exercised through a fallback browser runtime after the requested Browser path failed. That fallback launched one diagnostic posts-only backfill run. The run was cancelled and now reports `run_status=cancelled`.

## Primary Blocker: Browser Tool Transport Closed

Severity: high
Area: Codex Browser plugin / MCP runtime ownership

### Observed Behavior

- In-app browser was open at `http://localhost:3000/`.
- Browser setup was attempted through the required Browser plugin path:
  - imported `/Users/thomashulihan/.codex/plugins/cache/openai-bundled/browser/26.602.71036/scripts/browser-client.mjs`
  - called `setupBrowserRuntime({ globals: globalThis })`
  - attempted `agent.browsers.get("iab")`
- The call failed immediately:
  - `tool call failed for node_repl/js`
  - `Caused by: Transport closed`
- Adjacent DevTools bridge also failed:
  - `chrome-devtools-isolated/list_pages`
  - `Caused by: Transport closed`
- A previous Browser reset did not repair the active thread:
  - `make codex-browser-transport-reset`
  - reset completed and recommended refreshing/restarting Codex if transport stayed closed
  - retry still returned `Transport closed`

### Runtime Evidence

`make status-json` reported the workspace active and Browser plugin registry as healthy:

- `run_state=active`
- app health: `ok`
- backend health: `ok`
- plugin registry: `browser status=ok`
- browser label: `recoverable_auto_launch; live_mcp=chrome-devtools:present`

Codex Desktop logs contradicted that health state with runtime errors:

- repeated `screen recording permission is required but not granted`
- repeated `Item not found in turn state itemId=call_*`
- Browser sidebar lifecycle was present:
  - `IAB_LIFECYCLE received browser sidebar owner sync`
  - `browser_use_availability_resolved available=true browserPane=true`
- Result: Browser is visible/registered, but MCP control is not usable from this conversation.

### Expected Behavior

When the in-app browser is open and Browser is reported available, `@Browser` should attach to the selected tab or return a recoverable, user-actionable error that matches the real blocker.

### Actual Behavior

The automation bridge terminates with `Transport closed` before attaching to the page, while status surfaces continue to report Browser as available/ok.

## Startup Blocker: `make dev-hybrid` Fails Preflight

Severity: high
Area: TRR workspace startup

The TRR-required browser startup target was attempted first:

```text
make dev-hybrid
```

It failed during design-docs-agent package validation:

```text
Error: Cannot find module 'ajv/dist/2020'
Require stack:
- /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/package.json
```

The validator also imports `yaml` from the app package context. `TRR-APP/apps/web/package.json` and `TRR-APP/package.json` do not currently provide the expected `ajv`/`yaml` resolution path.

Impact: the documented TRR browser startup path blocks before services start, even though Instagram auth freshness and workspace doctor pass.

## Pipeline Findings From Fallback Run

Run ID: `988f22c8-f762-4ae1-aa25-5ef9dc67d029`
Job ID: `af37357c-1767-4be0-9600-96eb0a632c09`
Launch group: `f594a018-c094-4112-98f6-ad1ce15baed6`
Selected task: `post_details`
Final status: `cancelled`

### 1. Auth Messaging Is Contradictory

Severity: medium

The page showed both:

- `Modal posts auth not verified`
- `Instagram posts transport blocked`

and also:

- `AUTH STATE Usable`
- `No auth action is needed right now`
- `Local cookies healthy (instagram_cookies.json)`

Impact: an operator cannot tell whether it is safe to run posts backfill. The UI reports both a usable auth state and a blocked/unknown Modal posts state.

### 2. Hybrid/Remote Mode Fell Back To Local Background Runtime

Severity: high

Workspace status reported remote Modal dispatch active:

- `WORKSPACE_DEV_MODE=hybrid`
- `WORKSPACE_TRR_REMOTE_EXECUTOR=modal`
- `WORKSPACE_TRR_REMOTE_SOCIAL_POSTS=1`
- remote execution summary: `modal_dispatch_active`

But the run progress reported:

- `runtime_version.execution_backend=local`
- `runtime_version.label=local:api-background:catalog:instagram`
- `required_runtime_version.execution_backend=modal`
- `required_runtime_version.modal_function=run_social_posts_job`
- `runtime_version_pin_mismatch=true`
- `runtime_version_drift=true`

Impact: a run launched from a Modal-backed hybrid workspace can still execute through local API background work. That undermines the Modal runtime contract and makes operator-facing auth/runtime state ambiguous.

### 3. Cancel Is Not Immediate Enough To Avoid Work

Severity: medium

The diagnostic run was cancelled at `2026-06-09T18:21:05.999715+00:00`, but the cancelled job still reports:

- `scraped_count=88`
- `saved_count=88`
- `completed_posts=88`
- recent log: `shared account scrape cancelled - scraped 88 - saved 88`

Impact: cancel requests can leave meaningful side effects after a run has already started. This may be expected for cooperative cancellation, but the UI should communicate that cancellation is best-effort once a worker has claimed work.

### 4. Progress State Is Misleading At Launch

Severity: medium

Immediately after launch, the UI showed:

- `Run 988f22c8 - Discovering`
- `2%`
- `0 / 456 posts checked`
- `0 / 1 active workers`
- `0 running - 0 queued`

Impact: the run looks both active and idle. The operator cannot distinguish "starting", "waiting for Modal", "blocked", and "no worker claimed yet".

### 5. DB Pool Pressure Appeared During Launch

Severity: medium

Backend log during the run:

```text
[db-pool] acquire_failed label=fetch_one attempt=0 acquire_attempt=0 error=PoolError in_use=1 available=0
```

Later, a details refresh batch held a DB connection for about 16 seconds:

```text
label=instagram_details_refresh_batch held_ms=15996.5
```

Impact: the local backend ran with a very small available pool and showed pressure during admin run orchestration/progress activity.

### 6. Long-Lived Status Stream Prevents Network-Idle Browser Checks

Severity: low

The page held the live status stream open:

```text
GET /api/admin/trr-api/social/ingest/live-status/stream 200 in 34.0s
```

Earlier browser fallback waits for network idle timed out while the page was otherwise usable.

Impact: tests that use `networkidle` will look stalled on this admin page. Browser tests should wait on visible UI state or targeted API responses instead.

## Evidence Artifacts

- Initial fallback screenshot: `.logs/workspace/instagram-backfill-initial.png`
- Post-launch fallback screenshot: `.logs/workspace/instagram-backfill-after-start.png`
- App log: `.logs/workspace/trr-app.log`
- Backend log: `.logs/workspace/trr-backend.log`
- Startup preflight log: `.logs/workspace/dev-hybrid-background.log`
- Codex Desktop log: `/Users/thomashulihan/Library/Logs/com.openai.codex/2026/06/09/codex-desktop-ed0e1e56-238d-423b-b16b-cfc504b7a40e-97897-t0-i1-173449-0.log`

## Reproduction Steps

1. Open the in-app browser to `http://localhost:3000/`.
2. Attempt Browser setup through the Browser plugin runtime.
3. Observe `Transport closed` before the Browser can attach to the selected tab.
4. Run `make status-json`.
5. Observe Browser reported as `status=ok` despite the failed tool transport.
6. Inspect Codex Desktop logs for screen-recording permission errors and turn-state item errors.

## Cleanup Performed

- Cancelled run `988f22c8-f762-4ae1-aa25-5ef9dc67d029`.
- Cancel endpoint returned `status=cancelled`, `accepted=true`.
- Progress endpoint confirmed `run_status=cancelled`.

## Open Questions

- Should Browser availability checks fail closed when the active MCP call path returns `Transport closed`?
- Is missing macOS Screen Recording permission expected to break only screenshot/vision, or can it break the Browser MCP transport entirely?
- Why does hybrid Modal mode allow a local API background runtime to satisfy a run that records `required_runtime_version=modal`?
- Should the UI block `Start Backfill` when Modal posts auth is not verified, even if local cookies are healthy?
