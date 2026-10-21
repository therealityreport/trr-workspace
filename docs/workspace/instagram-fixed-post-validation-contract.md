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

## Bounded capability acceptance follow-up (2026-10-21)

The subsequent anonymous pass remains incomplete. Older account listing returned
HTTP 401 before any accepted native page; `public:local` entered backoff until
2026-10-21 22:26:25 UTC. A native 169-reply parent was identified for the normal
12-item child page size, but live multi-page proof is held by that cooldown.
The two known GIF comments remain saved with media URLs and no text, with fresh
accepted-run provenance; both still have zero hosted URLs.

The exact-photo media-only guard returned `held/local_public_lane_cooldown`
before creating a run. Review also identified generic-public media fallback
gates that do not share the local public lane; that source finding is not yet
fixed in the deployed runtime. Admin display was unverified after a filtered
post query timed out and the shared dev stack restarted. Passing recovery
and fresh fixed-post evidence is reused. Full-history stays closed pending
review and completion of the missing live evidence. Details are recorded in
backend commit `3f6d13ed` and the dated backend validation record.

### 2026-10-21 repair and bounded rerun

Media fallback gates now use their actual public network lane. The installed
local release already contains that repair. Backend commits `86777542` and
`f3d26caa` repair searched and unfiltered comment-profile reads; both paths were
verified in the TRR admin UI. The unfiltered request returned HTTP 200 in 15.6
seconds after previously timing out. Workspace `06ad556` fixes the reproduced
Bash 5.3 billing-guard startup hang without changing billing policy.

Fresh native multi-page child proof now exists for `C_aw2xGs-Uf`, parent
`17900330799028205`: two productive pages, 20 distinct replies, exact native
cursor continuation, and child exhaustion. The diagnostic stopped with the whole
post still partial. No canonical or evidence rows were written by that probe.

Acceptance is still incomplete: anonymous older-post listing returned HTTP 401
with `public_access_backoff`; the selected media-only comments expose known
placeholder URLs and have no real hosted GIF assets. The media-only run ended
`media_source_placeholder`. Do not claim older discovery or GIF display passed.
No authentication, proxy, cooldown reset or full-history run was used. The frozen
original is unchanged, no active unresolved owners or uncertain dispatches
remain, and every new budget tranche is closed. See the backend validation
record's evening repair section and private `repair-rerun` evidence.

Final deployment: Modal v97, tag `ig-acceptance-f3d26caa`, explicitly
`admin-56995 / trr-backend-jobs / main`. Health, readiness and source-only runtime
smoke passed. The final frozen manifest preserves the maintained source already
present in v96; six module hashes match, Reddit v2 remains enabled, and both
public lane keys are correct. Archives and preceding deployment are retained.
No SQL migration or app source/build change was required.
