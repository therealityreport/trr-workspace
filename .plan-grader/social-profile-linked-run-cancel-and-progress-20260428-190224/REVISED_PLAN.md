# Social Profile Linked Run Cancel And Progress Plan

Date: 2026-04-28
Status: revised by Plan Grader; ready for approval
Recommended executor after approval: `orchestrate-subagents`

## summary

Fix the Instagram social-profile admin page so run state, cancellation, and comment-count freshness come from bounded backend truth instead of the heavyweight profile summary. The current `@thetraitorsus` page has three linked failures:

1. Active catalog and comments lanes are not represented independently.
2. `Cancel Run` can appear to work locally but refresh can rehydrate the same or a linked lane as active.
3. `Comments Saved` can be stale or unavailable while the database and active comments job continue changing.

The implementation should add a backend active-lane contract that survives summary timeouts, make cancel lane-aware and durable, update workers to observe cancellation during long loops, and split the app UI state so catalog, comments, and unavailable summary states do not mask each other.

## saved_path

`/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-social-profile-linked-run-cancel-and-progress-plan.md`

Plan Grader package:

`/Users/thomashulihan/Projects/TRR/.plan-grader/social-profile-linked-run-cancel-and-progress-20260428-190224/`

## project_context

- Workspace: `/Users/thomashulihan/Projects/TRR`
- Backend owner: `/Users/thomashulihan/Projects/TRR/TRR-Backend`
- App owner: `/Users/thomashulihan/Projects/TRR/TRR-APP`
- Current browser URL: `http://admin.localhost:3000/social/instagram/thetraitorsus/comments`
- Current app surface: `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`
- Current comments surface: `TRR-APP/apps/web/src/components/admin/instagram/InstagramCommentsPanel.tsx`
- Current backend route surface: `TRR-Backend/api/routers/socials.py`
- Current backend repository surface: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`

Live browser-use evidence from 2026-04-28:

- Earlier snapshots showed `Run 7420c94e is Fetching`, `Comments Saved 13,184 / 105,716 comments`, and an enabled `Sync Comments` button while active comments run `599dcbc2` was hidden.
- After the user reported `Summary read timed out before completion. Retry in a moment.`, a fresh browser-use DOM snapshot showed:
  - `Comments Saved`
  - `Unavailable`
  - `Media Saved`
  - `Unavailable`
  - `Posts 0 / 0`
  - the timeout message in main content.
- In that degraded browser snapshot, `Cancel Run` and `Sync Comments` were not present as enabled buttons, even though the database still had active jobs. The plan therefore must not depend on the summary payload or existing catalog control row being available before it can show active run truth.

Live Supabase read-only evidence from 2026-04-28T19:02:24Z:

- Catalog run `7420c94e-e211-4f31-8927-6c2bfd673e50` was still `running`.
- Catalog job `290e43fe-36bf-4bb0-8d77-28d9b10ad615` was still `running`, with heartbeat `2026-04-28T19:02:19Z`, phase `details_refresh_fetch`, and `206 / 431` saved posts in job activity.
- Comments run `599dcbc2-2ae3-4008-8ef0-29d407bfcb11` was still `running`.
- Comments job `23321953-8717-4c5a-9b9c-d7a89535ae44` was still `running`, with heartbeat `2026-04-28T19:02:23Z`, phase `comments_scrapling_running`, `52 / 431` saved/matched posts in job activity, `items_found=7019`, and `persist_counters.comments_upserted=2647`.
- Prior comments run `7046bc7d-ca74-4dd3-86b8-a01ccde3afe9` was `cancelled`, which proves predecessor cancellation is possible but does not prove the current active lane is being shown or cancelled correctly.
- Live row counts were `431` materialized posts, `13,293` total comment rows, `13,167` active non-missing/non-deleted comment rows, `2,763` active replies, and latest comment scrape timestamp `2026-04-28T19:02:20Z`.
- The reported-comment denominator is drift-prone and source-dependent. Earlier UI showed `105,716`; later Supabase materialized-post sum was `104,579`. The UI must label the denominator as reported or estimated and expose freshness/source.

Relevant current-code facts:

- `SocialAccountProfilePage.tsx` maps the header tile from `summary?.comments_saved_summary?.saved_comments` and `summary?.comments_saved_summary?.retrieved_comments`.
- `SocialAccountProfilePage.tsx` formats summary timeouts as `Summary read timed out before completion. Retry in a moment.`
- `cancelCatalogRun()` locally applies cancellation, posts only to the catalog cancel route, then refreshes the snapshot.
- `InstagramCommentsPanel.tsx` polls comments progress only after it already has a local `scrapeRunId`; it does not discover an existing active comments run on page load.
- `api/routers/socials.py` has comments progress and catalog cancel routes but no comments cancel route.
- `request_cancel_social_account_catalog_run(...)` currently marks run/jobs as `cancelling`; final cancellation is delegated through follow-up background work.
- `_abort_claimed_job_if_cancelled(...)` only treats `cancelled` as terminal, not `cancelling`, so long-running workers can keep writing progress after an operator has requested cancellation.
- `_instagram_social_account_comments_saved_summary(...)` and detail rollup queries own the saved/retrieved comment numbers used by the header card.

## assumptions

1. Operators expect the page to show active catalog and comments work even when the heavyweight summary request times out.
2. `Cancel Run` must clearly state which lane it affects and must not hide a still-running linked or reused comments lane.
3. A reused active comments run must not be cancelled by catalog-only cancel unless the backend can prove it belongs to the same launch group.
4. A linked comments follow-up launched as part of the same catalog action can be cancelled by an explicit linked cancel action.
5. Backend-first sequencing applies because app behavior needs an authoritative run-state and cancellation contract.
6. Browser-use is required for final operator-facing verification; Supabase MCP read-only queries are required for live DB truth.

## goals

1. Add a bounded backend active-lane contract that returns active catalog and comments runs independently of the full summary.
2. Add a comments-run cancel path and make catalog cancel semantics lane-aware.
3. Make cancellation durable immediately enough that refresh cannot resurrect the exact same requested run as `running`.
4. Make long-running catalog/details/comments workers stop when run or job status is `cancelling` or `cancelled`.
5. Split app state so catalog, comments, and summary availability are rendered independently.
6. Disable or relabel comments sync controls while an active comments run exists for the same account.
7. Fix the `Comments Saved` tile so it uses a fresh or explicitly stale/progress-overlaid source while comments are running.
8. Label the denominator as reported/estimated comments and expose source/freshness.
9. Verify browser UI, backend API, and Supabase row state agree for the same run ids.

## non_goals

- No production data deletion.
- No broad social-profile dashboard redesign.
- No Supabase pool-size or capacity change.
- No scraper payload/schema expansion.
- No automatic cancellation of unrelated reused comments runs.
- No Render deployment changes unless later evidence proves hosted service logs are needed.

## phased_implementation

### Phase 0 - Freeze The Failure And Add Regression Fixtures

Concrete changes:

- Save a local-status note under `docs/ai/local-status/` with:
  - browser-use stale-card evidence from the first snapshots,
  - browser-use timeout evidence from the latest snapshot,
  - Supabase run/job truth for `7420c94e`, `599dcbc2`, `23321953`, and `7046bc7d`,
  - the code surfaces listed in `project_context`.
- Add backend fixtures for:
  - active catalog only,
  - active comments only,
  - active catalog plus active comments sharing a launch group,
  - active catalog plus reused active comments without shared launch group,
  - cancelled predecessor plus newer active replacement run,
  - summary timeout while active lanes still exist.
- Add app test fixtures for:
  - stale header stat,
  - unavailable summary with active lanes,
  - refresh after cancel returning the same run id,
  - refresh after cancel returning a different active comments run id.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "active_social_account"

cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run tests/social-account-profile-page.runtime.test.tsx -t "summary timed out" --reporter=dot
```

Acceptance criteria:

- The current failure is reproducible without depending on the live jobs remaining active.
- Tests can represent active lanes even when `summary` is null or unavailable.

Commit boundary:

- Evidence note plus failing or fixture-ready tests only.

### Phase 1 - Add A Bounded Active-Lane Contract Independent Of Summary

Concrete changes:

- Add a backend route or additive dashboard field that is cheap enough to resolve when the full summary times out. Preferred shape:
  - backend: `GET /api/v1/admin/socials/profiles/{platform}/{handle}/runs/active`
  - app proxy: `GET /api/admin/trr-api/social/profiles/[platform]/[handle]/runs/active`
- Return a stable payload such as:

```json
{
  "platform": "instagram",
  "handle": "thetraitorsus",
  "observed_at": "iso timestamp",
  "lanes": {
    "catalog": {
      "run_id": "uuid",
      "status": "running|cancelling|queued|pending|retrying",
      "job_id": "uuid",
      "job_status": "running",
      "phase": "details_refresh_fetch",
      "started_at": "iso timestamp",
      "heartbeat_at": "iso timestamp",
      "launch_group_id": "nullable string",
      "source": "catalog_attached|independent_catalog_run",
      "cancel_scope": "catalog_only|linked|separate_lane"
    },
    "comments": {
      "run_id": "uuid",
      "status": "running|cancelling|queued|pending|retrying",
      "job_id": "uuid",
      "job_status": "running",
      "phase": "comments_scrapling_running",
      "started_at": "iso timestamp",
      "heartbeat_at": "iso timestamp",
      "launch_group_id": "nullable string",
      "source": "catalog_attached|deferred_after_catalog|reused_active_run|independent_comments_run",
      "cancel_scope": "linked|separate_lane"
    }
  },
  "summary_state": {
    "available": false,
    "stale": true,
    "error_code": "summary_timeout",
    "last_success_at": "nullable iso timestamp"
  }
}
```

- Reuse existing helpers where possible, but keep the endpoint bounded:
  - `get_active_social_account_comments_run(...)`
  - current catalog active-run helper or a narrow equivalent if no public helper exists,
  - `get_social_account_comments_scrape_run_progress(...)` only when it does not trigger heavyweight summary work.
- Active statuses must include `queued`, `pending`, `retrying`, `running`, and `cancelling`.
- Do not make this endpoint depend on detail rollups, post list hydration, comment coverage rollups, media coverage, hashtags, collaborators, or raw payloads.
- Cache separately from the full dashboard summary with a short TTL, and invalidate it on cancel, launch, progress completion, and summary refresh.
- Include `summary_state` only as availability/freshness metadata; do not block lane rendering on summary success.

Affected files:

- `TRR-Backend/api/routers/socials.py`
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- `TRR-Backend/tests/api/routers/test_socials_season_analytics.py`
- `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/runs/active/route.ts`
- `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts`
- `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/api/routers/test_socials_season_analytics.py -k "active_lanes or profile_dashboard"
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "active_social_account_comments_run or active_social_account_catalog_run"

cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run tests/social-account-profile-page.runtime.test.tsx -t "active lanes" --reporter=dot
```

Acceptance criteria:

- Page-load code can show active catalog and comments lanes when `summary` is unavailable.
- The comments lane can be discovered without a locally-created `scrapeRunId`.
- `Sync Comments` state can be decided from backend active-lane truth.

Commit boundary:

- Backend active-lane contract, app proxy/types, and focused tests.

### Phase 2 - Make Cancel Durable, Lane-Aware, And Observable

Concrete changes:

- Add backend comments cancellation:
  - `POST /api/v1/admin/socials/profiles/{platform}/{account_handle}/comments/runs/{run_id}/cancel`
  - repository helper `request_cancel_social_account_comments_run(...)`
  - app proxy route at `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/comments/runs/[runId]/cancel/route.ts`
- Change catalog cancellation so the request path returns a state that refresh will preserve:
  - write `cancelling` or `cancelled` to `social.scrape_runs` and matching `social.scrape_jobs` in one transaction,
  - update summary/metadata with `cancel_requested_at`, `cancel_requested_by`, `cancel_scope`, and `cancel_target_lane`,
  - clear active-lane, dashboard snapshot, catalog progress, and comments progress caches immediately,
  - run expensive reconciliation or summary recompute asynchronously after the durable status write.
- Add lane rules:
  - `catalog_only`: cancel only the catalog run/job and show any active comments lane separately.
  - `comments_only`: cancel only the comments run/job.
  - `linked`: cancel catalog and comments only when `launch_group_id`, `attached_followups`, or stored config proves the same launch group.
  - `deferred_after_catalog`: remove or mark deferred follow-up metadata so comments cannot launch after catalog cancellation.
  - `reused_active_run`: never auto-cancel from catalog-only cancel; return it as still active.
- Make cancel response include current lane truth:

```json
{
  "accepted": true,
  "target": { "lane": "catalog", "run_id": "uuid", "status": "cancelling" },
  "linked_lanes": [],
  "still_active_lanes": [{ "lane": "comments", "run_id": "uuid", "status": "running" }]
}
```

- If the cancel POST did not reach the backend or failed auth/network, the app must show that failure and re-read active lanes before claiming the run is cancelled.

Affected files:

- `TRR-Backend/api/routers/socials.py`
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/catalog/runs/[runId]/cancel/route.ts`
- `TRR-APP/apps/web/src/app/api/admin/trr-api/social/profiles/[platform]/[handle]/comments/runs/[runId]/cancel/route.ts`
- `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "cancel_social_account_catalog_run or cancel_social_account_comments_run"
.venv/bin/python -m pytest -q tests/api/routers/test_socials_season_analytics.py -k "cancel"

cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run tests/social-account-profile-page.runtime.test.tsx -t "cancel" --reporter=dot
```

Acceptance criteria:

- Refresh cannot show the same requested run id as plain `running` immediately after a successful cancel response.
- A still-running comments run is either cancelled by explicit linked/ comments cancel or shown as separate active work.
- A deferred comments follow-up cannot launch after its cancelled catalog parent.

Commit boundary:

- Backend cancel semantics, app proxy route, and cancellation tests.

### Phase 3 - Add Cooperative Cancellation Checks Inside Long Workers

Concrete changes:

- Audit long loops in:
  - Instagram comments Scrapling job runner paths,
  - shared-account catalog/details refresh paths,
  - any helper that writes heartbeat/progress while iterating posts.
- Broaden `_abort_claimed_job_if_cancelled(...)` or add a new helper so both `cancelling` and `cancelled` stop execution.
- Check cancellation:
  - before remote fetch,
  - after each page/post batch,
  - before persistence writes,
  - before heartbeat/progress summary writes,
  - before final run status reconciliation.
- Prevent post-cancel worker updates from overwriting `cancelling` or `cancelled` run/job state back to active.
- Record operator-readable metadata where available:
  - `cancel_observed_at`,
  - `cancel_scope`,
  - `cancelled_by`,
  - `cancelled_after_posts_checked`,
  - `remote_invocation_id` if already known.

Affected files:

- `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Instagram comments job runner modules under `TRR-Backend/trr_backend/socials/instagram/`
- Relevant backend tests under `TRR-Backend/tests/`

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "cancelled or cancelling"
.venv/bin/python -m pytest -q tests/socials/instagram -k "cancel"
```

Acceptance criteria:

- Running comments jobs stop after observing `cancelling` or `cancelled`.
- Running details-refresh jobs stop cleanly and do not reselect themselves as active after cancellation.
- Worker progress metadata shows where cancellation was observed.

Commit boundary:

- Worker cancellation behavior and focused tests.

### Phase 4 - Split App Run State And Summary Error Rendering

Concrete changes:

- In `SocialAccountProfilePage.tsx`, split state into:
  - displayed catalog run,
  - active catalog run,
  - displayed comments run,
  - active comments run,
  - summary availability/freshness state.
- Load the active-lane endpoint on page load and after any launch/cancel/progress terminal state.
- Render lane controls independently of full summary success:
  - show catalog active lane,
  - show comments active lane,
  - show comments lane short id,
  - show status `running`, `cancelling`, `cancelled`, or `separate active comments run`.
- Replace ambiguous `Cancel Run` with lane-aware labels when more than one lane exists:
  - `Cancel Catalog Run`
  - `Cancel Comments Run`
  - `Cancel Linked Run`
- In `InstagramCommentsPanel.tsx`:
  - accept `activeCommentsRun` from parent,
  - initialize polling from that run id,
  - disable or relabel `Sync Comments` while active comments exists,
  - expose comments cancel through parent or panel.
- If the summary request times out, keep the header page in a degraded-but-truthful state:
  - do not reset posts/comments/media to misleading `0 / 0`,
  - show summary unavailable for summary-only fields,
  - continue showing active lanes from the bounded run-state endpoint,
  - show the timeout message in a scoped degraded-summary area.
- Local cancel state must not be overwritten by stale snapshots for the same run id. A newer different run id may replace it.

Affected files:

- `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`
- `TRR-APP/apps/web/src/components/admin/instagram/InstagramCommentsPanel.tsx`
- `TRR-APP/apps/web/src/components/admin/instagram/PostScrapeCommentsButton.tsx`
- `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts`
- `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run tests/social-account-profile-page.runtime.test.tsx -t "comments run" --reporter=dot
pnpm exec vitest run tests/social-account-profile-page.runtime.test.tsx -t "summary timed out" --reporter=dot
pnpm exec vitest run tests/social-account-profile-page.runtime.test.tsx -t "cancel" --reporter=dot
```

Acceptance criteria:

- Active comments run id is visible while comments are running.
- `Sync Comments` is disabled or relabeled while an active comments run exists.
- Summary timeout does not hide active run controls.
- Refresh after cancel does not resurrect the same cancelled or cancelling run as active.

Commit boundary:

- App state/rendering/proxy tests.

### Phase 5 - Repair Comments Saved Freshness And Denominator Semantics

Concrete changes:

- Trace and update the sources for `summary.comments_saved_summary`:
  - `_instagram_social_account_comments_saved_summary(...)`
  - `_instagram_comments_saved_summary_from_detail_rollup(...)`
  - lite dashboard/header summary construction
  - app snapshot stale-if-error cache paths.
- Define numerator:
  - `saved_comments` should mean active non-missing, non-deleted saved rows.
  - If a product decision intentionally counts missing markers or deleted rows, rename the label/sublabel so it is not called saved comments.
- Define denominator:
  - pick one source for the header denominator, preferably materialized Instagram post `comments_count` for the current account unless product explicitly wants catalog max/merge,
  - expose it as `reported_comments` or `estimated_reported_comments`,
  - include `denominator_source` and `denominator_observed_at` in the payload.
- During active comments runs, avoid stale count display:
  - bypass stale snapshot cache only for the lightweight comments-saved summary, or
  - overlay active comments progress and mark the base summary stale until a fresh summary lands.
- Add tile metadata:
  - `last_refreshed_at`,
  - `source`,
  - `stale`,
  - `active_run_id`,
  - `job_comments_upserted` when available.
- If summary is unavailable, the card should say `Unavailable` plus the active run state, not `0 / 0`.

Affected files:

- `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`
- `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts`
- `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "comments_saved_summary"

cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run tests/social-account-profile-page.runtime.test.tsx -t "Comments Saved" --reporter=dot
```

Acceptance criteria:

- The browser tile no longer remains fixed at an old value while Supabase rows and active job counters increase.
- The denominator is visibly identified as reported or estimated reported comments.
- Browser-use and Supabase read-only checks agree on whether the tile is fresh, cached, unavailable, or progress-overlaid.

Commit boundary:

- Backend summary freshness and app tile semantics/tests.

### Phase 6 - Browser-Use And Supabase Live Verification

Concrete changes:

- Start or reuse the local workspace dev stack.
- Use browser-use against:
  - `http://admin.localhost:3000/social/instagram/thetraitorsus/comments`
  - `http://admin.localhost:3000/social/instagram/thetraitorsus/catalog`
- Verify visible states before and after refresh:
  - active catalog lane appears when catalog is active,
  - active comments lane appears when comments is active,
  - summary timeout does not hide lane state,
  - `Sync Comments` is disabled or not offered during active comments,
  - cancel response changes visible state to `cancelling` or `cancelled`,
  - refresh does not show the same cancelled run as `running`,
  - comments denominator is labeled as reported/estimated.
- Use Supabase read-only checks to verify `social.scrape_runs` and `social.scrape_jobs` agree with the browser UI for the same run ids.
- If hosted behavior diverges from local browser and Supabase truth, configure Render MCP/CLI as a separate service-log check.

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR
make dev
```

Browser-use checks:

- DOM snapshot contains catalog and comments lane text when both are active.
- DOM snapshot contains the active comments run short id.
- DOM snapshot shows `Sync Comments` disabled or absent while active comments exists.
- DOM snapshot shows an explicitly fresh, stale, unavailable, or progress-overlaid `Comments Saved` tile.
- DOM snapshot labels the denominator as reported or estimated comments.
- After cancel, DOM snapshot and Supabase row status agree.

Acceptance criteria:

- Browser UI, backend API, and Supabase DB agree on active/cancelled state for the same run ids.
- No hidden active comments run keeps the page stuck behind a catalog-only or summary-only state.

Commit boundary:

- Verification artifacts only if any are saved.

## architecture_impact

- Backend becomes the source of truth for lane-level active run state.
- The app no longer has to infer comments activity from catalog progress or a locally-created comments run id.
- Cancellation becomes a lane-aware backend contract instead of a catalog-only UI side effect.
- Worker loops gain cooperative cancellation checks, reducing post-cancel writes.
- The summary card becomes a data consumer with freshness metadata rather than the gate for all run controls.

## data_or_api_impact

- Additive active-lane endpoint or additive dashboard payload fields.
- Additive comments cancel endpoint.
- Additive app proxy route for active lanes and comments cancel.
- No schema migration is expected unless existing `config`, `summary`, and `metadata` cannot carry needed cancellation/source metadata.
- Runtime mutations remain limited to existing tables:
  - `social.scrape_runs`
  - `social.scrape_jobs`
  - existing queue/progress metadata tables if already used by the run system.
- Cache invalidation must include active-lane, dashboard snapshot, catalog progress, and comments progress surfaces.

## ux_admin_ops_considerations

- Operators should see which lane is active and exactly which lane a cancel button affects.
- Summary timeout should degrade summary stats without hiding active job truth.
- `Comments Saved` should not imply `105k` comments are already saved; the denominator must be labeled as reported/estimated.
- Short run ids should remain visible in the UI; full run ids should be accessible in logs/debug/details.
- Browser-use verification is required because this is primarily operator-facing state drift.
- Supabase MCP read-only checks remain the live source of truth for row status during verification.

## validation_plan

- Backend repository tests:
  - active-lane discovery,
  - linked vs reused comments run classification,
  - catalog cancel,
  - comments cancel,
  - cancellation while status is `cancelling`,
  - comments saved summary and denominator source.
- Backend API tests:
  - active-lane route,
  - comments cancel route,
  - catalog cancel response includes lane truth.
- App Vitest:
  - summary timeout plus active lanes,
  - active comments lane rendering,
  - sync button disabled during active comments,
  - lane-aware cancel labels,
  - refresh after local cancel,
  - comments tile unavailable/stale/fresh states.
- Browser-use:
  - verify current admin page states after implementation.
- Supabase:
  - read-only status/count checks before and after cancel.

## acceptance_criteria

1. The admin page shows active catalog and active comments lanes independently for `@thetraitorsus`.
2. Active lanes render even when the heavyweight profile summary times out.
3. `Sync Comments` is not enabled while a comments run is active for the same account.
4. Cancelling a catalog run cannot leave that same run visible as plain `running` after refresh.
5. Cancelling linked lanes cancels both catalog and comments only when they are linked by backend contract.
6. Reused or independent comments runs are shown as separate active work instead of hidden.
7. The `Comments Saved` tile is fresh, explicitly stale, progress-overlaid, or unavailable; it is never silently stale.
8. The reported/expected comment denominator is labeled clearly.
9. Worker loops stop after observing `cancelling` or `cancelled`.
10. Browser-use and Supabase read-only checks agree on final state for the same run ids.

## risks_edge_cases_open_questions

- The live jobs may finish naturally before implementation; use fixtures and saved evidence rather than depending on live state.
- A cancel button click observed by the user does not prove the POST reached the backend; tests should cover request failure and backend-accepted paths separately.
- Remote Modal execution is cooperative through DB state unless a remote cancellation API is added.
- If `launch_group_id` is absent from old run config, classify conservatively as separate/reused rather than linked.
- Cache stale-if-error behavior may keep old snapshots visible unless active-lane cache is invalidated separately.
- The denominator can drift as materialized posts change; the UI should show source/freshness rather than pinning one unexplained number.

## follow_up_improvements

- Add a compact run timeline drawer showing launch group, attached followups, reused runs, and cancel history.
- Add an operator-only `Cancel All Active Lanes For This Account` action after lane-specific cancel behavior is stable.
- Add live DB pressure hints to the progress card when status reads are degraded.
- Add a one-account run-state reconciliation script that prints catalog/comments/media lane truth.

## recommended_next_step_after_approval

Use `orchestrate-subagents` with strict ownership:

- Main orchestrator owns backend contract shape and the large shared repository file.
- Backend worker may own API route/proxy tests and focused repository tests, but only one writer should touch `TRR-Backend/trr_backend/repositories/social_season_analytics.py` at a time.
- App worker owns `SocialAccountProfilePage.tsx`, `InstagramCommentsPanel.tsx`, app proxy routes, and Vitest coverage after backend payload shape is fixed.
- QA/browser worker owns browser-use and Supabase read-only verification after implementation.

Do not fan out before Phase 1 payload shape is settled.

## Cleanup Note

After this plan is completely implemented and verified, delete any temporary planning artifacts that are no longer needed, including generated audit, scorecard, suggestions, comparison, patch, benchmark, and validation files. Do not delete them before implementation is complete because they are part of the execution evidence trail.

## ready_for_execution

Yes, after approval. The plan is execution-ready with backend active-lane/cancel contracts first, app follow-through second, and browser-use plus Supabase verification last.
