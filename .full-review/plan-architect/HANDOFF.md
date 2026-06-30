# HANDOFF - BravoTV Instagram Backfill Recovery

Recommended execution target: `orchestrate-subagents`

Use one serialized backend/runtime operator scope. Do not split this into parallel workers because the child comments run has active production state and mutating recovery commands can re-dispatch jobs.

## Scope

1. Re-verify parent and child progress with read-only commands.
2. Confirm whether approval residuals are accepted terminal misses or explicitly approved for escalation.
3. Recover or terminalize the child comments run.
4. Recheck 2026 parent completion gates.
5. Launch 2025 fresh only after 2026 passes.

## Hard Stops

- Do not run default `make instagram-backfill-recover-stalled` during diagnosis.
- Do not dispatch while `instagram_comments_public_requires_approval` is still unresolved.
- Do not run approval-blocked terminal marking with `--apply` unless the user explicitly approves the current dry-run totals.
- Do not deploy the dirty backend tree without explicit approval or a reviewed scoped patch.
- Do not launch 2025 until 2026 passes or has recorded terminal reasons.

## First Commands

```bash
RUN_ID=8b2df911-e03d-4225-9376-10783d26f00b JSON=1 make instagram-backfill-progress
RUN_ID=4f4160a4-2287-42af-8f47-27345b1c018f JSON=1 make instagram-backfill-progress
make instagram-backfill-preflight ACCOUNT_HANDLE=bravotv
```

## Implemented Operator CLI

Dry run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./.venv/bin/python scripts/socials/instagram/classify_approval_blocked_comments.py \
  --run-id 4f4160a4-2287-42af-8f47-27345b1c018f \
  --account bravotv \
  --target-detail-limit 25 \
  --json
```

Latest read-only dry run on 2026-06-29 found 5 approval jobs, 3,377 candidate targets, 1,094 eligible targets under `reported_comments <= 99`, and 52,872 classified-missing rows that would be inserted. Apply was not run.

## Validation

Run public-mode and auto-auth tests for any config/env/policy change. Add lifecycle/backfill progress tests only if backend code changes.
