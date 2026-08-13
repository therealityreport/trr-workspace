const DEFAULT_FETCH_OPTIONS = Object.freeze({
  credentials: "same-origin",
  cache: "no-store",
  redirect: "follow",
});

function deepFreeze(value) {
  if (!value || typeof value !== "object" || Object.isFrozen(value)) return value;
  Object.freeze(value);
  for (const child of Object.values(value)) deepFreeze(child);
  return value;
}

function serializeError(error) {
  return {
    name: typeof error?.name === "string" ? error.name : "Error",
    message: typeof error?.message === "string" ? error.message : String(error),
    stack: typeof error?.stack === "string" ? error.stack : null,
  };
}

function buildUrl(pageUrl, definition) {
  const resolved = new URL(definition.route, pageUrl);
  for (const [name, value] of Object.entries(definition.query ?? {})) {
    resolved.searchParams.append(name, String(value));
  }
  return resolved;
}

function assertionResult(passed, code, detail, checks) {
  return { passed, code, detail, checks };
}

function elapsedMilliseconds(startedAt, endedAt) {
  return new Date(endedAt).getTime() - new Date(startedAt).getTime();
}

function classifyResolvedResponse({ definition, kind, pageOrigin, response, body, contentType }) {
  const statusCheck = {
    name: "status",
    expected: definition.expected.status,
    actual: response.status,
    passed: response.status === definition.expected.status,
  };
  const finalUrl = response.url || null;
  const finalOrigin = finalUrl ? new URL(finalUrl).origin : null;
  const originCheck = {
    name: "same-origin-final-url",
    expected: pageOrigin,
    actual: finalOrigin,
    passed: finalOrigin === pageOrigin,
  };
  const redirectCheck = {
    name: "not-redirected",
    expected: false,
    actual: Boolean(response.redirected),
    passed: !response.redirected,
  };
  const checks = [originCheck, redirectCheck, statusCheck];

  if (!originCheck.passed) {
    return assertionResult(false, "origin_drift", "The final response origin differs from the page origin.", checks);
  }
  if (!redirectCheck.passed) {
    return assertionResult(false, "redirect_detected", "The response followed or reports a redirect.", checks);
  }
  if (response.status >= 500) {
    return assertionResult(false, "http_5xx", `Observed HTTP ${response.status}.`, checks);
  }
  if (response.status === 401 || response.status === 403) {
    return assertionResult(false, "http_auth_failure", `Observed HTTP ${response.status}.`, checks);
  }
  if (!statusCheck.passed) {
    return assertionResult(false, "http_non_200", `Expected HTTP ${definition.expected.status}; observed ${response.status}.`, checks);
  }

  const expectedContentType = definition.expected.contentTypePrefix;
  const contentTypeCheck = {
    name: "content-type-prefix",
    expected: expectedContentType,
    actual: contentType,
    passed: typeof contentType === "string" && contentType.startsWith(expectedContentType),
  };
  checks.push(contentTypeCheck);
  if (!contentTypeCheck.passed) {
    return assertionResult(false, "content_type_mismatch", "The response content type does not match the expected prefix.", checks);
  }

  if (kind === "sentinel") {
    let parsed;
    try {
      parsed = JSON.parse(body);
    } catch {
      const jsonCheck = { name: "sentinel-json", expected: { hasAccess: true }, actual: "invalid-json", passed: false };
      checks.push(jsonCheck);
      return assertionResult(false, "body_assertion_failed", "The sentinel body is not valid JSON.", checks);
    }
    const keys = parsed && typeof parsed === "object" && !Array.isArray(parsed) ? Object.keys(parsed) : [];
    const sentinelBodyCheck = {
      name: "sentinel-body",
      expected: { hasAccess: true },
      actual: parsed,
      passed: parsed?.hasAccess === true && keys.length === 1 && keys[0] === "hasAccess",
    };
    checks.push(sentinelBodyCheck);
    if (!sentinelBodyCheck.passed) {
      return assertionResult(false, "body_assertion_failed", "The sentinel body is not exactly compatible with {hasAccess:true}.", checks);
    }
  } else if (definition.expected.bodyContains !== undefined) {
    const bodyCheck = {
      name: "body-contains",
      expected: definition.expected.bodyContains,
      actual: body.includes(definition.expected.bodyContains),
      passed: body.includes(definition.expected.bodyContains),
    };
    checks.push(bodyCheck);
    if (!bodyCheck.passed) {
      return assertionResult(false, "body_assertion_failed", "The response body does not contain the required text.", checks);
    }
  }

  return assertionResult(true, "success", "All response assertions passed.", checks);
}

async function executeCanaryRequest({ definition, kind = "vc", pageUrl, fetchImpl, clock = () => new Date() }) {
  const page = new URL(pageUrl);
  const resolved = buildUrl(page, definition);
  const startedAt = clock().toISOString();
  const fetchOptions = {
    method: definition.method,
    headers: { ...(definition.headers ?? {}) },
    ...DEFAULT_FETCH_OPTIONS,
  };
  const request = {
    method: fetchOptions.method,
    headers: fetchOptions.headers,
    credentials: fetchOptions.credentials,
    cache: fetchOptions.cache,
    redirect: fetchOptions.redirect,
  };

  let response;
  try {
    response = await fetchImpl(resolved.href, fetchOptions);
  } catch (error) {
    const endedAt = clock().toISOString();
    return {
      requestId: definition.id,
      kind,
      pageOrigin: page.origin,
      resolvedUrl: resolved.href,
      startedAt,
      endedAt,
      durationMs: elapsedMilliseconds(startedAt, endedAt),
      request,
      fetch: { resolved: false, rejected: true },
      error: serializeError(error),
      status: null,
      finalUrl: null,
      redirected: null,
      contentType: null,
      assertion: assertionResult(false, "pre_status_transport_rejection", "Fetch rejected before an HTTP status was observable.", []),
    };
  }

  const contentType = response.headers.get("content-type");
  let body;
  try {
    body = await response.text();
  } catch (error) {
    const endedAt = clock().toISOString();
    return {
      requestId: definition.id,
      kind,
      pageOrigin: page.origin,
      resolvedUrl: resolved.href,
      startedAt,
      endedAt,
      durationMs: elapsedMilliseconds(startedAt, endedAt),
      request,
      fetch: { resolved: true, rejected: false },
      error: serializeError(error),
      status: response.status,
      finalUrl: response.url || null,
      redirected: Boolean(response.redirected),
      contentType,
      assertion: assertionResult(false, "response_body_read_rejection", "Fetch resolved with an HTTP response, but reading its body rejected.", []),
    };
  }
  const endedAt = clock().toISOString();
  return {
    requestId: definition.id,
    kind,
    pageOrigin: page.origin,
    resolvedUrl: resolved.href,
    startedAt,
    endedAt,
    durationMs: elapsedMilliseconds(startedAt, endedAt),
    request,
    fetch: { resolved: true, rejected: false },
    error: { name: null, message: null, stack: null },
    status: response.status,
    finalUrl: response.url || null,
    redirected: Boolean(response.redirected),
    contentType,
    assertion: classifyResolvedResponse({ definition, kind, pageOrigin: page.origin, response, body, contentType }),
  };
}

async function runCanary({ pageUrl, requestDefinitions, fetchImpl, clock = () => new Date() }) {
  const sentinelDefinition = deepFreeze({
    id: "SENTINEL",
    method: "GET",
    route: "/api/admin/check",
    headers: { accept: "application/json" },
    expected: { status: 200, contentTypePrefix: "application/json" },
  });
  const sentinel = await executeCanaryRequest({
    definition: sentinelDefinition,
    kind: "sentinel",
    pageUrl,
    fetchImpl,
    clock,
  });

  if (!sentinel.assertion.passed) {
    return {
      status: "ABORTED_SENTINEL",
      sentinel,
      vcResults: [],
      vcRequestsAttempted: 0,
      abortedAt: "SENTINEL",
    };
  }

  const vcResults = [];
  for (const definition of requestDefinitions) {
    const result = await executeCanaryRequest({ definition, pageUrl, fetchImpl, clock });
    vcResults.push(result);
    if (!result.assertion.passed) {
      return {
        status: "ABORTED_VC",
        sentinel,
        vcResults,
        vcRequestsAttempted: vcResults.length,
        abortedAt: result.requestId,
      };
    }
  }

  return {
    status: "PASS",
    sentinel,
    vcResults,
    vcRequestsAttempted: vcResults.length,
    abortedAt: null,
  };
}

const canaryWrapperApi = Object.freeze({ executeCanaryRequest, runCanary });

if (typeof module === "object" && module?.exports) {
  module.exports = canaryWrapperApi;
} else {
  globalThis.__TRR_E8_CANARY_WRAPPER__ = canaryWrapperApi;
}
