# TRR Browser Debug Profile Selection

This runbook is for browser tasks that need the user's existing Chrome state, such as logged-in TRR admin, Decodo, payment, or profile-specific pages.

## Practical Rule

- Use the `TRR` Chrome profile for normal TRR/admin work.
- Use the real Codex Chrome profile only when the user asks for the Codex profile or `codex@thereality.report`.
- Do not treat the managed `openai-agent` automation clone as the Codex profile.
- Do not rely on the generic Chrome `extension` alias when a specific saved profile matters.

## Agent Selection Flow

1. Connect to the Chrome plugin.
2. Call `agent.browsers.list()`.
3. Select the Chrome extension instance by `metadata.profileName`:
   - `TRR` for admin/TRR/default workspace pages.
   - `Codex` for explicit Codex-profile work.
4. If `metadata.profileIsLastUsed` is not `"true"`, warn before continuing:

   ```text
   Chrome attached to <profile>, but it is not the last-used Chrome profile. I will continue with <profile> because it matches your request.
   ```

5. Use `browser.user.openTabs()` on the selected instance and match tabs by safe preview fields: title, origin/path, tab group, and recency.
6. If no tab is found, retry once on the explicit profile instance before falling back to screenshots or asking for the missing page.

## Example Browser-Client Pattern

```js
const browsers = await agent.browsers.list();
const requestedProfile = "TRR";
const chromeInfo = browsers.find((candidate) =>
  candidate.type === "extension" &&
  candidate.metadata?.profileName === requestedProfile
);

if (!chromeInfo) throw new Error(`Chrome profile not available: ${requestedProfile}`);
if (chromeInfo.metadata?.profileIsLastUsed !== "true") {
  console.warn(`Chrome attached to ${requestedProfile}, but it is not the last-used Chrome profile.`);
}

const chrome = await agent.browsers.get(chromeInfo.id);
const tabs = await chrome.user.openTabs();
```

## Decodo Case Study

The generic `extension` alias previously attached to another Chrome profile and returned zero user tabs. Selecting the explicit `TRR` extension instance found the live Decodo tabs, including `https://dashboard.decodo.com/welcome`.

## Chrome DevTools Boundary

The local `@ChromeDevTools` plugin is useful for dry-run evidence planning and fixture-backed evidence. It does not currently provide live Chrome tab attachment in this local first-slice mode. For live profile tabs, use `@Chrome` with the explicit profile selection flow above.

## E8 canary evaluator boundary

The E8 canary wrapper is request-capable, so it must never run through `tab.playwright.evaluate`. That evaluator is a read-only isolated world; it is deliberately not the page's network-capable JavaScript world, and `fetch` may be unavailable there.

The approved route is the selected tab's advertised CDP capability, using `Runtime.evaluate` with `awaitPromise: true` and `returnByValue: true`, with no execution-context ID. Every CDP send must include the third options argument `{ timeoutMs: 5000 }`; the connector's backend timeout starts only after the exact-origin permission gate, so omitting the client timeout can leave a dismissed or unanswered permission request waiting without a bound. This reaches the page main world. The repo-local adapter constructs only two bounded expressions:

1. A capability preflight that reads the origin and the `typeof` values of `globalThis.fetch` and `window.fetch`. It must not call `fetch`.
2. An execution expression that binds `globalThis.fetch.bind(globalThis)` inside that page main world and calls the byte-identical canary wrapper exactly once.

Before any tab creation or evaluation, require exactly one extension backend whose `metadata.profileName === "TRR"`. Do not fall back to another profile when there are zero or multiple matches.

Use one stable loopback origin for installed-runtime proof. Deliberately resolve the connector's supported raw-CDP permission prompt for that exact origin before interpreting the preflight result. A dismissed, unanswered, automatic, or timed-out permission result is not approval and must stop the run; do not retry on another origin or profile.

Hard stop rules:

- Do not send a canary request if the exact `TRR` backend is ambiguous or absent, the tab has no advertised CDP capability, preflight returns exception details, the page origin differs from the expected origin, or either fetch type is not `"function"`.
- Stop on any permission dismissal, permission timeout, client timeout, or malformed CDP result. Do not issue an unbounded `Runtime.evaluate` call.
- Do not use `playwright.evaluate` as a fallback and do not patch installed application or cache bytes.
- Keep the preflight receipt at zero network, sentinel, and VC requests. A sentinel failure stops before every VC request; the first VC failure stops the remaining sequence.
- Use only the narrow deterministic local check for source/contract changes: `make test-e8-browser-adapter`. Fresh-process loopback proof is a separate installed-runtime check; a production canary requires a separately accepted plan and fresh authorization.

## Viewport/Window Resize Guardrail

Window-bounds resize actions (`resize_page` / `resize_window` / `preview_resize`) must target the headful keeper on port `9222`, never the headless keeper on `9422`. The headless keeper has no real OS window, so a window-bounds reset never completes and hits the fixed per-call timeout. Only issue a resize when the active page is idle.

A timed-out resize-reset is a stale-transport signal. Run `make codex-browser-transport-reset` once and do not retry; restart the session if the next call still uses the stale transport. See `docs/workspace/chrome-devtools.md` for the full stale-transport recovery flow.
