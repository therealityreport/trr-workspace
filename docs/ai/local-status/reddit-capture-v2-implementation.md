# Reddit capture v2 implementation

## Handoff Snapshot

```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-10-21
  current_phase: "Full RHOSLC S7 production capture complete and verified"
  next_action: "No capture work remains; keep schedules and AI disabled"
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
