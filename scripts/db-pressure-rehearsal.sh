#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
ARTIFACT_DIR="${ROOT}/.logs/workspace/db-pressure-rehearsal-${TIMESTAMP}"
mkdir -p "$ARTIFACT_DIR"

redact_stream() {
  sed -E \
    -e 's#(postgres(ql)?://)[^ @]+@#\1[redacted]@#g' \
    -e 's#(service_role|anon|jwt|secret|token|password)[^[:space:]]*=[^[:space:]]+#\1=[redacted]#Ig' \
    -e 's#(Bearer )[A-Za-z0-9._~+/=-]+#\1[redacted]#g'
}

capture_status() {
  local label="$1"
  if bash scripts/status-workspace.sh --json >"${ARTIFACT_DIR}/status-${label}.json" 2>"${ARTIFACT_DIR}/status-${label}.stderr"; then
    return 0
  fi
  return 0
}

capture_url() {
  local label="$1"
  local url="$2"
  local output="${ARTIFACT_DIR}/${label}.json"
  local meta="${ARTIFACT_DIR}/${label}.meta"
  local http_code

  http_code="$(curl -sS --max-time 5 -w '%{http_code}' -o "$output.tmp" "$url" 2>"$meta.stderr" || true)"
  if [[ -s "$output.tmp" ]]; then
    redact_stream <"$output.tmp" >"$output"
  else
    printf '{"status":"skipped_or_empty"}\n' >"$output"
  fi
  rm -f "$output.tmp"
  {
    echo "url=${url}"
    echo "http_code=${http_code:-000}"
  } >"$meta"
}

capture_log_signals() {
  local output="${ARTIFACT_DIR}/log-signals.txt"
  local pattern='EMAXCONNSESSION|MaxClientsInSessionMode|UPSTREAM_TIMEOUT|DATABASE_SERVICE_UNAVAILABLE|postgres_pool_queue_depth|pool_capacity|connection pool exhausted'

  {
    echo "# DB Pressure Log Signals"
    echo
    for log_file in \
      "$ROOT/.logs/workspace/trr-app.log" \
      "$ROOT/.logs/workspace/trr-backend.log" \
      "$ROOT/.logs/workspace/trr-social-worker.log" \
      "$ROOT/.logs/workspace/trr-remote-workers.log"
    do
      echo "## ${log_file#$ROOT/}"
      if [[ -f "$log_file" ]]; then
        tail -n 1000 "$log_file" | rg -n "$pattern" || true
      else
        echo "not present"
      fi
      echo
    done
  } | redact_stream >"$output"
}

echo "[db-pressure] Artifact directory: ${ARTIFACT_DIR}"
echo "[db-pressure] Running strict workspace preflight with holder-budget enforcement..."

preflight_rc=0
set +e
WORKSPACE_ENFORCE_DB_HOLDER_BUDGET=1 make preflight >"${ARTIFACT_DIR}/preflight.log" 2>&1
preflight_rc="$?"
set -e

capture_status "before"
capture_url "backend-db-pressure" "http://127.0.0.1:8000/health/db-pressure"
capture_url "app-root" "http://127.0.0.1:3000/"
sleep 2
capture_status "after"
capture_log_signals

{
  echo "# DB Pressure Rehearsal"
  echo
  echo "- timestamp_utc: ${TIMESTAMP}"
  echo "- profile: ${PROFILE:-default}"
  echo "- preflight_rc: ${preflight_rc}"
  echo "- artifacts: ${ARTIFACT_DIR}"
  echo
  echo "Review \`status-before.json\`, \`status-after.json\`, \`backend-db-pressure.json\`, and \`log-signals.txt\`."
  echo "Artifacts are local-only under \`.logs/workspace/\` and must not contain raw secrets or full DB URLs."
} >"${ARTIFACT_DIR}/summary.md"

if [[ "$preflight_rc" != "0" ]]; then
  echo "[db-pressure] ERROR: strict preflight failed; see ${ARTIFACT_DIR}/preflight.log" >&2
  exit "$preflight_rc"
fi

echo "[db-pressure] Rehearsal complete: ${ARTIFACT_DIR}"
