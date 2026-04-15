#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/preflight-diagnostics.sh"
source "$ROOT/scripts/lib/preflight-handoff.sh"

preflight_diag_init "check-policy.sh" "$ROOT" "check-policy"
WORKSPACE_PREFLIGHT_STRICT="${WORKSPACE_PREFLIGHT_STRICT:-0}"

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
)

CLAUDE_FILES=()
while IFS= read -r relative_file; do
  [[ -n "$relative_file" ]] || continue
  CLAUDE_FILES+=("$ROOT/$relative_file")
done < <(
  cd "$ROOT"
  # screenalytics is a retired nested repo and is out of scope for workspace
  # make dev / preflight policy enforcement.
  rg --files -uu \
    -g 'CLAUDE.md' \
    -g '!screenalytics/**' \
    -g '!**/.git/**' \
    -g '!**/.venv/**' \
    -g '!**/node_modules/**' \
    -g '!**/__pycache__/**' \
    -g '!**/.next/**' \
    -g '!**/dist/**' \
    -g '!**/build/**' \
    -g '!**/.turbo/**' \
    -g '!**/.logs/**' \
    | LC_ALL=C sort
)

POLICY_SCAN_FILES=(
  "${AGENTS_FILES[@]}"
  "${CLAUDE_FILES[@]}"
  "$ROOT/.codex/config.toml"
  "$ROOT/.codex/rules/default.rules"
  "$ROOT/docs/workspace/dev-commands.md"
  "$ROOT/docs/workspace/chrome-devtools.md"
  "$ROOT/docs/ai/HANDOFF_WORKFLOW.md"
  "$ROOT/docs/agent-governance/skill_routing.md"
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

check_root_agents() {
  local file="$ROOT/AGENTS.md"
  local word_count

  if [[ ! -f "$file" ]]; then
    echo "[check-policy] ERROR: missing file $file" >&2
    failures=$((failures + 1))
    return
  fi

  if ! rg -q '^## Cross-Repo Implementation Order' "$file"; then
    echo "[check-policy] ERROR: missing cross-repo order section in $file" >&2
    failures=$((failures + 1))
  fi

  if ! rg -q '^## Shared Contracts' "$file"; then
    echo "[check-policy] ERROR: missing shared contracts section in $file" >&2
    failures=$((failures + 1))
  fi

  if ! rg -q 'docs/workspace/dev-commands\.md' "$file"; then
    echo "[check-policy] ERROR: missing dev-commands reference in $file" >&2
    failures=$((failures + 1))
  fi

  if ! rg -q 'docs/workspace/chrome-devtools\.md' "$file"; then
    echo "[check-policy] ERROR: missing chrome-devtools reference in $file" >&2
    failures=$((failures + 1))
  fi

  if ! rg -q 'docs/ai/HANDOFF_WORKFLOW\.md' "$file"; then
    echo "[check-policy] ERROR: missing handoff workflow reference in $file" >&2
    failures=$((failures + 1))
  fi

  if ! rg -q 'docs/agent-governance/skill_routing\.md' "$file"; then
    echo "[check-policy] ERROR: missing skill-routing reference in $file" >&2
    failures=$((failures + 1))
  fi

  if ! rg -q '^## MCP Invocation Matrix' "$file"; then
    echo "[check-policy] ERROR: missing MCP matrix section in $file" >&2
    failures=$((failures + 1))
  fi

  if ! rg -q '^## Trust Boundaries' "$file"; then
    echo "[check-policy] ERROR: missing trust boundaries section in $file" >&2
    failures=$((failures + 1))
  fi

  if ! rg -q 'untrusted input' "$file"; then
    echo "[check-policy] ERROR: missing explicit untrusted-input language in $file" >&2
    failures=$((failures + 1))
  fi

  for server in chrome-devtools github supabase figma; do
    if ! rg -q "\`$server\`" "$file"; then
      echo "[check-policy] ERROR: missing MCP server $server in $file" >&2
      failures=$((failures + 1))
    fi
  done

  word_count="$(wc -w < "$file" | tr -d ' ')"
  if [[ "$word_count" -gt 600 ]]; then
    echo "[check-policy] ERROR: $file exceeds 600 words ($word_count)." >&2
    failures=$((failures + 1))
  fi
}

check_repo_agents() {
  local file="$1"
  local word_count

  if [[ ! -f "$file" ]]; then
    echo "[check-policy] ERROR: missing file $file" >&2
    failures=$((failures + 1))
    return
  fi

  if ! rg -q '^## Scope' "$file"; then
    echo "[check-policy] ERROR: missing scope section in $file" >&2
    failures=$((failures + 1))
  fi

  if ! rg -q '^## Non-Negotiable Rules' "$file"; then
    echo "[check-policy] ERROR: missing non-negotiable rules section in $file" >&2
    failures=$((failures + 1))
  fi

  if ! rg -q '^## Validation' "$file"; then
    echo "[check-policy] ERROR: missing validation section in $file" >&2
    failures=$((failures + 1))
  fi

  if ! rg -q '\.\./AGENTS\.md' "$file"; then
    echo "[check-policy] ERROR: missing workspace-policy escalation rule in $file" >&2
    failures=$((failures + 1))
  fi

  word_count="$(wc -w < "$file" | tr -d ' ')"
  if [[ "$word_count" -gt 300 ]]; then
    echo "[check-policy] ERROR: $file exceeds 300 words ($word_count)." >&2
    failures=$((failures + 1))
  fi
}

check_root_agents
check_repo_agents "$ROOT/TRR-Backend/AGENTS.md"
check_repo_agents "$ROOT/TRR-APP/AGENTS.md"

expected_claude_content() {
  local file="$1"
  local agents_path="$ROOT/AGENTS.md"

  case "$file" in
    "$ROOT/TRR-Backend"/*)
      agents_path="$ROOT/TRR-Backend/AGENTS.md"
      ;;
    "$ROOT/TRR-APP"/*)
      agents_path="$ROOT/TRR-APP/AGENTS.md"
      ;;
  esac

  printf '# CLAUDE.md Pointer\n\nCanonical instructions for this scope are in:\n`%s`\n\nRules:\n1. Read `AGENTS.md` first.\n2. `HANDOFF.md` is generated; update canonical status sources and follow the lifecycle commands in `AGENTS.md`.\n3. If there is any conflict, `AGENTS.md` is authoritative.\n4. This file must remain a short pointer shim.' "$agents_path"
}

for file in "${CLAUDE_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "[check-policy] ERROR: missing file $file" >&2
    failures=$((failures + 1))
    continue
  fi

  line_count="$(wc -l < "$file" | tr -d ' ')"
  if [[ "$line_count" -gt 12 ]]; then
    echo "[check-policy] ERROR: $file exceeds 12 lines ($line_count)." >&2
    failures=$((failures + 1))
  fi

  actual_content="$(<"$file")"
  expected_content="$(expected_claude_content "$file")"
  if [[ "$actual_content" != "$expected_content" ]]; then
    echo "[check-policy] ERROR: $file does not match the canonical pointer-shim template." >&2
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

handoff_check_output=""
set +e
handoff_check_output="$(make -C "$ROOT" --no-print-directory handoff-check 2>&1)"
handoff_check_rc="$?"
set -e
if [[ "$handoff_check_rc" != "0" ]]; then
  if [[ "$WORKSPACE_PREFLIGHT_STRICT" == "1" ]]; then
    printf '%s\n' "$handoff_check_output" >&2
    echo "[check-policy] ERROR: generated handoffs are out of sync or canonical sources are invalid." >&2
    failures=$((failures + 1))
  else
    handoff_warning="$(preflight_handle_handoff_sync_result "$WORKSPACE_PREFLIGHT_STRICT" "$handoff_check_rc" "$handoff_check_output")"
    printf '%s\n' "$handoff_warning" >&2
    echo "[check-policy] WARNING: handoff validation did not block policy checks in non-strict mode." >&2
  fi
fi

if ! bash "$ROOT/scripts/check-codex.sh"; then
  echo "[check-policy] ERROR: Codex config or rules validation failed." >&2
  failures=$((failures + 1))
fi

if [[ "$failures" -gt 0 ]]; then
  echo "[check-policy] FAILED with ${failures} issue(s)." >&2
  exit 1
fi

echo "[check-policy] OK"
