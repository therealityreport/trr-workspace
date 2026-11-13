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

Hosted database role/policy behavior, production build, and production
activation are separate from these results. The app/rules pair requires release
authorization and target-specific checks before activation. No backend-owned
contract or Modal code changed.
