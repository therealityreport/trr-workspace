#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
CONFIG_FILE="${CODEX_CONFIG_FILE:-${CODEX_HOME_DIR}/config.toml}"
TEMPLATE_PATH="${ROOT}/config/codex/shared.toml.tmpl"

resolve_python_311_bin() {
  local configured="${PYTHON_BIN:-}"
  local candidate path

  for candidate in "$configured" python3.11 python3 python; do
    [[ -n "$candidate" ]] || continue
    if [[ -x "$candidate" ]]; then
      path="$candidate"
    elif command -v "$candidate" >/dev/null 2>&1; then
      path="$(command -v "$candidate")"
    else
      continue
    fi

    if "$path" - <<'PY' >/dev/null 2>&1
import sys
raise SystemExit(0 if sys.version_info >= (3, 11) else 1)
PY
    then
      echo "$path"
      return 0
    fi
  done

  echo "[codex-config-sync] ERROR: Python 3.11+ is required (tried: PYTHON_BIN, python3.11, python3, python)." >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage:
  scripts/codex-config-sync.sh install
  scripts/codex-config-sync.sh validate

Description:
  Installs or validates the canonical repo-managed Codex config template for
  the TRR workspace.
USAGE
}

backup_existing_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    return 0
  fi

  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  local backup="${CONFIG_FILE}.bak.repo-template-${timestamp}"
  cp "$CONFIG_FILE" "$backup"
  echo "[codex-config-sync] Backup: ${backup}"
}

render_template_to() {
  local destination="$1"
  sed "s|__TRR_ROOT__|${ROOT}|g" "$TEMPLATE_PATH" >"$destination"
}

validate_config() {
  local expected_wrapper="${ROOT}/scripts/codex-chrome-devtools-mcp.sh"
  local python_bin
  python_bin="$(resolve_python_311_bin)"

  "$python_bin" - "$CONFIG_FILE" "$expected_wrapper" <<'PY'
import pathlib
import sys
import tomllib

config_path = pathlib.Path(sys.argv[1])
expected_wrapper = sys.argv[2]

if not config_path.exists():
    raise SystemExit(f"[codex-config-sync] ERROR: config file not found: {config_path}")

with config_path.open("rb") as handle:
    data = tomllib.load(handle)

required_servers = {
    "figma": {"url": "https://mcp.figma.com/mcp"},
    "figma-desktop": {"url": "http://127.0.0.1:3845/mcp", "enabled": False},
    "chrome-devtools": {
        "command": expected_wrapper,
        "enabled": True,
        "startup_timeout_sec": 45,
        "tool_timeout_sec": 120,
        "env": {"CODEX_CHROME_MODE": "isolated", "CODEX_CHROME_ISOLATED_HEADLESS": "1"},
    },
    "playwright": {"command": "npx", "enabled": False},
    "github": {"url": "https://api.githubcopilot.com/mcp", "bearer_token_env_var": "GITHUB_PAT"},
    "supabase": {
        "url": "https://mcp.supabase.com/mcp?project_ref=vwxfvzutyufrkhfgoeaa&features=docs%2Caccount%2Cdatabase%2Cdebugging%2Cdevelopment%2Cfunctions%2Cbranching%2Cstorage",
        "bearer_token_env_var": "SUPABASE_ACCESS_TOKEN",
    },
}

errors = []
servers = data.get("mcp_servers") or {}

for name, expectations in required_servers.items():
    server = servers.get(name)
    if not isinstance(server, dict):
        errors.append(f"missing [mcp_servers.{name}]")
        continue
    for key, value in expectations.items():
        actual = server.get(key)
        if key == "env":
            actual = actual or {}
        if actual != value:
            errors.append(f"[mcp_servers.{name}] expected {key}={value!r}, found {actual!r}")

legacy_prefix = "".join(["a", "w", "s", "labs-"])
legacy_knowledge = "".join(["a", "w", "s", "knowledge"])
legacy_iac = "".join(["a", "w", "s", "iac"])
unexpected = sorted(name for name in servers if name.startswith(legacy_prefix) or name in {legacy_knowledge, legacy_iac})
for name in unexpected:
    errors.append(f"[mcp_servers.{name}] is no longer allowed in the repo-managed template")

if errors:
    for message in errors:
        print(f"[codex-config-sync] ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)

print(f"[codex-config-sync] Validation OK: {config_path}")
PY
}

install_template() {
  if [[ ! -f "$TEMPLATE_PATH" ]]; then
    echo "[codex-config-sync] ERROR: template not found: ${TEMPLATE_PATH}" >&2
    exit 1
  fi

  mkdir -p "$CODEX_HOME_DIR"
  backup_existing_config

  local rendered
  rendered="$(mktemp "${CONFIG_FILE}.tmp.XXXXXX")"
  render_template_to "$rendered"
  mv "$rendered" "$CONFIG_FILE"
  echo "[codex-config-sync] Installed canonical template -> ${CONFIG_FILE}"
  validate_config
}

case "${1:-}" in
  install)
    install_template
    ;;
  validate)
    validate_config
    ;;
  *)
    usage
    exit 1
    ;;
esac
