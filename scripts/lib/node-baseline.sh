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
