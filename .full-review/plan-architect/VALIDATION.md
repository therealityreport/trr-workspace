# VALIDATION - BravoTV Instagram Backfill Recovery Plan

Input plan: `/Users/thomashulihan/Projects/TRR/.full-review/plan-architect/REVISED_PLAN.md`
Audit source: `/Users/thomashulihan/.codex/attachments/b5ac7657-ccec-4c44-900f-1f78c4b48f72/pasted-text.txt`

## Evidence Checked

- Read Plan Architect `revise-plan`, parent `SKILL.md`, artifact, routing, suggestion, validation, result schema, and user-global `write-plan` contracts.
- Read the supplied approval-grade audit.
- Re-read the target `REVISED_PLAN.md`.
- Verified `instagram-backfill-recover-stalled` target defaults in `Makefile:234-250`.
- Verified mutating phases in `TRR-Backend/scripts/socials/instagram/recover_stalled_backfill.py:75-131`.
- Verified Modal default `SOCIAL_INSTAGRAM_COMMENTS_AUTO_AUTH_FALLBACK=1` in `TRR-Backend/trr_backend/modal_jobs.py:296-301`.
- Verified unconditional Modal defaults injection in `TRR-Backend/trr_backend/modal_jobs.py:568-570` and import-time call at `:629`.
- Verified `MIN_GAP` default and selection gate in `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/job_runner.py:2994-3024`.
- Verified authenticated fallback enqueue path in `job_runner.py:3027-3049`.
- Verified approval failure raise in `job_runner.py:5131-5134`.
- Verified public-comments default logic in `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/public_mode.py:55-70`.
- Verified posts-stage stale recovery inside `recover_stalled_backfill.py:75-82`.
- Verified general stale job helper can stage-filter in `TRR-Backend/trr_backend/socials/social_season_analytics_impl.py:13879-14150`.
- Verified approval failures are not in capacity-recovery allowlist in `social_season_analytics_impl.py:5857-5953`.
- Verified public-mode and auto-auth fallback test locations with `rg`.
- Verified implemented terminal-acceptance CLI with focused tests and a read-only dry run.

## Reality Verification Status

Status: pass with execution checkpoints.

- Current runtime counts remain point-in-time and must be re-read before mutation.
- The previous unsafe Step 3 mutation has been removed from diagnosis.
- The approval blocker is now framed as an escalation-or-terminal decision, not a simple config flip.
- Dirty backend deploy is a hard human checkpoint.
- No plan-critical claim now depends only on prior `REVISED_PLAN.md` text.

## Accepted Audit Changes

Accepted and incorporated:

- CHG-01: Step 3 made read-only; default `recover-stalled` warning added.
- CHG-02: Step 4 and deploy assumptions rewritten around `MIN_GAP` and Modal defaults.
- CHG-03: Step 6 now says recovery cannot clear approval by itself.
- CHG-04: Comments-stage stale recovery is explicit.
- CHG-05: Failed approval jobs require explicit requeue or terminal marking.
- CHG-06: False `comments_public` selector removed.
- CHG-07: Public-mode tests now run even for config/env changes.
- CHG-08: Re-verification before acting is a gate.
- CHG-09: Fabricated `catalog_complete_launch_pending` constant removed.
- CHG-10: "has cleared" wording replaced with pending-to-started wording.
- CHG-11: Stop rules scoped to new-year/blind redispatch.
- CHG-12: Dirty backend deploy is a hard checkpoint.
- CHG-13: Completion gate now defines `reported_comments >= 100` and accepted reasons.
- CHG-14: Rollback/abort section added.
- CHG-15: Public comments mode reframed as the default lane.

## Commands To Run During Execution

Read-only re-verification:

```bash
RUN_ID=8b2df911-e03d-4225-9376-10783d26f00b JSON=1 make instagram-backfill-progress
RUN_ID=4f4160a4-2287-42af-8f47-27345b1c018f JSON=1 make instagram-backfill-progress
make instagram-backfill-preflight ACCOUNT_HANDLE=bravotv
```

Validation for config/env/runtime policy changes:

```bash
TRR-Backend/.venv/bin/python -m pytest TRR-Backend/tests/socials/instagram/test_instagram_public_mode.py -k "public_comments_mode or public_relay"
TRR-Backend/.venv/bin/python -m pytest TRR-Backend/tests/socials/test_instagram_comments_scrapling_retry.py -k "auto_auth_fallback"
make instagram-backfill-preflight ACCOUNT_HANDLE=bravotv
```

Extra validation when backend code changes:

```bash
TRR-Backend/.venv/bin/python -m pytest TRR-Backend/tests/repositories/test_social_run_lifecycle_repository.py -k "deferred_comments_followup or recover_failed_deferred"
TRR-Backend/.venv/bin/python -m pytest TRR-Backend/tests/repositories/test_social_season_analytics.py -k "backfill_progress or deferred_comments_followup"
```

## Not Run

- No full backend pytest suite was run.
- No mutating recovery command was run.
- No SQL write/apply command was run.
- No Modal deployment or env change was made.
- No TRR-APP validation/build was run because this is a backend/runtime plan.

## Implementation Validation

Commands run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./.venv/bin/python -m pytest tests/scripts/test_classify_approval_blocked_comments.py tests/socials/test_instagram_comments_scrapling_retry.py -k "approval_blocked or terminal_missing_classified"
./.venv/bin/python -m py_compile scripts/socials/instagram/classify_approval_blocked_comments.py trr_backend/socials/instagram/comments_scrapling/job_runner.py
./.venv/bin/python scripts/socials/instagram/classify_approval_blocked_comments.py --run-id 4f4160a4-2287-42af-8f47-27345b1c018f --account bravotv --target-detail-limit 1 --json
```

Results:

- Focused pytest: 5 passed, 197 deselected.
- Compile check: passed.
- Read-only CLI dry run: 5 approval jobs, 3,377 candidate targets, 1,094 eligible targets under the default `reported_comments <= 99` guard, 52,872 rows would be inserted if apply is explicitly approved.

## Residual Risks

- Live run state can drift before execution.
- The exact persistence surface for terminal approval reasons must be verified before data mutation.
- Lowering `MIN_GAP` permits auth/proxy fallback and needs explicit approval.
- Backend deploy remains unsafe without scoped diff review or explicit dirty-tree approval.
