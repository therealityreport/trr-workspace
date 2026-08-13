"use strict";

const { createHash } = require("node:crypto");
const { readFileSync } = require("node:fs");
const { join } = require("node:path");

const SCHEMA_VERSION = 1;
const WRAPPER_SHA256 = "2e2c9c6c05bebc72615b21a7215d760e4506f77bce6a948706c19eabe9bead0f";
const HARNESS_SHA256 = "0da2db9137c3ce49d0b7969a566eaca24ae855b36688d437cbb6061028760632";
const WRAPPER_GLOBAL = "__TRR_E8_CANARY_WRAPPER__";
const EXPECTED_VC_IDS = Object.freeze(Array.from({ length: 20 }, (_value, index) => `VC-${String(index + 1).padStart(2, "0")}`));
const ASSERTION_CODES = new Set([
  "success",
  "origin_drift",
  "redirect_detected",
  "http_5xx",
  "http_auth_failure",
  "http_non_200",
  "content_type_mismatch",
  "body_assertion_failed",
  "pre_status_transport_rejection",
  "response_body_read_rejection",
]);
const SENSITIVE_PATTERN = /(?:authorization|cookie|bearer|token|nonce|secret|password|api[-_]?key|session)/i;
const SAFE_NAME_PATTERN = /^[A-Za-z][A-Za-z0-9_.-]{0,79}$/;

class TrrE8AdapterValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = "TrrE8AdapterValidationError";
  }
}

function fail(message) {
  throw new TrrE8AdapterValidationError(message);
}

function isPlainRecord(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null || Object.getPrototypeOf(prototype) === null;
}

function requirePlainRecord(value, label) {
  if (!isPlainRecord(value)) fail(`${label} must be a plain object.`);
  return value;
}

function requireExactKeys(value, allowed, label) {
  requirePlainRecord(value, label);
  const allowedKeys = new Set(allowed);
  for (const key of Object.keys(value)) {
    if (!allowedKeys.has(key)) fail(`${label} contains an unknown field: ${key}.`);
  }
}

function requireRequiredKeys(value, required, label) {
  for (const key of required) {
    if (!Object.prototype.hasOwnProperty.call(value, key)) fail(`${label} is missing required field: ${key}.`);
  }
}

function requireString(value, label, { min = 1, max = 512, pattern } = {}) {
  if (typeof value !== "string" || value.length < min || value.length > max) fail(`${label} must be a string of ${min}-${max} characters.`);
  if (pattern && !pattern.test(value)) fail(`${label} has an invalid format.`);
  return value;
}

function requireInteger(value, label, { min = Number.MIN_SAFE_INTEGER, max = Number.MAX_SAFE_INTEGER } = {}) {
  if (!Number.isInteger(value) || value < min || value > max) fail(`${label} must be an integer between ${min} and ${max}.`);
  return value;
}

function assertNoSensitiveValue(value, label = "value", seen = new Set()) {
  if (typeof value === "string") {
    if (SENSITIVE_PATTERN.test(value)) fail(`${label} contains a disallowed sensitive marker.`);
    return;
  }
  if (value === null || typeof value === "boolean" || typeof value === "number") return;
  if (typeof value !== "object" || seen.has(value)) fail(`${label} must be a finite JSON value.`);
  seen.add(value);
  if (Array.isArray(value)) {
    for (const [index, item] of value.entries()) assertNoSensitiveValue(item, `${label}[${index}]`, seen);
    return;
  }
  requirePlainRecord(value, label);
  for (const [key, item] of Object.entries(value)) {
    if (SENSITIVE_PATTERN.test(key)) fail(`${label}.${key} is not allowed in an adapter input or receipt.`);
    assertNoSensitiveValue(item, `${label}.${key}`, seen);
  }
}

function assertJsonValue(value, label = "value", seen = new Set()) {
  if (value === null || typeof value === "boolean" || typeof value === "string") return;
  if (typeof value === "number") {
    if (!Number.isFinite(value)) fail(`${label} must not contain a non-finite number.`);
    return;
  }
  if (typeof value !== "object" || seen.has(value)) fail(`${label} must be a serializable JSON value.`);
  seen.add(value);
  if (Array.isArray(value)) {
    for (const [index, item] of value.entries()) assertJsonValue(item, `${label}[${index}]`, seen);
    return;
  }
  requirePlainRecord(value, label);
  for (const [key, item] of Object.entries(value)) assertJsonValue(item, `${label}.${key}`, seen);
}

function assertExactOrigin(value, label = "expectedOrigin") {
  const origin = requireString(value, label, { max: 512 });
  let parsed;
  try {
    parsed = new URL(origin);
  } catch {
    fail(`${label} must be an absolute HTTP(S) origin.`);
  }
  if ((parsed.protocol !== "http:" && parsed.protocol !== "https:") || parsed.origin !== origin || parsed.pathname !== "/" || parsed.search || parsed.hash || parsed.username || parsed.password) {
    fail(`${label} must be an exact HTTP(S) origin without a path, query, fragment, or credentials.`);
  }
  return origin;
}

function assertIdentity(value, expected, label) {
  if (value !== expected) fail(`${label} does not match the frozen identity.`);
  return value;
}

function assertScalarMap(value, label) {
  requirePlainRecord(value, label);
  for (const [key, item] of Object.entries(value)) {
    requireString(key, `${label} key`, { max: 128, pattern: /^[A-Za-z0-9_.-]+$/ });
    if (!(typeof item === "string" || typeof item === "number" || typeof item === "boolean")) fail(`${label}.${key} must be a scalar.`);
  }
}

function assertHeaderMap(value, label) {
  requirePlainRecord(value, label);
  for (const [key, item] of Object.entries(value)) {
    requireString(key, `${label} key`, { max: 128, pattern: /^[A-Za-z0-9-]+$/ });
    if (SENSITIVE_PATTERN.test(key)) fail(`${label}.${key} is disallowed.`);
    requireString(item, `${label}.${key}`, { max: 512 });
    assertNoSensitiveValue(item, `${label}.${key}`);
  }
}

function assertRequestDefinition(value, index) {
  const label = `requestDefinitions[${index}]`;
  requireExactKeys(value, ["id", "method", "route", "headers", "expected", "query"], label);
  requireRequiredKeys(value, ["id", "method", "route", "headers", "expected"], label);
  requireString(value.id, `${label}.id`, { max: 16, pattern: /^VC-[0-9]{2}$/ });
  requireString(value.method, `${label}.method`, { max: 12, pattern: /^[A-Z]+$/ });
  const route = requireString(value.route, `${label}.route`, { max: 1024 });
  if (!route.startsWith("/") || route.startsWith("//") || route.includes("://")) fail(`${label}.route must be a same-origin absolute path.`);
  assertHeaderMap(value.headers, `${label}.headers`);
  requireExactKeys(value.expected, ["status", "contentTypePrefix", "bodyContains"], `${label}.expected`);
  requireRequiredKeys(value.expected, ["status", "contentTypePrefix"], `${label}.expected`);
  requireInteger(value.expected.status, `${label}.expected.status`, { min: 100, max: 599 });
  requireString(value.expected.contentTypePrefix, `${label}.expected.contentTypePrefix`, { max: 128 });
  if (value.expected.bodyContains !== undefined) requireString(value.expected.bodyContains, `${label}.expected.bodyContains`, { max: 2048 });
  if (value.query !== undefined) assertScalarMap(value.query, `${label}.query`);
  assertNoSensitiveValue(value, label);
}

function assertFrozenRequestDefinitions(value) {
  if (!Array.isArray(value) || value.length !== EXPECTED_VC_IDS.length) fail("requestDefinitions must contain the immutable VC-01 through VC-20 corpus.");
  for (const [index, definition] of value.entries()) {
    assertRequestDefinition(definition, index);
    if (definition.id !== EXPECTED_VC_IDS[index]) fail("requestDefinitions must retain the immutable VC order.");
  }
  assertJsonValue(value, "requestDefinitions");
  return value;
}

function assertPreflightInput(value) {
  requireExactKeys(value, ["expectedOrigin"], "preflight input");
  requireRequiredKeys(value, ["expectedOrigin"], "preflight input");
  return { expectedOrigin: assertExactOrigin(value.expectedOrigin) };
}

function assertExecutionInput(value) {
  requireExactKeys(value, ["expectedOrigin", "requestDefinitions", "wrapperSha256", "harnessSha256"], "execution input");
  requireRequiredKeys(value, ["expectedOrigin", "requestDefinitions", "wrapperSha256", "harnessSha256"], "execution input");
  const input = {
    expectedOrigin: assertExactOrigin(value.expectedOrigin),
    requestDefinitions: assertFrozenRequestDefinitions(value.requestDefinitions),
    wrapperSha256: assertIdentity(value.wrapperSha256, WRAPPER_SHA256, "wrapperSha256"),
    harnessSha256: assertIdentity(value.harnessSha256, HARNESS_SHA256, "harnessSha256"),
  };
  assertNoSensitiveValue(input, "execution input");
  return input;
}

function readQualifiedWrapper() {
  const wrapperPath = join(__dirname, "trr-e8-canary-wrapper.cjs");
  const wrapperSource = readFileSync(wrapperPath, "utf8");
  const observedHash = createHash("sha256").update(wrapperSource).digest("hex");
  if (observedHash !== WRAPPER_SHA256) fail("Durable canary wrapper hash differs from the frozen qualified bytes.");
  return { wrapperPath, wrapperSource, wrapperSha256: observedHash };
}

function buildCapabilityPreflightExpression(value) {
  assertPreflightInput(value);
  return `(() => ({\n  schemaVersion: ${SCHEMA_VERSION},\n  origin: location.origin,\n  globalThisFetchType: typeof globalThis.fetch,\n  windowFetchType: typeof window.fetch,\n  wrapperAvailability: globalThis.${WRAPPER_GLOBAL} && typeof globalThis.${WRAPPER_GLOBAL}.runCanary === "function" ? "available" : "absent",\n}))()`;
}

function buildExecutionExpression(value) {
  const input = assertExecutionInput(value);
  const { wrapperSource, wrapperSha256 } = readQualifiedWrapper();
  const serializedDefinitions = JSON.stringify(input.requestDefinitions);
  const serializedOrigin = JSON.stringify(input.expectedOrigin);
  return `(async () => {\n  const __trrSchemaVersion = ${SCHEMA_VERSION};\n  const __trrExpectedOrigin = ${serializedOrigin};\n  const __trrWrapperSha256 = ${JSON.stringify(wrapperSha256)};\n  const __trrHarnessSha256 = ${JSON.stringify(HARNESS_SHA256)};\n  const __trrKnownVcIds = ${JSON.stringify(EXPECTED_VC_IDS)};\n  const __trrDefinitions = ${serializedDefinitions};\n  const __trrOrigin = location.origin;\n  const __trrGlobalFetchType = typeof globalThis.fetch;\n  const __trrWindowFetchType = typeof window.fetch;\n  const __trrBase = (status, reason, wrapperAvailability) => ({\n    schemaVersion: __trrSchemaVersion,\n    origin: __trrOrigin,\n    globalThisFetchType: __trrGlobalFetchType,\n    windowFetchType: __trrWindowFetchType,\n    wrapperAvailability,\n    wrapperSha256: __trrWrapperSha256,\n    harnessSha256: __trrHarnessSha256,\n    status,\n    reason,\n    counters: { preflightNetworkRequests: 0, sentinelRequests: 0, vcRequestsAttempted: 0, totalRequestsObserved: 0 },\n    sentinel: null,\n    vcResults: [],\n    abortedAt: null,\n  });\n  if (__trrOrigin !== __trrExpectedOrigin) return __trrBase("PREFLIGHT_REJECTED", "origin_drift", "not_loaded");\n  if (__trrGlobalFetchType !== "function" || __trrWindowFetchType !== "function") return __trrBase("PREFLIGHT_REJECTED", "fetch_unavailable", "not_loaded");\n  const __trrHasPriorWrapper = Object.prototype.hasOwnProperty.call(globalThis, ${JSON.stringify(WRAPPER_GLOBAL)});\n  const __trrPriorWrapper = globalThis.${WRAPPER_GLOBAL};\n  const __trrSafeErrorName = (error) => {\n    const name = error && typeof error.name === "string" ? error.name : "Error";\n    return /^[A-Za-z][A-Za-z0-9_.-]{0,79}$/.test(name) ? name : "Error";\n  };\n  const __trrSafeResult = (result) => {\n    if (!result || typeof result !== "object") throw new Error("malformed_wrapper_result");\n    const assertion = result.assertion;\n    if (!assertion || typeof assertion !== "object" || typeof assertion.passed !== "boolean" || typeof assertion.code !== "string") throw new Error("malformed_wrapper_assertion");\n    if (!${JSON.stringify(Array.from(ASSERTION_CODES))}.includes(assertion.code)) throw new Error("unknown_wrapper_assertion");\n    const requestId = typeof result.requestId === "string" ? result.requestId : "";\n    const kind = result.kind === "sentinel" || result.kind === "vc" ? result.kind : "";\n    if (!requestId || !kind) throw new Error("malformed_wrapper_request");\n    let finalOrigin = null;\n    if (typeof result.finalUrl === "string" && result.finalUrl) finalOrigin = new URL(result.finalUrl).origin;\n    const status = result.status === null ? null : result.status;\n    if (status !== null && (!Number.isInteger(status) || status < 100 || status > 599)) throw new Error("malformed_wrapper_status");\n    const contentType = typeof result.contentType === "string" ? result.contentType.slice(0, 128) : null;\n    return { requestId, kind, status, finalOrigin, redirected: result.redirected === null ? null : Boolean(result.redirected), contentType, assertion: { passed: assertion.passed, code: assertion.code }, errorName: __trrSafeErrorName(result.error) };\n  };\n  try {\n${wrapperSource.split("\n").map((line) => `    ${line}`).join("\n")}\n    const __trrWrapper = globalThis.${WRAPPER_GLOBAL};\n    if (!__trrWrapper || typeof __trrWrapper.runCanary !== "function") return __trrBase("ADAPTER_REJECTED", "wrapper_unavailable", "not_loaded");\n    const __trrFetchImpl = globalThis.fetch.bind(globalThis);\n    const __trrRaw = await __trrWrapper.runCanary({ pageUrl: location.href, requestDefinitions: __trrDefinitions, fetchImpl: __trrFetchImpl });\n    if (!__trrRaw || typeof __trrRaw !== "object" || !__trrRaw.sentinel || !Array.isArray(__trrRaw.vcResults)) return __trrBase("ADAPTER_REJECTED", "malformed_wrapper_receipt", "loaded");\n    const __trrSentinel = __trrSafeResult(__trrRaw.sentinel);\n    const __trrVcResults = __trrRaw.vcResults.map(__trrSafeResult);\n    if (__trrSentinel.requestId !== "SENTINEL" || __trrSentinel.kind !== "sentinel" || __trrVcResults.some((result, index) => result.requestId !== __trrKnownVcIds[index] || result.kind !== "vc")) return __trrBase("ADAPTER_REJECTED", "receipt_identity_drift", "loaded");\n    if (!Number.isInteger(__trrRaw.vcRequestsAttempted) || __trrRaw.vcRequestsAttempted !== __trrVcResults.length) return __trrBase("ADAPTER_REJECTED", "receipt_counter_drift", "loaded");\n    const __trrAllowedStatus = ["PASS", "ABORTED_SENTINEL", "ABORTED_VC"];\n    if (!__trrAllowedStatus.includes(__trrRaw.status)) return __trrBase("ADAPTER_REJECTED", "receipt_status_drift", "loaded");\n    if (__trrRaw.status === "PASS" && (!__trrSentinel.assertion.passed || __trrVcResults.length !== __trrKnownVcIds.length || __trrVcResults.some((result) => !result.assertion.passed) || __trrRaw.abortedAt !== null)) return __trrBase("ADAPTER_REJECTED", "receipt_abort_drift", "loaded");\n    if (__trrRaw.status === "ABORTED_SENTINEL" && (__trrSentinel.assertion.passed || __trrVcResults.length !== 0 || __trrRaw.abortedAt !== "SENTINEL")) return __trrBase("ADAPTER_REJECTED", "receipt_abort_drift", "loaded");\n    if (__trrRaw.status === "ABORTED_VC" && (!__trrSentinel.assertion.passed || __trrVcResults.length < 1 || __trrVcResults.length > __trrKnownVcIds.length || __trrVcResults.at(-1).assertion.passed || __trrRaw.abortedAt !== __trrVcResults.at(-1).requestId)) return __trrBase("ADAPTER_REJECTED", "receipt_abort_drift", "loaded");\n    return {\n      schemaVersion: __trrSchemaVersion,\n      origin: __trrOrigin,\n      globalThisFetchType: __trrGlobalFetchType,\n      windowFetchType: __trrWindowFetchType,\n      wrapperAvailability: "loaded",\n      wrapperSha256: __trrWrapperSha256,\n      harnessSha256: __trrHarnessSha256,\n      status: __trrRaw.status,\n      reason: null,\n      counters: { preflightNetworkRequests: 0, sentinelRequests: 1, vcRequestsAttempted: __trrVcResults.length, totalRequestsObserved: 1 + __trrVcResults.length },\n      sentinel: __trrSentinel,\n      vcResults: __trrVcResults,\n      abortedAt: __trrRaw.abortedAt,\n    };\n  } catch (error) {\n    const receipt = __trrBase("ADAPTER_REJECTED", "wrapper_execution_exception", "loaded");\n    receipt.errorName = __trrSafeErrorName(error);\n    return receipt;\n  } finally {\n    if (__trrHasPriorWrapper) globalThis.${WRAPPER_GLOBAL} = __trrPriorWrapper;\n    else delete globalThis.${WRAPPER_GLOBAL};\n  }\n})()`;
}

function unwrapRuntimeEvaluateResponse(value) {
  requireExactKeys(value, ["result", "exceptionDetails"], "Runtime.evaluate response");
  if (Object.prototype.hasOwnProperty.call(value, "exceptionDetails") && value.exceptionDetails !== undefined && value.exceptionDetails !== null) fail("Runtime.evaluate returned exception details.");
  requireRequiredKeys(value, ["result"], "Runtime.evaluate response");
  requireExactKeys(value.result, ["type", "value"], "Runtime.evaluate result");
  requireRequiredKeys(value.result, ["type", "value"], "Runtime.evaluate result");
  if (value.result.type !== "object") fail("Runtime.evaluate result must be a returned-by-value object.");
  requirePlainRecord(value.result.value, "Runtime.evaluate result.value");
  return value.result.value;
}

function validateCapabilityPreflightReceipt(value, expectedOrigin) {
  const origin = assertExactOrigin(expectedOrigin);
  requireExactKeys(value, ["schemaVersion", "origin", "globalThisFetchType", "windowFetchType", "wrapperAvailability"], "capability preflight receipt");
  requireRequiredKeys(value, ["schemaVersion", "origin", "globalThisFetchType", "windowFetchType", "wrapperAvailability"], "capability preflight receipt");
  if (value.schemaVersion !== SCHEMA_VERSION) fail("Capability preflight schema version drifted.");
  if (value.origin !== origin) fail("Capability preflight origin drifted.");
  if (value.globalThisFetchType !== "function" || value.windowFetchType !== "function") fail("Capability preflight did not find callable page-main-world fetch.");
  if (value.wrapperAvailability !== "available" && value.wrapperAvailability !== "absent") fail("Capability preflight wrapper availability is invalid.");
  assertNoSensitiveValue(value, "capability preflight receipt");
  return Object.freeze({ ...value });
}

function validateCapabilityPreflightEvaluation(value, expectedOrigin) {
  return validateCapabilityPreflightReceipt(unwrapRuntimeEvaluateResponse(value), expectedOrigin);
}

function validateReceiptOrigin(value, label) {
  if (value === null) return null;
  return assertExactOrigin(value, label);
}

function validateSanitizedRequestResult(value, label, expectedId, expectedKind) {
  requireExactKeys(value, ["requestId", "kind", "status", "finalOrigin", "redirected", "contentType", "assertion", "errorName"], label);
  requireRequiredKeys(value, ["requestId", "kind", "status", "finalOrigin", "redirected", "contentType", "assertion", "errorName"], label);
  if (value.requestId !== expectedId || value.kind !== expectedKind) fail(`${label} request identity drifted.`);
  if (value.status !== null) requireInteger(value.status, `${label}.status`, { min: 100, max: 599 });
  validateReceiptOrigin(value.finalOrigin, `${label}.finalOrigin`);
  if (value.redirected !== null && typeof value.redirected !== "boolean") fail(`${label}.redirected must be boolean or null.`);
  if (value.contentType !== null) requireString(value.contentType, `${label}.contentType`, { max: 128 });
  requireExactKeys(value.assertion, ["passed", "code"], `${label}.assertion`);
  requireRequiredKeys(value.assertion, ["passed", "code"], `${label}.assertion`);
  if (typeof value.assertion.passed !== "boolean" || !ASSERTION_CODES.has(value.assertion.code)) fail(`${label}.assertion is not allowlisted.`);
  requireString(value.errorName, `${label}.errorName`, { max: 80, pattern: SAFE_NAME_PATTERN });
  return value;
}

function validateExecutionReceipt(value, expectedOrigin) {
  const origin = assertExactOrigin(expectedOrigin);
  requireExactKeys(value, ["schemaVersion", "origin", "globalThisFetchType", "windowFetchType", "wrapperAvailability", "wrapperSha256", "harnessSha256", "status", "reason", "counters", "sentinel", "vcResults", "abortedAt", "errorName"], "execution receipt");
  requireRequiredKeys(value, ["schemaVersion", "origin", "globalThisFetchType", "windowFetchType", "wrapperAvailability", "wrapperSha256", "harnessSha256", "status", "reason", "counters", "sentinel", "vcResults", "abortedAt"], "execution receipt");
  if (value.schemaVersion !== SCHEMA_VERSION || value.origin !== origin) fail("Execution receipt schema or origin drifted.");
  if (value.globalThisFetchType !== "function" || value.windowFetchType !== "function") fail("Execution receipt did not retain callable page-main-world fetch.");
  assertIdentity(value.wrapperSha256, WRAPPER_SHA256, "execution receipt wrapperSha256");
  assertIdentity(value.harnessSha256, HARNESS_SHA256, "execution receipt harnessSha256");
  if (!["not_loaded", "loaded"].includes(value.wrapperAvailability)) fail("Execution receipt wrapper availability is invalid.");
  requireExactKeys(value.counters, ["preflightNetworkRequests", "sentinelRequests", "vcRequestsAttempted", "totalRequestsObserved"], "execution receipt counters");
  for (const key of Object.keys(value.counters)) requireInteger(value.counters[key], `execution receipt counters.${key}`, { min: 0, max: 21 });
  if (value.counters.preflightNetworkRequests !== 0) fail("Execution receipt preflight network counter must be zero.");
  if (!Array.isArray(value.vcResults) || value.vcResults.length > EXPECTED_VC_IDS.length) fail("Execution receipt vcResults exceeds the immutable corpus.");
  const networked = ["PASS", "ABORTED_SENTINEL", "ABORTED_VC"];
  const rejected = ["PREFLIGHT_REJECTED", "ADAPTER_REJECTED"];
  if (![...networked, ...rejected].includes(value.status)) fail("Execution receipt status is not allowlisted.");
  if (rejected.includes(value.status)) {
    if (value.counters.sentinelRequests !== 0 || value.counters.vcRequestsAttempted !== 0 || value.counters.totalRequestsObserved !== 0 || value.sentinel !== null || value.vcResults.length !== 0) fail("Rejected execution receipt must fail closed before a request.");
    if (value.status === "PREFLIGHT_REJECTED") {
      if (value.wrapperAvailability !== "not_loaded" || !["origin_drift", "fetch_unavailable"].includes(value.reason) || value.abortedAt !== null || value.errorName !== undefined) fail("Preflight rejection receipt is malformed.");
    } else if (!["wrapper_unavailable", "malformed_wrapper_receipt", "receipt_identity_drift", "receipt_counter_drift", "receipt_status_drift", "receipt_abort_drift", "wrapper_execution_exception"].includes(value.reason)) {
      fail("Adapter rejection reason is not allowlisted.");
    }
  } else {
    if (value.counters.sentinelRequests !== 1 || value.counters.vcRequestsAttempted !== value.vcResults.length || value.counters.totalRequestsObserved !== 1 + value.vcResults.length) fail("Execution receipt counters drifted.");
    if (!isPlainRecord(value.sentinel)) fail("Networked execution receipt is missing sentinel evidence.");
    if (value.reason !== null) fail("Networked execution receipt must not include a rejection reason.");
    validateSanitizedRequestResult(value.sentinel, "execution receipt.sentinel", "SENTINEL", "sentinel");
    for (const [index, result] of value.vcResults.entries()) validateSanitizedRequestResult(result, `execution receipt.vcResults[${index}]`, EXPECTED_VC_IDS[index], "vc");
    if (value.status === "PASS") {
      if (!value.sentinel.assertion.passed || value.vcResults.length !== EXPECTED_VC_IDS.length || value.vcResults.some((result) => !result.assertion.passed) || value.abortedAt !== null) fail("PASS receipt does not contain the complete successful immutable corpus.");
    }
    if (value.status === "ABORTED_SENTINEL") {
      if (value.sentinel.assertion.passed || value.vcResults.length !== 0 || value.abortedAt !== "SENTINEL") fail("Sentinel abort receipt is malformed.");
    }
    if (value.status === "ABORTED_VC") {
      if (!value.sentinel.assertion.passed || value.vcResults.length < 1 || value.vcResults.at(-1).assertion.passed || value.abortedAt !== value.vcResults.at(-1).requestId) fail("VC abort receipt is malformed.");
    }
  }
  if (value.errorName !== undefined) requireString(value.errorName, "execution receipt.errorName", { max: 80, pattern: SAFE_NAME_PATTERN });
  assertNoSensitiveValue(value, "execution receipt");
  return Object.freeze(JSON.parse(JSON.stringify(value)));
}

function validateExecutionEvaluation(value, expectedOrigin) {
  return validateExecutionReceipt(unwrapRuntimeEvaluateResponse(value), expectedOrigin);
}

function getFrozenIdentities() {
  return Object.freeze({ schemaVersion: SCHEMA_VERSION, wrapperSha256: WRAPPER_SHA256, harnessSha256: HARNESS_SHA256, expectedVcIds: [...EXPECTED_VC_IDS] });
}

module.exports = Object.freeze({
  SCHEMA_VERSION,
  WRAPPER_SHA256,
  HARNESS_SHA256,
  EXPECTED_VC_IDS,
  TrrE8AdapterValidationError,
  getFrozenIdentities,
  readQualifiedWrapper,
  buildCapabilityPreflightExpression,
  buildExecutionExpression,
  unwrapRuntimeEvaluateResponse,
  validateCapabilityPreflightReceipt,
  validateCapabilityPreflightEvaluation,
  validateExecutionReceipt,
  validateExecutionEvaluation,
});
