# Reddit capture v2 implementation

## Handoff Snapshot

```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-10-22
  current_phase: "Manual preseason-gap capture and Episode 6 refresh completed and verified"
  next_action: "None; schedules and AI processing remain disabled"
  detail: self
```

Authority: approved full six-release plan in current chat. Contract:
`docs/workspace/reddit-capture-contract.md`.

- [x] Capture/comment/media correctness and additive migrations
- [x] Coverage, ownership, dispatch and retry durability
- [x] Unified transport and episode discovery
- [x] Operator UI and disabled-by-default schedules
- [x] New-capture lifecycle and manual legacy tools
- [x] Deterministic and disabled-by-default AI analysis
- [x] Focused tests, independent review, browser verification
- [x] Target-verified migration/deployment/canary; task-only commits

Constraints: future runs only; no automatic historical repair/cleanup; no schedule or
AI activation. Preserve pre-existing dirty files. Lead owns all integration and deployment.
Baseline audit: 79 backend tests passed; reproduced missing retries and false completion.

Runtime: additive migrations 20261021210000/20261021210100 applied to
`vwxfvzutyufrkhfgoeaa`. Modal `admin-56995/main/trr-backend-jobs` deployed
from backend `22ae7a68` plus the task manifest, compatible reader v92 then
capability-enabled release v94. Readiness and API cold-start canaries passed.
Discovery canary `0d760c98-c8f0-4185-b50e-71b152ff302c` saved three posts
with a proven 24-hour boundary. Detail canary
`5c247c57-3c2b-4786-859b-6ed9945697b2` saved six comments and two assets.
No unresolved targets. All schedule/AI settings remain disabled; zero legacy
enrollments. Rollback preserves schema/evidence; v91 is the prior release.

Source checks: focused backend unit and isolated PostgreSQL regression batches,
app route/component tests, quick validation, typecheck, generated contract checks,
and the explicitly approved production build passed. Independent review fixes
were checked in focused follow-up tests. Browser verified capture status, run selection, targets and disabled settings with
`make dev-hybrid` and the TRR profile. Follow-up browser verification on 2026-10-21 confirmed expanded requested/observed
boundaries, completion reasons, and all four detail-target disclosures. Empty lists
now show “None”; unavailable fields show “Not recorded”; absent retry times show
“Not scheduled”. The eight focused component tests and scoped ESLint passed after
this display fix. Live canaries had no unresolved children; that branch remains
covered by the component regression fixture.

Operator runbook: `TRR-Backend/docs/reddit-capture-v2-operations.md`.
AI quality: four synthetic fixture checks and four injected regressions; live model
quality remains unmeasured and no paid AI calls ran. Legacy shared storage objects
remain visibly unresolved until cross-platform reference safety is established.

## Closeout

- Backend commit: `3c5f13dd` (34 task-owned files).
- App commit: `7c9b718c` (41 task-owned files).
- Runtime: Modal v94, `main`, tag `reddit-v2-enabled-22ae7a68`.
- Automatic dispatch canary: `d34a9379-bff5-4e13-b96c-a83564943378`, completed
  by reusing existing successful comment/media captures.
- Deterministic analysis canary: `899338d4-bed1-4927-b1dd-bafe1f8e3973`, completed
  on one post and six comments with coverage/source metadata.
- Deployment source manifest and runtime receipt are committed in backend
  `docs/deploy/2026-10-21-reddit-capture-v2*`.
- Temporary deployment candidate and empty failed candidate moved to actual Trash
  after matching their source against committed files. No task branch/worktree was created.
- Existing unrelated edits remain unstaged. No Git push. Production app deployment
  completed in the explicitly authorized follow-up below.
- Hybrid workspace remains running for the user.
- Helper routing telemetry could not reconcile the native launch record; source/test
  acceptance uses the independently checked work and passing tests, not that telemetry.

## Production UI follow-up — 2026-10-21

- User explicitly authorized production deployment and browser verification.
- App source: `0e673fd11c1df1737dd5f094571afdfeae71e2a2`, exported from committed
  source; all 41 Reddit files matched the verified checkout. Unrelated local edits excluded.
- Vercel project `trr-app` (`prj_MHpStkwr26rV5kjt0f80zqhwZpAs`), team
  `team_EUsG2kN9TAvVDGOu4yZVEoCX`, environment `production`.
- Deployment: `dpl_3aWe6NR7KqBwoWt6HFmuZNtv7fAu`, READY.
  URL: https://trr-i3bg35x6q-the-reality-reports-projects.vercel.app
- Cloud production build passed compilation, TypeScript, all 104 static pages and
  output deployment. Prior focused tests were reused on unchanged source.
- The short production alias initially retained the old deployment. Reassigned
  `trr-app.vercel.app` to the new deployment and verified provider readback.
- Browser proof: friendly TRR Chrome profile, authenticated production page
  https://trr-app.vercel.app/summer-house/s10/social/reddit . All three coverage
  disclosures and four detail target disclosures opened successfully. Requested
  and observed boundaries, boundary_reached, six comments, two detected assets,
  None/Not recorded/Not scheduled labels and disabled schedule/AI settings verified.
- Live targets have no unresolved children; unresolved-child rendering retains the
  component fixture evidence. No new capture, maintenance or AI jobs were submitted.
- Rollback target retained: `dpl_3xUuchVT3jtTRYe9b6xKX7SiSpLW`; restore the short
  production alias as well as the project release if rollback is needed.
- No backend or SQL changes; existing Modal deployment remains applicable.
- Production browser tab left open with expanded evidence.
- Task-created production source snapshot and failed empty snapshot moved to actual
  Trash after deployment and browser verification; committed source and Vercel
  rollback deployment retain recovery. No temporary branches/worktrees remain.


## RHOSLC Season 7 bounded production capture — 2026-10-21

- Requested scope: a small production sample for Season 7 so far; schedules and AI remain disabled.
- Verified target: Supabase `vwxfvzutyufrkhfgoeaa`; Modal `admin-56995/main/trr-backend-jobs`.
- Community: `r/rhoslc` (`a9bb355f-4cdd-4d8d-94dd-06a55ae303f2`);
  Season 7: `20c4cc05-0ab1-433f-b2fd-848f0d46a250`.
- Discovery run `86422c24-8fe8-419f-a4ab-9f216cb1896a`: partial, 100 posts,
  one chronological listing page, two committed discovery targets. Requested window
  2026-09-16T04:00:00Z through 2026-10-21T22:48:15.140961Z; observed timestamps
  2026-10-15T11:48:37Z through 2026-10-21T21:56:30Z. Evidence correctly reports
  `page_budget_exhausted` and `chronological_boundary_proven=false`. This is a
  temporal community sample, not a complete season archive or a semantic S7-only set.
- Detail run `65ae388d-50c5-46dc-bf3c-f697d66ece13`: completed for selected posts
  `1xc0q1q` and `1x9csx1`. Saved 8 + 11 comments with no unresolved child IDs;
  six detected media assets committed. All ten detail targets committed (two comment,
  two parent media and six asset targets). Discovery coverage is correctly
  `not_requested` for this detail-only run.
- Repository settings readback after completion: schedule_enabled=false,
  ai_enabled=false, scheduled_analysis_enabled=false. No settings row was created,
  and no schedule or AI activation was performed.
- Browser verification found missing explicit undated-season selection and broken
  season/community aliases. App commit `277e87c969581eb98718b02b9663e677fd9e94b1`
  preserves explicit season selection, supports both admin community URL forms,
  and routes bare season aliases into the admin workspace on single-host production.
- Focused validation: 19 proxy tests, 13 community-view tests, 3 actual manager
  tests, targeted ESLint, typecheck and generated API inventory check passed.
- Local browser on the existing `make dev-hybrid` workspace confirmed the requested
  `/rhoslc/season-7` opens Season 7 and the community page retains both UUIDs,
  shows the new runs, and leaves settings disabled. Season metadata remains a
  placeholder with no episode air dates; capture did not modify show metadata.
- Production app deployment `dpl_7AiLPurG2DkH6pXAoCCxg5CdPbnc` is READY from
  the committed source snapshot. Compilation, TypeScript and 104 static pages passed.
  Reassigned `trr-app.vercel.app` and confirmed provider readback points to this release.
  Rollback remains available as `dpl_3aWe6NR7KqBwoWt6HFmuZNtv7fAu` (including
  restoration of the short alias).
- Production browser acceptance on the TRR Chrome profile: `/social/reddit` loads
  and selects rhoslc; `/rhoslc/season-7` resolves to the Season 7 workspace; the
  Reddit season selector retains S7; the community link opens
  `/social/reddit/rhoslc/rhoslc/s7` with the correct season and community.
- Both coverage disclosures match stored boundaries/reasons. All ten detail target
  disclosures opened; comment saved counts are 11 and 8, unresolved IDs None,
  no pending continuations/errors, and parent media targets each report 3 assets.
  The UI shows zero unresolved targets and all three schedule/AI switches off.
- Backend/API: existing deployed capture worker completed both requested phases;
  all four post/phase state rows committed with successful timestamps. No backend
  source, schema or direct-SQL ownership changes, so no new Modal deploy was needed.
- Both discovery target disclosures also passed: listing and page targets committed;
  listing stopping reason `page_budget_exhausted` and no scheduled retry.
- Production browser left open on expanded coverage. Screenshots saved for season,
  coverage and target evidence. Task-created deployment snapshot moved to actual
  Trash after its eight task files matched committed source; rollback release retained.


## Full RHOSLC Season 7 production capture — capture and recovery record

- User requested all remaining posts, comments and media, with schedules and AI disabled.
- Editing owner: lead in the existing root `main` checkout at `26bdd84f8c77aeb32a6de40d59bac53ba5779714`;
  owned path is this existing status record. Other dirty root/backend/app files are preserved.
- Supabase `vwxfvzutyufrkhfgoeaa`, Modal `admin-56995/main/trr-backend-jobs` verified live;
  worker probe reports healthy OAuth, reachable, no cooldown/block.
- Fixed request cutoff: `2026-10-21T23:06:47.895435Z`. Window begins 2026-09-16T04:00:00Z.
- Discovery `9a941344-1111-49e8-a662-888ad074cda1` completed with positive chronological boundary evidence:
  5 listing pages, oldest observed 2026-09-14T05:59:54Z, `boundary_reached`,
  `chronological_boundary_proven=true`, no coverage reasons. Saved 383 additional
  period assignments; 100 existing sample assignments retained, 483 distinct window posts.
- Five detail batches requested through the existing two-worker production limit,
  policy `missing`, comments and media phases. Existing confirmed captures are reused.
- Detail run `dfd8901a-dd5d-4a0a-a936-29b3f3b5b742`: 100 selected posts, period `rhoslc-s7-small-production-20261021`.
- Detail run `05cd944e-58d1-48d4-ad9d-ff27e3422bd3`: 100 selected posts, period `rhoslc-s7-full-production-20261021`.
- Detail run `f70eb01d-03c3-4fad-8710-c062e5eae0fd`: 100 selected posts, period `rhoslc-s7-full-production-20261021`.
- Detail run `6c7b35c7-e72e-4810-9f54-e5f01b66194e`: 100 selected posts, period `rhoslc-s7-full-production-20261021`.
- Detail run `22b710ae-172b-441c-9afb-8a2b59293f66`: 83 selected posts, period `rhoslc-s7-full-production-20261021`.
- Initial checkpoint: comment/media completeness and production browser acceptance were pending.
- Recovery: production batches exposed no-ID comment continuation markers at depth 10.
  The current worker records these conservatively but never fetches their subtree.
  Lead owns the backend transport and its focused tests in the existing backend
  checkout, branch `chore/repo-hygiene-2026-09-25`, base `972836af`.
  A read-only helper is investigating the protocol independently. All unrelated
  maintained deployed v97 overlays must be retained when preparing the repair release.
- Recovery releases: `cfcc40c2` follows no-ID continuation parents through the
  documented focal-comment endpoint, with atomic checkpoints and a shared request
  budget. 62 transport tests and three live checkpoint probes passed; independent
  review found no blockers. The probes recovered 275→280, 143→145 and 22→32 comments.
- `c4a5b305` resolves Tenor GIF sharing pages to verified HTTPS provider media URLs;
  original source identity is retained and binary mirror validation remains active.
  Twelve affected media tests initially passed; the HTTPS fix added a passing
  regression (11 resolver tests). Independent fix-only review closed that finding.
- `f2a9d3bf` plus formatting `1f62b059` raises the finite Reddit asset limit to
  100 MiB after a real 69,578,496-byte native GIF exceeded 50 MiB. The affected
  upload-failure/finite-limit regression and Ruff passed.
- The candidate preserves all 63 verified v97 source overlays. Two newer unrelated
  working-tree media-reuse edits differ from that accepted snapshot and remain
  untouched/excluded. Both repair releases use `admin-56995/main/trr-backend-jobs`;
  the latest tag is `reddit-full-1f62b059`. Required readiness and API canary passed.
- Storage audit target verified as bucket `trr-media-prod`, serving
  `media.thereality.report`. Scoped object HEAD validation has verified 1,026
  mirrored objects so far, including 76 added after the first 950-object snapshot;
  no object, length or content-type failures. The audit reuses unchanged evidence.
- Public CDN range reads returned HTTP 206 with correct content types and binary
  signatures for GIF, JPEG, PNG and MP4 samples.
- Warm pre-release worker containers retained old imports. Paused all five runs,
  verified claims released, and gracefully retired only the two task worker
  containers. Fresh worker transport/executor hashes match the v99 candidate.
  Formerly stuck continuation trees have now committed under the repaired runtime.
- At 00:03:30 UTC, 443 of 483 comment phases were committed, saved comments were
  35,607 against Reddit's reported 36,496, and parent references/depths had no
  inconsistencies. Remaining batches and final completeness checks are pending.
- Production capture panel loads current v2 run evidence and phase state. Separate
  catalog/episode landing reads hit their existing five-second proxy deadline.
  Verified production upstream matches the intended main Modal API; direct reads
  pass. Sensitive Vercel variables are redacted on export, so no credential drift
  was established and no credentials or production environment settings were changed.

### Final acceptance — 2026-10-21, production main

- Captured the fixed request window 2026-09-16T04:00:00Z through
  2026-10-21T23:06:47.895435Z (September 16 midnight through October 21,
  7:06:47 p.m. America/New_York). Discovery `9a941344-1111-49e8-a662-888ad074cda1`
  is complete: five chronological pages reached September 14, before the requested
  start; `boundary_reached`, chronological boundary proven, no coverage reasons.
- Final read-only reconciliation at 2026-10-22T00:13:52Z found 483 distinct posts,
  35,861 saved comment records, and all 483 comments plus all 483 media phases
  committed. No missing post phases, pending children, pending continuations,
  unresolved IDs, parent-reference gaps, cross-post parents or depth inconsistencies.
- Reddit reports 36,496 comments. Saved records include 104 `[deleted]` and
  425 `[removed]` stubs. The remaining reported-versus-saved difference is 635;
  exhausted exposed frontiers do not prove that those 635 are accessible comments.
  Keep the source-count discrepancy separate from resolved capture work.
- Six child IDs omitted by `morechildren` were independently confirmed as exact
  deletion/removal stubs via guarded `/api/info` and focal-comment reads. Repair
  `34d0532a` records their parent links and per-ID reason without retrieving removed
  text. Strict identity, atomicity, shared-budget, malformed-result and resume
  checks passed: 73 transport cases initially, then 14 affected cases after the
  exact-ID review fix (62 unaffected cases reused; 76 cases covered overall).
- Three paused original runs were safely superseded through normal cancel/retry
  controls after every claim released. Completed targets and checkpoints remain
  in the parents and were copied into the linked retries. Only nine unresolved
  posts were selected for fresh work. All three child runs completed:
  - `6e058adc-9a4d-463c-adf5-cffc0c20049f`, parent `dfd8901a-dd5d-4a0a-a936-29b3f3b5b742`, seven posts.
  - `42fb9874-a5a4-45be-a2b9-e2b5814a5460`, parent `6c7b35c7-e72e-4810-9f54-e5f01b66194e`, one post.
  - `672242fd-0950-4782-b803-95bb1d95840e`, parent `22b710ae-172b-441c-9afb-8a2b59293f66`, one post.
  The other two original 100-post detail runs completed normally. Historical
  cancelled/partial records remain visible; they are not the latest capture state.
- Media reconciliation: 1,036 expected source associations, all 1,036 saved links,
  1,033 unique linked assets, all mirrored; zero missing/dangling/unmirrored links
  or committed asset targets without associations. Storage HEAD checks verified
  existence, exact size and content type for every asset, reusing unchanged checks.
  Public HTTP 206 range reads verified GIF/JPEG/PNG/MP4 signatures and types, plus
  the repaired Tenor GIF and the native 69,578,496-byte GIF specifically.
- A final browser check exposed a legacy media counter reading only the old mirror
  ledger. Repair `127ae455` makes overall, per-period and enrichment reads recognize
  both ledgers with EXISTS predicates, preserving filters and counting each post
  once. Three affected analytics/backfill tests, including an executable SQL
  regression for legacy/v2/dual/multiple-link/pending/empty cases, and Ruff passed;
  independent review found no issues. Native live reads returned 288 of 483 posts
  with media, all 288 mirrored (59.6%). Media incidence differs from phase completion.
- Deployment: `admin-56995/main/trr-backend-jobs`, app `ap-DkLTRoSvqhbkGO7fHyHxrD`.
  Tombstone release v101/tag `reddit-tombstones-34d0532a` preserved accepted v100
  cache/runtime overlays; reader release v102/tag `reddit-media-summary-127ae455`
  preserved that complete snapshot. Both guarded deployments ran readiness for
  explicit environment `main` and passed the API cold-start canary.
- Provider readback subsequently showed v103/tag `ig-parser-08f51a1b-on-127ae455`
  at 2026-10-22T00:20:10Z. A fresh container started after that deployment retained
  exact accepted hashes for `reddit_transport.py`, `reddit_execution.py` and
  `reddit_refresh.py`; the production browser confirmed the updated reader.
  Rollback releases v102 and v101 remain available. No SQL/schema change was made.
- App: existing production source `277e87c9`, deployment
  `dpl_7AiLPurG2DkH6pXAoCCxg5CdPbnc`; no app-source/build change for this capture.
  TRR-profile browser at `/social/reddit/rhoslc/rhoslc/s7` is healthy, shows
  483/483 detail, 483/483 posts with comments, 288/483 posts with media and 59.6%.
  The three latest linked-run cards have zero unresolved targets. Expanded full
  discovery evidence shows the exact bounds, five pages, complete state and proven
  boundary. Earlier transient catalog/episode read errors cleared on final reload.
- The separate `14 stale windows` badge still reflects individual-window run
  history, including windows without an individual run. This manual capture used
  one season window; its full-window evidence and latest post phases are complete.
- Final persisted settings read: `schedule_enabled=false`, `ai_enabled=false`,
  `scheduled_analysis_enabled=false`. No schedule/AI settings were changed and no
  analysis was requested. Source, targeted checks, deployed runtime, stored data,
  object storage, public delivery and production capture UI were all verified.
- Production screenshots are under this chat's visualization directory:
  `rhoslc-full-production-summary.jpg` and `rhoslc-full-production-coverage.jpg`.
  Final accepted source snapshots and release manifests remain available for
  recovery. An empty failed snapshot and a finished diagnostic helper were cleaned
  up; unrelated root/backend/app changes and shared release snapshots were preserved.

## Comment-count discrepancy follow-up — 2026-10-21

- Completed the requested investigation and recovery, with schedules and AI disabled.
  The lead owned only this status record in the existing root `main` checkout.
  No backend/app source, schema, environment, or deployment changed in this follow-up;
  unrelated edits, index state, branches, and other tasks' commits were preserved.
- The original 483-post baseline was 35,861 saved comment IDs and 36,496 reported
  comments. The net 635 comprised 689 positive differences across 209 posts,
  offset by 54 excess saved rows across 35 posts. It was not an inventory of 635
  identifiable missing comment texts. Initial fresh OAuth metadata read 36,550;
  source counters and saved rows were captured at different times.
- A limit-1 root listing exposed IDs omitted by the larger listing, mostly
  deletion/removal placeholders. Exact IDs and same-post ancestors were validated,
  exposed child and continuation queues were closed, and normal native workers
  imported privacy-filtered checkpoints. No removed text was reconstructed.
- The deep known-anchor experiment remains partial. It is retained as diagnostic
  evidence and is not the final coverage proof. Final accepted scope is the bounded
  exposed-frontier pass across all 484 posts, with no held source errors or pending
  child IDs/continuations. It does not claim exhaustive enumeration of every
  comment Reddit could expose through every known-anchor query.
- Normal metadata refresh `207580d2-1bdb-492b-a526-cb6d14d5d819` completed five pages
  with `boundary_reached` and a proven chronological boundary. The fixed post window
  remains `2026-09-16T04:00:00Z` through `2026-10-21T23:06:47.895435Z`.
  Reddit newly exposed post `1xc1j7n`, posted `2026-10-21T22:30:39Z`, inside that
  cutoff. The frozen scope preserves the original 483 posts and adds this one post;
  period memberships are 100 small-production and 384 full-production posts.

### Accepted results

| Scope | Saved comments | Added readable comments | Added removed/deleted placeholders |
|---|---:|---:|---:|
| Original 483 posts | 36,804 | 73 | 870 |
| Newly exposed post | 16 | 13 | 3 |
| Total 484 posts | 36,820 | 86 | 873 |

- All 35,861 original IDs are preserved. All 73 readable additions on the original
  posts were created after each post's previous successful capture. The new post's
  16 comments have no original-capture baseline and are counted separately. No
  additions have null, empty, or whitespace-only bodies.
- All 913 recovery-ledger IDs and all 36,774 IDs in the 484 bounded source
  checkpoints exist canonically under the correct posts. Another 46 canonical IDs
  are newer readable comments proven by committed fresh native checkpoints.
- All 18 recovery jobs completed, with 285/285 comment targets committed and zero
  unresolved targets. Seven fresh jobs completed across 253 distinct posts.
  Four redundant queued fresh jobs were paused, checked for no claim/start/attempts
  or targets, and cancelled through native controls. Their zero-target outcomes
  remain explicit; they are not presented as completed captures.
- Native calls that lose the period claim can return `queued`; the independent
  dispatcher retries them. After checking all period owners were idle, the final
  25-post recovery `2fe3617f-cd11-43e0-81ae-d4701f04088e` was resumed through the
  normal `admin-56995/main/trr-backend-jobs` worker. The original per-period claim
  fence, privacy locks, and provider budgets remained active.
- The full recapture was stopped as redundant after the bounded source proof was
  established. Acceptance instead requires every source-checkpoint ID to be saved,
  original-ID preservation, provenance for fresh additions, completed recovery jobs,
  current committed phases, valid parents, media reconciliation, and live checks.
  Focused independent review found no remaining blocker in those prerequisites.
- Final read-only DB proof at `2026-10-22T02:27:38.484702Z` passed all 23 checks.
  Parent references, cross-post parents, missing depths, and depth inconsistencies
  are all zero. All 484 current comments phases are committed with empty queues.
  Privacy scanning covered 1,302 checkpoints and 224,988 identity nodes with no
  tombstone matches. Current tombstone sets are empty, so this does not prove
  behavior against an actual deletion.
- Final reconciliation at `2026-10-22T02:30:26.777549Z` found 36,820 saved rows versus
  36,591 stored reported comments, a net reported-minus-saved difference of -229.
  Eighty posts still have saved totals below their reported counters. All exposed
  queues and current phases are complete; counter equality is not a completion gate.
  [Reddit Help](https://support.reddithelp.com/hc/en-us/articles/204580009-Why-are-there-missing-comments-in-the-thread-I-m-in)
  explains that hidden removed comments can remain counted. This supports a possible
  source-count difference, not identification or recoverability of every absent ID.

### Media and live verification

- Media completion jobs `28a2d5da-5f51-4caa-ace0-e4321da70846` (two posts) and
  `cbd8ceee-e66c-49f2-992c-d507b6393692` (one post) completed all 12 targets.
  The final inventory has 1,038 source associations and 1,035 unique mirrored assets,
  with zero missing/dangling/unmirrored links or committed assets without links.
  All 484 comments and media phases and latest parent targets are committed.
- Storage HEAD checks verified the two new files and reused the unchanged 1,033
  asset proofs. All 1,035 assets have verified size/type and valid hosted metadata.
  Browser-style public HTTP 206 reads verified the new 33,111-byte JPEG and
  2,777,447-byte GIF signatures and ranges. Default urllib received a client-profile
  Cloudflare 403; compatible requests succeeded. No CDN/security setting changed.
- Native production counts, season summary, settings, and exact-scope coverage all
  returned HTTP 200. Counts are 484 tracked posts, 484/484 detail and comments,
  288/484 posts with media, all 288 mirrored (59.5% incidence). Media incidence is
  separate from completion of each post's media phase.
- The friendly TRR Chrome profile verified the cloud production page
  `https://trr-app.vercel.app/social/reddit/rhoslc/rhoslc/s7`. The initial catalog
  error cleared on reload; capture tools finished loading and showed successful
  recovery/media run cards with zero unresolved work. Native data and rendered
  checkboxes both confirm schedule, AI, and scheduled analysis are false.
  The separate `14 stale windows` badge still reflects per-window history; the
  manual recovery used the two explicit season capture periods.
- No local startup target was used: verification targeted cloud production.
  No Modal deployment was required; jobs used the existing main worker.
  TRR-APP build: not applicable (data recovery; no app source or contract change).
  No direct-SQL ownership or schema change occurred.
- Production screenshot: this chat's visualization directory,
  `rhoslc-comment-gap-recovery-final.jpg`. Private source checkpoints, SQL receipts,
  hashes, and native run receipts are retained under `/tmp` for audit/recovery;
  they contain no credentials in delivered summaries.

### Evidence

- `/tmp/trr-rhoslc-gap-final-scope.json`
- `/tmp/trr-rhoslc-comment-gap-sweep/frontier-only-summary.json`
  (SHA-256 `149f4304a065764088c236e7751931197e771b2298ccda5c86a36701b7c7b238`)
- `/tmp/trr-rhoslc-gap-recovery-runs.json`
- `/tmp/trr-rhoslc-gap-fresh-capture.json`
- `/tmp/trr-rhoslc-gap-cancel-redundant.json`
- `/tmp/trr-rhoslc-gap-db-verification.json`
- `/tmp/trr-rhoslc-gap-final-reconciliation.json`
- `/tmp/trr-rhoslc-gap-media-completion.json`
- `/tmp/trr-rhoslc-asset-audit.json`
- `/tmp/trr-rhoslc-gap-public-delivery.json`
- `/tmp/trr-rhoslc-gap-api-verification.json`


## Window-status correction and deeper search — completed 2026-10-22

- User authorized fixing the stale-window badge and investigating additional
  accessible comments, with schedules and AI kept disabled.
- Current read-only baseline: 484 posts, 36,820 comments, 80 posts with positive
  reported-minus-saved differences totalling 130; no active capture runs.
- Lead owns integration, this record, bounded source investigation and deployment.
  Existing helper owns the coupled backend status/API and app consumer changes.
  Work stays in current checkouts and branches; unrelated edits remain untouched.
- Backend baseline `f06b63c8`, root baseline `2bdd399`; current app baseline
  `b01eb3d0`. Predeployment refresh found accepted Modal runtime v106,
  `main`, `admin-56995`, `trr-backend-jobs`. Its full 2,588-file frozen source
  manifest was verified and preserved before adding the six task files.
- Acceptance: classify the actual displayed intervals using committed discovery
  evidence; distinguish covered, partial, upcoming and unknown windows; preserve
  date overrides; show the real season capture and cutoff; keep recovery controls
  consistent. No fabricated canonical runs or historical match rewrites.
- Deeper source checks must retain exact post/parent validation, shared request
  limits and privacy filtering. Compare new IDs to this task's fresh baseline;
  persist any validated additions through normal fenced workers and reconcile
  their media. Report bounded search limits explicitly.
- Reuse passing prior storage and source checks for unchanged inputs. Verify
  changed behavior through focused tests, explicit-target deployment, live API
  and browser checks, and final disabled-setting readback.

### Coverage release evidence

- Backend commit `e1196217`; Modal v107, tag
  `reddit-window-coverage-f06b63c8`, explicit `main` environment. Guarded
  deployment completed, required readiness passed, and API health returned 200.
- All 38 provider function bindings and five existing platform maintenance
  schedules are unchanged. RHOSLC workflow schedule, AI and scheduled analysis
  remain false. These are separate from the platform maintenance schedules.
- Authenticated production summary with the actual displayed date overrides
  returns 5 covered, 2 partial, 7 upcoming, 0 stale, 0 unknown and 0 uncovered.
  Proven cutoff remains `2026-10-21T23:06:47.895435Z`.
- The new backend SQL query passed against `trr-core` in a read-only transaction;
  it found the two qualifying discovery runs. No schema migration or app direct
  SQL ownership changed. Existing app inventory evidence remains applicable.
- Validation: 35 focused backend tests, 11 focused app tests, quick validation
  (82 checks), TypeScript, scoped ESLint/Ruff and diff checks passed.
- App commit `ea63cdb6`, built from base `b01eb3d0` plus exactly eight task
  files. Production `dpl_9aud5X9R9xP2JV3KaSV7Uk17PHDX` is READY and aliased
  to `trr-app.vercel.app`. The guarded full production build passed.
  Initial snapshot deployment omitted its Sentry release identifier; the
  unchanged source was redeployed with a scoped build/runtime release override.
  Node.js, Edge and Client source-map uploads all succeeded.
  Prior app `dpl_9J4UJLQQECJMS7rpLTtWvJykNfPA` and backend v106 remain rollback
  targets.
- Final production page currently renders 6 covered, 1 partial and 7 upcoming,
  and the authenticated API matches those displayed ranges with zero stale.
  The existing period-data request timed out: its unchanged fallback sets
  preseason start to September 16 midnight, whereas the earlier loaded period
  started September 9 at 20:00. The longer range correctly tests as partial
  (5 covered, 2 partial, 7 upcoming). No date setting was changed and the shorter
  fallback must not be used as proof for September 9–16. Episode 1's explicit
  19:01:01/19:01:10 cutovers remain displayed. This preexisting period-context
  timeout is separate from discovery-provenance classification.
- Browser verification uses cloud production in the friendly TRR profile; no
  local startup target was used.
- Private release receipts: `~/.codex/tmp/trr-reddit-window-01a16033/`.

### Deeper-search result and native persistence

- Completed the bounded pass in 17 minutes 38 seconds: 85 selected posts
  (80 positive-deficit posts plus 5 samples), 717 primary batches, 14 exact
  focal samples and 768 actual HTTP attempts including OAuth/retries/closure.
  There were no access errors, holds, budget holds or open exposed queues.
- Added six source-validated records through native run
  `2383b7c5-1cf1-4b49-aa21-73693ccf9d2d` on `main`: five older deleted/removed
  placeholders across three posts and one readable comment posted after the
  prior capture. No additional older readable text was found in this pass.
- The import used the unchanged 484-post scope and original fixed post window,
  paused/no-claim checkpoint staging, content locks, privacy filtering and the
  normal worker commit path. Existing canonical rows took precedence over
  source snapshots. No historical discovery interval or schedule was changed.
- All 12 import verification checks passed: all 36,820 baseline IDs preserved,
  exactly six additions, parent/depth integrity, committed target provenance,
  privacy compliance, frozen input hashes and disabled schedule/AI flags.
- Final totals: 484 posts, 36,826 comments, 1,035 mirrored assets. All 484
  comment and media phases remain committed; no capture runs are active.
  All 13 media references on the four affected posts are mirrored. All 1,035
  asset metadata receipts are unchanged, so prior storage verification was
  reused; no new storage HEAD requests were required.
- The search is not exhaustive: 1,179 known anchors remain unproven after the
  bounded requests. A completed exposed-frontier pass is not proof that Reddit
  has disclosed every comment or that its displayed count is an exact target.
- Search summary SHA-256:
  `b620e21a36251de3c88ea8b66cbfb0e07613d47117df2877268f1811f4afb86d`.
  Private search, import plan/run ledger, verification and media receipts are
  under `/tmp/trr-rhoslc-deeper-search/`; prior recovery receipts are preserved.
- Browser checkbox readback confirmed schedule, AI and daily AI all unchecked
  and enabled for editing; no setting was edited. Screenshot:
  `~/.codex/visualizations/2026/10/21/01a16033-1d49-7613-9356-7b6344b93322/reddit-window-coverage-final.png`.
  Existing period-context and Episode 1 cache-read timeouts remain visible;
  the corrected window badge and capture settings were independently verified.
- Final authenticated production post-detail API readback returned HTTP 200 for
  all four affected posts and delivered all six new IDs (164, 195, 139 and 17
  comments respectively). Receipt: `api-new-comments-verification.json` in the
  private deeper-search directory.


## Period and Episode 1 loading repair — 2026-10-22

Request: fix period loading and Episode 1 timeouts, verify coverage against the
intended dates, and keep Reddit schedules and AI processing off.

- Backend commit `674862feefb2ff5440dbd942a0a85c4c6edcc2ed` adds an
  authenticated calendar-only endpoint. It resolves the published analytics
  provider without importing the legacy provider early, reads canonical windows,
  and preserves existing inclusive bounds. It does not request content analytics,
  sentiment, capture, or analysis work.
- App commit `d8dae43f8d3c84f5a68eb95a63f7735b59071164` uses that endpoint,
  waits for calendar and episode context, blocks fallback-date coverage and
  reports metadata failures. Same-season metadata reuse remains allowed.
  Episode 1's authenticated stored-post reader now has a scoped 25-second budget.
  The exact prior warning came from the five-second primary-content reader, not
  the discovery cache. An initially investigated discovery-cache refactor was
  removed before validation and release.
- Focused validation: five backend endpoint/provider tests, five component tests,
  three app proxy tests and one stored-window reader test pass. Quick validation
  passes all generated checks and 79 tests; TypeScript and scoped ESLint/Ruff pass.
  Independent source review found no blockers. The existing unrelated import-graph
  baseline failure in the modified analytics provider remains outside this change.
- Modal v118, tag `reddit-periods-674862fe`, deployed to explicit
  `admin-56995/main/trr-backend-jobs`. Before release, the newest accepted v117
  snapshot was verified across all 2,642 files and preserved, with only the five
  task files applied. This retains the Instagram/TikTok/header work and the API
  concurrency update. Required readiness and the health canary pass (HTTP 200).
  All 38 function bindings and five platform-maintenance schedules are unchanged.
  Rollback: v117, `ig-no-local-cooldown-api-e6c04618e3a7`.
- Live backend reads: calendar HTTP 200 with 16 periods in 626 ms; Episode 1
  HTTP 200 with 94 posts in 591 ms; intended-window summary HTTP 200 in 1.63 s.
  These are observed requests, not a matched cold-start performance comparison.
  Intended coverage is 5 covered, 2 partial, 7 upcoming and 0 stale. The proven
  cutoff stays `2026-10-21T23:06:47.895435Z`.
- The intended preseason is September 9, 2026 at 20:00 through September 16 at
  19:00 America/New_York (`2026-09-10T00:00:00Z` through
  `2026-09-16T23:00:00Z`). It remains partial. Episode 1's explicit cutovers
  remain September 16 at 19:01:01 through September 23 at 19:01:10.
- Live settings return `schedule_enabled=false`, `ai_enabled=false`, and
  `scheduled_analysis_enabled=false`. No capture or analysis job was started,
  no database/schema or app direct-SQL ownership changed, and no date override
  was edited. Existing captures and totals remain unchanged by this repair.
- App production `dpl_DMvd5MzHay9ztvxSoCbJZJvgC2Mk` is READY and serves
  `trr-app.vercel.app`. The guarded production build passed, including TypeScript
  and Node.js/Edge/Client Sentry source-map uploads. It includes the maintained
  navigation/context-read repairs through `a491d06e` plus this task's six files.
  Frozen app source: 1,698 files, SHA-256
  `7b3c011a6de3bb8d5aea397bf20a597d6b2cbcda35fbd4d6e0480810daf05452`.
  Rollback app: `dpl_JEBUYe3MZxCpnsmC6pB4xrEn9ckG`.
- Authenticated production app readback passes all four checks: calendar HTTP 200
  with 16 periods in 2.84 s; Episode 1 HTTP 200 with 94 posts in 741 ms; coverage
  HTTP 200 in 1.28 s with the intended 5/2/7/0 classification; settings HTTP 200
  with all three flags false. Timings are individual observed requests.
- Visual production verification completed at `2026-10-22T18:09:52Z` after the
  user authorized the connected RHOSLC Chrome window. The current production
  alias still serves `dpl_DMvd5MzHay9ztvxSoCbJZJvgC2Mk` in READY state.
  The season page shows 5 covered, 2 partial and 7 upcoming, the intended
  September 9 at 20:00 preseason start, and Episode 1's saved 19:01:01/19:01:10
  cutovers. No period-loading warning or timeout warning is present.
- Opened Episode 1 through View All Posts (94). Its dashboard rendered 94 tracked,
  94 matched and 94 fetched posts, with 94 View Details links and no timeout.
  Opened the capture tools and waited for saved settings to finish loading:
  schedule, AI analysis and daily AI analysis are all unchecked, with enabled
  controls. No setting was edited/saved and no capture or analysis action ran.
  Capture tools were collapsed and the tab returned to the season overview.
- Browser target: cloud production; no local startup. Reused passing source/build
  checks because no application code changed. Screenshot and DOM evidence:
  `browser-verification.json`, `browser-coverage-final.png`,
  `browser-intended-dates.png`, `browser-episode1-loaded.png`, and
  `browser-settings-off.png` in the private release directory below.
- Release manifest, provider snapshots, commands and API receipts:
  `~/.codex/tmp/trr-reddit-periods-01a16033/`.


## Manual preseason gap and Episode 6 refresh — 2026-10-22

User authorization: manually capture the missing preseason dates, bring Episode 6
up to date, verify coverage, and keep schedules and AI processing off. This is
explicit manual historical capture authority; it does not activate automatic repair,
scheduling, lifecycle deletion, or analysis.

- Lead owns runtime submissions and the existing task record in the current
  checkouts. Existing branches, source edits and index state are preserved.
- Live preflight verified Supabase `vwxfvzutyufrkhfgoeaa` in a read-only transaction,
  and Modal `admin-56995/main/trr-backend-jobs` readiness passes. The current runtime
  is v120, `tiktok-public-posts-3d8d96c5e674`; this operator task changes no source
  or deployment. All three schedule/AI flags are false and no scoped capture runs
  were active before submission. Baseline: 484 posts and 36,826 saved comment IDs.
- Missing preseason interval: `2026-09-10T00:00:00Z` through
  `2026-09-16T04:00:00Z`; combine its native discovery evidence with existing proof
  through `2026-09-16T23:00:00Z`. Use canonical preseason key, missing policy,
  discovery/comments/media, and chronological listing without search backfill.
- Episode 6 capture: `2026-10-21T04:00:00Z` through the frozen current cutoff
  `2026-10-22T18:36:22.520417Z` (October 22, 14:36:22 America/New_York).
  Keep its displayed end `2026-10-28T04:00:00Z`. Capture with stale policy and
  60-second freshness; the future-ending displayed window remains partial.
- Both canonical match scopes were empty before launch, so new matches are
  correctly assigned without including unrelated existing scope. Current source
  preserves old assignments. Therefore refresh the 12 previously saved Episode 6
  posts separately, grouped by their actual period keys: one post under
  `rhoslc-s7-full-production-20261021` and eleven under
  `rhoslc-s7-small-production-20261021`. These selected detail runs request comments
  and media only and cannot create discovery coverage proof.
- Source investigation confirmed interval union, key and selection semantics,
  freshness controls, and completion criteria. Native run completion must have
  zero unresolved required targets; discovery needs a proven chronological boundary.
  Search results or a terminal label alone do not establish complete coverage.
- First native preseason run: `f8c3ed64-7ceb-40d1-8fcd-06a23f18db1c`. Its successful
  HTTP 200 response was retained and reconciled after the receipt parser expected
  `id` instead of the returned `run_id`; it was not resubmitted.
- All four native submissions were accepted in `main`: preseason
  `f8c3ed64-7ceb-40d1-8fcd-06a23f18db1c`; Episode 6
  `5225c66c-1a65-48de-84b1-67067c4cc717`; existing-post detail batches
  `32e67a79-44b6-442b-9090-e3343a252c23` and
  `0c08f0ad-711c-47d1-8391-1bd3411dfeb9`. Disabled flags were checked before
  every submission and after the batch. Both listing passes have complete
  chronological boundary evidence; all four native runs finished successfully.
  Frozen payloads, baseline IDs, readiness, intent/response receipts and run ledger:
  `~/.codex/tmp/trr-reddit-window-topup-20261022/`.


### Manual capture acceptance

- All four native runs completed on `main` with 230/230 required targets committed,
  zero unresolved work, no retry/error state, and no remaining active scoped runs.
  Required outcomes: 9 discovery targets, 60 comment targets and 161 media targets
  (post phases plus individual asset associations). Monitoring exited normally.
- Added 35 preseason posts and 13 Episode 6 posts to the season. Refreshed comments
  and media for the 12 existing Episode 6 posts as well. Final scope: 532 posts and
  38,852 saved comments, an increase of 48 posts and 2,026 comments. All 484 prior
  post IDs and all 36,826 prior comment IDs are preserved.
- Eleven final verification checks pass, including native target pagination,
  immutable discovery bounds and chronological proof, intended-window coverage,
  elapsed Episode 6 coverage, preserved baseline IDs and existing assignments,
  fresh comments/media for all 60 affected posts (120 phase rows), and metadata
  for all 101 distinct affected assets mirrored. Media success follows comment
  success for every affected post. Settings compare exactly to the preflight
  snapshot: schedule, AI and scheduled analysis remain false.
- Authenticated backend and app summaries both show 6 covered, 1 partial, 7 upcoming,
  0 stale and 0 unknown. The full intended preseason interval (September 9 at 20:00
  through September 16 at 19:00 America/New_York) is covered by the union of the new
  gap run and prior evidence. Episode 6's elapsed interval is fully covered through
  `2026-10-22T18:36:22.520417Z` (October 22 at 14:36:22 New York time). Its displayed
  October 28 end is preserved, so the future-ending window correctly stays partial.
- App stored-post routes return HTTP 200 with 35 preseason posts and 25 Episode 6
  posts. Production browser readback matches: 6/1/7, preseason marked covered,
  and Episode 6 marked partial through 14:36:22. No loading timeout was present.
  Screenshots: `browser-coverage.png` and `browser-preseason-covered.png` in the
  task's private artifact directory. Browser target was cloud production; no local
  startup or new app build was needed for these operator actions.
- No schedules or AI were enabled, no analysis was requested, no prior assignments
  were moved, and no source/schema/deployment changes were made. The only repository
  edit is this existing task record. Native intent/response receipts, full target
  snapshots, API/DB verification, and `completion-receipt.json` are retained under
  `~/.codex/tmp/trr-reddit-window-topup-20261022/`.
