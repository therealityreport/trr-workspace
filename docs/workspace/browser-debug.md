# TRR Browser Debug Profile Selection

This runbook is for browser tasks that need the user's existing Chrome state, such as logged-in TRR admin, Decodo, payment, or profile-specific pages.

## Practical Rule

- Use the `TRR` Chrome profile for normal TRR/admin work.
- Use the friendly `codex` Chrome profile only when the user requests it.
- Do not treat the managed `openai-agent` automation clone as the Codex profile.
- Do not rely on the generic Chrome `extension` alias when a specific saved profile matters.

## Agent Selection Flow

1. Follow the active browser tool's supported setup and identity-verification instructions.
2. Select the exact friendly profile: `TRR` for normal workspace work, or `codex` when explicitly requested. Do not assume that capitalization, a generic alias, or the last-used profile identifies the requested account.
3. Require an unambiguous match before account-specific actions. Pause that part of the task on a missing or ambiguous match and continue independent work.
4. Recheck after a profile switch, reconnection, or evidence that the account changed.
5. Inspect tabs on the verified connection using safe fields such as title and origin/path. An absent tab is not permission to switch accounts.

### Browser-client example

Use this example only when the active tool's documentation exposes these APIs; other tools have their own supported setup.

```js
const browsers = await agent.browsers.list();
const requestedProfile = "TRR";
const matches = browsers.filter((candidate) =>
  candidate.type === "extension" &&
  candidate.metadata?.profileName === requestedProfile
);
if (matches.length !== 1) {
  throw new Error(`Chrome profile missing or ambiguous: ${requestedProfile}`);
}
const chrome = await agent.browsers.get(matches[0].id);
const tabs = await chrome.user.openTabs();
```

## Decodo Case Study

The generic `extension` alias previously attached to another Chrome profile and returned zero user tabs. Selecting the explicit `TRR` extension instance found the live Decodo tabs, including `https://dashboard.decodo.com/welcome`.

## Chrome DevTools Boundary

Inspect the active tools before choosing a route; installed plugin names do not prove current live-tab support. Use any suitable supported tool that can verify the intended profile. Keep fixture evidence separate from live browser verification.

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

For the optional managed-keeper workflow, window-bounds resize actions (`resize_page` / `resize_window` / `preview_resize`) must target the headful keeper on port `9222`, never the headless keeper on `9422`. The headless keeper has no real OS window, so a window-bounds reset never completes and hits the fixed per-call timeout. Only issue a resize when the active page is idle.

A timed-out resize-reset may indicate a headless-window mismatch or stale transport. Inspect the target and error before repair; do not retry blindly. See `docs/workspace/chrome-devtools.md` for scoped recovery and restart guidance.
