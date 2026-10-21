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


## Public exhaustion settlement candidate (2026-10-21)

Backend candidate `71841b4e` adds durable comment settlement with `basis`,
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

This candidate is **not deployed or locally installed**. Diagnostic-only Modal
v90 (`ig-auth-proof-0b6cceeb`) is deployed to
`admin-56995/trr-backend-jobs/main` and passed strict worker readiness. Its one-shot
probe returned `credential_snapshot_unavailable`, with zero Instagram requests.
All six required IDs remain unproved under the pinned `livestnation` identity.
The settlement rollout and fresh fixed-post run remain held until that proof
passes or the user explicitly revises the prerequisite. The local worker remains
on `c38d0717` with its LaunchAgent unloaded. Production stays anonymous and the
full-history gate stays closed. No schema or public app API change is required.
