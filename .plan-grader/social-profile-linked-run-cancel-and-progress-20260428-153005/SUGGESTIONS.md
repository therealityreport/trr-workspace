# Remaining Optional Suggestions

All ten prior suggestions from `.plan-grader/social-profile-linked-run-cancel-and-progress-20260428-190224/SUGGESTIONS.md` were accepted and integrated into `REVISED_PLAN.md` under `ADDITIONAL SUGGESTIONS`.

Remaining optional follow-ups after this revised plan:

1. Title: Repeatable Account Reset Helper
   Type: Medium
   Why: The final reset workflow is deliberately manual and confirmation-gated, but repetition would benefit from a reviewed helper.
   Where it would apply: `TRR-Backend/scripts/` and reset evidence docs.
   How it could improve the plan: It would reduce manual SQL risk if account-scoped resets become recurring.

2. Title: Reset Evidence Template
   Type: Small
   Why: The reset/backfill phase needs before/after counts and Browser Use proof.
   Where it would apply: `docs/ai/local-status/`.
   How it could improve the plan: It would make future evidence packets consistent.

3. Title: Dry-Run Reset Counts Endpoint
   Type: Medium
   Why: Operators may need reset preview counts without direct Supabase access.
   Where it would apply: admin-only backend/app route after reset workflow proves useful.
   How it could improve the plan: It would lower operational friction while preserving delete confirmation gates.
