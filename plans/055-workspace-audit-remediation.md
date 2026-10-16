# Plan 055: Address the workspace audit and improve the codebase

Date: **2026-10-04**. Updated: **2026-10-16**. Status: **production delivery complete for the selected Plan 055 release; bounded verification limits and separate face-detector follow-up recorded**.

Current authority: [production release receipt](../docs/workspace/plan-055-production-release.md). App/backend safety commits and selected repairs are merged and deployed. Firebase and current surveys remain in place; full trusted admin access is verified. The earlier planning and row 1/2 sections below are historical inputs, not current blockers.

## Row 3 delivery plan and authentication/survey audit — 2026-10-16

**Status: delivered.** The full app build passed, app/backend implementation PRs merged, Vercel/Modal/Render deployments were verified, the shared credential rotated, and installed restrictive Firebase rules matched source. Normal-user survey save/reload/retry and isolation checks passed; all test records were removed. GitHub rules publishing was repaired and its live deployment succeeded. See the release receipt for exact identities, reused evidence, recovery, and verification limits. The unchanged default face-detector lane failed an additional check and remains a separate acceptance issue; the previously accepted YOLO lane completed a real production job.

**Administrator access:** The user explicitly wants the agent to retain full read/write capability for authorized TRR maintenance. Preserve trusted service-account/server access and the administrator workflow. Firestore client rules must restrict ordinary visitors without disabling privileged administration. Do not use public `allow read, write: if true` to provide agent access; verify actual administrative read/write access separately. The grant concerns authorized TRR work, not unrelated projects or public access.

**Survey direction:** Supabase/Postgres is the intended main home for responses. Retain the current Firestore and SQL transition during this release. A later consolidation plan must preserve existing answers, identify copies that can safely be retired, and define one authoritative record for each response.

### What this means in plain language

The selected repairs are now published and live. Sign-in, administrator access and survey persistence were checked against production. Existing answers were preserved, and the temporary verification records were removed. Exact compatible sources and recovery instructions are retained.

We are not starting the repairs again. We are finishing delivery. A different sign-in provider or survey builder is an optional later product decision, not a prerequisite for shipping the verified repairs.

### Reuse from rows 1 and 2

- Row 1 owns the candidate inventory, preimages, ownership classification, matching 93 tracked and 14 new candidate files, and 58-file isolated backend overlay. Preserve the linked reconciliation evidence below. Whole-file matches do not grant ownership of unrelated hunks.
- Keep backend safety commit `a76cd1df86fdfc54fde1097623912118d03c7b17`, app safety commit `b4fcbfa38b500d6ba2a8eaf34bd5b7a5f1d08246`, and workspace closeout `371ffea`. Backend/app HEADs still match those commits at this planning pass. They are local source receipts, not proof of push or deployment.
- Reuse the row 2 delivery-selection hashes and passing cleanup/TLS, SQL-key, typography, Getty and Plan 032 checks. Reuse the Plan 055 SQL/identity, survey validation, Firebase emulator, transport, fencing, messaging, auth-adapter, typecheck and quick-validation receipts for unchanged relevant inputs.
- Do not repeat a passing suite just because commits are assembled or time passed. Recheck only changed inputs, genuinely time-sensitive gates and missing connected/runtime proof. The expired architecture reviews and live provider identities require current evidence.
- Existing row 2 checks are sufficient for the standalone cleanup script unless changed. Shipping it does not authorize running a production deletion. Preserve all media assets; garbage collection remains separate.

### Ordered delivery work — retained acceptance plan

| Order / owner | Work in simple terms | Concrete acceptance |
|---|---|---|
| 1 — Lead, all repositories | Package the complete repairs without collecting unrelated work. | Refresh selected ownership and hashes against retained preimages. Assemble Plan 055 overlays plus safety commits into scoped commits on the current branches. Preserve other dirt and recovery files. Record exact workspace/app/backend revisions and release manifest. Do not deploy bare backend HEAD: it lacks the retained overlays. Include Plan 032 explicitly, which was absent from historical v53. Publish only the selected candidate through the established repository process when implementation/publication is authorized. |
| 2 — Architecture owner | Resolve expired review approvals. | Reassess the 34 expired reviews and 26 exceptions/overages against current source; retain the per-file owner and extraction seam. Reduce specific overages or obtain justified, bounded exceptions under the existing policy. No automatic date extension or ceiling increase. Refresh the changed screentime hash even though its size is unchanged. Require the current hotspot and release-classification gates to pass. Reuse unchanged import-graph proof. |
| 3 — App owner | Prove the website can be built and inspect the release destinations. | Reuse unaffected quick/typecheck evidence; run only invalidated lightweight checks. Obtain the full production build approval required by `.codex/rules/trr-project.md` once the candidate is concrete, then build once. Record exact Vercel project/environment, API/Render service, Firebase project/rules release, Supabase target and Modal environment. Inspect actual access rather than assuming October 4 access failures persist. |
| 4 — Backend/security owner | Update services and their shared secret in a compatible order. | Map every secret producer/consumer first. Prepare supported credential rotation and recovery without logging values. Where dual-key overlap exists, activate new verification, update consumers, prove new use, then retire old credentials. Otherwise use an explicit coordinated change window; never assume dual-key support. Publish compatible backend/API/worker changes before dependent clients or restrictive rules. No database migration is currently required by P1/P2; any newly discovered schema need requires its own compatibility assessment. |
| 5 — App/Firebase owner | Release the website and permissions together. | Verify Firebase project `trr-web-25d2e` against deployed app configuration; treat the local name as a candidate until verified. Check old/new client compatibility for all changed Firestore collections. Put trusted server writes in service before denying the corresponding client writes. Handle existing browser sessions explicitly; if compatibility cannot be maintained, use a bounded maintenance/reload procedure. Verify the installed rules release/hash, not only the repository file or emulator. Do not restore insecure rules as a recovery shortcut. |
| 6 — Lead/browser owner | Use the actual site as a signed-in user and prove answers remain saved. | Use verified friendly TRR browser identity. Check enabled sign-in methods, session persistence/logout, owner isolation, survey submission/reload/results and legacy retry. Link evidence to deployed revisions. Verify API consumers and Modal dispatch point to the same intended release. Local Portless acceptance does not replace production-domain acceptance. Use designated test identities/records; avoid destructive tests on real respondents. |
| 7 — Lead/operations | Prove recovery works and close the release. | Reconfirm `admin-56995 / trr-backend-jobs` and resolve the environment from current live configuration (historically `main`). Run `python3.11 scripts/modal/verify_modal_readiness.py --env <resolved-env>` from backend plus the affected health/worker smoke against that same environment. Preserve fenced snapshot and compatible app/API/rules/config identities. Verify recovery with a safe rehearsal or equivalent existing matching evidence; never blindly restore unfenced v52 after new claims. Observe one complete representative job and a signed-in submission through completion; record a traffic-appropriate monitoring window and error baseline before promotion. Stop promotion on auth bypass, lost/duplicate responses, stale-worker writes, incompatible rules or identity mismatch. |

Steps 1 and 2 can progress alongside read-only destination inspection. Steps 4–7 depend on a coherent candidate and the applicable release gates. Any major decomposition needed by step 2 must be estimated separately before broadening the delivery packet. No fixed implementation duration is promised until those exceptions and provider access are checked.

**Release receipt:** selected revisions and artifact hashes; provider project/environment/deployment IDs; installed rules identity; secret-version identifiers only; reused versus new evidence; signed-in outcomes; observation period/results; recovery snapshot and procedure; unresolved dispositions. Row 3 is complete only when intended live targets and observed behavior match this receipt.

### Authentication audit: what exists now

| Area | Source finding | What remains |
|---|---|---|
| User sign-in | Firebase client is used for email/password and Google. Apple popup code exists in registration, controlled by `NEXT_PUBLIC_ENABLE_APPLE`, default false. Password-reset UI exists. | Verify the actual enabled providers, authorized domains, OAuth callbacks and reset-email delivery in the intended Firebase project. Do not call Apple delivered merely because its button/code exists. |
| Server sessions | `src/lib/server/auth.ts` verifies Firebase ID tokens and session cookies through Admin SDK with revocation checking. The repaired candidate rejects failed verification. Origin/Host binding has retained adapter evidence. | Confirm deployed credentials, cookie behavior, production origins, invalid/revoked-session rejection and logout. Verify no production dev bypass. Local tests do not prove deployed configuration. |
| Alternative auth | A Supabase verifier, shadow diagnostics and cutover-readiness code exist. The source explicitly rejects durable session mode with Supabase because Firebase currently issues `__session` cookies. | This is not a completed provider migration. Do not flip `TRR_AUTH_PROVIDER` as a release shortcut. A switch needs client, session, user-ID, Firestore and data-ownership migration. |
| Linking accounts | This scoped source search found no explicit provider-linking calls. | Check existing same-email behavior and prevent accidental duplicate profiles or lost responses. Linking must prove control of both identities; do not merge solely on matching email. New linking UI is a separate feature unless required to repair an actual release regression. |
| Authorization | Firebase identity is used by app/server authorization; owner rules constrain private Firestore records and reserve global aggregates for the server. App SQL historically connects with privileged `postgres` access. | Prove server authorization on private/admin paths; do not assume database RLS protects privileged server calls. Verify installed rules deny another user's records and client aggregate writes. Admin MFA, account deletion/export, email-verification policy and abuse controls need a focused product/security follow-up; this source pass does not claim they are fully configured or missing. |

Source anchors: [Firebase client](../TRR-APP/apps/web/src/lib/firebase.ts), [registration](../TRR-APP/apps/web/src/app/auth/register/page.tsx), [server authentication](../TRR-APP/apps/web/src/lib/server/auth.ts), [cutover guard](../TRR-APP/apps/web/src/lib/server/auth-cutover.ts), [Firestore rules](../TRR-APP/firestore.rules).

### Survey audit: what exists now

There are three distinct response systems. The name `firebase_surveys` is misleading without context: it is a PostgreSQL schema for Firebase-authenticated users, not a Firestore collection.

| Family | Current design and retained repair | Delivery proof needed |
|---|---|---|
| App normalized surveys | Custom branded question renderer, admin question/options editing, scheduled runs and normalized answers in PostgreSQL `firebase_surveys`. Submit derives Firebase UID from server authentication, validates questions/options before inserts, and uses a transaction plus per-user/run locking for submission limits. | Signed-in create/play/submit/reload/admin-results path, closed-run/invalid-answer handling and another user's access denial. Verify the actual runtime role and server authorization. |
| Backend surveys | Separate `surveys.*` model expects a Supabase-style UUID identity via `auth.uid()`. Plan 055 repairs scalar response IDs and transaction-local identity. | Confirm which clients actually use it and prove their authenticated route. Firebase text IDs cannot simply be cast to these UUIDs. Do not route the Firebase app here without an explicit identity mapping design. |
| Legacy/profile surveys and games | Firestore owner records coexist with SQL synchronization. Candidate marks pending/error/synced states and leaves failures retryable; aggregate writes move to trusted server behavior. | Prove a partial sync does not falsely show completion, retry retains answers, and both writes complete. Check old clients against tightened rules. The systems do not become one atomic database transaction. |

Source anchors: [schema identity](../TRR-APP/apps/web/src/lib/server/surveys/survey-schema.ts), [normalized submit](../TRR-APP/apps/web/src/app/api/surveys/[surveySlug]/submit/route.ts), [run persistence](../TRR-APP/apps/web/src/lib/server/surveys/survey-run-repository.ts), [custom questions](../TRR-APP/apps/web/src/components/survey/QuestionRenderer.tsx), [legacy synchronization](../TRR-APP/apps/web/src/lib/db/surveys.ts), [backend surveys](../TRR-Backend/api/routers/surveys.py).

The renderer already includes cast/poster ranking, reunion seating, ratings, text, multiple choice and two-axis inputs. Replacing it with a generic form builder would require meaningful feature and data compatibility work. Keep the three families separate for this repair, as already decided. For future work, prefer the normalized PostgreSQL path for new signed-in TRR surveys after its live acceptance, with deliberate migration of legacy flows later.

### Recommended tools and future direction

These are fit recommendations, not a universal vendor ranking. Assumption: TRR's main surveys are branded, signed-in entertainment experiences; simple public feedback forms are secondary. Official documentation was consulted October 16. Provider prices, actual account plans and production configuration were not audited.

| Need | Recommended choice | Why / tradeoff |
|---|---|---|
| Authentication for this release | **Keep Firebase Auth.** Prioritize email/password and Google; enable Apple only after configuration and connected proof. | Matches existing accounts, session cookies and Firestore ownership. Supports social providers and credential linking. Repair delivery is much smaller than moving identities. [Firebase web auth](https://firebase.google.com/docs/auth/web/start), [session cookies](https://firebase.google.com/docs/auth/admin/manage-cookies), [account linking](https://firebase.google.com/docs/auth/web/account-linking). |
| Future auth consolidation | **Supabase Auth is the first alternative to evaluate**, if reducing identity/storage systems is a firm goal. | Fits the existing Postgres platform, but requires preserving user ownership, sessions, social-provider links and legacy Firestore access. Existing shadow code is insufficient acceptance. [Supabase Auth](https://supabase.com/docs/guides/auth). |
| Keep Firebase with Supabase data access | **Consider supported Firebase third-party auth only for a separately scoped integration.** | Supabase supports Firebase JWTs, so moving data does not inherently require changing login. Configuration, trusted issuer/audience, role claims and policies are needed. It does not convert Firebase text IDs into the backend survey UUID model or fix privileged direct SQL automatically. [Official integration](https://supabase.com/docs/guides/auth/third-party/firebase-auth). |
| Managed account UI and social connections | **Clerk is an alternative if ready-made account management becomes the main priority.** | Adds a different identity/session system to migrate and operate; no identified Plan 055 requirement justifies that now. [Social connections](https://clerk.com/docs/guides/configure/auth-strategies/social-connections/overview). |
| TRR surveys and responses | **Keep custom TRR screens plus server validation and normalized PostgreSQL responses.** | Preserves specialized visual questions, show/season/cast links, permissions and reporting. Use durable database records as the response authority; a form renderer alone does not provide secure storage, ownership or recovery. |
| Visual survey authoring | **SurveyJS is the strongest candidate to evaluate if admins need a drag-and-drop designer.** | Form Library is MIT licensed; Creator and other advanced products require commercial licensing. Pilot one real TRR survey, including custom ranking, accessibility, export and versioned questions, before replacing the existing admin editor. [Form Library](https://surveyjs.io/form-library/documentation/overview), [licensing](https://surveyjs.io/licensing). No license purchase is proposed for this release. |
| Standalone public forms | **Tally for simple intake; Formbricks for feedback programs.** | Keep these outside core authenticated TRR response flows unless a reviewed integration maps identity, consent, storage and deletion. They are options for different product needs, not required replacements. [Tally documentation](https://tally.so/help), [Formbricks documentation](https://formbricks.com/docs/platform/introduction). |

A future survey improvement plan should settle question/version immutability after responses exist, draft/resume behavior, duplicate/retry policy, accessible mobile ranking, exports/aggregates, retention/deletion and anonymous participation. Existing functionality must be inventoried before calling any of these missing. Anonymous forms must be a deliberate product choice, not an identity-check bypass. Social sign-in establishes a TRR account; it does not grant permission to scrape a user's social account.

### Decisions and boundaries before implementation

Default recommendation: finish Plan 055 with Firebase, existing survey families and existing custom UI. No authentication migration, survey-vendor adoption, anonymous survey feature or wholesale schema consolidation is included. Those can become separate planned focuses after release.

The current request authorizes this plan/audit only. At implementation time, obtain only genuinely missing authority: the full-build approval explicitly required by the project, any unresolved release target, spending or provider action outside the implementation grant. Reuse the standing Modal grant when applicable; do not request blanket duplicate confirmation. Existing current user policy permits focused necessary regression tests during authorized implementation; older opt-in wording later in this historical plan does not override current policy.

Keep six recorded JS advisory matches, operator cryptography/model provenance, media-watch failure history, licensing, protected-output disposition, SQL skips/lint-OOM/dedup limitations and routed-delivery limitations visible. Determine which actually affect the selected release and require repair or an authorized disposition; do not erase them or relabel a concrete blocker as optional. This scoped source audit does not claim current provider settings, active response counts, all user journeys or production security certification.

## Row 2 safety closeout — 2026-10-16

The user authorized the bounded safety batch after row 1 and requested a remaining-work handoff before row 3. This section supersedes the row 1 starting-state and missing-source statements below. Source commits are local only; provider publication, secret rotation, Firebase rules and production rollout remain row 3 work. No live database cleanup was performed.

| Safety item | Completed behavior | Verification |
|---|---|---|
| Season cleanup | The script removes only selected `media_links` IDs belonging to the requested season. Source/page filters remain. Apply locks those links inside the transaction; errors roll back. Dry run selects only. All media assets are retained because references also exist outside `media_links`; asset garbage collection is separate work. | Four actual PostgreSQL groups using migration 0059: unchanged dry run, injected deletion-fault rollback, matching-only apply preserving other-season/person/nonmatching links and every asset, and repeat no-op. The disposable Unix-socket server was stopped and PID absence confirmed. |
| Strict SSL | Strict mode verifies certificates with the configured CA or system trust; there is no insecure missing-CA fallback. Installed pg URL behavior and explicit non-strict choices remain intact. Direct negotiation, CA, client certificate/key and pg's non-enumerable key protection survive resolution. Importing the script does not load `.env.local` or connect. | Final cleanup/TLS module: 19 tests against installed pg parsing, including secure URLs, explicit opt-outs, strict overrides, CA failures, direct negotiation, key descriptors and transaction failures. |
| Plan 002 | Both previously unguarded cast-screentime updaters validate all mapping keys before constructing assignments or issuing SQL. JSON/value parameters and empty-payload lookups remain intact. Existing guarded subtitle and screenalytics paths were retained. The module stays at its unchanged 1,911-line ceiling. | Eight malformed-key cases failed before repair because they reached SQL. Initial affected repository run: 27 passed. Final equivalent validation-at-loop form: 25 cast repository tests passed; unchanged screenalytics result reused (2 passed). Scoped ruff passed. |
| Public typography errors | Unexpected failures return a fixed HTTP 500 error; server diagnostics remain. Successful data, cache hits and seed behavior remain. | 3 focused route tests; scoped eslint and app typecheck. |
| Plan 003 | Existing Getty UUID guard retained byte-for-byte. New regression coverage proves invalid tokens cannot reach filesystem/job resolution, invalid requested job tokens become fresh UUIDs, and legitimate UUID payloads work. Current invalid-hydration exception semantics are preserved. | 6 cases in `getty-prefetch-token.test.ts`; no real Getty files or jobs touched. |
| Plan 032 | The retained `_shared.py` sanitization correction and its queue-status sentinel regression are explicitly included in the backend source commit and delivery selection. It preserves the existing 400/503 branches. | Existing error-detail/route-shape tests: 5 passed. Exact queue-status no-reflection regression: 1 passed. Earlier broad advisor work is not automatically accepted. |

### Candidate, checks and preservation

- Backend source commit: `a76cd1df86fdfc54fde1097623912118d03c7b17` on `chore/repo-hygiene-2026-09-25` (four selected files). App source commit: `b4fcbfa38b500d6ba2a8eaf34bd5b7a5f1d08246` on that same existing branch name in its own repository (five selected files). No branches were switched, and nothing was pushed. These commits do not contain the other dirty Plan 055 overlays.
- Owning-plan closeout for 002/003/032 is committed locally in workspace `371ffea` on the existing `main` branch. Plan 055, the shared plan index/local status and parked-work manifest remain local working-copy updates alongside their pre-existing edits; they were not swept into that commit.
- App quick validation passed all generated checks and 80 tests. Nonincremental app typecheck passed. Final affected eslint/ruff and whitespace checks passed. Earlier passing checks were not repeated after unrelated edits. Full app production build was not run: no current-chat build approval; the larger candidate's build acceptance remains open.
- Independent review of the full safety batch found two TLS problems; correction-only re-review found a non-enumerable client-key regression. After two finding rounds, the lead reassessed and simplified SSL copying to a single descriptor-preserving copy, then closed that exact defect with focused parser regressions. No third review round or unrelated full suite was run. Code/SQL verification and source acceptance remain distinct from a production release.
- Router implementation dispatch was held during its automatic maintenance cutover; the unlaunched preparation was cancelled and the lead implemented the fixes. A verified Sol/high native reviewer ran. Its findings are retained; routed instruction-delivery acceptance was rejected because manually copied optional skill excerpts differed from the preparation. Do not claim exact routed delivery. This protocol limitation is separate from the source findings and the lead's focused verification.
- Before-state hashes, full starting patches, owned preimages, review findings, final source selection and preservation evidence are in [row 2 evidence](/Users/thomashulihan/Documents/Codex/2026-10-04/trr-055-implementation/row2-safety-2026-10-16/checks.json). The repeatable [cleanup SQL probe](/Users/thomashulihan/Documents/Codex/2026-10-04/trr-055-implementation/row2-safety-2026-10-16/cleanup-postgres-probe.mjs) uses only a disposable local database, not the project database.
- [Delivery selection](/Users/thomashulihan/Documents/Codex/2026-10-04/trr-055-implementation/row2-safety-2026-10-16/row2-delivery-selection.json) pins the selected source/test hashes, including Plan 032. Preserve the original fenced Plan 055 candidate plus this selection for row 3; deploying bare HEAD plus row 2 would omit the other uncommitted repairs. Blind v52 rollback remains unsafe.
- Release classification initially detected two now-committed paths still listed as current dirt. Only `_shared.py` and its queue-status test entries were retired from the parked manifest, with their full prior records retained externally. This retirement does not imply provider delivery. All other existing work and recovery material remain.
- No schema, grant, migration, or direct-SQL ownership boundary changed. Existing shared-schema script SQL remains in its current owner; no new app/server direct-SQL call site was introduced.

### Row 3 handoff — not started

1. Assemble the coherent cross-repo release from the retained Plan 055 overlays and row 2 source commits. Complete scoped commit/publication ownership without sweeping unrelated hygiene or experiments into the release. Plan 032 is now selected locally but still absent from the historical v53 snapshot.
2. Close the architecture gate: 34 reviews and 26 exceptions expired October 11, with 26 uncovered overages retained. Row 2 changes the screentime hotspot's source hash while keeping its ceiling; refresh that narrow review metadata too. No waivers, review dates or ceilings were changed in row 2.
3. Complete the required approved app build, friendly-TRR signed-in browser checks, installed Firebase-rule verification and compatible server-before-client/rules release. Recheck actual connection availability; October 4 browser absence/HTTP 401 are historical.
4. Complete secret rotation and exact API/Render/Vercel/Modal source/environment alignment, including dispatch consumers. The standing Modal requirement remains part of row 3: no new runtime delivery is claimed here because the user explicitly requested a stop before production-delivery row 3. Preserve the fixed fenced snapshot and verify recovery before promotion.
5. Retain explicit dependency/model-provenance exceptions, media-watch failure history, licensing and protected-output cleanup dispositions. Existing source-test skips, lint/OOM and dedup limitations remain. Routing-delivery limitations must not be erased by successful source checks.

**Row 2 is complete at the bounded source boundary. Plan 055 remains partial. Stop for the user's review before row 3.**

## Row 1 reconciliation — 2026-10-16

This is the retained pre-row-2 reconciliation snapshot; the row 2 closeout above now owns current status. This section superseded the October 4 checkpoint's current-status claims at the row 1 boundary. Its scope was reconciliation and documentation across the three repositories. The ordering comes from [Review outstanding TRR tasks](codex://threads/01a0f92f-6c91-72d0-9d91-775a036fa98f).

### Candidate identity and preservation

`/Users/thomashulihan/Projects/TRR` and `/Users/thomashulihan/Development/Projects/TRR` resolve to the same workspace. These are three repositories, not two workspace copies. Starting Git state for this reconciliation:

| Repository | Branch | HEAD | Porcelain entries: tracked / untracked groups |
|---|---|---|---|
| Workspace | `main` | `b2205f70f5f1c2dab761740f8d59df76bbf07653` | 33 / 1 |
| Backend | `chore/repo-hygiene-2026-09-25` | `e72d7054a4b92cc8c753becbaa16bbb3c4a09ec6` | 102 / 6 |
| App | `chore/repo-hygiene-2026-09-25` | `c20d8a055ef2afb56d5e309ced3a48c9264810c0` | 40 / 11 |

All three indexes started with no staged changes. Counts above use normal grouped untracked-directory output, not expanded file counts. Workspace advanced through two memory/instruction commits since the October 4 receipt; app advanced through removal of `apps/web/CLAUDE.md`. Backend HEAD is unchanged. These commits do not replace the dirty implementation candidate.

- **93 tracked candidate files match** `p10-final-checkout.json` final hashes: workspace 7, app 32, backend 54. These are Plan 055 deltas against preserved preimages, not ownership of every hunk in each file.
- **14 new candidate files match** their final packet receipts: app 10, backend 4. The final `session-origin.ts` hash comes from the P7 C1 receipt; its initial hash is superseded. All 58 backend overlay files match the isolated Modal candidate receipt.
- **All 148 hotspot source hashes match** the independently reviewed October 4 snapshot. No new hotspot source drift was found. The earlier JS input manifest has 1,217 unchanged hashes; its other two files match the later final P8 extraction and P7 C1 receipts.
- P9 routing/research documents match their retained final hashes. The parked-work manifest remains the owner/disposition record for surrounding work. Matching a candidate delta does not accept older hygiene changes, experiments, API error repairs, or other hunks for delivery. Keep the original preimages, diffs, tests, reviews, isolated backend snapshot and recovery material.
- No branch switch, stage, commit, push, stash, reset, deletion, dependency install, application change, provider mutation or new test asset is part of this row. Plan 055 remains an untracked local document; this update does not publish it.

Detailed path classifications, hashes, current Git state, per-file hotspot follow-ups and preservation results are retained in [row 1 reconciliation evidence](/Users/thomashulihan/Documents/Codex/2026-10-04/trr-055-implementation/row1-reconciliation-2026-10-16/reconciliation.json), alongside the original implementation packet. The pre-edit preservation manifest covers every tracked dirty and expanded untracked path across all three repos. This is local evidence, not a portable public release artifact.

### Reconciled package ownership and evidence

| Package | Current candidate and retained proof | Remaining acceptance / owner |
|---|---|---|
| P1 backend surveys | Scalar UUID RPC, verified transaction-local identity, ordered SQL detail results and error handling remain in the matching candidate. Retain actual SQL/JWT/HTTP, pool isolation, rollback and focused test evidence. | P10: verify the actual API deployment and connected app behavior. Keep backend `surveys`, app `firebase_surveys`, and legacy flows separate. No survey-unification project or production migration is needed for this repair. |
| P2 app persistence | Normalized-answer checks, owner-scoped rules, server-owned game completion and retryable legacy partial writes remain. Retain emulator/SDK/HTTP and the final 35-check real legacy SQL procedure. | P10: full build, signed-in UI, installed-rule identity and compatible server-before-client/rules release. Historical Firebase rule inspection failed with HTTP 401; present access is unverified. |
| P3 media safety | Destination pinning, redirects, TLS, caller byte caps and total deadlines remain in both language implementations. Retain independent correction review and transport probes. | P10: connected runtime acceptance. This packet does not repair the separate season-cleanup/SSL defects assigned to row 2. |
| P4 jobs / Plan 010 | Claim fencing, transactional finish/counters and same-run recovery-child handling remain. Retain C1 SQL/full-runner evidence, independent review and P8 composition checks. | P10: current deployment, dispatch-consumer identity and runtime recovery proof. Plan 010's September missing-source statement is historical; do not start a duplicate atomicity implementation. |
| P5 dependencies | Matching JS/Python manifests and locks; operator-cookie environment isolation; historical Linux vision smoke. | P5/P10: six recorded JS advisory matches, isolated operator cryptography disposition and checkpoint provenance/loading assumptions remain. No fresh advisory scan or clean dependency claim. |
| P6 messaging | Atomic direct-conversation creation, message/timestamp persistence, scoped request replay and best-effort events remain. Retain actual concurrency, injected-fault and membership-lock probes. | P10: API/app runtime acceptance. Redis listener recovery remains a separate later workstream; durable reads and best-effort events do not prove it. |
| P7 auth/data | Firebase verification rejection fails closed; login/logout bind explicit origin to actual Host. Retain the final 162-check C1 adapter evidence and read-only data dispositions. | P10/issues 50/78: production auth settings, secret rotation, signed-in browser and installed-provider evidence. Licensing ownership remains unresolved before redistribution. |
| P8 structure/governance | Both audited backend cycles and import debt remain removed; extraction files match final evidence, including the unchanged 208-test app runtime suite inputs. | Architecture governance is **reopened** by expiry; see below. Existing lint/OOM limits, 35 detail-SQL skips and cross-identity request-dedup limitation remain explicit. |
| P9 organization | Domain routing, reference-only Vue lifecycle, diagram authority and research classification remain documented. | Plan 019/P9: protected outputs and research remain in place until receiver/archive/reference gates close. Documentation is not physical-cleanup completion. |
| P10 delivery | Retain October 4 Modal v53 readiness, composition, vision and sampled source-identity receipts. | Current providers and UI are **not reverified** in row 1. Full app build, Firebase/rules, app/API publication, provider alignment and safe recovery remain open. |

### Current gates and expired exceptions

| Check | October 16 result | Meaning |
|---|---|---|
| `TRR-Backend/.venv/bin/python scripts/architecture/check-release-manifests.py` | PASS: 9 packets, 15 evidence records | Existing local classification is valid. This does not prove clean committed candidates or a deployed release. Historical packet bases are unchanged. |
| `python3 scripts/architecture/check-import-graph.py --check-zero` | PASS: backend 546 modules / 1,497 edges; app 1,148 / 3,016 | Backend/app cycles, social legacy imports and nonliteral import debt remain zero in checker scope. |
| `TRR-Backend/.venv/bin/python scripts/architecture/check-hotspots.py --fail-expired --as-of 2026-10-16` | FAIL: 34 expired file reviews, 26 expired exceptions, 26 uncovered line-ceiling overages | All expiries are October 11. Previous passing evidence is time-limited and no longer satisfies this gate. |
| Workspace handoff check | Initial age-based drift; canonical status and generated workspace index reconciled in this row | Preserve historical records and use the supported generator. No app/backend handoff rewrite is required for this documentation pass. |

The 26 exceptions are reassessed as **unchanged source, expired authorization**. Their hashes and measured maxima still match; there is no basis to call them current or to raise ceilings. P8 retains the exact per-file owner, extraction seam and closure action in `p8-hotspots-parent-review.md` and the new evidence file. Before release, reduce the affected files or obtain individually justified, bounded review under the existing policy. Also renew the eight expired reviews without overages. No waiver or review date was extended in row 1.

Historical source checks and reviews are reused only for the matching final inputs. No app suite/build, live SQL, browser session, dependency scan or provider probe was repeated solely to refresh a date. Browser-profile absence and Firebase HTTP 401 describe October 4 observations; they are not claims about today's connections.

### Delivery gap carried into row 2

The local Plan 032 correction in `TRR-Backend/api/routers/socials/_shared.py` sanitizes the unexpected-error response. It is preserved earlier work and is **not included** in the isolated v53 overlay. Its current SHA256 is `cdda4e3edfe39d59490771df0ad7db95b97b2197430f77c3f3871d5b67300b69`; the v53 snapshot contains `db082dddb4653073f8c6ceb7a5ece18a866ccaadf6d3df113d4a594ce6ab900e` and the raw-error branch. Earlier v52 evidence must not be promoted into v53 acceptance. Row 2 must include this correction explicitly in its delivery candidate; row 3 must verify actual API/Modal targets. This is snapshot evidence, not a live production exposure claim.

### Remaining work before release; next row boundary

1. **Row 2 — safety batch, not executed here:** season-scoped deletion of shared media; strict SSL behavior in the cleanup script; screentime dynamic-SQL field validation (Plan 002); safe public typography errors; Getty UUID-token regression coverage (Plan 003); include and review the retained Plan 032 correction for delivery. Current source still shows these gaps; the Getty guard itself already exists.
2. **Row 3 / P8/P10:** close the expired review/exception gate; complete approved app build and friendly-TRR signed-in acceptance; coordinate Firebase rules and app/API publication; rotate and record the shared admin secret; refresh exact Modal/Render/Vercel source identities and dispatch consumers. Resolve access through supported connections when that work starts. No build or publication approval is requested by this reconciliation.
3. **Residual disposition:** keep dependency exceptions, model provenance, media-watch failure history, licensing, protected-output cleanup and Jev routing limitations explicit. These remain with their named packages; they are not silently accepted or merged into row 2.

The last verified Modal receipt is **October 4**, `admin-56995 / trr-backend-jobs / main`, v53, tag `plan055-20261004-bb660d43`. Its candidate receipt still contains preparatory `runtime_status`/`readiness_status` values; the later deployment/readiness/smoke receipts establish the historical deployment. Neither record establishes current runtime state. Retain forward recovery from the fixed snapshot; do not blindly restore unfenced v52 after new claims. The historical media-watch heartbeat did not close its failure history.

**Row 1 is complete at the source/evidence/document boundary.** Plan 055 remains partial. Stop here for the user's review before moving to row 2. No Modal update is needed for these documentation changes. Backend/API test evidence is retained rather than rerun; TRR-APP build is not applicable to this documentation-only pass, and the implementation candidate's required full-build acceptance remains open.

## October 4 implementation checkpoint — historical

The following is the retained October 4 checkpoint. Present-tense statements here describe that snapshot; the October 16 reconciliation above owns current status.

- Survey identity/validation, Firebase ownership and legacy retry behavior, media destination safety, job fencing/counter atomicity, messaging transactions, and session authentication corrections have focused source and real-boundary evidence. The final legacy Firebase/PostgreSQL probe passed 35 checks; backend extraction passed six actual PostgreSQL groups. No production data migration was needed.
- App extraction retains existing behavior and passes the unchanged 208-test runtime suite. Final combined app quick validation and nonincremental type checking pass. Request deduplication still uses the original route/detail keys; cross-identity isolation was not added by this extraction.
- Backend extraction removes both audited cycles and the internal legacy/nonliteral import debt without reducing checker scope. Independent review found no new blocking defect. Explicit API/Modal composition dependencies remain.
- The 148 hotspot reviews are current. All ceilings remain unchanged; 26 individually reviewed exact-snapshot exceptions expire October 11. The checker passes but does not enforce hashes/maxima embedded in exception reasons; source changes require renewed review.
- The direct-SQL inventory now records 135 app-local call sites, with no shared-schema exception added. Release classification passes after separating current Plan 055 work from pre-existing dirt and retiring stale current-dirt entries. Historical packet bases remain unchanged.
- Dependency source candidates pass isolated checks and independent review. Six JavaScript advisory matches and the isolated operator cryptography exception remain documented. Linux/deployed vision inference passed on Modal v53 with torch 2.13.0+cpu / torchvision 0.28.0+cpu; deployed checkpoint identity is recorded separately from the Mac smoke.
- The full app build awaits explicit current-chat approval required by `.codex/rules/trr-project.md`. The active browser connection exposes THB and codex, but no TRR profile; signed-in UI proof is pending that connection. Firebase rules and app-provider publication remain coordinated with the app release.
- Modal target confirmed live: `admin-56995 / trr-backend-jobs / main`. Isolated candidate `plan055-20261004-bb660d43` uses backend base `e72d7054a4b92cc8c753becbaa16bbb3c4a09ec6` plus 58 owned overlay files, excluding unrelated pre-existing dirt. Deployed as v53; explicit-main readiness, API health, social provider composition and real vision inference passed. Live source hashes for job ownership and vision match the snapshot. The media watch resumed its lease heartbeat; its pre-existing failure history remains unresolved. Blind rollback to unfenced v52 is unsafe after new claims; retain this fixed snapshot for forward recovery.
- Evidence and repeatable procedures: `/Users/thomashulihan/Documents/Codex/2026-10-04/trr-055-implementation/`. No commit, push, branch switch, bulk deletion or new test source file is part of this delivery.

## Execution record

The entries below preserve the chronological execution record; the checkpoint above supersedes earlier in-progress statements.

- User authorized implementation using Jev-routed agents on 2026-10-04. The plan-only boundary below describes the original planning deliverable; current implementation is authorized within the recorded package and project safeguards.
- P1 assigned through Jev to `fix_surveys`, task `trr-055-p1-surveys`, assignment `8801f7a8-1bb1-46de-b7a0-1face1253196`; selected Sol/high. Native host record identifies child `01a1058c-9a6e-7cf3-adee-814101c036d7`. Runtime reconciliation remains pending after a management timeout; exact prepared-message delivery is not verified because two optional skill-excerpt phrases differed. Child was directed to the pinned canonical skill file. No routed acceptance is claimed.
- P1 preserves pre-existing edits to `tests/api/test_survey_submit.py`. Initial relevant checks: 42 passed; actual adapter probes reproduce the scalar UUID and nested SQL projection failures.
- Parent read-only backend connection verified the TRR project and a `postgres` role with RLS bypass and permission to set `authenticated`. Settled P1 design: fixed transaction-local authenticated role plus verified request claims; no user-supplied role and no anonymous schema relaxation. Disposable local PostgreSQL checks authorized; no production writes delegated.
- Implementation evidence: `/Users/thomashulihan/Documents/Codex/2026-10-04/trr-055-implementation/`. Parent owns remaining assignments, independent review, integration, current provider verification and delivery.
- P1 source candidate: 100 focused checks and five parent-maintained API smoke checks passed. Actual disposable SQL/JWT/HTTP checks cover authenticated identity, scalar UUID, rollback, pool reuse, nested-transaction rejection and ordered detail queries. Connected aggregate scalar/array, JSON adaptation and native timestamp failures were repaired. Runtime delivery remains unverified; no migration was needed.
- P2 normalized answers: Jev assignment `ad5ca8ef-44e9-4796-9215-6ac8057a992c`, `fix_app_surveys`, Sol/high. Preparation timed out after applying; the saved native-prepared receipt was recovered before one native launch. Firebase rules/games/legacy persistence remain separate pending work.
- P3 media: Jev assignment `3e11c559-f39a-4e95-8850-3eee6bd89ca9`, `fix_media`, Sol/high. P4 jobs: `a4422484-7786-4032-b9dc-e1f9672d9d5d`, `fix_job_fencing`, Sol/high. Both are in progress, not accepted.
- P4 settled design: additive UUID in job config for each acquisition; immutable exact-job context bound at execution entry and reset in finally, explicit propagation across thread boundaries, no current-row token lookup or worker-prefix bypass. Parent owns companion call-site integration. Counter failure must roll back job completion under plan 010.
- Local app configuration names Firebase `trr-web-25d2e` and TRR-bound database candidates. Live Supabase metadata confirms `firebase_surveys` writes denied to authenticated/service roles and available to postgres; actual app connection role and installed Firebase rules still need verification. No grants were changed.
- Later app-role read-only probes verified both configured database candidates target TRR and connect as `postgres`, with the expected privileged writes. Deployed app identity and installed Firebase rules remain unverified.
- P1 independent review returned no findings; retained actual SQL procedure closes its initial reproduction-detail gap. Normalized P2 independent review returned no qualifying findings. Runtime acceptance remains open.
- P3 independent review found the Python caller byte-limit regression and a TLS-handshake total-deadline gap. These are blocking corrections in progress; no transport acceptance is claimed. TypeScript transport had no qualifying findings.
- Firebase P2 candidate passed actual isolated rules, boundary, HTTP and client checks plus typecheck/lint. P6 messaging candidate passed actual SQL/JWT/HTTP concurrency/fault checks and existing DM/realtime checks. Both await independent review. Legacy real SQL verification, Firebase rule publication, app build/browser and provider delivery remain open.
- P4 correction now includes retained-generation fencing for delayed cleanup/heartbeat/dispatch metadata and atomic same-run authenticated fallback children. Existing durable dispatch lease is reused; a per-run authenticated-child cap must be enforced by both reservation and claim paths, with nonblocking locks and no provider calls under locks.
- P5 Python assignment `b842ccdb-f6e9-44bd-a0b6-c556bc5c05f6` is active. Parent approved separating the Chrome-cookie helper into an operator-only environment to remove its cryptography pin from runtime locks. Coordinated Torch/Torchvision compatibility remains an explicit decision gate.
- P2 Firebase review closed two correction batches: canonical game identity plus ordered dual writes, then latest-persisted completion outcomes so failed completion followed by an incomplete save cannot navigate to results. P6 independent review found no remaining actionable defect. Both retain actual procedure/hash evidence; installed rules and real legacy SQL/browser proof remain open.
- P3 correction review closed configured-byte-cap and TLS-handshake deadline findings. Header-only probes retain DNS/TLS/redirect validation. Source acceptance is separate from runtime delivery.
- P4 independent review found four blockers: residual-health rollback of queued recovery children, incomplete administrative dispatch snapshots, a refill path through the legacy dispatcher, and ignored account-media reservation rejection. C1 fixes are in progress with one integrated disposable SQL/full-runner verification owner. A completed source shard may hand off residual gaps only when actual same-run active recovery children cover every deliberately deferred target, with explicit incomplete/deferred metadata.
- P5 JavaScript candidate passed frozen install, native/tool smoke, 80 quick checks and nonincremental typecheck. Remaining six GHSA are documented by dependency path and affected API; no full-build or deployed-remediation claim. Python runtime/main, lean and browser locks have no current OSV matches; vision and the isolated operator cryptography pin retain explicit unresolved dispositions.
- AUTH-R2 now fails closed on every Firebase Admin verification rejection. Initial offline checks passed. Independent actual Next adapter review exposed a Portless origin mismatch not covered by direct NextRequest construction. C1 binds explicitly configured external origins to the actual Host header; final adapter review remains pending. No arbitrary forwarded-host trust is added.
- P7 live read-only metadata verifies intentional service-only access for the four RLS INFO tables. Both flagged FK child tables are empty; index assessment is deferred with activation/retention triggers, without schema changes. License ownership remains a maintainer decision before redistribution; optional 15-second cross-admin cache freshness is unchanged.
- P8 app feature extraction is active under Jev assignment `35135ff4-19b7-4027-97c8-1d5dbc3499fb`; current UI/API/cache responsibilities move under the existing feature boundary. Hotspot review assignment `e7d7ba5c-5fbc-41bc-ad4a-8314b883df99` is prepared but not launched after native capacity rejection; no execution claimed. Backend cycle removal waits for P4 behavioral acceptance.
- P9 domain/research/experiment documentation and diagram authority candidate completed under `cd9848a9-6f32-4c9e-9c44-bb0abe75ea1d`, with isolated generation, 83 link checks and retained source hashes. Physical plan019/output disposition gates remain open; no cleanup is implied by classification.

## Outcome and scope

Repair the audited correctness and security defects, establish evidence that the app/API/workers work together, then simplify domain ownership and code organization. Keep the workspace, TRR-APP and TRR-Backend as three independent repositories. A monorepo conversion is deferred: it does not fix the observed persistence, authorization, transport or job-ownership defects.

This plan is the execution index for the October audit findings. Existing plans remain owners of their existing requirements; do not create parallel implementations or erase unresolved acceptance work. Writing this plan does not authorize implementation, deployments, cleanup, new test assets or a production app build.

Audit evidence, including source lines and safe reproductions:

- [Audit summary](/Users/thomashulihan/Documents/Codex/2026-10-03/trr-workspace-audit/AUDIT.md)
- [Finding register](/Users/thomashulihan/Documents/Codex/2026-10-03/trr-workspace-audit/FINDINGS.md)
- [Architecture and organization proposal](/Users/thomashulihan/Documents/Codex/2026-10-03/trr-workspace-audit/ARCHITECTURE-ROADMAP.md)
- [Evidence and coverage](/Users/thomashulihan/Documents/Codex/2026-10-03/trr-workspace-audit/EVIDENCE.md)
- [Dependency triage](/Users/thomashulihan/Documents/Codex/2026-10-03/trr-workspace-audit/DEPENDENCIES.md)

These are local evidence links, not published artifacts. Review security detail and link portability before any later publication. No publication is part of this request.

## Starting state and constraints

Planning-time Git inspection confirms the audit's HEADs and dirty-entry counts: workspace `3d5b0cff` on `main` (23); app `06cf0986` (11) and backend `e72d7054` (56), both on `chore/repo-hygiene-2026-09-25`. Counts/HEADs do not prove unchanged working-file contents; package owners must recheck the specific source they change.

The audit recorded three failing gates: backend import debt, hotspot reviews/ceilings, and release classification. It recorded passing focused tests, typechecks and generated-contract checks, but no authenticated browser proof or full build. Deployed revisions differ from the checkout. None of these results should be promoted into current release acceptance without checking relevant source and runtime identity.

The planning-time `make handoff-check` now fails with generated-index drift, including date-based movement into Older Plans. No source snapshot was repaired and no generated handoff was rewritten. The normal pre-plan wrapper can auto-sync; this planning pass used its read-only check because unrelated auto-repair is outside scope. P0 below owns reconciliation before implementation.

- Stay on current branches unless the user requests otherwise; preserve dirty work and existing worktrees.
- Shared contracts and shared database changes are implemented backend-first, then app consumers.
- Preserve public URLs, serialized jobs, API compatibility, Python module aliases and applied migration history.
- Use existing test assets and direct controlled behavior checks. List failure cases before implementation. New unit/integration/E2E/spec files, fixtures or reusable test helpers require explicit approval; an implementation request alone does not authorize them.
- Do not run a full production app build without current-chat approval. Run `make app-validate-quick` first; request the required build only after a concrete candidate exists and lightweight validation passes.
- Reverify provider identity before each affected live action. Supabase is `vwxfvzutyufrkhfgoeaa`; Modal is `admin-56995` / `trr-backend-jobs`, with environment resolved from current request/config/live evidence. Audit evidence used `main`, which must be reconfirmed.
- Plan-only scope ends with this document. During later authorized implementation, the standing Modal completion grant applies to affected backend/worker/runtime changes; do not ask for duplicate deployment approval once the target is unambiguous. Other live mutations follow their applicable authorization rules.

## Design decisions

1. **Keep repository boundaries; improve internal boundaries.** Thin route adapters, domain-owned behavior, shared transport/auth helpers and explicit persistence owners are the target. Avoid broad moves while repairing behavior.
2. **Repair each survey persistence family separately.** Backend `surveys`, app `firebase_surveys`, and legacy Firebase/SQL flows must have distinct contracts and acceptance. Do not migrate them into one database as a prerequisite for correctness.
3. **Preserve authentication guarantees.** Recommended backend survey policy is authenticated-only because current schema/grants require identity. If anonymous submissions are a required product feature, that is a separate explicit product/schema decision; never weaken NOT NULL or grants simply to mask lost identity. Independent packets can continue while this decision is resolved.
4. **Keep currently used Firebase collections where they are for the initial repair.** Align narrowly scoped owner rules and clients. Move aggregate writes behind trusted server behavior. Defer wholesale Firebase/Postgres consolidation until a separate migration case is accepted.
5. **Every mutable job write must prove current ownership.** Use an existing immutable claim-generation contract if available; otherwise introduce one additively. A reusable worker name by itself is insufficient. Keep the durable detail-contract lane intact.
6. **Use one documented network-safety policy across Python and TypeScript.** Keep idiomatic implementations, but align address, DNS, redirect, byte-limit and deadline behavior. Validation must apply to the destination actually contacted.
7. **Keep optional work optional.** Cross-admin cache freshness, index removal, monorepo conversion and unimplemented product features are not blockers without an agreed requirement. Unverified auth risks receive investigation, not invented exploit claims.

## Work packages and dependency order

| Package | Priority / owner | Findings | Depends on | Done when |
|---|---|---|---|---|
| P0 — Reconcile candidate and acceptance | First / lead + workspace | WS-03, WS-04, WS-05 | — | Dirty ownership, actual failure cases, source identities and required proof are recorded |
| P1 — Backend survey contracts | P1 / backend data owner | BE-01–03 | P0; survey identity decision | Real SQL/HTTP path returns correct identity, details, UUID and errors |
| P2 — App submission and Firebase correctness | P1 / app persistence owner | APP-01, APP-02, APP-04 | P0; Firebase/app-DB identity | Valid submissions persist; foreign answers and cross-user/aggregate writes are denied |
| P3 — Media destination safety | P1 / transport owners | BE-04, APP-03 | P0; shared policy agreed | Unsafe destinations cannot be contacted through any sampled hop |
| P4 — Social claim fencing | P1 / backend job owner | BE-05 | P0; reconcile plan 010 | Stale workers cannot change newer claims, cancellation or counters |
| P5 — Dependency maintenance | P1 triage / app + backend owners | DEP-01 | P0 | Applicable advisories fixed or explicitly justified, all affected lock/runtime lanes verified |
| P6 — Messaging transactions | P2 / backend messaging owner | BE-06, BE-07 | P0; reuse P1 identity contract if needed | Pair creation is unique/atomic; send response and durable state agree under failure |
| P7 — Authentication/data investigations | P2 investigation / security + data owners | AUTH-R1/R2, DATA-R1/R2, LEGAL-R1; APP-05 optional | P0 | Each risk has a verified result, bounded repair or explicit accepted disposition |
| P8 — Structural and generated-document repair | P2 / domain owners | WS-01, WS-02, ORG-01 | Relevant behavioral repair accepted | Cycles resolved; owners/ceilings justified; first extractions preserve behavior |
| P9 — Taxonomy and safe disposition | P3 / workspace + domain owners | ORG-02–04 | P0; relevant P8 ownership | One vocabulary/index; experiments labeled; approved moves preserve references |
| P10 — Integration and release acceptance | Required / lead | WS-04, WS-05 and all shipped findings | Each intended release packet | Candidate, deployed targets and observed behavior are linked with rollback evidence |

P1–P4 can run in parallel only with disjoint file ownership. Dependency investigation can run alongside them; lockfile upgrades should land separately from behavioral repairs so regressions are attributable. P6 and P7 do not need to wait for all P1–P5 work. P8 must wait for the behavior of the specific domain it extracts. P10 is repeated for each coherent release packet; security repairs need not wait for organization work.

## P0 — Reconcile the candidate

**Owned surface:** workspace release manifests, relevant handoff sources and this plan's status. Lead owns source/runtime acceptance and unresolved product decisions.

1. Refresh Git status, relevant file hashes and current provider revision metadata. Classify existing changes as included, deferred or owned by another task; do not reset/stash or sweep all dirty files into the repair.
2. Recheck audit source locations and reproduce the boundary failures using existing safe mechanisms. Mark already-fixed findings with evidence; remove no finding solely because a branch name or old plan says done.
3. Resolve backend anonymous-submission policy and confirm the Firebase project plus app database target. Verify actual application database identity semantics; connector identity cannot stand in for it.
4. Reconcile the handoff drift through its canonical sources and supported generator only within authorized documentation scope. Restore release manifest classification for the selected changes.
5. Record existing passing evidence, what each packet invalidates, and the owner of every verification run.

**Acceptance:** a bounded candidate includes revision and relevant dirty-diff identity; all blocker IDs have a requirement/failure scenario/closure check; required versus optional scope is explicit. Source and runtime readiness remain separate.

## P1 — Repair backend surveys

**Owned files:** `TRR-Backend/api/routers/surveys.py`, `api/deps.py`, `trr_backend/db/session.py`, directly related authorization/transaction helpers, and only necessary new forward migrations. Changes to shared DB helpers require lead review of all affected callers.

- Inventory RPC consumers before changing generic return/error semantics. Add a deliberate scalar-result contract for UUID-returning functions and consistently map SQL errors to API statuses. Preserve unrelated row-returning RPC behavior.
- Bind the verified request identity within the same database transaction as submission. Use parameterized transaction-local context or an explicitly authorized identity argument consistent with the actual connection role; verify context cannot survive pool reuse. An auth.uid()-dependent function must not run through an identity-free adapter.
- Replace PostgREST-style nested projection with supported batched SQL/joins, retaining question/option ordering.
- Align the endpoint's authentication/anonymous promise with the selected policy. Define conflict, unpublished/closed-survey and malformed-input responses without exposing raw SQL errors.
- Check app consumers and generated contracts after the backend contract is settled. Update only affected consumers; do not confuse this path with app-owned normalized surveys.

**Acceptance:** real disposable/local database plus HTTP exercise proves valid submission returns one UUID and one durable response; retry/duplicate returns the intended conflict; rejected requests leave no response; two users and a reused pooled connection retain correct isolation; both detail routes return ordered options. Use supported existing infrastructure; missing safe DB infrastructure is a named verification gap, never a reason to test writes in production.

**Rollback:** preserve prior code and contract snapshots; use additive schema changes and forward correction for persistent data. Do not restore an old adapter that silently drops identity and call that a successful rollback.

## P2 — Repair app submissions and Firebase ownership

**Owned files:** normalized submission route/repository, existing survey validation owners, Firestore rules, profile/preferences/survey client persistence, and the two game aggregate managers/server endpoints as needed.

- Validate the submitted answer set against the selected run's survey inside the transaction: question membership, option membership, duplicate IDs, required answers, permitted value shape/range and any defined completion rules. Preserve run-window checks and advisory-lock submission limits.
- Confirm current live constraints before deciding whether an additive database constraint is useful. Shared-schema ownership remains backend-first; app-local SQL exceptions must stay documented.
- Define explicit collection access: users edit their own permitted profile fields; preferences and responses are owner-scoped; public profile/username access exposes only intended public fields; metadata is server-owned where appropriate. Do not grant broad collection writes.
- Server-own aggregate analytics, validate accepted game events and deduplicate event processing. Do not simply proxy arbitrary client totals through an authenticated server endpoint.
- Define failure handling for legacy Firebase→Postgres dual writes: visible retry/reconciliation status, stable submission identity and no silent claim of full success after partial persistence. Avoid a wholesale storage migration in this packet.

**Acceptance:** profile completion/reload, preferences/reload, valid survey submit/reload, foreign question/option rejection, missing required answer rejection, user isolation, aggregate overwrite/delete denial and duplicate event handling. Verify installed Firebase rules separately from source rules; mock-only passes do not close this packet.

**Rollback:** stage compatible server behavior before tightening dependent client rules; retain previous rule/code revisions. Rollback may restore a working restricted path, never reopen arbitrary aggregate or cross-user writes.

## P3 — Enforce safe media fetching

**Owned files:** backend `media/s3_mirror.py` and `socials/media_url_safety.py`; app image-proxy/analyze-image routes and a shared server transport owner. Keep S3/object naming and content hashes unchanged.

- Agree a shared policy: allowed schemes/origins where appropriate, complete IPv4/IPv6 parsing, public resolved destinations, rejection of private/mixed answers, bounded redirects, maximum bytes, connection and whole-body deadlines.
- Ensure the checked destination is the one contacted while preserving correct TLS certificate/hostname verification. A separate DNS lookup followed by unrestricted fetch is insufficient.
- Apply the policy at each redirect and before network access. Reuse the existing safer transport where it meets the full contract; audit its gaps rather than assuming its name establishes safety.
- Preserve valid provider redirects and controlled error behavior. Report denied origin safely without credentials/query secrets.

**Acceptance:** actual transport behavior with controlled endpoints proves private/literal/mapped addresses, DNS changes and redirected private destinations are rejected before contact; normal allowed images still import; slow/oversized bodies terminate. No cloud metadata or real private-service probing.

**Rollback:** retain prior source and object references, but do not reactivate a known unsafe fetch path. Prefer disabling the affected import action temporarily if a safety-preserving fallback cannot work.

## P4 — Fence standard social job mutation

**Owned files:** ordinary claim/progress/finish/recovery/cancel paths in `social_season_analytics_impl.py` and existing control-plane/executor owners. One implementation owner touches the large module at a time.

- Reconcile [plan 010](010-atomic-social-run-finish-counters.md): its counter atomicity issue is related but distinct from stale-claim fencing. Preserve both requirements and their separate acceptance checks.
- Trace every production caller and define the claim identity created by acquisition and passed through execution. If the existing immutable generation is sufficient, use it consistently; otherwise add a lease token through an additive migration and mixed-version rollout.
- Require matching job/claim identity and permitted current status in progress/finish updates. Check affected-row results. A stale completion must not update associated counters or enqueue follow-ups.
- Ensure cancellation wins according to the documented state machine; keep retry/requeue/recovery transitions explicit. Preserve detail_contract_version=1 receipt semantics.

**Acceptance:** controlled concurrent A/B claims prove old A cannot finish after B claims; cancellation is not resurrected; retries retain correct attempts; duplicate completion is idempotent; counter/follow-up changes reflect accepted transitions only. Reconcile strict counter atomicity or a reviewed durable repair invariant under plan 010.

**Rollback:** record worker versions and claim schema compatibility before rollout. Do not mix a token-required contract with unfenced old writers. Rollback requires a compatible writer or controlled halt of the affected dispatch lane, not blind image reversal.

## P5–P7 — Dependencies, messaging and unresolved risks

**P5 dependencies:** refresh advisory evidence; distinguish runtime reachability from package matches. Revisit the pinned glob override; update direct parents and lockfiles through supported tools. Cover backend main and Modal lane locks, native wheels and container/runtime inputs. Keep dependency commits separate from domain refactors. Acceptance requires applicable advisory closure/disposition plus affected auth, image processing and rendering checks. Preserve previous locks and images; do not claim deployed remediation from a lockfile update alone.

**P6 messaging:** restrict direct-conversation lookup to the 1:1 contract; use canonical pair uniqueness and one transaction for conversation/members/read receipts. Reject self/invalid targets before leaving durable orphans. Make message/timestamp writes atomic. Decide the promised delivery level: if reliable events are required, use an existing durable outbox or explicitly designed equivalent; otherwise document best-effort fanout and reconcile reads. Add request idempotency where retries can duplicate messages. Acceptance: concurrent reciprocal creation yields one conversation, injected write failure leaves consistent state, retries do not duplicate accepted sends, and API/event semantics agree. Do not remove duplicate/orphan historical rows without a separate reviewed data-repair packet.

**P7 investigations:** verify same-origin session creation and Firebase fallback rejection semantics with controlled browser/provider evidence. Add proven repairs to the same packet with explicit closure. Inspect RLS policies/roles for the four service tables without opening them merely to silence INFO notices. Assess the two FK indexes using representative plans/write cost; never remove 379 indexes from unused-index notices alone. Obtain first-party license/third-party-notice ownership before redistribution. APP-05 cache freshness remains optional: document accepted TTL first, then change invalidation only if the product requires it.

## P8 — Reduce coupling without changing behavior

**Owned surfaces:** backend social dependency graph and domain modules; app social account-profile feature; generated diagram authority. Coordinate existing [plan 051](051-social-architecture-media-acceptance-followup.md) and tooling follow-up [052](052-historical-tooling-gate-followup.md).

1. Break the `instagram_detail_targets ↔ instagram.catalog_ingest` and `account_catalog.launch ↔ social_season_analytics_impl` cycles with import-neutral types/ports and explicit composition. Preserve compatibility aliases and patch identity.
2. Extract one settled backend lifecycle responsibility behind those ports. Do not move the entire 68k-line module at once or hide it behind new indirection without reducing ownership overlap.
3. Extract the app account-profile feature into cohesive UI, state and API-adapter units under a domain feature boundary. Keep Next route files and component-facing interfaces stable.
4. Review 148 expired hotspot reviews, 11 expired ceiling exceptions and 24 growth violations against current code. Classify generated vs authored hotspots. Each waiver needs a named owner, bounded rationale and revisit criterion; blanket expiry extension is not closure.
5. Resolve manual-versus-generated diagram ownership. Preserve authored edits, change the source of generation, then inspect the generated diff.

**Acceptance:** zero-debt import gate passes without reduced scope; affected import/runtime behavior and feature flows remain correct; hotspot exceptions are current and justified; generator produces only intended changes. Record architectural improvement through removed cycles/ownership overlap and understandable interfaces, not an arbitrary line-count target.

**Rollback:** behavior repairs and structural moves remain separate changes so extraction can be reverted without losing fixes. Keep facades until consumers and compatibility ledgers permit removal.

## P9 — Naming, documentation and safe cleanup

- Adopt the proposed domain vocabulary: catalog, social, media, community/surveys, games, design and operations. Map product terms to API, persistence, job and code owners; preserve language/framework conventions and established aliases.
- Add one short domain routing index; link existing authority rather than copying large documents. Keep specialized Instagram/runtime glossaries in their current owning documents.
- Label Vue Wordle reference-only with owner, installation/CI boundary and promotion/retirement criteria. A move into experiments is optional, not a prerequisite for clarity.
- Execute scratch/research disposition through existing [plan 019](019-clean-tracked-root-artifacts.md) and the output-disposition ledger. Require source hash, inbound-reference review, receiver acceptance and reversible archive before each relocation/removal.
- Retain applied migrations, active aliases, credentials/data, existing rollback evidence and runtime-imported generated inputs. Do not treat ignored directories or old files as automatic deletion candidates.

**Acceptance:** representative names resolve to one owner; internal links/imports and public URLs remain valid; moved artifacts have matching hashes and known receivers; no unrelated dirty work is included. No bulk filename/schema/environment rename is planned.

## P10 — Integrate, review and deliver each release packet

1. Run the narrow relevant existing checks. App baseline: `make app-validate-quick` and nonincremental typecheck. Backend: affected auth/survey/DM/media/job tests plus actual adapter/transaction evidence. Shared changes: backend OpenAPI check, app generation check and consumer behavior together.
2. Run affected workspace gates: import graph, hotspots, release manifests, durable contracts, direct-SQL inventory, migration ownership, environment/deployment contracts and handoff check. Do not repeat unrelated passing checks without changed inputs or a required gate.
3. Obtain independent review of authentication, SSRF transport, transactional integrity and worker concurrency changes. Track blocker IDs and affected follow-up evidence; use no CodeRabbit PR-review step under the current preference.
4. For app routing/contracts/build-sensitive changes, complete the required production build after explicit approval and passing quick validation. If approval is not given, label build acceptance incomplete; do not silently waive it.
5. Verify real UI behavior through the friendly TRR browser profile and Portless URLs. Default startup is `make dev-hybrid` when startup is within implementation authority. Do not substitute another account/profile; missing identity limits only the affected verification.
6. Reconfirm Supabase project and migration target; review forward migration and rollback implications before authorized writes. Keep version-ledger parity separate from actual schema/policy/transaction proof.
7. For affected Modal deployment work, verify profile/app/environment live, record exact source including dirty changes, deploy through the current backend procedure, then run `python3.11 scripts/modal/verify_modal_readiness.py --env <resolved-env>` and a targeted smoke with the same explicit environment. Verify dispatching consumers use that deployment. This is future implementation work, not performed by this plan.
8. Complete authorized API/app provider delivery and source-identity checks. Record Render, Vercel and Modal identities together; healthy endpoints alone do not establish feature compatibility. Follow applicable publication instructions if commit/push/PR/merge is requested.
9. Save a compact acceptance record: included finding IDs, source revisions/diffs, migration/rule versions, check evidence, provider targets, observed behavior, rollback method and remaining limitations. Keep per-packet statuses as planned → in progress → source verified → runtime verified → accepted; never label a source-only result runtime verified.

**Stop promotion** on cross-user identity leakage, stale-claim mutation, network-safety bypass, failed contract compatibility, data loss, wrong provider identity or missing required build evidence. Continue independent safe work while the affected packet is unresolved.

## Planned delegation

These are future assignments to prepare through the current Jev Router. No model/effort is selected here and no implementation helper has been launched. Check availability/capacity and current file ownership at dispatch. All helpers must preserve others' edits and stay on the current branch.

| Assignment | Semantic role / mode | Ownership and dependencies | Risk / verification inputs |
|---|---|---|---|
| Survey data repair | Implementer / implementation after design settlement | P1; backend survey/DB boundary; lead approves shared helper contract | High auth/data-integrity consequence; actual SQL + HTTP + pool isolation required |
| App persistence repair | Implementer / implementation | P2; normalized surveys/Firebase/game persistence; exclude P3 image files | High authorization consequence; real rules/user isolation and transaction validation |
| Media transport repair | Implementer / implementation | P3 Python + TS transport contract; one owner or disjoint language helpers | High network-boundary consequence; controlled transport evidence, no private live probes |
| Social lifecycle repair | Implementer / implementation | P4; sole ownership of large lifecycle module while active; plan 010 coordination | High distributed-state consequence; concurrent claim/cancel/retry evidence |
| Dependency assessment | Investigator / investigation, then bounded implementation assignment | P5; advisory/runtime map first; one lockfile mutation owner per repository | Package match vs reachable behavior, worker lane/image coverage |
| Structural/organization work | Implementer / implementation after prerequisites | P8/P9; scoped domain extraction or documentation packet | Preserve route/import/history compatibility; focused behavior/reference checks |
| Independent acceptance review | Reviewer / review | Read-only review of completed packets; no ownership edits | Requirement fit, regressions, security/concurrency boundaries and missing proof |

Lead retains consequential design decisions, cross-repository contracts, sequencing, live target selection and final acceptance. P6/P7 may be kept with the lead or prepared as separate bounded assignments when parallel benefit exceeds coordination cost. Runtime-specific routing evidence and exact prompts are prepared at dispatch, not fabricated in this plan.

## Completion checklist

- [x] P0 row 1 source candidate/evidence/ownership reconciliation complete on 2026-10-16; current provider and release acceptance remain with P10.
- [ ] BE-01–03 and APP-01/02/04 accepted at their actual persistence boundaries.
- [ ] BE-04 / APP-03 transport safety accepted.
- [ ] BE-05 claim fencing accepted, plan 010 counter requirements reconciled.
- [ ] DEP-01 applicable runtime/tooling risks resolved or explicitly dispositioned.
- [ ] BE-06/07 messaging atomicity and retry semantics accepted.
- [ ] AUTH-R1/R2 and DATA/LEGAL risks have evidence-backed dispositions; optional APP-05 decision recorded.
- [ ] WS-01–05 have current gate/release/behavior evidence.
- [ ] ORG-01–04 completed through their owners, with protected data/history intact.
- [ ] Every shipped packet has required source, app/build, SQL/rules, API, Modal and browser evidence, or remains explicitly incomplete.

The initial planning deliverable is complete when this document is saved, linked and checked. The checklist above remains open until later authorized implementation satisfies each condition.
