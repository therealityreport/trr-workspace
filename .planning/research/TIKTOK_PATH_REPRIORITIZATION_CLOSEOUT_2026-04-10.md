# TikTok Path Reprioritization Closeout

Date: 2026-04-10

## 2026-04-11 correction

The pivot tasks marked `done` below were completed in working-tree changes that were never committed to `main` on 2026-04-10. Actual backend branch commit SHAs are:

- `571e4bc` — `feat(tiktok): make ytdlp the primary scraper path`
- `7d2bb90` — `fix(tiktok): force shared-account fallback onto ytdlp`
- `28bcca1` — `feat(tiktok): surface scraper diagnostics in cli and api`

The canonical on-main default `scrape_mode="api"` persisted through 2026-04-10.

## Scope Ledger

The source plan at `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_PATH_REPRIORITIZATION_PLAN.md` enumerated 6 implementation-focus items. This closeout also carries forward the 2 follow-up work items that became part of the same workstream, yielding the 8-item final ledger below.

1. `scrape_mode` default to `ytdlp`, keep `auto` as a deprecated alias, and make direct HTTP transport lazy.
   Status: done.
   Evidence: `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/ai/local-status/tiktok-path-reprioritization-2026-04-10.md`

2. Normalize first-class `yt-dlp` diagnostics (`retrieval_mode=ytdlp`, `http_client=yt_dlp`, `fallback_chain=["yt_dlp"]`, cookie usage, `profile_enrichment_status=skipped`).
   Status: done.
   Evidence: `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/ai/local-status/tiktok-path-reprioritization-2026-04-10.md`

3. Force explicit `scrape_mode="ytdlp"` at production callers and benchmarks.
   Status: done.
   Evidence: `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/ai/local-status/tiktok-path-reprioritization-2026-04-10.md`

4. Route shared-account TikTok posts away from the partitioned direct API path.
   Status: done.
   Evidence: `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/ai/local-status/tiktok-path-reprioritization-2026-04-10.md`

5. Park direct TikTok comments behind `SOCIAL_TIKTOK_ENABLE_DIRECT_COMMENT_API_EXPERIMENT=1`.
   Status: done for the parking contract; implementation remains parked.
   Evidence: `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/ai/local-status/tiktok-path-reprioritization-2026-04-10.md`

6. Preserve direct transport experiments and document Bright Data proxy debt as off the critical path.
   Status: done.
   Evidence: `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/ai/local-status/tiktok-path-reprioritization-2026-04-10.md`, `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/ai/local-status/tiktok-http-triage-followups.md`

7. Run the bounded HTML parser fallback spike and update fallback planning.
   Status: done for the spike, with a `NO-GO`; comments parking follow-up remains parked by design.
   Evidence: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_HTML_PARSER_DRIFT_SPIKE.md`, `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_SCRAPE_RESILIENCE_BOARD.md`

8. Reassess `browser_intercept` as the only remaining in-repo fallback and decide whether it is repairable.
   Status: blocked on pagination drift repair successor work.
   Evidence: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_BROWSER_INTERCEPT_SANITY_CHECK_2026-04-10.md`, `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_BROWSER_INTERCEPT_RECOVERY_TRIAGE_2026-04-10.md`, `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_BROWSER_INTERCEPT_DRIFT_DISAMBIGUATION_2026-04-10.md`

## Final Fallback Topology

- `yt-dlp`: sole working TikTok posts path.
- `browser_intercept`: blocked on pagination drift repair.
- HTML parser: `NO-GO`.
- `curl_cffi + proxy`: parked on Bright Data authenticated CONNECT `ProxyError`.
- direct `/api/*`: broken for posts on current evidence.

## Artifact Index

- Root plan: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_PATH_REPRIORITIZATION_PLAN.md`
- HTML parser spike: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_HTML_PARSER_DRIFT_SPIKE.md`
- Resilience board: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_SCRAPE_RESILIENCE_BOARD.md`
- Browser-intercept sanity check: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_BROWSER_INTERCEPT_SANITY_CHECK_2026-04-10.md`
- Browser-intercept recovery triage: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_BROWSER_INTERCEPT_RECOVERY_TRIAGE_2026-04-10.md`
- Drift disambiguation: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_BROWSER_INTERCEPT_DRIFT_DISAMBIGUATION_2026-04-10.md`
- Task 6 re-evaluation: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_TASK6_COMMENTS_REEVALUATION_2026-04-10.md`
- yt-dlp degradation runbook: `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/runbooks/tiktok-ytdlp-degradation.md`
- Workspace test hygiene flag: `/Users/thomashulihan/Projects/TRR/docs/ai/local-status/workspace-test-hygiene-flags-2026-04-10.md`
- TikTok pivot implementation status: `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/ai/local-status/tiktok-path-reprioritization-2026-04-10.md`
- TikTok HTTP triage follow-ups: `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/ai/local-status/tiktok-http-triage-followups.md`

No separate TikTok health-canary design artifact was written in this chain.

## Successor Session Pre-Read — Constraint Wall

The empty-body pattern is stealth-null anti-bot behavior, not a crash or block. A response of HTTP 200 with `content-type: application/json` and `content-length: 0` is a deliberate anti-bot pattern: the server returns a shaped success response containing no data, specifically to avoid signaling detection to the client. Crashes would return 5xx, blocks would return 403 or 429, redirects would return 3xx, and malformed responses would have the wrong `content-type`. Stealth-null is none of those; it is a content-aware detection response.

The asymmetry confirms this is targeted, not global. `/api/repost/item_list/` still returns a normal `itemList` payload from the same session, same auth, same region, and same client. Only `/api/post/item_list/` is getting stealth-nulled. That rules out broad session, auth, region, or rate-limit hypotheses and points at content-aware detection on the posts endpoint specifically.

1. Request signing (`msToken`, `X-Bogus`, `_signature`, or current equivalents) — currently out of scope per the original plan.
2. Residential proxy routing to defeat IP-based fingerprinting — currently parked on unresolved Bright Data `ProxyError`.
3. TLS fingerprint matching (`JA3` or `JA4` to mimic a real browser) — not in scope and would require new infrastructure work.
4. Session warming (establishing realistic cookie and fingerprint state before the request fires) — in scope, with uncertain effectiveness.
5. Header shape alignment (matching headers byte-for-byte, including ordering, to a real Chrome session) — in scope, with uncertain effectiveness.

Approaches 1 and 2 are likely the most effective, but both are currently closed off. The successor session should expect to hit this constraint wall within its first hour and should not start implementation without first deciding which constraint, if any, to relax.

1. "Learn from yt-dlp" angle — diff yt-dlp's TikTok extractor request shape against `browser_intercept`, copy what is copyable, and stop when a request-signing dependency appears.
2. Reopen request signing as in scope for this specific endpoint via a time-boxed spike.
3. Reopen the Bright Data proxy failure as the blocker to resolve.
4. Accept `browser_intercept` as currently unrepairable and invest the repair-session budget in additional `yt-dlp` hardening instead.

Read this section before touching any code, then record a framing decision before starting repair work.

Sanity-Check Addendum — 2026-04-10 — bdturing mechanism and partial signing observed
A post-closeout sanity check on the raw response headers captured in TIKTOK_BROWSER_INTERCEPT_DRIFT_DISAMBIGUATION_2026-04-10.md — Response Body Capture — /api/post/item_list/ — surfaced two facts that refine the constraint wall framing above.

1. The empty body is the symptom; bdturing verification is the mechanism. The captured response includes x-vc-bdturing-parameters and bdturing-verify headers containing a {"type":"verify","subtype":"3d",...} challenge payload, plus tt-ticket-guard-result: 0. bdturing is TikTok's (ByteDance) client-side anti-bot verification system, and the 3d subtype corresponds to a turnstile-style verification widget that a real user session would see and complete in the browser UI. The empty body is not a silent stealth-null — it is TikTok withholding the response until the challenge is completed. The challenge instructions are in the headers; the body is empty because there is no data to serve until the client proves it is not automated. This is explicit challenge-response behavior with the challenge hidden in headers, not silent detection.

2. Request signing is already happening implicitly via the browser context — msToken is the specific gap. The request URL in the same capture shows X-Bogus=DFSzsIVOnSbANCc4Co9c8TVxWZ9A, X-Gnarly=M8uGaRdCWLz9/JGi..., and verifyFp=verify_mmgesh9c_1xQXZi3b_... all populated, but msToken= empty. Those three signing parameters are produced naturally by TikTok's own JavaScript running inside the Playwright browser context — our code is not generating them. This means the browser_intercept session is already producing nearly valid signed requests; msToken is the only missing piece. That reframes the "request signing is out of scope" guardrail:

Still out of scope: writing custom Python code to generate msToken, X-Bogus, _signature, or equivalent values from scratch. This is what the original plan forbade and it remains forbidden.
In scope: investigating why the browser's natural msToken generation is producing an empty value on this specific endpoint. The most likely causes are session warming (the browser hasn't established enough state before the request fires), script timing (the msToken-producing script hasn't executed yet when the request is made), or cookie state (the msToken generator depends on cookies that aren't present in the session).
Implication for the successor session's first action: these two findings should be read together. The bdturing verification is probably triggered by the empty msToken, because msToken is one of the signals TikTok uses to decide whether a request is from a real browser session. If msToken were populated correctly, the bdturing challenge might not fire at all, and the response body would contain real data. Conversely, if the bdturing challenge is unavoidable regardless of msToken state, then no amount of signing work will fix this endpoint and the session should pivot to Option 1's endpoint-avoidance variant (see mandate addendum).

## Next Session Start Point

Scheduled successor mandate (Option 1 framing): `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_BROWSER_INTERCEPT_REPAIR_SESSION_MANDATE_2026-04-10.md`

Read `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_BROWSER_INTERCEPT_DRIFT_DISAMBIGUATION_2026-04-10.md` -> `Response Body Capture — /api/post/item_list/` -> pick repair approach from the four-category classification.
