TikTok browser_intercept Repair Session Mandate
Scheduled: 2026-04-10
Status: Not yet started
Pre-read (required): .planning/research/TIKTOK_PATH_REPRIORITIZATION_CLOSEOUT_2026-04-10.md → "Successor Session Pre-Read — Constraint Wall" section

Primary Mandate (Framing Option 1: Learn from yt-dlp)
Diff yt-dlp's TikTok extractor request shape against the current browser_intercept implementation at TRR-Backend/trr_backend/socials/tiktok/scraper.py:1443, and copy what's copyable until either:

(a) browser_intercept returns ≥1 post on @bravotv, in which case write a follow-up validation plan and hand off for verification, OR
(b) progress is blocked by a request-signing, proxy, or other closed-off constraint, in which case STOP, document the specific wall, and write an escalation recommending which of Framing Options 2/3/4 to pursue with evidence.
yt-dlp source of truth: the TikTok extractor in the vendored or installed yt-dlp package. Public, readable, documents exactly which headers, query parameters, cookies, and session-setup steps it performs. This is the diff source.

Diff target: _scrape_browser_intercept at scraper.py:1443 and any helpers it calls.

Control group: /api/repost/item_list/ on @bravotv is known to return a normal itemList payload under current session conditions. Use it as a reference for "what a working request looks like" from inside browser_intercept.

Failing endpoint: /api/post/item_list/ returns HTTP 200 with content-type: application/json and content-length: 0 on @bravotv under current session conditions. This is the target to fix.

Sanity-Check Addendum — 2026-04-10 — Reframed diff target
A post-scheduling sanity check on the raw capture in TIKTOK_BROWSER_INTERCEPT_DRIFT_DISAMBIGUATION_2026-04-10.md reframes Option 1's diff target. Read the closeout note's Sanity-Check Addendum — 2026-04-10 — bdturing mechanism and partial signing observed section before starting this session.

Reframed diff question: The original mandate framed Option 1 as "what headers does yt-dlp send that browser_intercept does not?" That framing assumed the fix would be header-level. The bdturing finding changes the question to "which endpoint does yt-dlp hit, and does it avoid bdturing gating entirely?"

Evidence that endpoint-avoidance is the most likely fix path: The same drift disambiguation capture observed four XHR paths firing during page load and first scroll:

/api/post/item_list/ — HTTP 200, content-length: 0, bdturing challenge in headers. Broken.
/api/user/playlist/ — observed firing, not characterized in detail but did not produce the same bdturing challenge. Likely working.
/api/story/item_list/ — observed firing, not characterized in detail. Likely working.
/api/repost/item_list/ — HTTP 200 with a normal itemList JSON payload. Confirmed working.
Three of the four TikTok item_list-family endpoints are not bdturing-gated on this session. Only /api/post/item_list/ is. That is strong circumstantial evidence that bdturing gating is endpoint-specific, not session-specific, and that yt-dlp most likely works by hitting a different endpoint rather than by defeating bdturing on the posts endpoint.

Concrete first-hour investigation sequence:

Locate the yt-dlp TikTok extractor source (vendored or installed — follow the dependency pin from _SOCIAL_IMAGE_PIP_PACKAGES in TRR-Backend/trr_backend/modal_jobs.py:152).
Search for api/post/item_list in the extractor. If yt-dlp hits this endpoint, escalate — the simple endpoint-avoidance hypothesis is wrong and the problem is harder than expected.
If yt-dlp does NOT hit /api/post/item_list/, identify which endpoint(s) it does hit to retrieve user posts. Candidates worth looking for in order: /api/user/playlist/, /api/post/item/, web page HTML scraping, or a different item_list variant.
Cross-reference what yt-dlp hits against what the drift disambiguation capture observed firing from the browser session. If there is overlap, browser_intercept can probably be repointed at the same endpoint with minimal changes.
Reframed msToken sub-question: If endpoint-avoidance does not yield a fix, the secondary investigation is why is msToken empty in the current browser_intercept capture? The closeout addendum notes that X-Bogus, X-Gnarly, and verifyFp are all populated naturally by TikTok's JavaScript, but msToken is empty. Investigate session warming, script timing, and cookie state as possible causes. The guardrail against writing custom signing code remains in effect — this sub-question is about why the browser isn't producing msToken naturally, not about generating it in Python.

Exit criteria update: the original success criterion (browser_intercept returns ≥1 post on @bravotv) is unchanged. The original escalation criterion (document the wall, recommend which framing option to pursue) is also unchanged. The reframing above only changes what the first hour investigates, not what counts as success or failure.

Guardrails (do not violate mid-session)
Do not unilaterally reopen request signing (msToken, X-Bogus, _signature, or equivalents). It remains out of scope for this session. If the investigation shows signing is unavoidable, document that finding and escalate — do not implement signing.
Do not unilaterally reopen the Bright Data ProxyError. It remains parked. Same rule — document if proxy routing is unavoidable, do not resolve the ProxyError inside this session.
Do not modify yt-dlp behavior, its vendored copy, or its dependency pin. yt-dlp is the sole proven path and must not be disturbed by repair work on a different path.
Do not modify _scrape_shared_tiktok_posts_partitioned or its callers. The posts-path routing in social_season_analytics.py was settled in the original pivot and is not in scope here.
Time-box the investigation at 4 hours of active work. If 4 hours elapse without a fix or a confident wall-diagnosis, stop and escalate.
Parallel Background Task (Framing Option 4, scoped narrowly)
While the primary mandate runs, wire the existing yt-dlp single-path alerts (currently confirmed only on admin endpoint surfaces per tiktok-ytdlp-degradation.md) to a push-escalation destination — Slack, PagerDuty, or equivalent, whichever is already wired to the ingest health pipeline.

Scope guardrails for the parallel task:

Push-escalation gap only. Do not broaden into retry logic, cache-fallback work, or instrumentation rewrites.
If the push destination isn't trivially available in existing infrastructure, document the gap and stop — do not build new infrastructure for this.
This task is independent of the primary mandate's success or failure and should complete regardless.
Exit Criteria
Primary mandate success:

browser_intercept returns ≥1 post on @bravotv under the same session conditions as the 2026-04-10 triage run.
A follow-up validation plan is written naming what to verify before shipping the fix.
Primary mandate blocked (escalation):

A written finding names the specific closed-off constraint that blocks progress.
A recommendation is made for which framing option (2, 3, or 4) to pursue next, with evidence.
Parallel task success:

yt-dlp degradation alerts have a confirmed push destination OR the push-destination gap is documented as infrastructure-level with a specific ask for the next planning pass.
Out of Scope
Request signing in any form.
Bright Data ProxyError resolution.
Task 6 (comments via browser_intercept) — still gated on repair session outcome.
HTML parser retry — NO-GO remains in effect.
TLS fingerprinting work (JA3/JA4 matching).
Any code changes outside _scrape_browser_intercept and its direct helpers, plus the parallel-task push-destination wiring.
Validation After Session
python3 /Users/thomashulihan/Projects/TRR/scripts/sync-handoffs.py --check — green.
bash /Users/thomashulihan/Projects/TRR/scripts/handoff-lifecycle.sh post-phase — green.
If code changes land: pytest /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/socials/tiktok/test_scraper.py -q — all pass.
After the mandate file is written, please also:

Add a one-line entry to TIKTOK_SCRAPE_RESILIENCE_BOARD.md under the closed-workstream section linking to the new mandate file, noting "successor session scheduled with Option 1 framing."
Add a one-line note to the closeout file TIKTOK_PATH_REPRIORITIZATION_CLOSEOUT_2026-04-10.md noting that a mandate has been scheduled and linking to the mandate file.
Do NOT run the mandate. This is a scheduling artifact only.
Run the two validation commands to confirm nothing broke.
★ Insight ─────────────────────────────────────

Why "pick now" beats "leave for the session's opening" for this specific decision: decisions made at session-opening tend to be rushed because the session clock is already running. Decisions made at scheduling-time can be leisurely and evidence-based. The exact question we just worked through — weighing four framings against each other — is much easier to answer calmly from closeout than from the start of a new session under execution pressure. Scheduling with a pre-made mandate converts a planning decision into a starting point, which is almost always the right trade.
Why the mandate names both a success criterion and an escalation criterion: mandates that only define success silently permit scope creep when things get hard — the session starts negotiating with itself about whether to relax a constraint to achieve the goal. Naming the escalation criterion ("document the wall and recommend which option to pursue next") gives the session a dignified way to fail, which prevents the creep. Mandates without escalation paths are how teams end up reversing firm prior decisions without realizing it.
Why the parallel Option 4 task is scoped so aggressively small: the usual failure mode of "do two things at once" is that the smaller task absorbs the larger task's scope when the larger task hits friction ("since we're already in here, we might as well also..."). Scoping Option 4 to exactly one deliverable — push-destination wiring — with explicit "do not broaden into X, Y, Z" language is what keeps it from becoming a general yt-dlp hardening project. The goal is for Option 4 to complete even if Option 1 fails, and the only way to guarantee that is to make Option 4 trivially small. [$writing-plans](/Users/thomashulihan/.codex/superpowers/skills/writing-plans/SKILL.md)
