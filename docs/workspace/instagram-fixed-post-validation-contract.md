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


## Public exhaustion settlement (2026-10-21)

Backend implementation `71841b4e` adds durable comment settlement with `basis`,
`expected_total`, `observed_total` and `count_gap`. The gap is
`max(expected_total - observed_total, 0)`. Existing count parity includes counts
above the reported total. Public-native exhaustion may settle a positive gap
only for version-1 public Relay with durable root-start proof, native exhaustion,
complete child lanes, valid reply counts and topology, and the existing source,
retained-evidence, cutoff and ownership guards. Root-proven resume remains
eligible; missing root proof and authenticated REST gaps remain unresolved.
Settlement is saved atomically in the checkpoint and commit receipt. Inspection
reads it from the same fresh receipt used by existing validation checks; legacy
receipts may report null. New committed comment targets include settlement.

`retrieval_passed` means the frozen targets met this retrieval policy with fresh
matching evidence. It does not establish universal comment coverage.
`is_missing` means absent from the qualifying scan's visibility, not proven
deleted from Instagram. Residual gaps may reflect visibility differences or
unresolved count semantics; neither explanation is established for every gap.
The live multi-page child criterion remains unverified.

The user explicitly removed the authenticated six-ID prerequisite on 2026-10-21.
Acceptance now uses the anonymous public retrieval policy above. Authenticated
retrieval is not required for this rollout; the earlier unavailable-credential
diagnostic supplies no comment-coverage evidence.

Settlement source is deployed as Modal v91 (`ig-public-settle-c1c15970`) on
`admin-56995/trr-backend-jobs/main`, from byte-verified source
`c1c159705b36860914817daedc647ef274fa15fd`. Strict worker readiness and a
state-free settlement smoke passed; all five schedules are unchanged. The
matching local release is installed with its LaunchAgent unloaded and `c38d0717`
retained for rollback. Fresh fixed-post run
`9ab92d4f-578d-4a42-b2d4-153d1ca6a478` uses a new manifest/state and the existing
shared request ledger. It completed with `retrieval_passed`: all six targets have
fresh matching receipts, and all three comment checkpoints match their receipt
settlement metadata. Actual counts and final audit results are in the dated
backend record.
Production stays anonymous and the full-history gate stays closed. No schema or
public app API change is required.
