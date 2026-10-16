# Plan 055 production delivery — October 16, 2026

Status: production rollout delivered for the selected release; verification limits and separate face-detector follow-up retained. This receipt supersedes the October 4 and row 1/2 delivery blockers. It does not accept unrelated concurrent work or claim that every existing product feature has been tested.

## Delivered source and destinations

| Surface | Delivered identity | Evidence |
|---|---|---|
| App | Runtime source `d11cd2813df09cf05e0c4712a5c5aae31826f780`; merged in PR 134 (`7516cb5d8e8b8b66929a491100f8afd4a2cd41d2`, identical tree) | Full isolated production build passed; Vercel build passed. |
| Vercel | Team `the-reality-reports-projects`, project `prj_MHpStkwr26rV5kjt0f80zqhwZpAs`; production `dpl_GTftK96AymQheX2juaiQqXJPZ2ax` | Canonical `https://trr-app.vercel.app` moved explicitly from the stale deployment to this verified release. Source metadata and guarded project binding retained. |
| Backend | Runtime source `59ccb5f4fcd63ca804aca7deea3958c4cc3c9816`; merged in PR 190 (`c4bb4abddc62abcc64a102146bc1d5a8ce12c96f`) | Required CI passed. Ruff-only edits are AST equivalent; narrow typing corrections reviewed. |
| Modal | `admin-56995 / main / trr-backend-jobs`, app `ap-DkLTRoSvqhbkGO7fHyHxrD`, version `v55`, tag `plan055-20261016-59ccb5f4-rotated` | Explicit-target readiness and health passed; actual provider probe and YOLO workload completed. |
| Render | Secondary service `srv-d6phk5vkijhs73fcsk7g`, owner `tea-d6pglsu3jp1c73cctvf0`; deployment `dep-db8sk40n74is73cme8m0`, source `c4bb4abd` | Provider reported live; health and authenticated read returned 200. Production app dispatches to Modal. |
| Firebase | `trr-web-25d2e`; installed rules SHA256 `4324fb1929df26138b5e3a4ca5246416c82b93fd7fb78bd1ca966ccc5e7d2db8` | Installed readback matched source; trusted admin CRUD passed; ordinary-owner and denial checks passed. |
| Supabase | `vwxfvzutyufrkhfgoeaa` | Production connection verified. Existing survey tables exercised; no schema migration applied. |

App safety ancestor `b4fcbfa38b500d6ba2a8eaf34bd5b7a5f1d08246` and backend safety ancestor `a76cd1df86fdfc54fde1097623912118d03c7b17` are included. Plan 032's sanitized error path is present in this release. Current branches were retained and unrelated dirty files preserved.

Firebase remains the sign-in provider. Existing administrator/server access was preserved; tested admin routes and trusted Firestore create/read/update/delete passed. Ordinary browser clients cannot gain admin access by writing profile fields. Existing Firestore, legacy SQL, and normalized survey flows remain in place; consolidation is separate work.

## Live acceptance

- Browser: friendly TRR profile, production HTTPS origin, verified administrator. Auth/status, survey administration, full survey read and backend proxy returned 200. Secure, HttpOnly, SameSite=Lax session cookie observed. Final Shows view loaded 16 covered shows and Healthy status. An initial 5-second read timeout recovered through Retry; this is recorded rather than hidden.
- Normal Firebase fixture: login and logout succeeded; admin/proxy access denied; signed-out survey submission, foreign ownership and cross-origin session requests rejected.
- Legacy survey: two successful submissions retained exactly one SQL row and its identity. Existing answers were not touched.
- Normalized survey: valid response persisted with the correct Firebase owner and answer; reload showed the submission count and disabled further submission. Invalid question, duplicate and closed-run submissions were rejected.
- Installed Firestore rules: owner write/reload succeeded with synchronized state. Foreign/anonymous reads, client aggregate writes and privilege-field writes were denied.
- Cleanup: exactly one temporary answer, response, run, question, survey, legacy response, Firestore response and Firebase user removed; absence verified. Denied-write documents remained absent.
- Credential rotation: new internal-admin credential accepted (200), old credential rejected (403) by both Modal and Render. Vercel and local configurations aligned. Values are excluded from all shared receipts.
- Representative worker: production `run_admin_vision`, explicit YOLO mode, call `fc-01M51RV0YEB5RMWFW8R1W3N2CZ`, completed in 14.35 seconds and detected three people. This is actual inference, separate from the state-free provider-composition probe.
- Observation: final release installed at 06:54 UTC; survey/browser/API/worker observations continued through at least 07:17 UTC. No response loss or duplicate, unauthorized access, or stale-worker write was observed in these checks. No organic social scrape job completed during the sampled window; this is bounded synthetic acceptance, not a sustained load claim.

Survey persistence was verified through production HTTP and direct stored-state readback using a dedicated normal user. The browser verified administrator access and rendered data; this receipt does not claim a click-through survey UI submission, password-reset email delivery, Apple sign-in, or account linking.

## Recovery and residual work

The protected evidence directory retains exact app/backend deployment archives, source hashes, preimages, original provider identities and credential recovery material. Current compatible source was deployed successfully with the rotated credential, restrictive rules and explicit provider targets. Recovery uses the same tested guarded deployment path against these retained exact sources; no destructive fault-injection rollback was performed.

1. Verify the incident and the exact target before changing runtime state. Preserve current logs and state.
2. Use the retained `release/TRR-Backend` source `59ccb5f4` and `release/TRR-APP` source `d11cd281`, or a reviewed compatible fix. Check the recovery source receipt for byte equivalence. Keep the current rotated credential on all consumers.
3. Redeploy backend with the guarded `scripts/modal/deploy_backend.py --env main`, explicit profile `admin-56995`, and a unique recovery tag. Run the same explicit-main readiness and changed-path smoke. If Render is affected, use its verified owner/service guard.
4. Redeploy the app with its guarded `scripts/vercel.sh` to the pinned project, verify deployment binding, and explicitly check the canonical alias. Verify admin and survey persistence again.
5. Preserve the restrictive rules hash above. Never restore public read/write rules, the retired shared credential, or unfenced Modal v52 as a rollback shortcut.

The default `faces_then_yolo` workload returned an unavailable InsightFace detector during an additional check. Relevant source, image definition and dependency locks exactly match the prior v53 snapshot; prior proof covered YOLO only. Thus this is a newly observed failure in an unchanged, previously unverified lane, not evidence that this release regressed it. Default face-mode acceptance remains open. Diagnose container initialization logs and model provisioning before choosing a repair; do not change defaults or substitute model weights merely to pass a smoke test.

Retained dispositions remain explicit: six JS advisories; isolated operator cryptography exception; trusted checkpoint provenance/unrestricted loading assumption; 35 historical detail-SQL skips; giant-page lint/OOM limit; cross-identity route dedup limitation; licensing ownership and CSS emitter authority; protected output/archive receiver gates. No production media deletion or research/output relocation occurred. These retain their existing owners and do not authorize unrelated cleanup or redistribution.

Architecture reviews were reassessed individually with unchanged ceilings and bounded October 23 expiry. The historical parked-work inventory was reconciled against committed paths; newly appearing ingestion work remains outside this release.

## Evidence and publication

Private evidence root: `/Users/thomashulihan/Documents/Codex/2026-10-04/trr-055-implementation/row3-delivery-2026-10-16`. Nonsecret receipts include `survey-live-nonsecret.json`, `fixture-cleanup-nonsecret.json`, `browser-production-receipt.json`, `final-api-observation.json`, `firebase-live-receipt.json`, `representative-yolo-job.json`, `recovery-source-verification.json`, and `vercel-final-release-evidence.log`. Earlier passing checks are reused for unchanged inputs; no redundant full local suite was run.

Published implementation: [app PR 134](https://github.com/therealityreport/trr-app/pull/134), [backend PR 190](https://github.com/therealityreport/trr-backend/pull/190). Publisher repair: [app PR 135](https://github.com/therealityreport/trr-app/pull/135), merge `cdb320119be82e776c7de25be3c6b88331550eb9`. Contract documentation: [backend PR 191](https://github.com/therealityreport/trr-backend/pull/191).

The Firebase publisher now uses encrypted project service-account credentials, rejects other projects, and cleans its temporary credential file. Its existing account needed the Firebase Rules Admin role to run the required compilation check; other IAM bindings and user administration were preserved. IAM propagation delayed the first retry; a subsequent direct compilation check returned 200. The successful final GitHub publisher outcome is recorded below.

Final Firebase publisher: GitHub run `38865658475` succeeded after IAM propagation; installed rules read back at 07:18 UTC with the same reviewed ruleset/hash. No permissions were opened to ordinary clients.

Final local gates: 148 hotspot checks passed; isolated committed-candidate release classification passed (9 packets, 15 evidence records); direct-SQL inventory and workspace handoff checks passed; five affected deployment-target tests passed. The mutable shared checkout continued receiving another task's ingestion files, so its dirt inventory is a point-in-time record, not a claim that concurrent work is accepted.

Workspace publication retained the existing main ancestry, including four earlier local memory/plugin-guidance commits (`b2205f7`, `c9e7e1c`, `3d5b0cf`, `a61d549`) alongside the row 2 and release receipts. No unrelated uncommitted files were included. Backend contract documentation PR191 merged as `c1ad6b1f`; it changes no runtime code. Non-blocking full backend pytest remained in progress at the last check; required CI passed.
