# TikTok Scrape Resilience — Planning Board & Audit

**Created:** 2026-04-09
**Status:** Closed — successor work identified on 2026-04-10
**Tracks:** TikTok emergency triage, cross-platform resilience investment

---

## Context

TikTok post scraping is returning fake-200 / empty-body / challenge responses. The primary TikTok scrape path uses public web API endpoints (`/api/user/detail/`, `/api/post/item_list/`) via plain `requests`/`urllib3` with optional cookies. No TLS fingerprinting, no proxy support on the direct HTTP path.

### Current Architecture (verified against codebase 2026-04-09)

| Component | State | Key files |
|---|---|---|
| HTTP client | `requests.Session` + `urllib3` retry adapter. Hardcoded Chrome 144 UA. **No TLS fingerprint management.** | `scraper.py` |
| Scrape modes | `api` (default), `browser_intercept` (Playwright), `auto` (cascade) | `scraper.py` |
| Cookie/auth | Env-loaded cookies (`sessionid`, `sid_tt`). Auto-refresh via Playwright login flow gated by `SOCIAL_TIKTOK_COOKIE_AUTO_REFRESH`. | `cookie_refresh.py`, `browser_cookie_refresh.py` |
| Session persistence | `AccountBrowserSessionManager` stores `storage_state` + cookies per account. **Not wired into browser_intercept mode.** | `account_browser_sessions.py` |
| Crawlee runtime | Built: request queue, session pool, proxy config, retry, error taxonomy. **Defaults to disabled** (`SOCIAL_CRAWLEE_ENABLED=false`). | `crawlee_runtime/` |
| Proxy | Crawlee layer reads `SOCIAL_CRAWLEE_PROXY_URLS_TIKTOK`. Direct HTTP path has **zero proxy support**. Env var not in `.env.example`. | `crawlee_runtime/runtime.py` |
| Browser evasion | `--disable-blink-features=AutomationControlled` only. No stealth plugins. | `scraper.py`, `browser_cookie_refresh.py` |
| Media resolution | yt-dlp → watch-page JSON → tikwm → OG tags → oEmbed cascade | `media_resolver.py` |
| Orchestration | Supabase-backed job queue, Modal remote dispatch, worker pools (8 posts / 8 comments), in-flight cap 24 | `social_season_analytics.py`, `control_plane/` |

---

## Planning Board

### Layer Model

| Layer | Purpose | Active candidates | Priority |
|---|---|---|---|
| **L1 HTTP hardening** | TLS fingerprint + HTTP client swap | `curl_cffi` | **Highest — TikTok triage** |
| **L2 Browser automation** | Full browser when HTTP insufficient | `Playwright` (baseline), `playwright-stealth` | High |
| **L3 Browser infrastructure** | Remote browser hosting + reconnectable state | `Browserless`, `Browserbase`, `Steel Browser` | High, second-wave |
| **L4a State persistence** | Save/restore auth/session state | `Playwright persistent context`, `storageState` | High for long-term |
| **L4b Auth repair / operator tooling** | Human/semi-auto re-login when sessions die | `chrome-devtools-mcp`, `Playwright MCP`, `browser-use` | High for long-term |
| **L4c Session refresh automation** | Proactive cookie/profile refresh before expiry | Scheduled Playwright refresh job, `browser-use` re-auth | **Highest for long-term** |
| **L5 Orchestration** | Crawl queueing, retries, session pools | `Crawlee Python` (already built, needs enablement) | Medium-high |
| **L6 Proxy/network reputation** | IP reputation and stickiness | `Bright Data`, `Decodo`, `Oxylabs`, `IPRoyal`, `NetNut` | **Highest — TikTok triage** |
| **L7 Evasion / challenge handling** | Patch detection surfaces, solve challenges | `rebrowser-patches`, `Camoufox`, `nodriver` | Medium |

### Monitoring (added by audit)

| Layer | Purpose | Action |
|---|---|---|
| **M1 Observability** | Know which layer is failing | Add structured logging: `{layer, platform, error_code, response_status, has_cookies, proxy_used}` |
| **M2 yt-dlp audit** | yt-dlp has its own TLS fingerprint | Quick check: is yt-dlp also getting blocked? |

---

## Audit Findings (2026-04-09)

### L1 — curl_cffi

- **Verdict:** Correct priority, highest-leverage single change.
- Current `requests`/`urllib3` produces a Python-default JA3 fingerprint trivially distinguishable from Chrome.
- `curl_cffi` replaces the HTTP layer with libcurl's BoringSSL fork → Chrome-accurate JA3/JA4.
- **Integration note:** `curl_cffi` lacks `requests.Session`-style retry adapters. Reimplement retry logic (3 retries, 1.5x backoff, status codes 429/500/502/503/504) manually or via wrapper.
- **Gap:** Also test with comment fetching (`/api/comment/list/`, `aid=1988`) — separate API surface, may have different fingerprint gates.

### L2 — Playwright baseline

- **Already more built than board implies.** `browser_intercept` mode exists with response interception, auto-scroll, cookie injection.
- **Missing:** No `playwright-stealth`. No persistent context in browser_intercept (fresh context per run). Browser mode only intercepts post listing, not comments or user detail.
- `playwright-stealth` should be tested as part of L2 (it's a Playwright plugin), not only in L7.

### L3 — Remote browser infra

- **Eval criteria need sharpening beyond "which preserves state best":**
  - Modal compatibility (scrape jobs run on Modal containers)
  - Proxy passthrough (BYO residential proxy vs. forced IP pool)
  - Cost at TRR scale (100-500 sessions/day)

### L4a — State persistence

- **Further along than board implies.** `AccountBrowserSessionManager` already stores `storage_state` per account with per-account locking.
- **Concrete gap:** Browser_intercept mode doesn't use `AccountBrowserSessionManager`. Connecting these is a bounded task.

### L4b — Auth repair

- **Mechanism exists** (Playwright login flow, control-plane entrypoint).
- **Reliability is the gap:** Hardcoded selectors break on DOM changes. No CAPTCHA handling. Fragile validation.
- Board candidates (`chrome-devtools-mcp`, `Playwright MCP`, `browser-use`) are about making auth repair human-supervised and recoverable when automation fails.

### L4c — Session refresh automation

- **Correctly identified as biggest unsolved ops gap.**
- Current auto-refresh is reactive (triggers on stale detection), not proactive (scheduled before expiry).
- TTL check is validation-staleness, not cookie-expiry.

### L5 — Crawlee orchestration

- **Already built.** Full runtime in `crawlee_runtime/`. TikTok adapter exists.
- `SOCIAL_CRAWLEE_ENABLED` defaults to `false`. Frame as "enable and harden" not "evaluate."

### L6 — Proxy/network reputation

- **Zero infrastructure exists** on the direct HTTP path. Env var not in `.env.example`.
- Crawlee layer has proxy wiring but only applies when Crawlee is enabled.
- **Key recommendation:** Wire proxies into the `curl_cffi` swap (L1+L6 together). Don't retrofit onto `requests` then swap later.

### L7 — Evasion / challenge handling

- `FlareSolverr` / `cloudscraper` are Cloudflare-specific. TikTok doesn't use Cloudflare. Only relevant for other platforms.
- `playwright-stealth` spans L2/L7.

---

## Current Fallback Topology — 2026-04-11

1. `yt-dlp`
   - Status: sole proven TikTok posts path.
   - Current state: local 2026-04-11 `@bravowwhl` dry-run reached `1800` posts in `104.7s`; the live Modal run `b38c33b5-fffe-43a6-b8ab-5926770bcd43` advanced to `3277 / 3277`.
   - Deployment note: production run progress observed mixed runtime labels (`modal` and `modal:main · im-sMysH7ppTegIK6j75iXci9`) inside the same run, which is the concrete source of the `Runtime Version Drift` warning.

2. `browser_intercept`
   - Status: only remaining in-repo backup path.
   - Current state: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_BROWSER_INTERCEPT_DRIFT_DISAMBIGUATION_2026-04-10.md` narrows the 2026-04-10 `@bravotv` failure to `pagination_drift`, with `/api/post/item_list/` returning `200` plus `content-length: 0`; the safety net remains blocked pending pagination-drift repair.

3. direct `/api/*`
   - Status: unavailable for production fallback.
   - Blocker: `origin/main` still kept `scrape_mode="api"` through 2026-04-10; explicit `api` mode remains broken and the shared-account fallback on main was still routed through `auto` instead of an explicit `ytdlp` primary path.

4. `curl_cffi + proxy`
   - Status: unavailable / parked.
   - Blocker: Bright Data authenticated CONNECT `ProxyError`; do not reopen here without new evidence.

5. HTML parser
   - Status: unavailable / `NO-GO`.
   - Blocker: `secUid` remains present but `itemList` is empty on both anonymous and authenticated captures, so the parser sees no posts.

The effective fallback matrix has collapsed from five candidate paths to two meaningful paths (`yt-dlp` and `browser_intercept`), and only `yt-dlp` is currently proven live. Production cutover still requires a fresh Modal image build from merged `main`; the current fleet is mixed-runtime.

## Execution Order

### Track 1: TikTok Emergency Triage

| Step | What | Question answered |
|---|---|---|
| 1a | `curl_cffi` swap on TikTok HTTP calls (no proxy) | Is TLS fingerprinting part of the fake-200 problem? |
| 1b | `curl_cffi` + residential proxy (Bright Data or Decodo) | Is this mostly IP reputation? |
| 1c | Instrument with structured logging (M1) | Which layer fails, how often? |

**Implementation note:** Steps 1a and 1b are a single client swap. Test without proxy first to isolate TLS fingerprint impact, then add proxy to isolate IP reputation. Build as one client.

### Track 2: Platform Resilience Investment

| Step | What | Depends on |
|---|---|---|
| 2a | Wire `AccountBrowserSessionManager` into `browser_intercept` | Nothing |
| 2b | Enable Crawlee runtime for TikTok (`SOCIAL_CRAWLEE_ENABLED=true`) | Nothing |
| 2c | Add `playwright-stealth` to browser paths | 2a |
| 2d | Add proactive session refresh cron job | 2a |
| 2e | Evaluate `Browserless` vs `Browserbase` vs `Steel` | 2a, 2c |
| 2f | `Camoufox` / `nodriver` escalation | Only if 2c insufficient |

---

## Deferred

### Task 6 — TikTok comments via _scrape_browser_intercept

- Status: Parked pending a `browser_intercept` recovery-triage repair plan or a formal abandonment decision.
- Unpark trigger: Revisit immediately after `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_BROWSER_INTERCEPT_RECOVERY_TRIAGE_2026-04-10.md` closes with either a repair plan or a formal abandonment decision.
- Updated parking notes:
  - Task 5's trigger has fired, so the next planning cycle needs an explicit re-evaluation rather than a reflexive re-park.
  - `browser_intercept` is now load-bearing for both posts-backup risk and the eventual comments path.
  - Task 6 remains parked for scoping and risk-control reasons, not because fallback capacity is abundant.
  - The next planning pass should compare comments urgency against single-safety-net fragility before implementation.
  - Updated planning note: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_TASK6_COMMENTS_REEVALUATION_2026-04-10.md` is the source of truth for whether comments work stays parked after the browser-intercept recovery triage.
- Target entrypoint: `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/tiktok/scraper.py:1616`
- Open questions:
  - Can comments reuse the existing posts storage-state partition, or does `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/account_browser_sessions.py:188` need a comments-only partition?
  - Does comments-via-browser-intercept need a separate heavier browser image, or can `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/modal_jobs.py:174` keep sharing the current browser-enabled social image?
  - Should `SOCIAL_TIKTOK_ENABLE_DIRECT_COMMENT_API_EXPERIMENT=1` act as the cutover gate, or does comments-via-browser-intercept need its own env flag?
- Non-goals:
  - Do not revisit request signing (`msToken`, `X-Bogus`, `_signature`).

## Active Shortlist

- `curl_cffi`
- `Bright Data`
- `Decodo`
- `Playwright` (existing)
- `Playwright persistent context`
- `playwright-stealth`
- `Browserless`
- `Browserbase`
- `Steel Browser`
- `Crawlee Python` (existing, needs enablement)
- `chrome-devtools-mcp`
- `Playwright MCP`
- `browser-use`
- `rebrowser-patches`
- `Camoufox`
- `nodriver`

## Dropped From Active Board

| Candidate | Reason |
|---|---|
| Apify TikTok actors | Paid API path |
| TikTok Research API | Paid API path |
| EnsembleData | Paid API path |
| TikTok-Api | Unmaintained |
| Crawl4AI | Crawlee already integrated |
| Selenium | Playwright is baseline |
| Puppeteer | Playwright is baseline |
| FlareSolverr | Cloudflare-specific, TikTok doesn't use CF |
| cloudscraper | Cloudflare-specific |
| Botasaurus | Crawlee covers this space |
| sweet-cookie | `AccountBrowserSessionManager` already exists |
| requests-ip-rotator / swiftshadow | AWS/free proxies insufficient for TikTok |

## Workstream Closeout — 2026-04-10

- The TikTok Path Reprioritization workstream is closed.
- Successor work: browser-intercept pagination drift repair.
- Forwarding address: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_PATH_REPRIORITIZATION_CLOSEOUT_2026-04-10.md`
- Successor session scheduled with Option 1 framing: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_BROWSER_INTERCEPT_REPAIR_SESSION_MANDATE_2026-04-10.md`
