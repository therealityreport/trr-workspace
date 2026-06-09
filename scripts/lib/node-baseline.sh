#!/usr/bin/env bash

trr_node_trim_space() {
  echo "$1" | tr -d '[:space:]'
}

trr_node_required_major() {
  local root="${1:-}"
  local default_major="${TRR_REQUIRED_NODE_MAJOR:-24}"
  local target="${default_major}"

  if [[ -n "$root" && -f "$root/.nvmrc" ]]; then
    local target_from_file
    target_from_file="$(trr_node_trim_space "$(cat "$root/.nvmrc" 2>/dev/null || true)")"
    if [[ -n "$target_from_file" ]]; then
      target="${target_from_file}"
    fi
  fi

  echo "$target"
}

trr_node_version_string() {
  node --version 2>/dev/null || echo "unknown"
}

trr_node_major_version() {
  local raw
  raw="$(trr_node_version_string)"
  echo "${raw}" | sed -E 's/^v([0-9]+).*/\1/'
}

trr_package_manager_spec() {
  local package_root="${1:-}"
  local package_json="${package_root%/}/package.json"

  if [[ -z "$package_root" || ! -f "$package_json" ]]; then
    echo ""
    return 0
  fi

  python3 - "$package_json" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

try:
    data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
except Exception:
    raise SystemExit(0)

value = data.get("packageManager")
if isinstance(value, str):
    print(value.strip())
PY
}

trr_pnpm_version() {
  local package_root="${1:-}"
  local spec

  spec="$(trr_package_manager_spec "$package_root")"
  if [[ "$spec" =~ ^pnpm@(.+)$ ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi

  echo ""
}

trr_pnpm() {
  local package_root="${1:-}"
  shift || true

  if ! trr_ensure_node_baseline "$package_root"; then
    return 1
  fi

  if [[ -z "$(command -v corepack 2>/dev/null || true)" && -z "$(command -v pnpm 2>/dev/null || true)" ]]; then
    trr_try_activate_required_node_with_nvm "$package_root" || true
  fi

  local pnpm_version
  pnpm_version="$(trr_pnpm_version "$package_root")"
  if [[ -n "$pnpm_version" && "$(command -v corepack 2>/dev/null || true)" ]]; then
    corepack "pnpm@${pnpm_version}" "$@"
    return $?
  fi

  if [[ "$(command -v pnpm 2>/dev/null || true)" ]]; then
    pnpm "$@"
    return $?
  fi

  echo "[pnpm] ERROR: pnpm is not available on PATH and corepack is unavailable." >&2
  echo "[pnpm] Remediation: source ~/.nvm/nvm.sh && nvm use $(trr_node_required_major "$package_root")" >&2
  return 127
}

trr_try_activate_required_node_with_nvm() {
  local root="${1:-}"
  local nvm_dir nvm_sh target_alias

  nvm_dir="${NVM_DIR:-$HOME/.nvm}"
  nvm_sh="${nvm_dir}/nvm.sh"
  target_alias="$(trr_node_required_major "$root")"

  if [[ ! -s "$nvm_sh" ]]; then
    return 1
  fi

  # shellcheck disable=SC1090
  source "$nvm_sh"
  if ! command -v nvm >/dev/null 2>&1; then
    return 1
  fi

  nvm use --silent "$target_alias" >/dev/null 2>&1 || return 1
  hash -r
  return 0
}

trr_ensure_node_baseline() {
  local root="${1:-}"
  local required_major current_major

  required_major="$(trr_node_required_major "$root")"
  current_major="$(trr_node_major_version)"

  if [[ -z "$current_major" ]] || ! [[ "$current_major" =~ ^[0-9]+$ ]]; then
    return 2
  fi

  if (( current_major == required_major )); then
    return 0
  fi

  if ! trr_try_activate_required_node_with_nvm "$root"; then
    return 1
  fi

  current_major="$(trr_node_major_version)"
  if [[ -z "$current_major" ]] || ! [[ "$current_major" =~ ^[0-9]+$ ]]; then
    return 2
  fi

  if (( current_major == required_major )); then
    return 0
  fi

  return 1
}

trr_ensure_node_baseline_or_exit() {
  local label="${1:-node}"
  local root="${2:-}"
  local required_major

  required_major="$(trr_node_required_major "$root")"
  if trr_ensure_node_baseline "$root"; then
    return 0
  fi

  echo "[${label}] ERROR: Node $(trr_node_version_string) does not satisfy required ${required_major}.x baseline." >&2
  echo "[${label}] Remediation:" >&2
  echo "[${label}]   source ~/.nvm/nvm.sh && nvm use ${required_major}" >&2
  echo "[${label}]   source ~/.nvm/nvm.sh && nvm install ${required_major}" >&2
  exit 1
}
