# AUDIT - BravoTV Instagram Backfill Recovery Plan

Audit source: `/Users/thomashulihan/.codex/attachments/b5ac7657-ccec-4c44-900f-1f78c4b48f72/pasted-text.txt`

## Verdict

The prior revised plan was directionally correct but unsafe to execute. The revised artifact now addresses the audit blockers.

## Former Blockers

| Item | Risk | Resolution |
| --- | --- | --- |
| CHG-01 | Step 3 treated `instagram-backfill-recover-stalled` as evidence collection even though it mutates and dispatches by default. | Step 3 now uses only read-only progress/preflight commands. The skipped form is shown only as a safe progress wrapper, with warning. |
| CHG-02 | Step 4 assumed the approval blocker could be cleared by a config-only switch, but auto-auth fallback is already on and `MIN_GAP` is the real gate. | Step 4 now frames the choice as terminal acceptance versus explicit `MIN_GAP`/auth fallback escalation. |

## High-Risk Fixes Folded In

- Recover-stalled cannot clear approval failures by itself.
- Stale comments shard recovery must target `comments_scrapling`, not the posts stage.
- Approval-failed comments jobs will not self-heal through capacity recovery.
- Public-mode and auto-auth fallback tests are required for config/env changes.
- Fresh read-only re-verification is required before mutation.

## Remaining Controlled Risks

- Live run state can drift before execution.
- Terminal-reason persistence must be verified before SQL/data mutation.
- Lowering `MIN_GAP` permits auth/proxy fallback and needs explicit approval.
- Backend deployment remains blocked by dirty tree until scoped patch review or explicit human approval.
