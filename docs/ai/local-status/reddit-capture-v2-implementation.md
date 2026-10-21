# Reddit capture v2 implementation

## Handoff Snapshot

```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-10-21
  current_phase: "Implemented and enabled for future runs"
  next_action: "Operator opt-in only for schedules or AI; no automatic legacy repair"
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
