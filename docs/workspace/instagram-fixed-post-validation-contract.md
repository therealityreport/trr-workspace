# Instagram fixed-post validation contract

The backend owns fixed-post validation through
`TRR-Backend/scripts/ingestion/validate_fixed_posts.py`. This operator CLI does not
extend the public launch API. It uses the production scheduler, activities,
public adapters and durable persistence.

## Temporary launch restriction

The backend rejects `bravotv` full-history and resume-tail intents while fixed-post
retrieval remains unaccepted. The restriction applies to new launches, resume and
retry controls, and dispatch of existing runs. Cancellation remains available.
Bounded validation is permitted. V2 retains ownership; callers must not fall back
to a legacy ingestion route after a rejection.

The restriction is intentionally left closed after this repair. Removing it
requires a separate decision based on the recorded retrieval evidence.

## Incomplete cursors and results

`cursor_stalled` means the public source repeated a pagination cursor. Previously
committed rows and page evidence remain valid, but the lane is incomplete.
Ordinary resume does not authorize replaying the broken cursor. An explicit,
audited restart of a cancelled run's affected lane preserves its previous
checkpoint and evidence and starts that lane at its root.

Workflow state and validation status have separate meanings:

- A workflow may settle an unavailable target and reach `completed`.
- The CLI reports `retrieval_passed` only when every frozen target is committed
  with source requests, fresh retained evidence and a matching commit receipt.
- Otherwise the CLI reports `retrieval_not_passed` and exits with code 2.
- This result covers `frozen_target_retrieval_only`. The full capability matrix
  remains `not_evaluated` by the CLI: parent pagination, qualified child pagination,
  interruption/resume and fresh-session repeat require separate acceptance proof.

Clients must not convert unavailable or incomplete results into successful
comment coverage. Existing app capability and proxy consumer tests cover the
unchanged response routing; no app production build is required for this
backend/operator change.

See the dated backend record:
`TRR-Backend/docs/deploy/2026-10-20-instagram-fixed-post-validation.md`.
