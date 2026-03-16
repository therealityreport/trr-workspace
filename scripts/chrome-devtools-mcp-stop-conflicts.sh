#!/usr/bin/env bash
set -euo pipefail

APPLY=0
INCLUDE_CLAUDE=0

usage() {
  cat <<'EOF'
Usage:
  chrome-devtools-mcp-stop-conflicts.sh
  chrome-devtools-mcp-stop-conflicts.sh --apply
  chrome-devtools-mcp-stop-conflicts.sh --apply --include-claude

Description:
  Lists non-Codex browser-control clients that may contend with shared Chrome.
  By default, `--apply` only terminates non-Claude clients such as Playwright.
  Claude browser-control clients remain visible in the report but are preserved
  unless `--include-claude` is passed explicitly.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "${1}" in
    --apply)
      APPLY=1
      ;;
    --include-claude)
      INCLUDE_CLAUDE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[chrome-devtools-mcp] ERROR: unknown argument: ${1}" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

list_conflicts() {
  ps -axo pid,ppid,command | awk -v self="$$" -v parent="$PPID" '
    BEGIN { IGNORECASE = 1 }
    $1 == self || $1 == parent { next }
    /chrome-devtools-mcp-stop-conflicts\.sh|chrome-devtools-mcp-status\.sh/ { next }
    /chrome-control\/server\/index\.js/ { print "external_claude_control\t" $0; next }
    /chrome-native-host/ { print "external_native_host\t" $0; next }
    /@playwright\/mcp|playwright-mcp/ { print "external_playwright\t" $0; next }
  '
}

filter_terminable_conflicts() {
  local include_claude="$1"
  if [[ "$include_claude" == "1" ]]; then
    cat
    return 0
  fi

  awk -F'\t' '$1 != "external_claude_control" && $1 != "external_native_host"'
}

conflicts="$(list_conflicts)"
count="$(printf '%s\n' "$conflicts" | sed '/^$/d' | wc -l | tr -d ' ')"
terminable_conflicts="$(printf '%s\n' "$conflicts" | sed '/^$/d' | filter_terminable_conflicts "$INCLUDE_CLAUDE")"
terminable_count="$(printf '%s\n' "$terminable_conflicts" | sed '/^$/d' | wc -l | tr -d ' ')"

if [[ "$count" == "0" ]]; then
  echo "[chrome-devtools-mcp] No conflicting non-Codex browser-control clients detected."
  exit 0
fi

echo "[chrome-devtools-mcp] Conflicting non-Codex browser-control clients:"
printf '%s\n' "$conflicts" | sed '/^$/d' | while IFS=$'\t' read -r kind line; do
  echo "  - ${kind}: ${line}"
done

if [[ "$APPLY" != "1" ]]; then
  if [[ "$terminable_count" == "0" ]]; then
    echo "[chrome-devtools-mcp] Dry run only. No terminable non-Claude conflicts are present."
  else
    echo "[chrome-devtools-mcp] Dry run only. Re-run with --apply to terminate non-Claude conflicts."
  fi
  echo "[chrome-devtools-mcp] Claude browser-control clients are preserved by default."
  echo "[chrome-devtools-mcp] Re-run with --apply --include-claude only if you explicitly want to terminate Claude browser-control clients too."
  exit 0
fi

if [[ "$terminable_count" == "0" ]]; then
  echo "[chrome-devtools-mcp] No terminable non-Claude conflicts found. Claude browser-control clients were preserved."
  exit 0
fi

printf '%s\n' "$terminable_conflicts" | sed '/^$/d' | while IFS=$'\t' read -r _kind line; do
  pid="$(printf '%s\n' "$line" | awk '{print $1}')"
  if [[ -n "$pid" ]]; then
    kill -TERM "$pid" >/dev/null 2>&1 || true
  fi
done

sleep 1

printf '%s\n' "$terminable_conflicts" | sed '/^$/d' | while IFS=$'\t' read -r _kind line; do
  pid="$(printf '%s\n' "$line" | awk '{print $1}')"
  if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
    kill -KILL "$pid" >/dev/null 2>&1 || true
  fi
done

if [[ "$INCLUDE_CLAUDE" == "1" ]]; then
  echo "[chrome-devtools-mcp] Requested termination of conflicting non-Codex browser-control clients, including Claude clients."
else
  echo "[chrome-devtools-mcp] Requested termination of conflicting non-Claude browser-control clients. Claude clients were preserved."
fi
