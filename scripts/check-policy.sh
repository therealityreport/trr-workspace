#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY_ROOT="$SCRIPT_ROOT"
CHECK_POLICY_SKIP_EXTERNAL="${CHECK_POLICY_SKIP_EXTERNAL:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      POLICY_ROOT="$(cd "$2" && pwd)"
      shift 2
      ;;
    *)
      echo "[check-policy] ERROR: unknown argument $1" >&2
      exit 2
      ;;
  esac
done

source "$SCRIPT_ROOT/scripts/lib/preflight-diagnostics.sh"
source "$SCRIPT_ROOT/scripts/lib/preflight-handoff.sh"

preflight_diag_init "check-policy.sh" "$SCRIPT_ROOT" "check-policy"
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
  "$POLICY_ROOT/AGENTS.md"
  "$POLICY_ROOT/TRR-Backend/AGENTS.md"
  "$POLICY_ROOT/TRR-APP/AGENTS.md"
)

# Only the three repo entrypoint CLAUDE.md files are policy-managed pointer shims.
# Brain-local CLAUDE.md files remain substantive boot docs and are intentionally excluded.
collect_entrypoint_claude_files() {
  local candidate
  for candidate in \
    "$POLICY_ROOT/CLAUDE.md" \
    "$POLICY_ROOT/TRR-Backend/CLAUDE.md" \
    "$POLICY_ROOT/TRR-APP/CLAUDE.md"
  do
    printf '%s\n' "$candidate"
  done
}

CLAUDE_FILES=()
while IFS= read -r candidate; do
  CLAUDE_FILES+=("$candidate")
done < <(collect_entrypoint_claude_files | LC_ALL=C sort -u)

POLICY_SCAN_FILES=("${AGENTS_FILES[@]}")
for candidate in \
  "$POLICY_ROOT/.codex/config.toml" \
  "$POLICY_ROOT/.codex/rules/default.rules" \
  "$POLICY_ROOT/docs/workspace/dev-commands.md" \
  "$POLICY_ROOT/docs/workspace/chrome-devtools.md" \
  "$POLICY_ROOT/docs/ai/HANDOFF_WORKFLOW.md" \
  "$POLICY_ROOT/docs/agent-governance/skill_routing.md" \
  "$POLICY_ROOT/docs/agent-governance/claude_skill_overlap.md" \
  "$POLICY_ROOT/docs/agent-governance/mcp_inventory.md"
do
  [[ -f "$candidate" ]] && POLICY_SCAN_FILES+=("$candidate")
done
for candidate in "${CLAUDE_FILES[@]}"; do
  [[ -e "$candidate" || -L "$candidate" ]] && POLICY_SCAN_FILES+=("$candidate")
done

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
  local file="$POLICY_ROOT/AGENTS.md"
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
check_repo_agents "$POLICY_ROOT/TRR-Backend/AGENTS.md"
check_repo_agents "$POLICY_ROOT/TRR-APP/AGENTS.md"

expected_claude_target() {
  local file="$1"
  local agents_path="$POLICY_ROOT/AGENTS.md"

  case "$file" in
    "$POLICY_ROOT/TRR-Backend"/*)
      agents_path="$POLICY_ROOT/TRR-Backend/AGENTS.md"
      ;;
    "$POLICY_ROOT/TRR-APP"/*)
      agents_path="$POLICY_ROOT/TRR-APP/AGENTS.md"
      ;;
  esac

  printf '%s\n' "$agents_path"
}

resolve_symlink_target_path() {
  python3 - "$1" <<'PY'
import os
import sys

path = sys.argv[1]
target = os.readlink(path)
print(os.path.abspath(os.path.join(os.path.dirname(path), target)))
PY
}

if [[ "${#CLAUDE_FILES[@]}" -gt 0 ]]; then
  for file in "${CLAUDE_FILES[@]}"; do
    if [[ ! -e "$file" && ! -L "$file" ]]; then
      echo "[check-policy] ERROR: missing file $file" >&2
      failures=$((failures + 1))
      continue
    fi

    if [[ ! -L "$file" ]]; then
      echo "[check-policy] ERROR: $file must be a symlink to its matching AGENTS.md file." >&2
      failures=$((failures + 1))
      continue
    fi

    expected_target="$(expected_claude_target "$file")"
    symlink_target_path="$(resolve_symlink_target_path "$file")"
    if [[ "$symlink_target_path" != "$expected_target" ]]; then
      echo "[check-policy] ERROR: $file must point to $expected_target (got $symlink_target_path)." >&2
      failures=$((failures + 1))
    fi
  done
fi

if rg -n -i 'playwright' "${POLICY_SCAN_FILES[@]}" >/tmp/trr-policy-playwright-hits.txt; then
  if [[ -s /tmp/trr-policy-playwright-hits.txt ]]; then
    echo "[check-policy] ERROR: disallowed 'playwright' references found:" >&2
    cat /tmp/trr-policy-playwright-hits.txt >&2
    failures=$((failures + 1))
  fi
fi
rm -f /tmp/trr-policy-playwright-hits.txt

if [[ "$CHECK_POLICY_SKIP_EXTERNAL" != "1" ]]; then
  handoff_check_output=""
  set +e
  handoff_check_output="$(make -C "$POLICY_ROOT" --no-print-directory handoff-check 2>&1)"
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

  if ! bash "$SCRIPT_ROOT/scripts/check-codex.sh"; then
    echo "[check-policy] ERROR: Codex config or rules validation failed." >&2
    failures=$((failures + 1))
  fi
fi

if [[ "$failures" -gt 0 ]]; then
  echo "[check-policy] FAILED with ${failures} issue(s)." >&2
  exit 1
fi

echo "[check-policy] OK"
