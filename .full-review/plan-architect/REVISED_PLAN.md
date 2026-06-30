# BravoTV Instagram Backfill Recovery Revised Plan

Generated: 2026-06-29T10:32:19-04:00
Revised from audit: 2026-06-29

## Current Decision

Do not execute the 2026-06-26 plan as written.

The old blocker, a pending deferred comments follow-up, has advanced past its pending stage. That only means the child comments run was created or reused; it does not mean comments are complete. The active blocker is now the comments child run:

- Parent 2026 run: `8b2df911-e03d-4225-9376-10783d26f00b`
- Child comments run: `4f4160a4-2287-42af-8f47-27345b1c018f`
- Active child-run blocker from latest checked snapshot: `instagram_comments_public_requires_approval`
- Latest checked child-run shape: `status=running`, `active_jobs=1`, `completed_jobs=5`, `failed_jobs=5`
- Latest checked parent 2026 catalog/details/canonical state: complete for 1,843 rows
- Latest checked parent comments state: 393,771 saved comment rows; 479 reporting posts still have no saved comments
- Latest checked media state: 1,640 mirrored, 193 `hosted_unmarked`, 10 unrecoverable

The safe plan is:

1. Re-verify the snapshot with read-only commands.
2. Decide whether sub-`MIN_GAP` approval residuals are accepted terminal misses or approved for authenticated fallback escalation.
3. Only then mutate the existing comments child run.
4. Finish 2026 gates.
5. Launch 2025 fresh only after 2026 is clean or explicitly accepted.

Default if no human chooses escalation: accept sub-`MIN_GAP` `requires_approval` residuals as terminal with an enumerated reason. Do not lower `MIN_GAP`, do not permit extra auth/proxy escalation, and do not blind-dispatch comments work while the approval token is still active.

## Beneficial Capabilities For This Plan

| Capability | Invocation Path | Use | Validation Contribution |
| --- | --- | --- | --- |
| Backfill Operator | `/Users/thomashulihan/Projects/TRR/.agents/skills/backfill-operator/SKILL.md` | Keep posts serialized, use progress/preflight/recovery commands safely, apply stop rules. | Prevents launching new years or raising concurrency while auth/checkpoint/approval blockers are active. |
| Plan Architect revise-plan | `/Users/thomashulihan/.codex/plugins/cache/local-plugins/plan-grader/1.0.0/skills/revise-plan/SKILL.md` | Incorporate the approval-grade audit into the plan artifact. | Forces plan changes into `REVISED_PLAN.md`, validation/result artifacts, and `PATCHES.md` trace instead of chat-only notes. |
| DebugPro discipline | Developer instruction | Evidence-first validation, one falsifiable track at a time. | Verified that `recover-stalled` mutates by default and that `MIN_GAP` is the real approval gate before revising steps. |
| Repo make targets | `make instagram-backfill-progress`, `make instagram-backfill-preflight`, `make instagram-backfill-recover-stalled` | Read state and run the existing recovery path only when safe. | Defines read-only versus mutating operations and their expected outputs. |
| Existing backend repository helpers | `trr_backend.repositories.social_season_analytics` | Recover stale comments-stage jobs and inspect failed comments jobs without adding a new abstraction. | Uses existing recovery functions instead of creating new backfill orchestration code. |

## Reality Verification

| Claim | Evidence Source | Status | Contradiction Check | Plan Consequence |
| --- | --- | --- | --- | --- |
| Parent 2026 run and child comments run are the current active lane. | `RUN_ID=8b2df... make instagram-backfill-progress`; parent config has `comments_run_id=4f4160...`. | verified_runtime | Snapshot can drift. | Treat IDs/counts as point-in-time only; Step 3 must re-verify before action. |
| Parent 2026 catalog/details/canonical rows are complete. | Latest progress JSON: catalog rows 1,843; missing details/canonical rows 0. | verified_runtime | Future changes can alter counts. | Keep as 2026 gate, but re-read before passing 2026. |
| Child comments run is not complete and has approval failures. | Latest child progress JSON: `status=running`, `active_jobs=1`, `failed_jobs=5`, sample error `instagram_comments_public_requires_approval`. | verified_runtime | Runtime state can drift; audit did not mutate. | Do not launch 2025; focus on child comments run first. |
| `instagram-backfill-recover-stalled` is mutating by default. | `Makefile:234-250`; `recover_stalled_backfill.py:75-131` runs stale recovery, repair, media normalize, frontier recovery, and dispatch unless `SKIP_*` flags are set. | verified_source | None found. | Step 3 must not run it with defaults for evidence collection. |
| Dispatching the child run before approval is resolved can relaunch blocked comments jobs. | `recover_stalled_backfill.py:126-131` calls `dispatch_due_social_jobs`; audit points to dispatch selecting queued/pending/retrying jobs with no approval gate. | verified_source | Approval failure happens at job runtime, not dispatch selection. | Dispatch-enabled recovery moves to Step 6 only after Step 5 decision. |
| `SOCIAL_INSTAGRAM_COMMENTS_AUTO_AUTH_FALLBACK` is already enabled in Modal defaults. | `TRR-Backend/trr_backend/modal_jobs.py:296-301`, `:568-570`, `:629`. | verified_source | No run-specific switch to simply turn on. | Remove "config-only switch" framing. |
| Residual `requires_approval` is controlled by `MIN_GAP`, default 100. | `comments_scrapling/job_runner.py:2994-3024` selects fallback only when expected count is at least `MIN_GAP`; failure raised at `:5131-5134`. | verified_source | None found. | Choose between lower `MIN_GAP`/auth fallback or record terminal reason. |
| Existing auto-clear path uses authenticated endpoint-cursor fallback. | `comments_scrapling/job_runner.py:3027-3049` enqueues `instagram_comments_endpoint_cursor`. | verified_source | This conflicts with a strict no-auth/proxy public-first posture. | Escalation requires explicit human approval and Modal/env/deploy consideration. |
| Public comments mode is the default lane. | `public_mode.py:55-70` defaults missing mode to `PUBLIC_COMMENTS_SCRAPE_MODE`; modal defaults set public-first behavior. | verified_source | None found. | Reframe approval as intended terminal policy for low-value gaps, not accidental config. |
| `recover-stalled` stale-job recovery is posts-stage scoped. | `recover_stalled_backfill.py:75-82` calls `recover_stale_running_jobs(... stage=SHARED_ACCOUNT_POSTS_STAGE)`. | verified_source | General helper can recover `comments_scrapling`, but the script does not pass that stage. | Use the existing helper explicitly for the comments-stage stale job or terminalize separately. |
| The five approval-failed comments jobs will not be auto-requeued by capacity recovery. | `recover_failed_instagram_comments_capacity_jobs` allowlist at `social_season_analytics_impl.py:5857-5953` does not include `instagram_comments_public_requires_approval`. | verified_source | None found. | Explicitly requeue after approved escalation or mark terminal; do not expect self-heal. |
| The previous `comments_public` pytest selector was false confidence. | `rg` found real public-mode tests in `tests/socials/instagram/test_instagram_public_mode.py`; `comments_public` was not a reliable selector. | verified_source | No live pytest run in this revision. | Replace selectors with public-mode and auto-auth-fallback test files. |
| Dirty backend deploy is unsafe without a human checkpoint. | `git -C TRR-Backend status --short --branch` showed ahead/behind plus unrelated dirty files. | verified_runtime | Could change before execution. | Step 8 hard-stops deploy until scoped patch or explicit approval. |

## Stop Rules

These stop launching a new year and any blind comments re-dispatch while active. They do not block read-only diagnosis or intentionally pausing the existing 2026 child comments run.

Stop if any of these appear:

- `401`
- `403`
- `checkpoint`
- `checkpoint_required`
- `instagram_graphql_cursor_unauthorized`
- `instagram_graphql_cursor_forbidden`
- `instagram_comments_public_requires_approval`
- auth cooldown failures above `0`
- stale `running` comments jobs after one explicit comments-stage recovery pass

`instagram_comments_public_requires_approval` means public comments mode hit the intended approval boundary for public-incomplete targets below the auto-auth fallback threshold. It is not a generic retryable scraper failure.

## Execution Plan

### 1. Freeze Scope Before Runtime Mutation

Run:

```bash
git status --short --branch
git -C TRR-Backend status --short --branch
git -C TRR-APP status --short --branch
```

Required decision:

- Preserve unrelated dirty files.
- Do not deploy the current backend tree blindly.
- If code changes become necessary, use a scoped patch or get explicit human approval to deploy the dirty backend tree.

Current known risk: `TRR-Backend` is ahead of and behind origin and has unrelated dirty files.

### 2. Keep The Old Pending-Followup Fix Out Of The Active Recovery Path

Do not implement `recover_pending_deferred_comments_followups` for the active 2026 run.

Reason:

- The parent run already has `deferred_comments_followup.state=started`.
- The comments child run already exists.
- The blocker is in the child comments run, not in parent follow-up creation.

If a pending sweep is later implemented for other runs:

- Gate it behind an env flag or a run/account/date scope.
- Reuse `_maybe_start_deferred_comments_followup`.
- Add an advisory lock per parent run.
- Add tests for duplicate prevention and stale pending-state recovery.

### 3. Re-Verify Before Acting

The run IDs and counts above are a 2026-06-29 snapshot and will drift. This step is the re-verification gate.

Run only read-only commands:

```bash
RUN_ID=8b2df911-e03d-4225-9376-10783d26f00b JSON=1 make instagram-backfill-progress
RUN_ID=4f4160a4-2287-42af-8f47-27345b1c018f JSON=1 make instagram-backfill-progress
make instagram-backfill-preflight ACCOUNT_HANDLE=bravotv
```

Stop and re-derive the plan if any of these changed materially:

- Child run is no longer `running`.
- Child run no longer reports `instagram_comments_public_requires_approval`.
- Parent residual counts changed materially from 479 zero-comment reporting posts, 193 `hosted_unmarked`, or 10 unrecoverable media rows.
- Auth cooldown is active.
- Parent no longer points to child run `4f4160a4-2287-42af-8f47-27345b1c018f`.

Do not run `instagram-backfill-recover-stalled` with default flags in this step.

If an operator wants the script's progress wrapper only, use the fully skipped form:

```bash
RUN_ID=4f4160a4-2287-42af-8f47-27345b1c018f JSON=1 \
  SKIP_RECOVER=1 SKIP_REPAIR=1 SKIP_MEDIA_NORMALIZE=1 SKIP_FRONTIER_RECOVER=1 SKIP_DISPATCH=1 \
  make instagram-backfill-recover-stalled
```

Warning: `instagram-backfill-recover-stalled` is a mutating recover-and-dispatch target by default. It relaunches jobs and must not run with dispatch enabled while `instagram_comments_public_requires_approval` is the active blocker.

### 4. Identify The Actual Approval Gate

Search the real gate symbols:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
rg -n "auto_auth_fallback|AUTO_AUTH_FALLBACK|min_gap|MIN_GAP|comments_public_mode_from_config" trr_backend tests
```

Expected interpretation:

- `SOCIAL_INSTAGRAM_COMMENTS_AUTO_AUTH_FALLBACK` is already `1` in Modal defaults.
- Public comments mode is the default lane, not an accidentally enabled flag.
- Residual `requires_approval` targets are below `SOCIAL_INSTAGRAM_COMMENTS_AUTO_AUTH_FALLBACK_MIN_GAP`, default `100`.
- The only existing auto-clear path is authenticated endpoint-cursor fallback.

This creates a real execution decision:

- **Default, no extra approval:** accept sub-`MIN_GAP` targets as terminal and record an enumerated reason.
- **Escalation path:** lower `SOCIAL_INSTAGRAM_COMMENTS_AUTO_AUTH_FALLBACK_MIN_GAP` or change the code/policy around `job_runner.py:5090-5154`. This permits auth/proxy fallback and needs explicit human approval. It may require a Modal env/secret update and a redeploy or restart; changing baked defaults requires deploy.
- **Code path:** add or change terminal-reason recording at the raise site or in the post-run completion accounting. Keep it scoped.

### 5. Choose Terminal Acceptance Or Escalation

Use the conservative default unless the user explicitly chooses escalation:

- Accept terminal reason: `approval-blocked`
- High-volume threshold: `reported_comments >= 100`
- Accepted reason set: `approval-blocked`, `public-pagination-exhausted`, `deleted-by-source`, `age-cutoff`
- Free-text reasons do not pass the 2026 gate.

If accepting terminal residuals:

- Do not dispatch more comments shards for the approval-blocked child run.
- Record blocked targets with one of the accepted reasons.
- Use the scoped dry-run-first CLI now added in the backend:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./.venv/bin/python scripts/socials/instagram/classify_approval_blocked_comments.py \
  --run-id 4f4160a4-2287-42af-8f47-27345b1c018f \
  --account bravotv \
  --target-detail-limit 25 \
  --json
```

The apply form is intentionally confirmation-gated and must not be run without explicit human approval:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./.venv/bin/python scripts/socials/instagram/classify_approval_blocked_comments.py \
  --run-id 4f4160a4-2287-42af-8f47-27345b1c018f \
  --account bravotv \
  --apply \
  --confirm-apply "CLASSIFY APPROVAL BLOCKED COMMENTS" \
  --confirm-run-id 4f4160a4-2287-42af-8f47-27345b1c018f \
  --target-detail-limit 25 \
  --json
```

Latest read-only dry run on 2026-06-29: 5 approval-failed jobs, 3,377 candidate targets, 1,094 targets eligible under the default `reported_comments <= 99` guard, and 52,872 classified-missing rows that would be inserted if apply is approved. These counts are point-in-time and must be re-read before applying.

If escalating:

- State the approved `MIN_GAP` value.
- State whether auth/proxy fallback is allowed for this run.
- Run the public-mode and auto-auth fallback tests before dispatch.
- Update Modal env/secret and redeploy/restart if needed.

### 6. Recover The Existing Comments Child Run

Proceed only after Step 5 resolves the approval blocker as terminal or escalation.

First handle the stale comments-stage job. The existing `recover-stalled` script's stale recovery is posts-stage scoped, so it will not terminalize a stuck `comments_scrapling` shard by itself.

Use the existing repository helper for the comments stage:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./.venv/bin/python - <<'PY'
from trr_backend.utils.env import load_env
from trr_backend.repositories import social_season_analytics as social_repo

load_env()
rows = social_repo.recover_stale_running_jobs(
    run_id="4f4160a4-2287-42af-8f47-27345b1c018f",
    stage=social_repo.INSTAGRAM_COMMENTS_SCRAPLING_STAGE,
    stale_after_seconds=900,
    limit=5,
)
print({"recovered_jobs": [str(row.get("id") or row.get("job_id") or "") for row in rows]})
PY
```

Then handle the failed approval jobs:

- If terminal acceptance was chosen, run the dry-run-first CLI above, then run the confirmation-gated apply only after explicit approval. Do not expect capacity recovery to requeue those jobs.
- If escalation was chosen, explicitly requeue failed approval jobs after the `MIN_GAP`/auth policy change. The capacity recovery helper will not requeue `instagram_comments_public_requires_approval` on its own.

Only after the above, run one dispatch-enabled pass if needed:

```bash
RUN_ID=4f4160a4-2287-42af-8f47-27345b1c018f JSON=1 make instagram-backfill-recover-stalled
RUN_ID=4f4160a4-2287-42af-8f47-27345b1c018f JSON=1 make instagram-backfill-progress
```

Expected result depends on Step 5:

- Terminal acceptance: approval-blocked targets remain terminal with enumerated reasons, not re-dispatched.
- Escalation: approval-blocked targets are requeued or dispatched only after the approved policy change.
- No stale `running` comments jobs remain after explicit comments-stage recovery.
- If `instagram_comments_public_requires_approval` recurs after escalation, treat it as expected evidence that remaining targets are still below the active threshold and return to Step 5.

### 7. Recheck Parent 2026 Completion Gates

Run:

```bash
RUN_ID=8b2df911-e03d-4225-9376-10783d26f00b JSON=1 make instagram-backfill-progress
```

2026 passes only when:

- Catalog oldest post is on or before `2026-01-01`.
- Details missing rows are `0`.
- Canonical missing rows are `0`.
- Child comments run is completed, or all remaining misses have accepted terminal reasons.
- High-volume zero-saved posts are `0` for `reported_comments >= 100` unless they have an accepted reason in a named persisted field.
- The 479 zero-comment reporting-post residual is reduced or fully reasoned with accepted reason values.
- Media rows are mirrored, hosted, or explicitly unrecoverable.
- Auth cooldown failures remain `0`.

Current known residuals from the latest checked snapshot:

- 479 reporting posts have no saved comments.
- 193 media rows are `hosted_unmarked`.
- 10 media rows are `unrecoverable`.

### 8. Progress Messaging Change Only If Current Output Still Misleads

The previous progress-message change is not part of the active blocker.

Keep it only if a fresh progress read labels a `started`, failed, or approval-blocked comments child run as waiting for catalog completion.

If needed, make the smallest script-only change in:

```text
TRR-Backend/scripts/socials/instagram/backfill_progress.py
```

Actual current model:

- Pending before catalog completion may use `waiting_for_catalog_completion`.
- Once deferred state is not `pending`, catalog-waiting markers should be removed.
- Do not invent `catalog_complete_launch_pending` unless a new constant is deliberately added to code and tests.
- Started child runs with failures should show child-run status/error, not catalog waiting.
- Failed follow-up alerts remain unchanged.

### 9. Validation And Deploy Gates

Run these even for config-only or Modal-env-only approval changes:

```bash
TRR-Backend/.venv/bin/python -m pytest TRR-Backend/tests/socials/instagram/test_instagram_public_mode.py -k "public_comments_mode or public_relay"
TRR-Backend/.venv/bin/python -m pytest TRR-Backend/tests/socials/test_instagram_comments_scrapling_retry.py -k "auto_auth_fallback"
make instagram-backfill-preflight ACCOUNT_HANDLE=bravotv
```

If backend code changes are required, also run:

```bash
TRR-Backend/.venv/bin/python -m pytest TRR-Backend/tests/repositories/test_social_run_lifecycle_repository.py -k "deferred_comments_followup or recover_failed_deferred"
TRR-Backend/.venv/bin/python -m pytest TRR-Backend/tests/repositories/test_social_season_analytics.py -k "backfill_progress or deferred_comments_followup"
```

HUMAN CHECKPOINT (required): the backend tree is dirty and ahead/behind origin. Do not run `deploy_backend.py` until a human explicitly approves deploying the dirty tree or the fix is reduced to a reviewed scoped patch. Hard stop.

If deploy is approved:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./.venv/bin/python scripts/modal/deploy_backend.py
./.venv/bin/python scripts/modal/verify_modal_readiness.py --json
```

If the resolution is terminal acceptance through data-only marking, state the direct-SQL or admin-operation status in the final handoff.

### 10. Rollback And Abort

Abort the recovery path if any of these happen:

- failed job count increases after a dispatch-enabled pass
- auth cooldown failures become greater than `0`
- `401`, `403`, `checkpoint`, or cursor unauthorized/forbidden appears
- `instagram_comments_public_requires_approval` recurs after an escalation that was expected to clear it
- comments-stage running job remains stale after one explicit comments-stage recovery pass

Abort procedure:

1. Stop all `recover-stalled` and dispatch commands for the run.
2. Capture progress JSON for parent and child run IDs.
3. Capture failed-job error classes for the child run.
4. Leave the run intentionally paused with an enumerated reason.
5. If a backend deploy caused the regression, redeploy the prior known-good backend revision.

### 11. Launch Fresh 2025 Only After 2026 Passes

Do not recover `eef42618-6571-41ca-8a9e-23325045bdf7` as the active lane.

Before launching 2025:

```bash
make instagram-backfill-preflight ACCOUNT_HANDLE=bravotv
```

Launch a fresh 2025 all-lanes run only after:

- 2026 comments are complete or explicitly terminal with accepted reasons.
- 2026 media residuals are handled or explicitly accepted.
- No auth/cursor/checkpoint/public-approval stop rule is active.

Keep posts discovery serialized.

### 12. Continue Year By Year

Repeat for 2024 and earlier only after the prior year passes its gates.

Track each year:

- run id
- date range
- catalog rows and oldest post
- details/canonical missing rows
- comments reported/saved and zero-saved-post count
- media mirrored/hosted/unrecoverable counts
- cooldowns and stop-rule hits
- final status

## Archive And Cleanup After Implementation

After implementation and verification:

- Mark the superseded 2026-06-26 plan package as superseded.
- Keep this `REVISED_PLAN.md` and `result.json` as the current Plan Architect pointer.
- Delete only temporary generated scratch files after the 2026 year gates have been recorded.
- Do not delete evidence artifacts needed to explain why sub-`MIN_GAP` approval residuals were accepted or escalated.

## Validation Status

- Backend/API validation: focused implementation validation passed with `./.venv/bin/python -m pytest tests/scripts/test_classify_approval_blocked_comments.py tests/socials/test_instagram_comments_scrapling_retry.py -k "approval_blocked or terminal_missing_classified"` and `py_compile` for the CLI plus comments job runner.
- App validation/build: not applicable; this is backfill/runtime planning and no TRR-APP behavior changed.
- SQL status: read-only dry run executed for the child comments run; no SQL writes or apply command were run.
- Modal follow-through: not touched. Required only if escalation changes Modal env/runtime or backend code.

## Minimal Next Command

Start with read-only re-verification:

```bash
RUN_ID=8b2df911-e03d-4225-9376-10783d26f00b JSON=1 make instagram-backfill-progress
RUN_ID=4f4160a4-2287-42af-8f47-27345b1c018f JSON=1 make instagram-backfill-progress
make instagram-backfill-preflight ACCOUNT_HANDLE=bravotv
```
