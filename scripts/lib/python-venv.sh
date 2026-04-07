#!/usr/bin/env bash

TRR_REQUIRED_PY_MAJOR="${TRR_REQUIRED_PY_MAJOR:-3}"
TRR_REQUIRED_PY_MINOR="${TRR_REQUIRED_PY_MINOR:-11}"

TRR_PYTHON_BIN="${TRR_PYTHON_BIN:-}"
TRR_LAST_VENV_CREATED=0

trr_python_version_str() {
  local py="$1"
  "$py" -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")' 2>/dev/null || echo "unknown"
}

trr_python_version_ok() {
  local py="$1"
  local major minor
  local out

  out="$("$py" -c 'import sys; print(f"{sys.version_info[0]} {sys.version_info[1]}")' 2>/dev/null || true)"
  major="${out%% *}"
  minor="${out##* }"

  if [[ -z "$major" || -z "$minor" ]]; then
    return 1
  fi

  if ! [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ ]]; then
    return 1
  fi

  if (( major > TRR_REQUIRED_PY_MAJOR )); then
    return 0
  fi
  if (( major == TRR_REQUIRED_PY_MAJOR && minor >= TRR_REQUIRED_PY_MINOR )); then
    return 0
  fi
  return 1
}

trr_resolve_python_bin() {
  if [[ -n "$TRR_PYTHON_BIN" && -x "$TRR_PYTHON_BIN" ]] && trr_python_version_ok "$TRR_PYTHON_BIN"; then
    echo "$TRR_PYTHON_BIN"
    return 0
  fi

  local configured="${PYTHON_BIN:-}"
  local candidate path

  if [[ -n "$configured" ]]; then
    if [[ -x "$configured" ]]; then
      path="$configured"
    elif command -v "$configured" >/dev/null 2>&1; then
      path="$(command -v "$configured")"
    else
      echo "[python-venv] WARNING: PYTHON_BIN is set but not executable/found: ${configured}" >&2
      path=""
    fi

    if [[ -n "$path" ]]; then
      if trr_python_version_ok "$path"; then
        TRR_PYTHON_BIN="$path"
        echo "$TRR_PYTHON_BIN"
        return 0
      fi
      echo "[python-venv] WARNING: skipping ${path} ($(trr_python_version_str "$path")); need >=${TRR_REQUIRED_PY_MAJOR}.${TRR_REQUIRED_PY_MINOR}." >&2
    fi
  fi

  for candidate in python3.11 python3 python; do
    if command -v "$candidate" >/dev/null 2>&1; then
      path="$(command -v "$candidate")"
      if trr_python_version_ok "$path"; then
        TRR_PYTHON_BIN="$path"
        echo "$TRR_PYTHON_BIN"
        return 0
      fi
      echo "[python-venv] WARNING: skipping ${path} ($(trr_python_version_str "$path")); need >=${TRR_REQUIRED_PY_MAJOR}.${TRR_REQUIRED_PY_MINOR}." >&2
    fi
  done

  echo "[python-venv] ERROR: Missing Python interpreter (tried: PYTHON_BIN, python3.11, python3, python)." >&2
  echo "[python-venv] Install Python ${TRR_REQUIRED_PY_MAJOR}.${TRR_REQUIRED_PY_MINOR}+ and ensure it is on PATH." >&2
  return 1
}

trr_venv_path_ok() {
  local repo_dir="$1"
  local expected="${repo_dir}/.venv"
  local activate="${expected}/bin/activate"
  local actual

  if [[ ! -f "$activate" ]]; then
    return 1
  fi

  actual="$(grep '^VIRTUAL_ENV=' "$activate" | head -n 1 | cut -d= -f2-)"
  if [[ -z "$actual" ]]; then
    return 1
  fi

  [[ "$actual" == "$expected" ]]
}

trr_ensure_repo_venv() {
  local repo_dir="$1"
  local venv_py="${repo_dir}/.venv/bin/python"
  local resolved_python

  TRR_LAST_VENV_CREATED=0

  if [[ -x "$venv_py" ]]; then
    if trr_python_version_ok "$venv_py" && trr_venv_path_ok "$repo_dir"; then
      return 0
    fi

    echo "[python-venv] Recreating venv: ${repo_dir}/.venv (found python $(trr_python_version_str "$venv_py"), need >=${TRR_REQUIRED_PY_MAJOR}.${TRR_REQUIRED_PY_MINOR} and correct venv path)" >&2
    rm -rf "${repo_dir}/.venv"
  fi

  resolved_python="$(trr_resolve_python_bin)" || return 1
  echo "[python-venv] Creating venv: ${repo_dir}/.venv (${resolved_python})" >&2
  "$resolved_python" -m venv "${repo_dir}/.venv"
  TRR_LAST_VENV_CREATED=1
}

trr_install_repo_requirements() {
  local repo_dir="$1"
  local requirements_file="$2"
  local venv_py="${repo_dir}/.venv/bin/python"

  if [[ ! -x "$venv_py" ]]; then
    echo "[python-venv] ERROR: ${repo_dir}/.venv/bin/python missing after ensure step." >&2
    return 1
  fi

  echo "[python-venv] Installing requirements from ${requirements_file}" >&2
  "$venv_py" -m pip install --upgrade pip
  "$venv_py" -m pip install -r "$requirements_file"
}

trr_ensure_repo_runtime() {
  local repo_dir="$1"
  local requirements_file="$2"

  trr_ensure_repo_venv "$repo_dir" || return 1
  if [[ "$TRR_LAST_VENV_CREATED" == "1" ]]; then
    trr_install_repo_requirements "$repo_dir" "$requirements_file" || return 1
  fi
}
