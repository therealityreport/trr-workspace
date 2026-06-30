# PATCHES - Audit Change Trace

Source audit: `/Users/thomashulihan/.codex/attachments/b5ac7657-ccec-4c44-900f-1f78c4b48f72/pasted-text.txt`

| Audit Item | Status | Plan Change |
| --- | --- | --- |
| CHG-01 | accepted | Step 3 is read-only; skipped `recover-stalled` form and mutating warning added. |
| CHG-02 | accepted | Approval blocker rewritten around Modal auto-auth fallback, `MIN_GAP`, terminal acceptance, and explicit escalation approval. |
| CHG-03 | accepted | Dispatch-enabled recovery no longer promises to clear approval by itself. |
| CHG-04 | accepted | Comments-stage stale recovery added via existing repository helper. |
| CHG-05 | accepted | Failed approval jobs require explicit requeue or terminal marking. |
| CHG-06 | accepted | Dead `comments_public` selector removed; public-mode tests added. |
| CHG-07 | accepted | Tests/preflight run even for config/env changes. |
| CHG-08 | accepted | Re-verify-before-acting gate added. |
| CHG-09 | accepted | Fabricated `catalog_complete_launch_pending` constant removed. |
| CHG-10 | accepted | "Cleared" wording replaced with pending-to-started wording. |
| CHG-11 | accepted | Stop rules scoped to new years/blind redispatch while preserving diagnosis. |
| CHG-12 | accepted | Human deploy checkpoint made a hard stop. |
| CHG-13 | accepted | High-volume threshold and accepted terminal reasons defined. |
| CHG-14 | accepted | Rollback/abort section added. |
| CHG-15 | accepted | Public comments mode reframed as default lane and approval as intended boundary. |

No audit item was rejected.

## Implementation Trace

- Added a backend CLI for terminal acceptance: `TRR-Backend/scripts/socials/instagram/classify_approval_blocked_comments.py`.
- Added `approval-blocked` as a non-retryable incomplete reason in the comments Scrapling retry path.
- Added focused tests for dry-run/apply behavior and retry filtering.
- Ran a read-only dry run for child run `4f4160a4-2287-42af-8f47-27345b1c018f`; apply was not run.
