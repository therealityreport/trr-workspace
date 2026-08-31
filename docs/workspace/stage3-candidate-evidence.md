# Architecture Cleanup Exact-Cohort Candidate Record

Recorded locally on 2026-08-31 at 19:34 EDT and last validated at 19:46 EDT.

Evidence cohort: workspace foundation `a9ae98ac32799fe561b57121ed9a89241448ef56`, backend merge `a01bf8442302a7e63c034a462c072c7e23352c0c`, and app merge `4d05b1f12b155d5561eeea67220c8bfe14530585`.

The backend merge has the same tree as source candidate `4c2e940eaf01b9970dd3483ce779c7cdaed5cff3`. The app merge has the same tree as source candidate `d3184441dc9302a53c65eb90b4bd023644034029`. This record proves source, local validation, GitHub publication of the backend/app candidates, and the read-only Production baseline below. It does not claim Preview acceptance, Production alignment, Production deployment, browser acceptance, or observation-period completion.

| Checkpoint | Result | Evidence |
| --- | --- | --- |
| 1. Evidence foundation | Pass | `expected_state` now distinguishes files that must exist from files intentionally deleted by the release. Missing files fail by default. An intentional deletion is accepted only when Git proves a base blob, candidate absence, and a base-to-candidate deletion. The complete 183-test architecture guard run passed. The selected evidence branch contains only the approved architecture files; the 207 unrelated deletions and untracked session log in the original workspace remain untouched. |
| 2. Release packets | Pass | The nine active packets are bound to the exact evidence cohort above. Six stale backend path names were replaced with their current `20260805` files, and exactly three app paths are classified as intentional deletions. Candidate SHA, owned-path manifest SHA-256, and binary tracked-diff SHA-256 values reproduced successfully: `architecture-release-manifests: OK clean-candidate packets=9 evidence=15`. Superseded Preview/Production history is unchanged. |
| 3. Existing source validation | Pass | The tree-equivalent source candidates previously passed the complete 511-file app test run, lint, TypeScript, a guarded full local production build with 104/104 static pages, backend/API contract checks, architecture guards, and hosted checks. No new app or backend product source changed in this evidence branch, so a second full local app production build is neither required nor authorized. |
| 3a. Current evidence validation | Pass | The current cohort passed 183 architecture guard tests in 302.02 seconds, including all 120 release-manifest validator tests. Candidate durability passed `46/46`, evidence hygiene passed for 28 files, the hotspot ceiling passed for 148 tracked files, and deployment-target validation passed. Backend and app import graphs reported zero cycles. The checked-in OpenAPI contract and generated app types are current, the direct-SQL inventory check passed, and the unchanged app passed its quick validation with 3 test files and 14 tests. |
| 4. GitHub publication | Pass for backend/app | [Backend PR #186](https://github.com/therealityreport/trr-backend/pull/186) merged as `a01bf8442302a7e63c034a462c072c7e23352c0c`. [App PR #131](https://github.com/therealityreport/trr-app/pull/131) merged as `4d05b1f12b155d5561eeea67220c8bfe14530585`. The workspace evidence PR is a separate publication step and is not represented as merged by this local candidate record. |
| 5. Production reconciliation | Pass, read-only | The exact Supabase, Vercel, Render, and Modal targets were inspected on 2026-08-31 without deployment, alias, database, environment, job, or service mutation. The baseline below shows that Vercel's public alias and both backend runtimes do not yet use the exact evidence cohort. |
| 6. Protected Preview | Blocked before creation | No Preview resource was created. A new unchanged Supabase branch attempt is prohibited after repeated `MIGRATIONS_FAILED` results, the hard cross-provider `$5` cap is not currently enforceable, the Modal billing guard is weakened by a break-glass environment value and fails five guard tests, the repository lacks a reviewed four-provider teardown watchdog, and the guarded Render CLI path lacks `TRR_RENDER_API_KEY`. |
| 7. Production result | Not run | Production alignment, deployment, rollback execution, and observation remain separate decisions after a successful protected Preview. Production was not changed during this work. |

## Read-only Production baseline — 2026-08-31

| Provider | Exact target | Observed state | Restore/pre-change receipt |
| --- | --- | --- | --- |
| Supabase | `vwxfvzutyufrkhfgoeaa` | Only default branch `main` (`ab2fc1bb-05e5-4976-a7b8-4e04852e6fac`) exists. The linked ledger has 311 local/remote pairs, zero mismatches, through `20260806133000`. | Project, default branch ID, and 311-entry ledger. This proves migration parity, not application-data health. |
| Vercel | team `team_EUsG2kN9TAvVDGOu4yZVEoCX`, project `prj_MHpStkwr26rV5kjt0f80zqhwZpAs` | Newest Production-target deployment `dpl_D9a37zNKkgvhTSCRvHCiDhdfVboa` is READY/STAGED at app merge `4d05b1f12b155d5561eeea67220c8bfe14530585`. Public alias `trr-app.vercel.app` still resolves to READY/PROMOTED deployment `dpl_J47i25Sny5zd1j7FUyaScCRF459J` at older app commit `c9b842d958c2d46623c4bf112d251df99d364012`. | Preserve the public alias binding and both deployment IDs; immediately preceding listed deployment is `dpl_GLwQC1MSSLVtVL47rRv9TM2LLV9r` at `3c922bfb241eb5245f8f42757b991687c23023b1`. |
| Render | owner `tea-d6pglsu3jp1c73cctvf0`, service `srv-d6phk5vkijhs73fcsk7g` | Authenticated read-only connector inspection found live deployment `dep-da47kduk1f9s73arq0r0` at backend commit `e92e06dbbcb6125797ff7e552eded468c46da1da`. Auto-deploy and Preview generation are off. | Current live deployment ID/commit; prior deactivated deployment `dep-d9tnb59t0dsc73bnfe20` at `97f0eefc319e11f3df3fc24a3cab1e43497f18ca`. |
| Modal | profile/workspace `admin-56995`, environment `main`, app `trr-backend-jobs` | Current version `v42` was deployed from backend commit `e92e06dbbcb6125797ff7e552eded468c46da1da`; no active tasks were observed. | Current `v42`; prior `v41` at `6d71e83fe97303710d6afc8ab720b87375c0e89a`. |

This table is a timestamped baseline, not Preview or Production acceptance. It contains no credential values. The Render connector closed the live read-only identity gap, but the repository's guarded Render CLI remains unavailable until the exact API credential is present.

## Current protected Preview gate

The accepted Preview shape remains an empty temporary Supabase, Render, Modal, and Vercel stack, with forced teardown beginning at 75 minutes and terminal absence by 90 minutes. Execution is not currently approved because its mandatory preconditions are false:

- Diagnose or obtain a provider-confirmed change to the Supabase branch replay path before another attempt; do not repeat the unchanged `MIGRATIONS_FAILED` workflow.
- Supply an enforceable aggregate `$5` ceiling, or explicitly approve a different measurable cost boundary.
- Repair and revalidate the inert Modal Preview guard without the break-glass override.
- Provide the exact Render credential for the guarded local workflow and add reviewed temporary create/cancel/delete handling.
- Add a reviewed watchdog that records every temporary ID, starts teardown at 75 minutes, and proves exact-account absence by 90 minutes.

Until those items are closed, there is no Preview run ID, no cost approval receipt, and no E13 successor.

The ordinary clean-candidate target must discover this exact active inventory without a special packet-selection override. The explicit command below documents the required nine-packet/15-evidence membership:

```text
TRR-Backend/.venv/bin/python scripts/architecture/check-release-manifests.py --clean-candidate \
  --packet docs/workspace/release-packets/local-foundation-runtime-guards.json \
  --packet docs/workspace/release-packets/local-identity-canonical-routes.json \
  --packet docs/workspace/release-packets/local-covered-shows.json \
  --packet docs/workspace/release-packets/local-networks-streaming.json \
  --packet docs/workspace/release-packets/local-recent-people-external-ids.json \
  --packet docs/workspace/release-packets/local-person-media.json \
  --packet docs/workspace/release-packets/local-season-survey-roles.json \
  --packet docs/workspace/release-packets/local-social-freshness.json \
  --packet docs/workspace/release-packets/local-show-presentation-extractions.json \
  --evidence docs/workspace/architecture-evidence/local-foundation-runtime-guards.workspace-focused.json \
  --evidence docs/workspace/architecture-evidence/local-identity-canonical-routes.app-focused.json \
  --evidence docs/workspace/architecture-evidence/local-identity-canonical-routes.backend-focused.json \
  --evidence docs/workspace/architecture-evidence/local-covered-shows.app-focused.json \
  --evidence docs/workspace/architecture-evidence/local-covered-shows.backend-focused.json \
  --evidence docs/workspace/architecture-evidence/local-networks-streaming.app-focused.json \
  --evidence docs/workspace/architecture-evidence/local-networks-streaming.backend-focused.json \
  --evidence docs/workspace/architecture-evidence/local-recent-people-external-ids.app-focused.json \
  --evidence docs/workspace/architecture-evidence/local-recent-people-external-ids.backend-focused.json \
  --evidence docs/workspace/architecture-evidence/local-person-media.app-focused.json \
  --evidence docs/workspace/architecture-evidence/local-person-media.backend-focused.json \
  --evidence docs/workspace/architecture-evidence/local-season-survey-roles.app-focused.json \
  --evidence docs/workspace/architecture-evidence/local-season-survey-roles.backend-focused.json \
  --evidence docs/workspace/architecture-evidence/local-social-freshness.backend-focused.json \
  --evidence docs/workspace/architecture-evidence/local-show-presentation-extractions.app-focused.json
```

Result: `architecture-release-manifests: OK clean-candidate packets=9 evidence=15`.

## Historical E13 addendum — preview prerequisite attempt (2026-08-19)

Status: **failed/incomplete; all temporary resources removed**.

At that time, the candidate was rebound to workspace `a991d0f01671c50da0515a75a4694d914d9d251b`, backend `e92e06dbbcb6125797ff7e552eded468c46da1da`, and app `c9b842d958c2d46623c4bf112d251df99d364012`. Before preview work, the backend migration regression suite passed `3/3`, the combined focused backend suite passed `153/153`, app quick validation passed `3` files and `14` tests, the import graph had zero prohibited cycles, the 148-file hotspot ratchet passed, clean-candidate validation passed with nine packets and 15 evidence records, and candidate durability passed `46/46`.

Three bounded attempts stopped before Modal or Vercel preview creation:

- Branch `03c26a95-10ca-4068-bd38-fd9d9016fb73` (`azpcptzpofoepxubykup`) was created and deleted after the exact `TRR` Chrome connection reset during Vercel preflight.
- Branch `6d5f52af-41e5-4c00-96d2-711d52ecc8ab` (`kjtnhpvvpcuxqhayikvp`) was created and deleted when the branch-detail credential response could not be safely consumed under the first evidence-handling contract.
- Final branch `3a563215-0723-454f-b184-a6b6ad8e9d15` (`doxrzezlkycftemmurxc`) passed the recovered `TRR` Chrome gate but entered `MIGRATIONS_FAILED` during Supabase provisioning. It was deleted by exact ID.

Post-cleanup inventory contained only production Supabase `main` (`ab2fc1bb-05e5-4976-a7b8-4e04852e6fac`), production retained 311 migration receipts, and protected Modal production remained app `ap-DkLTRoSvqhbkGO7fHyHxrD` version `v41`. No Modal preview environment, app, or secret; Vercel deployment, alias, or token; Render resource; production provider mutation; or production data/schema mutation occurred. The total quoted branch rate was `$0.01344/hour` per short-lived branch, with each attempt removed promptly.

E13 therefore did not pass. The Supabase failure remains unresolved, and the current gate above records the additional cost, guard, credential, and teardown conditions now known. Production deployment and E14 remain prohibited until a separately authorized run produces a successful Preview and teardown receipt.
