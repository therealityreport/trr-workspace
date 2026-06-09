# TRR Gate Recovery And PR Orchestration Plan

> Status: draft plan only. Revalidate this against the current branch, dirty
> tree, tests, and active user request before using it as implementation
> authority.

## Summary

Clear the remaining blockers before publishing the three TRR repo PRs. The stale TRR-APP local publish branch is already deleted and the hidden env docs have been classified for publication, so the active blockers are now:

- Instagram Profile 13 still requires a manual checkpoint before auth repair can proceed.
- Full backend pytest no longer hangs, but it fails with 105 test failures.
- PR orchestration must be constrained to the three active TRR repos and must exclude the detached backend worktree and adjacent `screenalytics` repo.

Success means the backend gate is green or intentionally waived with named failures, Instagram auth repair reaches Modal apply/deploy/remote verification where required, and PR orchestration creates or updates only the intended TRR workspace, app, and backend PRs.

## Project Context

- Workspace root: `/Users/thomashulihan/Projects/TRR`
- Active repos:
  - `/Users/thomashulihan/Projects/TRR`
  - `/Users/thomashulihan/Projects/TRR/TRR-APP`
  - `/Users/thomashulihan/Projects/TRR/TRR-Backend`
- Old TRR-APP branch cleanup status:
  - `codex/publish/trr-app/20260520-174013` was confirmed tree-equivalent to `main`.
  - The local branch ref is now deleted.
- Env docs decision:
  - Publish the changed workspace env/security docs.
  - `skip-worktree` has been cleared for the affected docs under `/Users/thomashulihan/Projects/TRR/docs/workspace/`.
- Backend gate status:
  - Full backend pytest completed in about 59 minutes.
  - Current result: `105 failed, 4587 passed, 19 skipped`.
  - The previous first-test hang appears fixed.
- Instagram auth status:
  - Local auth repair validation returned `manual_checkpoint_required`.
  - Modal secret apply, Modal deploy, and remote verification were not reached.
- PR inventory status:
  - The three target repos are eligible and dirty.
  - Inventory also sees `/Users/thomashulihan/Projects/TRR/.worktrees/TRR-Backend-auth-profile-deploy` as a detached non-publishable worktree.
  - Inventory also sees `/Users/thomashulihan/Projects/TRR/screenalytics`, which is out of this plan's active scope.

## Assumptions

- Do not publish PRs while the backend gate is red unless the user explicitly approves a red-gate PR with documented failures.
- Do not mark Modal-affecting backend/social work complete until Modal update status is known or the blocker is written down.
- Do not run a TRR-APP production build unless the user explicitly approves it in the current chat.
- Browser proof for admin social pages should use `make dev-hybrid` unless the user specifies another startup target.

## Implementation Changes

### Phase 1: Close The Manual Instagram Auth Blocker

Outcome: Profile 13 has a valid Instagram session and the repair script can proceed past local validation.

Tasks:

1. Open Chrome Profile 13 to Instagram.
2. Complete the email/checkpoint challenge manually.
3. Rerun local validation:

   ```bash
   cd /Users/thomashulihan/Projects/TRR/TRR-Backend
   ./.venv/bin/python scripts/modal/repair_instagram_auth.py --validate-local-only --json
   ```

4. If local validation succeeds, rerun the repair flow required by the current script/runbook.
5. Capture whether the run reached:
   - Modal secret apply
   - Modal deploy
   - remote verification

Stop condition:

- If validation still reports `manual_checkpoint_required`, stop and preserve the JSON result. Do not keep retrying without completing the browser checkpoint.

### Phase 2: Triage The 105 Backend Pytest Failures

Outcome: the red backend gate becomes a short repair queue grouped by root cause.

Tasks:

1. Rerun focused failure groups instead of immediately rerunning the full hour-long suite.
2. Start with failures likely caused by the local job-plane override fixture:

   ```bash
   cd /Users/thomashulihan/Projects/TRR/TRR-Backend
   ./.venv/bin/pytest \
     tests/api/routers/test_admin_operations.py::test_start_operation_request_prefers_remote_in_dev_without_override \
     tests/api/routers/test_socials_season_analytics.py \
     tests/test_modal_jobs.py \
     -q
   ```

3. Separate failures into these buckets:
   - test setup fallout from forced local job-plane defaults
   - real Modal/remote execution contract regressions
   - DB pool naming or sizing expectation drift
   - social repository/read-model expectation drift
   - scraper/auth tests affected by the Instagram checkpoint state
4. Fix the smallest shared cause first, then rerun only the affected focused group.
5. Keep the first-test hang fix intact. Do not remove the safety fixture unless an equivalent isolation mechanism replaces it.

Stop condition:

- If the same focused group fails twice with the same error, capture the command, stack trace, and recent related diff before changing another area.

### Phase 3: Restore The Full Backend Gate

Outcome: backend pytest is dependable and green, or red only by explicit documented waiver.

Tasks:

1. After focused groups are fixed, run:

   ```bash
   cd /Users/thomashulihan/Projects/TRR/TRR-Backend
   ./.venv/bin/pytest
   ```

2. Record:
   - total runtime
   - pass/fail/skip counts
   - first failing test if still red
   - whether any worker/thread warnings remain
3. If full pytest passes, run the broader workspace fast gate:

   ```bash
   cd /Users/thomashulihan/Projects/TRR
   make test-fast
   ```

4. If app changes are still in scope, run lightweight app validation before any build request:

   ```bash
   cd /Users/thomashulihan/Projects/TRR
   pnpm -C TRR-APP/apps/web run validate:quick
   ```

Stop condition:

- Do not move to PR publication with an unexplained backend failure.

### Phase 4: Browser-Prove Admin Social Tabs

Outcome: the admin social UI remains usable across the important Instagram tabs after the backend and app changes.

Tasks:

1. Start the workspace with:

   ```bash
   cd /Users/thomashulihan/Projects/TRR
   make dev-hybrid
   ```

2. Use Browser against:
   - `http://admin.localhost:3000/social/instagram/thetraitorsus`
   - `http://admin.localhost:3000/social/instagram/thetraitorsus/catalog`
   - `http://admin.localhost:3000/social/instagram/thetraitorsus/hashtags`
   - `http://admin.localhost:3000/social/instagram/thetraitorsus/comments`
3. Confirm:
   - the primary profile summary renders before secondary panels finish
   - catalog progress/repair routes do not trigger page-level failure
   - degraded secondary panels show operator-readable messages
   - no visible `BACKEND_TIMEOUT`, `BACKEND_SATURATED`, or 503/504 page-level failure appears

Stop condition:

- If Browser proof fails on a user-visible route, fix or document that route before PR orchestration.

### Phase 5: Run Scoped Three-Repo PR Orchestration

Outcome: PR orchestration publishes only the TRR workspace, app, and backend changes.

Tasks:

1. Rerun inventory:

   ```bash
   cd /Users/thomashulihan/Projects/TRR
   python3 /Users/thomashulihan/Projects/PLUGINS/workspace-pr-orchestrator/scripts/workspace_pr_inventory.py \
     /Users/thomashulihan/Projects/TRR \
     --action publish-and-sync \
     --mode publish-only \
     --format json
   ```

2. Confirm these are the only publish targets:
   - `/Users/thomashulihan/Projects/TRR`
   - `/Users/thomashulihan/Projects/TRR/TRR-APP`
   - `/Users/thomashulihan/Projects/TRR/TRR-Backend`
3. Exclude:
   - `/Users/thomashulihan/Projects/TRR/.worktrees/TRR-Backend-auth-profile-deploy`
   - `/Users/thomashulihan/Projects/TRR/screenalytics`
4. Publish only after:
   - backend pytest is green or explicitly waived
   - Instagram auth repair status is no longer ambiguous
   - hidden env docs are included in the workspace PR
   - changed app/backend helper files are included in their matching repo PRs

Stop condition:

- If the orchestrator cannot exclude the detached worktree or `screenalytics`, run repo-specific PR commands instead of a broad workspace publish.

## Validation

Required validation before PR publication:

```bash
cd /Users/thomashulihan/Projects/TRR
make check-policy
make test-fast
```

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./.venv/bin/pytest
```

```bash
cd /Users/thomashulihan/Projects/TRR
pnpm -C TRR-APP/apps/web run validate:quick
```

Required validation after Instagram checkpoint completion:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./.venv/bin/python scripts/modal/repair_instagram_auth.py --validate-local-only --json
```

Required Browser validation if app/admin social behavior changed:

```bash
cd /Users/thomashulihan/Projects/TRR
make dev-hybrid
```

Then verify the four admin social tabs through Browser.

## Acceptance Criteria

- TRR-APP stale publish branch remains deleted.
- Env/security workspace docs are visible to git and included in the workspace PR.
- Instagram auth repair no longer stops at `manual_checkpoint_required`, or that blocker is explicitly carried into the PR/handoff.
- Backend full pytest completes without hanging.
- Backend full pytest passes, or every remaining failure is grouped and explicitly approved for deferral.
- Admin social tabs have Browser evidence after relevant fixes.
- PR orchestration targets only the three active TRR repos.
- Modal update status is stated for backend/social changes.

## Risks / Open Questions

- The backend failures may include real regressions hidden behind the job-plane hang fix. Treat the 105 failures as current truth until grouped.
- Instagram checkpoint completion requires manual browser action that Codex should not fake or bypass.
- The detached backend worktree can block broad automation if the orchestrator is run against every discovered repo.
- `screenalytics` is adjacent and dirty, but it is outside this TRR three-repo plan.
- App production build remains approval-gated by project policy.

## Recommended Handoff

Use sequential execution first:

1. Complete or explicitly defer the Instagram checkpoint.
2. Triage and fix backend pytest groups.
3. Run full backend pytest and fast workspace validation.
4. Browser-prove admin social tabs.
5. Use `workspace-pr-orchestrator` only after the gates are clear.

Use `orchestrate-subagents` only for independent focused pytest failure groups after the first root-cause split is known. Do not split the Instagram checkpoint work because it depends on a single Chrome Profile 13 manual state.

## Ready For Execution

Partially ready.

Ready now:

- Backend pytest failure grouping and focused repair.
- Scoped PR inventory filtering.
- Env doc inclusion in the workspace PR.

Blocked:

- Instagram auth repair completion until the Profile 13 checkpoint is manually cleared.
- Final PR publication until backend pytest is green or explicitly waived.

## Completion Contract

- saved_path: `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-05-21-trr-gate-recovery-and-pr-orchestration.md`
- compatibility_wrapper_used: true
- canonical_skill: `write-plan`
