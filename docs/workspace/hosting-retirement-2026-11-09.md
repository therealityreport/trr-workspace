# Vercel + Modal hosting and Render retirement

Record date: 2026-11-09. This record distinguishes provider observations from
repository standardization. No first-traffic cutover date has been established.

## Official architecture

`Vercel trr-app -> Modal serve_backend_api -> Supabase trr-core`

Modal also runs asynchronous backend jobs. Production identities:

- Vercel team `team_EUsG2kN9TAvVDGOu4yZVEoCX`, project
  `prj_MHpStkwr26rV5kjt0f80zqhwZpAs` (`trr-app`).
- Stable application alias: `https://trr-app.vercel.app`.
- Production server-side `TRR_API_URL`: `https://admin-56995--trr-backend-api.modal.run`.
- Modal `admin-56995` / `main` / `trr-backend-jobs`; API `serve_backend_api`.
- Supabase project `vwxfvzutyufrkhfgoeaa` (`trr-core`).

Owning contracts: [deployment targets](deployment-targets.json),
[environment contract](env-contract.md), and
[backend deployment guide](../../TRR-Backend/docs/deploy/modal.md).

## Dates and provider evidence

- Render's service event history records `trr-backend-api`
  (`srv-d6phk5vkijhs73fcsk7g`) suspended on **2026-10-31 at 03:03**
  in the dashboard's displayed time. The dashboard timezone was not established.
- The latest successful Render deployment shown was commit `c4bb4ab` on
  **2026-10-16 at 02:55**, in the same displayed time.
- On **2026-11-09**, Vercel Production `TRR_API_URL` was verified after its
  passkey check. It points to Modal. The authenticated Vercel operations-health
  route worked through that API while the old Render health endpoint returned 503.
- Repository contracts and active deployment instructions were standardized on
  **2026-11-09**. These observations do not prove when Vercel first changed hosts.

Provider records: [Render service events](https://dashboard.render.com/web/srv-d6phk5vkijhs73fcsk7g/events),
[Render billing](https://dashboard.render.com/w/tea-d6pglsu3jp1c73cctvf0/billing).

## Billing decision

Read-only billing review on 2026-11-09 found:

- Render workspace plan: Hobby, no recurring workspace fee.
- November projected total: **$0.00**.
- October 2026 unpaid invoice: **$31.27**. September and August invoices are paid.
- The retired API service remains suspended.

No paid workspace subscription needs cancellation. Keep the free account for the
unpaid invoice and billing records. No invoice was paid, no service was resumed,
and no account or provider data was deleted during this task. The remaining
invoice is separate from TRR's ability to run without Render.

## Stale show-refresh investigation

Operation `6b617b00-9e73-44c8-b2bb-dfbf0da16424` targets show
`7782652f-783a-488b-8860-41b97de32e75` (`show_core`). It started on
2026-10-22 at 07:10:41 UTC; its last heartbeat was 07:55:40 UTC.
It had no claim token, lease, worker, terminal result, or child operation.

The approximately 45-minute duration matches the current Modal admin timeout.
The historical provider cancellation event is unavailable, so timeout is a likely
cause. Source reproduction confirmed that Modal cancellation bypasses the
ordinary `Exception` handler. The old `finally` released its claim without a
terminal state. The repair records an owned interrupted claim as failed, or as
cancelled if cancellation was already requested, then propagates the interruption.

Stale cleanup now also compares the selected heartbeat and claim snapshot during
its update. A renewed job is skipped. The live repair is restricted to this one
operation; unrelated stale operations are outside this task.

## Completed deployment and scoped repair

- Modal app `ap-DkLTRoSvqhbkGO7fHyHxrD`, version **v188**, tag
  `stale-refresh-retirement-20261109`, environment **main**; deployed
  2026-11-09 at 01:56:08 -05:00.
- Source export: current Backend revision `7b5dd01a49306ef54adaf97a1df6023ba9eb04c8`
  plus the two reviewed admin-operation source files listed below. The export
  retained current committed provider-initialization work. Separate unfinished
  media-storage changes stayed in the shared checkout and were excluded.
- The maintained deployment wrapper completed readiness, maintenance ownership
  and schedule verification, and the API cold-start canary (HTTP 200, first attempt).
- Maintenance remains Modal singleton cron: executor heartbeat each minute,
  social queue sweep every two minutes, timezone `America/New_York`.
- `/health/live`, `/health`, and `/health/runtime` each returned HTTP 200.
  `probe_admin_operation_runtime` returned healthy with claim and heartbeat support.
- A guarded, single-statement Supabase repair required the exact operation ID,
  type, show, unchanged October heartbeat, empty claim/lease, no children, and no
  new event. It atomically set `cancelled` and added terminal audit event **9**.
  No schema migration or direct-SQL ownership changed.
- Repair completed at **2026-11-09 06:58:45.414661 UTC**. The other 78 active
  operation records retained the same status/timestamp fingerprint before and after.
- The authenticated production Vercel operations-health route worked after deploy.
  The selected operation GET returned `cancelled`, its completion timestamp, and
  `latest_event_seq: 9` through `https://trr-app.vercel.app`.
- A deployed `run_admin_operation_v2` smoke for that terminal operation returned
  `claimed: false`; no replacement show-refresh was started.

The interruption handler is best effort for cancellation that reaches Python.
An abrupt container kill can still prevent database cleanup. The historical
45-minute timeout remains an inference, not a verified provider event.

## Validation and recovery

- Initial focused backend repository/router/external-runtime checks: 53 passed.
- Added actual Modal cancellation cases passed. After review fixes, affected
  interruption/heartbeat checks: 19 passed, 20 deselected. Unaffected passing
  checks were reused. Ruff passed all edited Python modules.
- Workspace target/runtime tests: 28 passed; runtime-capacity/profile: 15 passed;
  release compatibility and successor/historical fixture checks: 4 + 4 passed.
- Independent review returned two blockers (cleanup exception preservation and
  remaining active Render runbook instructions); both were fixed together and
  the reviewer confirmed closure. No remaining review blocker.
- TRR-APP behavior did not change; its deployment documentation was updated.
  A production app build was not applicable.
- Browser verification used live Vercel production in the TRR Chrome profile.
  No local startup target was used.
- Historical Render release packets remain unchanged. Git retains the retired
  blueprint and wrapper source. Their obsolete working copies were moved to Trash.

Rollback is available through prior Modal version **v187**:

```bash
MODAL_PROFILE=admin-56995 MODAL_WORKSPACE=admin-56995 MODAL_ENVIRONMENT=main \
  .venv/bin/python -m modal app rollback ap-DkLTRoSvqhbkGO7fHyHxrD v187 --env main
```

Run this from `TRR-Backend` only if rollback is needed, then repeat target readiness
and the affected health/worker check. The selected operation's cancellation and
terminal audit event remain durable; do not restore it to running.

Task-only source hashes at deployment:


- `trr_backend/pipeline/admin_operations.py`: `ed466496e8892f6797d67442fbc60b2f06c76353cadfcbf25e11172014b159a9`.
- `trr_backend/repositories/admin_operations.py`: `ea20d279f806280fee6dde41139f6130ef57d8c9b57da76f8d44e1717a441289`.

Local implementation commits:

- Backend: `c8e305c5a941c675d9e491bff4f58b3bf588d8dc`.
- App deployment documentation: `7dacb80b6d79db7a61e7cf2284187adc4599b34c`.

Private pre-edit snapshots are retained at
`/Users/thomashulihan/.codex/tmp/command-guard/45dd736d-d90b-4b7a-86a9-19041794cda9/baseline`
and
`/Users/thomashulihan/.codex/tmp/command-guard/37605195-1371-469d-8498-d310d64044f4/baseline`.
They preserve pre-existing shared-checkout documentation hunks, including the
superseded Render guide introduction. Keep them until those separate documentation
edits are integrated or deliberately retired. Deployment source is reproducible
from the recorded revision and committed source hashes; its temporary export can
be removed after the verified deployment. No temporary branch or worktree was created.
