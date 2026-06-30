# IMPROVEMENTS - Audit Incorporation

## Applied

1. Made diagnosis read-only and moved mutating recovery after the approval decision.
2. Replaced the false config-only approval framing with the actual public-mode, auto-auth fallback, and `MIN_GAP` model.
3. Added a conservative default: accept sub-`MIN_GAP` targets as terminal unless the user approves escalation.
4. Added explicit comments-stage stale job recovery using the existing repository helper.
5. Added handling for failed approval jobs: explicit requeue after escalation or terminal marking after acceptance.
6. Replaced false-confidence pytest selectors with public-mode and auto-auth fallback tests.
7. Added re-verify-before-acting, rollback/abort, and dirty-backend deploy hard-stop gates.
8. Tightened 2026 completion gates with a high-volume threshold and accepted reason set.

## Deferred

- Implementing a generic pending deferred-followup sweep. It is not needed for the active 2026 run and would need gating before use.
- Adding a new progress status constant. Current code has a two-state model; inventing `catalog_complete_launch_pending` is not needed.
- Any backend code or Modal deploy. This turn only revises plan artifacts.

## Rejected

- Treating `instagram_comments_public_requires_approval` as retryable.
- Running default `instagram-backfill-recover-stalled` during diagnosis.
- Deploying the dirty backend tree without approval.
