#!/usr/bin/env bash

context7_plugin_root() {
  echo "${CONTEXT7_PLUGIN_ROOT:-$HOME/.codex/plugins/context7}"
}

context7_cache_root() {
  echo "${CONTEXT7_CACHE_ROOT:-$HOME/.codex/plugins/cache/local-plugins/context7}"
}

context7_cache_version() {
  echo "${CONTEXT7_CACHE_VERSION:-0.1.2}"
}

context7_repair_script() {
  echo "$(context7_plugin_root)/scripts/repair-context7-mcp.mjs"
}

context7_config_status() {
  local repair_script check_output check_rc had_errexit=0
  repair_script="$(context7_repair_script)"
  if [[ ! -x "$repair_script" ]]; then
    echo "missing_repair_script"
    return 0
  fi

  case "$-" in
    *e*) had_errexit=1 ;;
  esac
  set +e
  check_output="$(node "$repair_script" --check 2>/dev/null)"
  check_rc="$?"
  if [[ "$had_errexit" == "1" ]]; then
    set -e
  else
    set +e
  fi
  if [[ "$check_rc" == "0" ]]; then
    echo "wrapper_config_ok"
    return 0
  fi

  if printf '%s' "$check_output" | "${MCP_RUNTIME_PYTHON_BIN:-python3}" -c '
import json
import sys

try:
    payload = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)

config_results = payload.get("results") or []
if config_results and all(item.get("status") == "ok" for item in config_results if isinstance(item, dict)):
    raise SystemExit(0)
raise SystemExit(1)
' >/dev/null 2>&1; then
    echo "wrapper_config_ok"
    return 0
  fi

  echo "needs_repair"
}

context7_status_label() {
  local status="$1"
  case "$status" in
    wrapper_config_ok) echo "wrapper config OK" ;;
    missing_repair_script) echo "repair script missing" ;;
    needs_repair) echo "needs repair (run: make context7-repair)" ;;
    *) echo "$status" ;;
  esac
}

context7_cache_plugin_root() {
  echo "$(context7_cache_root)/$(context7_cache_version)"
}

context7_cache_parity_status() {
  local plugin_root cache_plugin_root
  plugin_root="$(context7_plugin_root)"
  cache_plugin_root="$(context7_cache_plugin_root)"
  if [[ ! -d "$cache_plugin_root" ]]; then
    echo "missing_cache_copy"
    return 0
  fi
  if diff -qr "$plugin_root" "$cache_plugin_root" -x .DS_Store -x node_modules >/dev/null 2>&1; then
    echo "ok"
    return 0
  fi
  echo "differs"
}

context7_stale_cache_copies() {
  local cache_root cache_version
  cache_root="$(context7_cache_root)"
  cache_version="$(context7_cache_version)"
  if [[ ! -d "$cache_root" ]]; then
    return 0
  fi
  find "$cache_root" -mindepth 1 -maxdepth 1 -type d ! -name "$cache_version" -print 2>/dev/null | sort
}

context7_stale_cache_count() {
  context7_stale_cache_copies | sed '/^$/d' | wc -l | tr -d ' '
}
