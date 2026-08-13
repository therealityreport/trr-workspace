"use strict";

const assert = require("node:assert/strict");
const { createHash } = require("node:crypto");
const { readFileSync } = require("node:fs");
const { join } = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const root = join(__dirname, "..", "..");
const adapterPath = join(root, "scripts", "lib", "trr-e8-browser-adapter.cjs");
const wrapperPath = join(root, "scripts", "lib", "trr-e8-canary-wrapper.cjs");
const harnessPath = join(
  root,
  "scripts",
  "tests",
  "fixtures",
  "trr-e8-canary-harness.json",
);
const runbookPath = join(root, "docs", "workspace", "browser-debug.md");
const makefilePath = join(root, "Makefile");
const origin = "https://fixture.trr.localhost";

const adapter = require(adapterPath);
const wrapper = require(wrapperPath);
const harness = JSON.parse(readFileSync(harnessPath, "utf8"));
const requestDefinitions = harness.requestDefinitions;

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function runtimeEvaluate(value) {
  return { result: { type: "object", value: JSON.parse(JSON.stringify(value)) } };
}

function executionInput() {
  const identities = adapter.getFrozenIdentities();
  return {
    expectedOrigin: origin,
    requestDefinitions,
    wrapperSha256: identities.wrapperSha256,
    harnessSha256: identities.harnessSha256,
  };
}

function response({ status = 200, url, redirected = false, contentType = "text/html", body = "ok" } = {}) {
  return {
    status,
    url,
    redirected,
    headers: { get: (name) => (name.toLowerCase() === "content-type" ? contentType : null) },
    text: async () => body,
  };
}

function successfulResponse(definition, url) {
  if (definition === null) {
    return response({ url, contentType: "application/json", body: JSON.stringify({ hasAccess: true }) });
  }
  return response({
    url,
    contentType: `${definition.expected.contentTypePrefix}; charset=utf-8`,
    body: definition.expected.bodyContains ?? "ok",
  });
}

async function evaluateExecution({ pageOrigin = origin, responder } = {}) {
  const expression = adapter.buildExecutionExpression({
    ...executionInput(),
  });
  const calls = [];
  const fetch = async (url, options) => {
    const index = calls.length;
    const definition = index === 0 ? null : requestDefinitions[index - 1];
    calls.push({ url, options, definition });
    return responder ? responder({ url, options, definition, index }) : successfulResponse(definition, url);
  };
  const sandbox = { URL, fetch, location: { origin: pageOrigin, href: `${pageOrigin}/admin` } };
  sandbox.globalThis = sandbox;
  sandbox.window = sandbox;
  const value = await vm.runInNewContext(expression, sandbox, { timeout: 1_000 });
  return { expression, calls, value };
}

function sentinelDefinition() {
  return {
    id: "SENTINEL",
    method: "GET",
    route: "/api/admin/check",
    headers: { accept: "application/json" },
    expected: { status: 200, contentTypePrefix: "application/json" },
  };
}

function selectExactlyOneTrrExtension(backends) {
  const matches = backends.filter(
    (candidate) => candidate?.type === "extension" && candidate.metadata?.profileName === "TRR",
  );
  if (matches.length !== 1) {
    throw new Error(`Expected exactly one TRR Chrome extension backend; found ${matches.length}.`);
  }
  return matches[0];
}

test("request-capable adapter expressions never select playwright.evaluate", () => {
  const adapterSource = readFileSync(adapterPath, "utf8");
  const preflight = adapter.buildCapabilityPreflightExpression({ expectedOrigin: origin });
  const execution = adapter.buildExecutionExpression({
    ...executionInput(),
  });

  assert.doesNotMatch(adapterSource, /playwright\.evaluate/i);
  assert.doesNotMatch(preflight, /playwright\.evaluate/i);
  assert.doesNotMatch(execution, /playwright\.evaluate/i);
});

test("preflight is callable, reports fetch types only, and cannot invoke fetch", () => {
  const expression = adapter.buildCapabilityPreflightExpression({ expectedOrigin: origin });
  let fetchCalls = 0;
  const sandbox = {
    location: { origin },
    fetch: () => {
      fetchCalls += 1;
      throw new Error("preflight must not call fetch");
    },
  };
  sandbox.globalThis = sandbox;
  sandbox.window = sandbox;

  assert.doesNotMatch(expression, /(?:globalThis|window)\.fetch\s*\(/);
  assert.doesNotMatch(expression, /\bfetch\s*\(/i);
  const receipt = vm.runInNewContext(expression, sandbox, { timeout: 1_000 });
  assert.deepEqual(JSON.parse(JSON.stringify(receipt)), {
    schemaVersion: 1,
    origin,
    globalThisFetchType: "function",
    windowFetchType: "function",
    wrapperAvailability: "absent",
  });
  assert.equal(fetchCalls, 0);
  assert.deepEqual(adapter.validateCapabilityPreflightEvaluation(runtimeEvaluate(receipt), origin), JSON.parse(JSON.stringify(receipt)));
});

test("execution binds page-main-world fetch and calls the unchanged wrapper once", async () => {
  const result = await evaluateExecution();

  assert.match(result.expression, /globalThis\.fetch\.bind\(globalThis\)/);
  assert.equal((result.expression.match(/__trrWrapper\.runCanary\(/g) ?? []).length, 1);
  assert.match(result.expression, /const canaryWrapperApi = Object\.freeze\(\{ executeCanaryRequest, runCanary \}\)/);
  assert.equal(result.calls.length, 21);
  assert.deepEqual(adapter.validateExecutionEvaluation(runtimeEvaluate(result.value), origin), JSON.parse(JSON.stringify(result.value)));
});

test("builders accept plain records from a separate JavaScript context", () => {
  const crossContextInput = vm.runInNewContext(`(${JSON.stringify(executionInput())})`);
  const expression = adapter.buildExecutionExpression(crossContextInput);

  assert.match(expression, /globalThis\.fetch\.bind\(globalThis\)/);
  assert.throws(
    () => adapter.buildCapabilityPreflightExpression(
      vm.runInNewContext(`new (class Input { constructor() { this.expectedOrigin = ${JSON.stringify(origin)}; } })()`),
    ),
    /plain object/,
  );
});

test("wrapper and immutable 20-request harness retain their exact frozen identities and order", () => {
  const identities = adapter.getFrozenIdentities();
  const wrapperSource = readFileSync(wrapperPath, "utf8");
  const harnessSource = readFileSync(harnessPath, "utf8");

  assert.equal(sha256(wrapperSource), "2e2c9c6c05bebc72615b21a7215d760e4506f77bce6a948706c19eabe9bead0f");
  assert.equal(identities.wrapperSha256, sha256(wrapperSource));
  assert.equal(sha256(harnessSource), "0da2db9137c3ce49d0b7969a566eaca24ae855b36688d437cbb6061028760632");
  assert.equal(identities.harnessSha256, sha256(harnessSource));
  assert.deepEqual(requestDefinitions.map((definition) => definition.id), identities.expectedVcIds);
  assert.deepEqual(identities.expectedVcIds, Array.from({ length: 20 }, (_value, index) => `VC-${String(index + 1).padStart(2, "0")}`));
});

test("success runs SENTINEL then VC-01 through VC-20 in exact order", async () => {
  const result = await evaluateExecution();
  const receipt = adapter.validateExecutionEvaluation(runtimeEvaluate(result.value), origin);

  assert.equal(receipt.status, "PASS");
  assert.deepEqual(result.calls.map((call) => call.definition?.id ?? "SENTINEL"), ["SENTINEL", ...adapter.EXPECTED_VC_IDS]);
  assert.equal(receipt.counters.preflightNetworkRequests, 0);
  assert.equal(receipt.counters.sentinelRequests, 1);
  assert.equal(receipt.counters.vcRequestsAttempted, 20);
  assert.equal(receipt.counters.totalRequestsObserved, 21);
});

test("preflight origin failure aborts with zero network, sentinel, and VC requests", async () => {
  const result = await evaluateExecution({ pageOrigin: "https://wrong.trr.localhost" });
  const receipt = result.value;

  assert.equal(receipt.status, "PREFLIGHT_REJECTED");
  assert.equal(receipt.reason, "origin_drift");
  assert.deepEqual(JSON.parse(JSON.stringify(receipt.counters)), {
    preflightNetworkRequests: 0,
    sentinelRequests: 0,
    vcRequestsAttempted: 0,
    totalRequestsObserved: 0,
  });
  assert.equal(result.calls.length, 0);
  assert.throws(() => adapter.validateExecutionEvaluation(runtimeEvaluate(receipt), origin), adapter.TrrE8AdapterValidationError);
});

test("sentinel failure performs one sentinel request and no VC requests", async () => {
  const result = await evaluateExecution({
    responder: ({ url, definition }) => {
      if (definition === null) return response({ url, contentType: "application/json", body: JSON.stringify({ hasAccess: false }) });
      return successfulResponse(definition, url);
    },
  });
  const receipt = adapter.validateExecutionEvaluation(runtimeEvaluate(result.value), origin);

  assert.equal(receipt.status, "ABORTED_SENTINEL");
  assert.equal(receipt.abortedAt, "SENTINEL");
  assert.equal(receipt.sentinel.assertion.code, "body_assertion_failed");
  assert.equal(receipt.vcResults.length, 0);
  assert.deepEqual(receipt.counters, {
    preflightNetworkRequests: 0,
    sentinelRequests: 1,
    vcRequestsAttempted: 0,
    totalRequestsObserved: 1,
  });
  assert.equal(result.calls.length, 1);
});

test("first VC failure stops immediately and leaves every remaining VC unattempted", async () => {
  const result = await evaluateExecution({
    responder: ({ url, definition }) => {
      if (definition?.id === "VC-01") return response({ url, status: 503, contentType: "text/html", body: "temporary failure" });
      return successfulResponse(definition, url);
    },
  });
  const receipt = adapter.validateExecutionEvaluation(runtimeEvaluate(result.value), origin);

  assert.equal(receipt.status, "ABORTED_VC");
  assert.equal(receipt.abortedAt, "VC-01");
  assert.deepEqual(receipt.vcResults.map((item) => item.requestId), ["VC-01"]);
  assert.equal(receipt.vcResults[0].assertion.code, "http_5xx");
  assert.deepEqual(result.calls.map((call) => call.definition?.id ?? "SENTINEL"), ["SENTINEL", "VC-01"]);
  assert.deepEqual(adapter.EXPECTED_VC_IDS.slice(1), requestDefinitions.slice(1).map((definition) => definition.id));
});

test("response, CDP, and malformed-result failure classes remain distinct", async () => {
  const definition = sentinelDefinition();
  const cases = [
    ["origin drift", { url: "https://other.trr.localhost/api/admin/check", contentType: "application/json", body: JSON.stringify({ hasAccess: true }) }, "origin_drift"],
    ["redirect", { url: `${origin}/login`, redirected: true, contentType: "application/json", body: JSON.stringify({ hasAccess: true }) }, "redirect_detected"],
    ["login surface", { url: `${origin}/login`, status: 401, contentType: "text/html", body: "login" }, "http_auth_failure"],
    ["non-200", { url: `${origin}/api/admin/check`, status: 418, contentType: "application/json", body: JSON.stringify({ hasAccess: true }) }, "http_non_200"],
    ["5xx", { url: `${origin}/api/admin/check`, status: 503, contentType: "application/json", body: JSON.stringify({ hasAccess: true }) }, "http_5xx"],
    ["content type", { url: `${origin}/api/admin/check`, contentType: "text/plain", body: JSON.stringify({ hasAccess: true }) }, "content_type_mismatch"],
    ["body assertion", { url: `${origin}/api/admin/check`, contentType: "application/json", body: JSON.stringify({ hasAccess: false }) }, "body_assertion_failed"],
  ];

  for (const [label, fixture, code] of cases) {
    const result = await wrapper.executeCanaryRequest({
      definition,
      kind: "sentinel",
      pageUrl: `${origin}/admin`,
      fetchImpl: async () => response(fixture),
    });
    assert.equal(result.assertion.code, code, label);
  }

  assert.throws(
    () => adapter.validateExecutionEvaluation({ result: { type: "object", value: {} }, exceptionDetails: { text: "synthetic" } }, origin),
    { name: "TrrE8AdapterValidationError", message: /exception details/ },
  );
  assert.throws(
    () => adapter.validateExecutionEvaluation({ result: { type: "object" } }, origin),
    { name: "TrrE8AdapterValidationError", message: /missing required field: value/ },
  );
});

test("receipts reject sensitive markers and bounded-field escapes", async () => {
  const valid = (await evaluateExecution()).value;
  const variants = [
    ["cookie", (value) => { value.cookie = "synthetic"; }],
    ["bearer token", (value) => { value.errorName = "BearerSyntheticToken"; }],
    ["nonce", (value) => { value.nonce = "synthetic"; }],
    ["stack", (value) => { value.stack = "synthetic stack"; }],
    ["response body", (value) => { value.responseBody = "synthetic body"; }],
    ["unbounded content type", (value) => { value.sentinel.contentType = "x".repeat(129); }],
  ];

  for (const [label, mutate] of variants) {
    const candidate = JSON.parse(JSON.stringify(valid));
    mutate(candidate);
    assert.throws(() => adapter.validateExecutionReceipt(candidate, origin), adapter.TrrE8AdapterValidationError, label);
  }
  assert.equal(Object.hasOwn(valid.sentinel, "finalUrl"), false);
  assert.equal(Object.hasOwn(valid.sentinel, "stack"), false);
  assert.equal(Object.hasOwn(valid.sentinel, "body"), false);
});

test("operator profile selector accepts exactly one TRR extension before tab creation", () => {
  const trr = { id: "trr", type: "extension", metadata: { profileName: "TRR" } };
  assert.equal(selectExactlyOneTrrExtension([{ id: "other", type: "extension", metadata: { profileName: "Codex" } }, trr]).id, "trr");
  assert.throws(() => selectExactlyOneTrrExtension([]), /exactly one TRR Chrome extension backend; found 0/);
  assert.throws(() => selectExactlyOneTrrExtension([trr, { ...trr, id: "trr-duplicate" }]), /exactly one TRR Chrome extension backend; found 2/);
});

test("narrow Make command and runbook preserve the CDP main-world hard-stop contract", () => {
  const runbook = readFileSync(runbookPath, "utf8");
  const makefile = readFileSync(makefilePath, "utf8");

  assert.match(makefile, /^test-e8-browser-adapter:\n\t@node --test scripts\/tests\/trr-e8-browser-adapter\.test\.cjs$/m);
  for (const phrase of [
    "read-only isolated world",
    "advertised CDP capability",
    "`Runtime.evaluate`",
    "`{ timeoutMs: 5000 }`",
    "exact-origin permission gate",
    "A dismissed, unanswered, automatic, or timed-out permission result is not approval",
    "page main world",
    "exactly one",
    "`TRR`",
    "Do not fall back",
    "Do not send a canary request",
  ]) {
    assert.match(runbook, new RegExp(phrase.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  }
});
