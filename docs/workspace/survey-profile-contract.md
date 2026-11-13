# Survey and profile repair contract

## Storage and identity

Firebase owns identity and profiles. PostgreSQL owns submitted survey responses;
Firestore owns editable survey drafts. This repair does not migrate stored data.

`GET /api/profile` and `PATCH /api/profile` authenticate the Firebase user. The
server derives UID, email, and provider from authentication. PATCH accepts only
name, username, birthday, shows, showRequests, gender, livesInUS, state, and country.
Missing fields remain unchanged, and existing `createdAt` is preserved. Changing
residence clears the inactive state or country field.

The profile editor loads saved fields before accepting edits. Drafts belong to a
single authenticated UID; old unscoped drafts are never imported. Failed reads
and writes remain visible. Only a successful save clears the current draft.
Profile completion requires username, birthday, and at least three shows.

## Username ownership and compatible release

The server reserves normalized usernames in private `username_claims` documents.
The claim and profile update share a Firestore transaction. Creation uses a
create-only precondition, and name changes release only a claim owned by that
user. Legacy profile records also block new claimants. Availability is advisory;
the save returns HTTP 409 when a competing account owns the requested name.

Existing duplicates are preserved. An unchanged duplicate permits unrelated
profile edits and reports `usernameStatus: conflict`; a legacy unclaimed name
reports `unreserved`. Only an owned, non-conflicting claim reports `reserved`.
The UI calls unresolved names “Username on file”. No bulk rename is required.

The app and `TRR-APP/firestore.rules` form a compatible release pair. The rules
deny direct client username creation/changes and all client claim access. Before
production activation, authorize and verify both artifacts against the intended
Firebase project. Keep the previous app revision and the secure rules artifact
as rollback material. Never restore unrestricted client username writes. A safe
rollback must retain the server profile path or temporarily disable profile edits.
No frontend or Firestore production activation is included in this local repair.

## Survey eligibility and exports

The active-run response retains `canSubmit` and adds `eligibility` with one of
`sign-in-required`, `no-active-run`, `allowed`, or `limit-reached`. Requests belong
to both survey slug and authenticated UID. Successful submission and eligibility
refresh are separate results: a refresh failure never changes a saved response
into a failed submission. Answers reset only when the user selects “Submit
another response”.

The normalized system has no public results view or aggregate API. Its play
route therefore uses `/hub/surveys` for navigation and states that results are
not available yet. The reusable player can show a results action when supplied
with a real destination. This repair does not publish respondent data or add an
aggregate results feature.

CSV exports use the same encoder for headers and values. Matrix answers use
deterministic JSON in their existing question column; legacy numeric Likert
answers remain numeric. Text cells are quoted, embedded quotes are escaped, and
formula-leading text receives an Excel-oriented tab prefix. This prefix changes
the exported text. It is not a universal guarantee across spreadsheet programs
or subsequent save/reopen workflows. Stored answers are unchanged. See
[OWASP CSV Injection](https://community.owasp.org/attacks/CSV_Injection).

Nested admin routes enforce survey/run/question/option relationships. Mismatched
identifiers return 404 without a mutation. Mutation queries retain the parent
constraints; runs with responses remain protected from deletion. SQL ownership
stays in the app repository's survey data-access layer.

## Local verification

Focused API, component, survey, export, and parent-scope tests cover the repair.
The opt-in `tests/profile-emulator.test.ts` uses project
`demo-trr-profile-repair` and requires loopback Firestore and Auth emulators.
Run it with `TRR_PROFILE_EMULATOR_TEST=1`, two Vitest workers, a 2 GB Node heap,
and a 2 GB Java heap under `codex-heavy`. It must never run against a live project.
The existing eleven draft/submission ownership tests remain required.

Full production build evidence requires current-chat approval after the
lightweight app gate. Local checks are not production activation evidence.

### Repair verification, 2026-11-13

App candidate: `f705619b`, built from baseline `d9429e0a` with the existing
checkout's unrelated edits preserved. The independent full review and fix-only
review were completed; the final cookie-only redirect finding was resolved by
removing the redundant server registration decision and testing client recovery.

- Profile API: 7 tests passed. Actual Firebase emulator transactions/rules: 5
  tests passed; the expanded foreign-claim preservation case also passed.
- Profile/auth components and registration layout: 23 tests passed.
- Normalized survey requests/player: 13 tests passed. The 11 existing survey
  draft/submission storage tests passed unchanged.
- Export/admin behavior: 25 tests passed across the initial suite and the two
  added admin-context count cases. Isolated PostgreSQL checks confirmed scoped
  mutations, deletion guards, and per-user counts of 1, 2, and 0 in one run.
- `make app-validate-quick`: generated contracts and 79 routing tests passed.
  The admin inventory was regenerated and checked again after count-route edits.
  Typecheck, scoped ESLint, and whitespace checks passed after the repair batch.
- Browser: reused the running `make dev-hybrid` workspace (recorded mode
  `hybrid`) through the declared HTTPS routes in Chrome's TRR profile. Saved
  profile fields loaded, and the active normalized `rhoslc-s7` player rendered.
  No live profile update, survey submission, or admin mutation was performed.

- The user approved the full local production build in this chat. The first
  attempt compiled but exhausted the 2 GB TypeScript heap. The same candidate
  passed with a 3 GB heap (the wrapper default) and two workers: TypeScript,
  104 static pages, optimization, and route generation completed. Build ID:
  `zZGzk7PXMgW_xpOuM031O`. The build included the preserved unrelated checkout
  edits. A Sentry/OpenTelemetry `require-in-the-middle` static-dependency warning
  remained. No application checks were disabled.

Hosted database role/policy behavior and production activation are separate from
these results. The app/rules pair requires release authorization and
target-specific checks before activation. No backend-owned contract or Modal
code changed. Nothing was pushed or deployed.

### Closeout

Temporary Next.js include entries and `next-env.d.ts` imports were restored to
their pre-build development paths. The running `.next` output and unrelated
checkout edits remain intact. After removing the temporary build, the development
CSS compiler retained an invalid escaped selector and returned HTTP 500. A CSS
compiler refresh cleared it; the temporary refresh comment was removed,
`globals.css` matched its original content, and `/auth/register` returned HTTP
200. No persistent CSS repair or server restart was needed.

These disposable task outputs moved to actual
`/Users/thomashulihan/.Trash/` after verification:

| Original task output | Trash directory | Measured size |
| --- | --- | --- |
| Temporary `trr-profile-emulator-1y8vu0tr` directory | `trr-profile-emulator-20261113-01a1d68d` | 898,411 bytes |
| Temporary `improve-codebase/session-digest-2026-11-07_2026-11-13-both-TRR` | `trr-survey-profile-session-digest-20261113-01a1d68d` | 1,644,285 bytes |
| `TRR-APP/apps/web/.next-survey-profile-repair-f705619b` | `trr-survey-profile-build-f705619b-20261113` | 1,998,188 KiB |

The build was for verification only and has no pending activation consumer.
Committed source, focused tests, this receipt, and the existing running app
retain the required evidence and recovery path. Trash was not emptied.

Both repositories were fetched with pruning. The merged workspace branch
`claude/upbeat-lalande-8dc526` was deleted. Existing dependency worktree branches
were retained for their other checkout; release branches were retained because
their local tips differ from the merged pull-request head IDs. No worktree was
created, removed, or switched for this repair.

## Production release — 2026-11-13

The user explicitly authorized pushing the repair, activating the app and
Firestore rules together, and verifying production. App branch
`chore/repo-hygiene-2026-09-25` was pushed through
`7f41787c718b0e16d10a866f59b1869f79ebbb2d`. It includes repair `f705619b`
and the existing dependency refresh from main (`45930f42`, `bda5f429`,
cherry-picked as `1c771974`, `7f41787c`). Production source comparison showed
those dependencies were already deployed; retaining them avoids a downgrade.
Unrelated uncommitted files were excluded through an exact Git source export.

- Vercel: team `team_EUsG2kN9TAvVDGOu4yZVEoCX`, project
  `prj_MHpStkwr26rV5kjt0f80zqhwZpAs`, deployment
  `dpl_FFKbuMkS325kjsuP1FXPkwP3otGU`, canonical URL
  `https://trr-app.vercel.app`. The production build, TypeScript, and 104 static
  pages passed. Source maps uploaded with the exact commit as `SENTRY_RELEASE`.
- Firestore: project `trr-web-25d2e`, active ruleset
  `a44cbe8b-d409-4b4a-8fd1-9fea14adb0d7`, activated at
  `2026-11-13T21:10:52.158859Z`. Source SHA-256:
  `1fdca09ca950a271506a064c98d84e2d24b8dc0a8d4c0f7db1e05c9a4a71c9d7`.
  The app was promoted first, followed immediately by the precompiled rules;
  both provider identities were verified after activation.
- With the production dependency versions: 84 focused tests (including five
  actual Firebase emulator cases), 79 routing tests, all six generated-contract
  checks, and focused lint passed. A memory-pressure guard held the first lint
  attempt; the later admitted attempt passed without an override.
- Twelve production API checks passed using temporary test accounts and survey
  fixtures: unauthenticated rejection, competing username claims, partial edits
  and creation-time preservation, location cleanup, invalid-write retention,
  denial of direct username writes/private claim reads, old-claim release,
  signed-out eligibility, limits of one and two, per-account counts, matrix and
  spreadsheet-safe CSV, parent mismatch rejection, and protected run deletion.
- Native Chrome's verified `TRR` profile loaded saved profile/editor values.
  The production UI showed "Username on file". Two synthetic survey responses
  verified explicit repeat submission, answer reset only on request, final
  completion at the limit, unavailable-results text, and working navigation to
  `/hub/surveys`. No real profile fields were edited. Failure injection and
  fresh third-party OAuth sign-in were covered by local tests, not forced in
  production.

Temporary Firebase users, profiles, and claims were removed. The empty secondary
survey was removed through its API. The survey with four synthetic responses
correctly encountered PostgreSQL's restrictive foreign key during whole-survey
cleanup; a narrowly guarded transaction in verified `trr-core`
(`vwxfvzutyufrkhfgoeaa`) deleted those fixture responses and their survey.
The query confirmed zero remaining verification surveys. No schema or ownership
change was made, and no Modal deployment was needed.

Release evidence and recovery source are retained under
`/Users/thomashulihan/Documents/Codex/2026-11-13/survey-profile-release/`.
`candidate-source.tar` is the exact committed release source. The previous app
deployment and previous rules are recorded for comparison; do not restore the
old direct-username-write policy. Recovery must retain this server-owned profile
write path and restrictive claims policy. The first staged deployment
`dpl_64FddP1WgAypX9A9s6JqoriH37UM` was canceled before activation because its
source-map release ID was empty. Its diagnostic log is retained.
