# Storage ownership implementation — October 31, 2026

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-10-31
  current_phase: "Storage implementation, deployment and data reconciliation delivered"
  next_action: "Frontend release and final production acceptance in progress"
  detail: self
```

## Scope and ownership

The user authorized implementation of the corrected storage plan, then verified Google Auth and explicitly authorized the production build, push, merge, frontend deployment and production checks on October 31. Old buckets remain untouched and two-account testing stays deferred. TRR-Backend owns storage, survey submission transactions, ingestion and retained screentime processing. TRR-APP owns UI, Firebase identity verification, drafts and API adapters. The archived SCREENALYTICS repository is not required.

Existing shared checkouts and branches were retained. Unrelated edits remain untouched. Backend task commit: `bb9ded3936d27dde58df4670e18c414d4d815fd3`. App task commit: `c3d04facf1812c8248dea9e628cdcf868913180b`. Insert-only importer commit: `cf784740`. Scoped release branches were pushed; backend PR #199 is merged. Final frontend and workspace release evidence appears below.

## Delivered runtime and data

- Modal: workspace `admin-56995`, app `trr-backend-jobs`, environment `main`, app ID `ap-DkLTRoSvqhbkGO7fHyHxrD`, task deployment `v178` on October 31 at 03:52 EDT. A subsequent deployment `v179` at 03:53 EDT is current; direct container SHA-256 inspection verified that all nine changed runtime modules exactly match this task release. The API smoke checks ran against that current deployment. Source was committed base `8745a6919494fbfe45fbc95ef2e3208f4aa97c85` plus exactly the reviewed storage files in the release manifest. This avoided deploying unrelated ongoing edits.
- Modal readiness passed. Deployed health returned 200. Survey GET with a scoped synthetic absent-owner assertion returned 200 and null state; unauthenticated GET returned 401. This did not create user records.
- Firestore project `trr-web-25d2e`: draft rules compiled, deployed and read back. Ruleset `204c3da1-4100-42bb-86ef-5055ed94bd06`; source SHA-256 `c926284892363c886b5f76b666fb611165198b36c1d75dfa822d736ab912b6cb`.
- Supabase target: `vwxfvzutyufrkhfgoeaa`. Existing private-video ledger reused; no SQL schema migration.
- Video migration `0e4f437c-5b75-4c14-9e6e-324d073b3a77`: complete, 29 objects / 3,488,488,660 bytes / 55 references. All destination SHA-256 values match; all references are `db_updated`; all 29 source objects remain present. Zero source deletion or bucket-setting changes.
- Authenticated deployed playback URL returns 200 with 3600-second lifetime. Signed initial and seek range requests return 206; unauthenticated API returns 401; unsigned object request is rejected. The initial tiny test asset correctly rejected an out-of-bounds seek (416); seek acceptance used a larger migrated asset.
- New Instagram comment-page receipts use compact v2 proofs; full current target checkpoints and old-format readability remain. No historical rows were deleted or rewritten. A synthetic 1,000-comment fixture shrank from 165,772 JSON bytes to 362 (99.78%); this is not a production-disk or billing-savings measurement.

## Validation and limits

Focused backend video/runtime/subtitle checks: 47 passed. Private-storage, checkpoint/recovery, survey contract and app tests passed; affected review fixes were tested once and independently cleared. App survey regression batch: 11 passed. Lightweight app validation, TypeScript, focused lint and contract/inventory checks passed. Existing passing checks were reused for unchanged inputs.

Google Auth acceptance later passed for the existing admin account on the local `make dev-hybrid` stack and production. Local private video playback advanced successfully; production sign-in, reload persistence and logout were verified. The explicitly approved production app build passed with two workers and a 3 GB heap; subsequent app edits are test-only CI repairs. Two-account testing remains deferred. Final frontend release evidence is recorded below.

## Survey reconciliation

Read-only aggregate reconciliation found three completed legacy Survey X records and one completed episode response absent from PostgreSQL. An initial RHOP rating-conflict interpretation was superseded: RHOP has no PostgreSQL season_rating column, and the initial comparison incorrectly compared the legacy answer with a synthetic SQL NULL. Schema-aware comparison confirms its supported ranking fields match. The original Firestore rating remains preserved. One existing PostgreSQL owner is absent from current Firebase Auth and remains preserved for provenance review.

The insert-only importer applied three Survey X/profile pairs and one RHOSLC episode response on October 31 at 08:09 UTC. Original timestamps, answer payload provenance and source revision hashes were retained in PostgreSQL; Firestore writes were zero. A subsequent read-only dry run reports all five candidates as existing/matching, with no eligible missing rows. RHOP comparison uses its supported submitted fields (ranking); the legacy RHOP rating remains preserved in Firestore and was not overwritten. The importer has 13 passing focused tests, including concurrent-insert rollback and exact Firestore source-revision checks. It is an operator CLI, not a change to deployed request or worker behavior.

## Recovery and retained material

Durable task evidence resides at `.artifacts/storage-ownership-20261031`. The temporary `/tmp/trr-storage-implementation/dev-hybrid.log` is retained while the shared development services are active. Preserve the deployment manifest, deployment/readiness evidence, Firestore prior rules/release and aggregate migration receipts for closeout. The temporary expanded release snapshot was moved to actual Trash after verifying that commit `bb9ded39` and its parent reproduce the manifest exactly. The existing database ledger contains original reference values and checksums. Original objects remain in the old bucket under the user's preservation requirement.

Do not blindly roll back all runtime code to v177 after this cutover: older readers may not understand private references or compact receipts. Keep compatible private-storage readers and compact-proof readers during any writer rollback. Reference reversal requires concurrent-change checks and must not weaken the selected private delivery policy. No historical retirement or old-object removal is authorized by this implementation.

Shared handoff-index generation is blocked by the unrelated `reddit-anchor-recovery-2026-10-23.md`, which lacks its required Handoff Snapshot section. This task handoff parses successfully. The closeout wrapper stopped before policy checks; no unrelated handoff was edited.

## Production release acceptance

Backend PR [#199](https://github.com/therealityreport/trr-backend/pull/199) merged as `d78f2716d291d0246441c22350b145b282ef0976`. Required tests, Ruff, Pyright and secret checks passed. Import-order and test-type repairs passed 22 affected tests and an independent fixes-only review.

Current Modal runtime is `v180`, deployed October 31 at 15:13 EDT by the maintenance owner. Readiness passed against `main`, and Vercel production points to its API. Eight storage runtime modules match the release byte-for-byte; the ninth differs only in reviewed import ordering. No behavioral backend change or runtime rollback was introduced during Git release.

A smoke executed inside the deployed container used real PostgreSQL persistence in a rollback-only transaction: two compact v2 page receipts, two canonical comments, legacy and compact recovery, tamper rejection, and release/re-reserve continuation passed. Both receipts were 426 JSON bytes. Rollback absence was verified; zero Instagram sends or media jobs occurred. This proves deployed persistence and resume, not live Instagram retrieval or queue dispatch.

Frontend PR [#140](https://github.com/therealityreport/trr-app/pull/140) includes the storage UI and seven pre-existing social-profile test fixture/selector repairs. The seven affected cases passed. Current-head CI and production deployment are in progress.
