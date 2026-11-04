# X anonymous research search

The `X research search` panel on `/admin/social` runs one explicit query through
the existing protected backend search route. It does not load X credentials,
write results, download media, create schedules, or change the default collector.
The panel requires the existing TRR operator session. Both proxy and backend
retain their admin authorization checks.

## Request

The app uses `POST /api/admin/trr-api/social/twitter/search`. This uncached proxy
forwards the verified admin context to
`POST /api/v1/admin/socials/twitter/search`, with no retry.

```json
{
  "mode": "anonymous_research",
  "provider": "lurkbird",
  "query": "Artemis",
  "sort": "latest",
  "max_pages": 1,
  "max_items": 20
}
```

The provider and mode must be explicit. Sort accepts `latest` or `top`.
The default limits are one page and 20 posts. The operator can explicitly select
up to two pages and 40 posts. The provider prohibits automated bulk collection;
this panel has no automatic initial request, polling, retry, or continuation.

Anonymous mode rejects persistence, media uploads, and explicitly supplied date,
reply/link, delay, association, or persistence-label options. Omitted legacy
model defaults do not count as explicit filters. The dedicated panel only shows
supported inputs. Omitted mode retains standard search and still requires both
`date_start` and `date_end`. Standard authentication, filtering, persistence,
and optional media behavior remain in the existing collector.

## Response and display

The existing `TwitterSearchResponse` shape remains. Anonymous records populate
ID, author handle, display text, timestamp, and canonical X URL. Missing
engagement, verification, and reply/retweet/quote flags are `null`; regular
collector values and existing defaults remain unchanged. Media arrays are empty
because this mode does not collect media. They do not prove a post lacks media.

`complete` is always `false`. `retrieval_meta` includes:

- `retrieval_mode: anonymous_research` and `provider: lurkbird`.
- `status: partial` when records exist, or `unavailable` when none were obtained.
- The stop reason, pages read, configured limits, and per-page retrieval evidence.
- Unknown global coverage, freshness, and upstream authentication.
- A display-text warning: the mirror can truncate text or omit media links.
- An explicit list of unavailable fields.

The route retains valid records and an error when a later page fails. The UI
shows both. An empty or blocked source is shown as unavailable or unverified;
it never proves zero matching posts. `persist_summary` and `scrape_run_id` stay
`null`. Page exhaustion does not establish full coverage or ranking equivalence.

## Validation boundaries

Backend focused tests exercise the protected API, real adapter parser with
recorded HTML, null fields, caps, partial/error behavior, and thread-pool dispatch.
They forbid credential loading, persistence, and media services. Existing
standard search tests cover default compatibility.

App focused tests exercise panel submission through the real same-origin route
handler with fixture admin and upstream responses. They cover explicit opt-in,
limits, unknown coverage, partial/error/blocked display, admin rejection, no
automatic work, and request cleanup. These fixtures do not prove a deployed
operator session or current provider availability. Build, deployed API, and
live protected UI checks remain distinct release evidence.

`TRR-APP/apps/web/tests/runtime/twitter-research-runtime.mjs` runs the actual
panel in a new test-owned Playwright context at the canonical admin origin.
Its intercepted API bridge calls the protected FastAPI route with a fixture JWT
and the real provider parser over recorded HTML. Three flows cover records,
retained records after a later 429, and an unavailable source. The test closes
only its own context, checks that a separate sentinel context and cookie remain,
then closes its test-owned browser. It imports no browser state and makes no live
provider request. This bridge skips the Next.js proxy; the focused Vitest test
exercises that actual handler separately. It is not deployed Next.js UI proof.

## Release acceptance — 2026-11-04

- Backend commit `8750227d150ed404c9201a69f00e891a0f6d93df` deployed through
  the guarded `admin-56995/main/trr-backend-jobs` procedure, tag
  `twitter-anonymous-8750227d`. Readiness, maintenance configuration and API
  health passed. The remote search returned 10 records with zero calls to the
  authentication loader or persistence functions.
- App commit `f7afe661562f431974027930e768e9c423b1335a` passed the approved
  production build. Production deployment `dpl_7WV4NgFG2sZSKgJu8rDj87KTqabW`
  is READY at https://trr-app.vercel.app. Explicit SENTRY_RELEASE metadata fixed
  the initial source-map upload warning; Node.js, Edge and Client uploads passed.
- The deployed panel returned 20 live posts for a narrow nebula query through
  the actual UI, proxy and backend. A NASA result matched independently checked
  first-party evidence. This check preceded the metadata-only redeployment of
  identical app source. Only task-owned browser tabs were closed.
- Backend affected checks passed (82 tests). App focused checks passed (9 tests),
  as did 79 lightweight tests and five generated checks. Fixture browser tests
  covered partial and unavailable results and sentinel-context preservation.
- last30days `3.34.1+codex.20261104`, commit `98492204`, passed scoped refresh,
  installed-source parity, fresh host discovery, actual HTTPS MCP research and
  two clean-environment CLI queries returning 40 records each. Its mvanhorn
  identity is unchanged.
- Bounded FxTwitter branch expansion returned 67 unique posts in five requests.
  Selected new posts and parent relationships matched first-party responses.
  Thread completeness remains unknown; this does not prove full-thread coverage.

Detailed receipts and sample outputs remain in
`~/.local/share/trr-twitter-validation/20261104/` and
`~/.local/share/last30days-mirror-validation/anonymous-installed/`.
`acceptance.json` records the final deployment and cleanup. Disposable release
exports were moved to actual Trash after acceptance. Source commits, manifests,
logs, samples, previous deployments, the last30days service rollback and plugin
cache versions required by active sessions remain available. Recovery material
can be retired only after its replacement and dependent sessions are verified.
No active chat or existing browser session was restarted.
