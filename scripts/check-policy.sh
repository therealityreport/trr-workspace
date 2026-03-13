#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/preflight-diagnostics.sh"

preflight_diag_init "check-policy.sh" "$ROOT" "check-policy"

check_policy_on_signal() {
  local signal_name="$1"
  export WORKSPACE_PREFLIGHT_DIAGNOSTICS_SIGNAL_SEEN="$signal_name"
  export WORKSPACE_PREFLIGHT_DIAGNOSTICS_EXIT_CODE="$(preflight_diag_signal_exit_code "$signal_name")"
  preflight_diag_log_event signal_received signal "$signal_name"
  preflight_diag_log_snapshot "signal_${signal_name}"
  trap - "$signal_name"
  kill -s "$signal_name" "$$"
}

check_policy_on_exit() {
  local rc="$?"
  local inferred_signal=""
  if [[ -n "${WORKSPACE_PREFLIGHT_DIAGNOSTICS_EXIT_CODE:-}" ]]; then
    rc="$WORKSPACE_PREFLIGHT_DIAGNOSTICS_EXIT_CODE"
  fi
  if [[ -z "${WORKSPACE_PREFLIGHT_DIAGNOSTICS_SIGNAL_SEEN:-}" ]]; then
    inferred_signal="$(preflight_diag_exit_code_signal_name "$rc")"
    if [[ -n "$inferred_signal" ]]; then
      preflight_diag_log_event signal_received signal "$inferred_signal" inferred "true"
    fi
  fi
  preflight_diag_log_event exit exit_code "$rc" failures "${failures:-0}"
}

AGENTS_FILES=(
  "$ROOT/AGENTS.md"
  "$ROOT/TRR-Backend/AGENTS.md"
  "$ROOT/TRR-APP/AGENTS.md"
  "$ROOT/screenalytics/AGENTS.md"
)

CLAUDE_FILES=()
while IFS= read -r file; do
  CLAUDE_FILES+=("$file")
done < <(find "$ROOT" -type f -name 'CLAUDE.md' | sort)

POLICY_SCAN_FILES=(
  "${AGENTS_FILES[@]}"
  "${CLAUDE_FILES[@]}"
  "$ROOT/docs/agent-governance/codex_skills.md"
  "$ROOT/docs/agent-governance/claude_skill_overlap.md"
  "$ROOT/docs/agent-governance/mcp_inventory.md"
)

failures=0

if preflight_diag_is_enabled; then
  preflight_diag_set_phase "policy_scan"
  preflight_diag_log_event session_start \
    agents_count "${#AGENTS_FILES[@]}" \
    claude_count "${#CLAUDE_FILES[@]}" \
    policy_scan_count "${#POLICY_SCAN_FILES[@]}"
  trap check_policy_on_exit EXIT
  trap 'check_policy_on_signal INT' INT
  trap 'check_policy_on_signal TERM' TERM
  trap 'check_policy_on_signal HUP' HUP
fi

for file in "${AGENTS_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "[check-policy] ERROR: missing file $file" >&2
    failures=$((failures + 1))
    continue
  fi

  if ! rg -q '^## MCP Invocation Matrix' "$file"; then
    echo "[check-policy] ERROR: missing MCP matrix section in $file" >&2
    failures=$((failures + 1))
  fi

  if ! rg -q '^### Before Each Plan' "$file"; then
    echo "[check-policy] ERROR: missing planning-skill subsection in $file" >&2
    failures=$((failures + 1))
  fi

  if ! rg -q 'Review the skills available' "$file"; then
    echo "[check-policy] ERROR: missing skill-review rule in $file" >&2
    failures=$((failures + 1))
  fi

  if ! rg -q 'Choose the minimum skill set' "$file"; then
    echo "[check-policy] ERROR: missing minimum-skill rule in $file" >&2
    failures=$((failures + 1))
  fi

  if ! rg -q 'plan writing' "$file"; then
    echo "[check-policy] ERROR: missing plan-writing skill rule in $file" >&2
    failures=$((failures + 1))
  fi

  if ! rg -q 'implementation' "$file"; then
    echo "[check-policy] ERROR: missing implementation-skill rule in $file" >&2
    failures=$((failures + 1))
  fi

  if ! rg -q 'fall back to workspace-local, then globally canonical' "$file"; then
    echo "[check-policy] ERROR: missing canonical fallback order in $file" >&2
    failures=$((failures + 1))
  fi

  if ! rg -q '^### AWS Deploy Rule' "$file"; then
    echo "[check-policy] ERROR: missing AWS deploy-rule subsection in $file" >&2
    failures=$((failures + 1))
  fi

  if ! rg -q 'deployable AWS/cloud-infra/backend' "$file"; then
    echo "[check-policy] ERROR: missing deploy trigger definition in $file" >&2
    failures=$((failures + 1))
  fi

  if ! rg -q 'Required checks must pass before deploy' "$file"; then
    echo "[check-policy] ERROR: missing checks-before-deploy rule in $file" >&2
    failures=$((failures + 1))
  fi

  if ! rg -q 'Implementation is not complete until the AWS deployment is executed successfully' "$file"; then
    echo "[check-policy] ERROR: missing auto-deploy completion rule in $file" >&2
    failures=$((failures + 1))
  fi
done

for file in "${CLAUDE_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "[check-policy] ERROR: missing file $file" >&2
    failures=$((failures + 1))
    continue
  fi

  line_count="$(wc -l < "$file" | tr -d ' ')"
  if [[ "$line_count" -gt 20 ]]; then
    echo "[check-policy] ERROR: $file exceeds 20 lines ($line_count)." >&2
    failures=$((failures + 1))
  fi

  if ! rg -q 'AGENTS\.md' "$file"; then
    echo "[check-policy] ERROR: $file does not point to AGENTS.md." >&2
    failures=$((failures + 1))
  fi

  if ! rg -qi 'authoritative|conflict.*AGENTS\.md|AGENTS\.md.*wins' "$file"; then
    echo "[check-policy] ERROR: $file missing AGENTS authority/conflict rule." >&2
    failures=$((failures + 1))
  fi

  if ! rg -qi 'pointer shim' "$file"; then
    echo "[check-policy] ERROR: $file missing pointer-shim rule." >&2
    failures=$((failures + 1))
  fi
done

if rg -n -i 'playwright' "${POLICY_SCAN_FILES[@]}" >/tmp/trr-policy-playwright-hits.txt; then
  if [[ -s /tmp/trr-policy-playwright-hits.txt ]]; then
    echo "[check-policy] ERROR: disallowed 'playwright' references found:" >&2
    cat /tmp/trr-policy-playwright-hits.txt >&2
    failures=$((failures + 1))
  fi
fi
rm -f /tmp/trr-policy-playwright-hits.txt

if [[ "$failures" -gt 0 ]]; then
  echo "[check-policy] FAILED with ${failures} issue(s)." >&2
  exit 1
fi

echo "[check-policy] OK"
