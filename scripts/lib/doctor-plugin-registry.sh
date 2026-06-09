#!/usr/bin/env bash

WORKSPACE_DOCTOR_PLUGIN_REPAIR="${WORKSPACE_DOCTOR_PLUGIN_REPAIR:-0}"
DOCTOR_PLUGIN_REPAIR_REGISTRY=(
  context7
  browser
  supabase
  modal
  scrapling
  vercel
  decodo
)
DOCTOR_PLUGIN_STATUS=""
DOCTOR_PLUGIN_LABEL=""
DOCTOR_PLUGIN_NEEDS_REPAIR=0
DOCTOR_PLUGIN_REQUIRED=0
DOCTOR_PLUGIN_SKIPPED=0
DOCTOR_PLUGIN_REPAIR_HINT=""
DOCTOR_PLUGIN_REPAIRABLE=0
DOCTOR_PLUGIN_REPAIR_ATTEMPTED=0
DOCTOR_PLUGIN_REPAIRED=0
DOCTOR_PLUGIN_REPAIR_FAILED=0
DOCTOR_PLUGIN_LIVE_MCP_NAME=""
DOCTOR_PLUGIN_LIVE_MCP_STATUS="not_checked"
DOCTOR_PLUGIN_LIVE_MCP_LABEL=""
DOCTOR_PLUGIN_LIVE_MCP_STATE="not_loaded"
DOCTOR_PLUGIN_LIVE_MCP_ROWS=""

doctor_plugin_reset_state() {
  DOCTOR_PLUGIN_STATUS=""
  DOCTOR_PLUGIN_LABEL=""
  DOCTOR_PLUGIN_NEEDS_REPAIR=0
  DOCTOR_PLUGIN_REQUIRED=0
  DOCTOR_PLUGIN_SKIPPED=0
  DOCTOR_PLUGIN_REPAIR_HINT=""
  DOCTOR_PLUGIN_REPAIRABLE=0
  DOCTOR_PLUGIN_REPAIR_ATTEMPTED=0
  DOCTOR_PLUGIN_REPAIRED=0
  DOCTOR_PLUGIN_REPAIR_FAILED=0
  DOCTOR_PLUGIN_LIVE_MCP_NAME=""
  DOCTOR_PLUGIN_LIVE_MCP_STATUS="not_checked"
  DOCTOR_PLUGIN_LIVE_MCP_LABEL=""
}

doctor_plugin_python() {
  "${MCP_RUNTIME_PYTHON_BIN:-python3}" "$@"
}

doctor_plugin_append_label() {
  local detail="$1"
  if [[ -z "$detail" ]]; then
    return 0
  fi
  if [[ -z "$DOCTOR_PLUGIN_LABEL" ]]; then
    DOCTOR_PLUGIN_LABEL="$detail"
  else
    DOCTOR_PLUGIN_LABEL="${DOCTOR_PLUGIN_LABEL}; ${detail}"
  fi
}

doctor_plugin_live_mcp_expected_name() {
  case "$1" in
    context7) echo "context7" ;;
    browser) echo "chrome-devtools" ;;
    supabase) echo "supabase" ;;
    modal) echo "modal-ops" ;;
    scrapling) echo "ScraplingServer" ;;
    decodo) echo "decodo" ;;
    *) echo "" ;;
  esac
}

doctor_plugin_load_live_mcp_rows() {
  local payload rc

  if [[ "$DOCTOR_PLUGIN_LIVE_MCP_STATE" != "not_loaded" ]]; then
    return 0
  fi

  if ! command -v codex >/dev/null 2>&1; then
    DOCTOR_PLUGIN_LIVE_MCP_STATE="unavailable"
    DOCTOR_PLUGIN_LIVE_MCP_ROWS=""
    return 0
  fi

  set +e
  payload="$(cd "$ROOT" && codex mcp list --json 2>/dev/null)"
  rc="$?"
  set -e
  if [[ "$rc" != "0" || -z "$payload" ]]; then
    DOCTOR_PLUGIN_LIVE_MCP_STATE="unavailable"
    DOCTOR_PLUGIN_LIVE_MCP_ROWS=""
    return 0
  fi

  DOCTOR_PLUGIN_LIVE_MCP_ROWS="$(doctor_plugin_python - "$payload" <<'PY'
import json
import sys

try:
    data = json.loads(sys.argv[1])
except Exception:
    raise SystemExit(1)

if not isinstance(data, list):
    raise SystemExit(1)

for entry in data:
    if not isinstance(entry, dict):
        continue
    name = entry.get("name")
    if not isinstance(name, str) or not name:
        continue
    enabled = entry.get("enabled")
    print(f"{name}\t{str(enabled is True).lower()}")
PY
)" || true

  if [[ -z "$DOCTOR_PLUGIN_LIVE_MCP_ROWS" ]]; then
    DOCTOR_PLUGIN_LIVE_MCP_STATE="unavailable"
    return 0
  fi
  DOCTOR_PLUGIN_LIVE_MCP_STATE="loaded"
}

doctor_plugin_apply_live_mcp_validation() {
  local plugin="$1"
  local expected_name
  local line enabled

  expected_name="$(doctor_plugin_live_mcp_expected_name "$plugin")"
  DOCTOR_PLUGIN_LIVE_MCP_NAME="$expected_name"

  if [[ -z "$expected_name" ]]; then
    DOCTOR_PLUGIN_LIVE_MCP_STATUS="not_applicable"
    DOCTOR_PLUGIN_LIVE_MCP_LABEL="live_mcp=not_applicable"
    doctor_plugin_append_label "$DOCTOR_PLUGIN_LIVE_MCP_LABEL"
    return 0
  fi

  doctor_plugin_load_live_mcp_rows
  if [[ "$DOCTOR_PLUGIN_LIVE_MCP_STATE" != "loaded" ]]; then
    DOCTOR_PLUGIN_LIVE_MCP_STATUS="unavailable"
    DOCTOR_PLUGIN_LIVE_MCP_LABEL="live_mcp=unavailable"
    doctor_plugin_append_label "$DOCTOR_PLUGIN_LIVE_MCP_LABEL"
    return 0
  fi

  line="$(printf '%s\n' "$DOCTOR_PLUGIN_LIVE_MCP_ROWS" | awk -F '\t' -v name="$expected_name" '$1 == name {print; exit}')"
  if [[ -z "$line" ]]; then
    DOCTOR_PLUGIN_LIVE_MCP_STATUS="missing"
    DOCTOR_PLUGIN_LIVE_MCP_LABEL="live_mcp=${expected_name}:missing"
    DOCTOR_PLUGIN_NEEDS_REPAIR=1
    if [[ -z "$DOCTOR_PLUGIN_REPAIR_HINT" ]]; then
      DOCTOR_PLUGIN_REPAIR_HINT="bash scripts/codex-config-sync.sh bootstrap"
    fi
    doctor_plugin_append_label "$DOCTOR_PLUGIN_LIVE_MCP_LABEL"
    return 0
  fi

  enabled="${line#*$'\t'}"
  if [[ "$enabled" != "true" ]]; then
    DOCTOR_PLUGIN_LIVE_MCP_STATUS="disabled"
    DOCTOR_PLUGIN_LIVE_MCP_LABEL="live_mcp=${expected_name}:disabled"
    DOCTOR_PLUGIN_NEEDS_REPAIR=1
    if [[ -z "$DOCTOR_PLUGIN_REPAIR_HINT" ]]; then
      DOCTOR_PLUGIN_REPAIR_HINT="enable ${expected_name} in Codex MCP config"
    fi
    doctor_plugin_append_label "$DOCTOR_PLUGIN_LIVE_MCP_LABEL"
    return 0
  fi

  DOCTOR_PLUGIN_LIVE_MCP_STATUS="present"
  DOCTOR_PLUGIN_LIVE_MCP_LABEL="live_mcp=${expected_name}:present"
  doctor_plugin_append_label "$DOCTOR_PLUGIN_LIVE_MCP_LABEL"
}

doctor_plugin_enabled_status() {
  local plugin_key="$1"
  local manifest_glob="$2"
  local config_file="${CODEX_CONFIG_FILE:-$HOME/.codex/config.toml}"

  doctor_plugin_python - "$config_file" "$plugin_key" "$manifest_glob" <<'PY'
import glob
import pathlib
import sys
import tomllib

config_path = pathlib.Path(sys.argv[1])
plugin_key = sys.argv[2]
manifest_glob = sys.argv[3]

if not config_path.exists():
    print("missing user config")
    raise SystemExit(1)

with config_path.open("rb") as handle:
    data = tomllib.load(handle)

plugins = data.get("plugins") or {}
entry = plugins.get(plugin_key)
if not isinstance(entry, dict):
    print(f"missing [plugins.{plugin_key!r}]")
    raise SystemExit(1)
if entry.get("enabled") is not True:
    print(f"{plugin_key} disabled")
    raise SystemExit(1)

manifests = sorted(glob.glob(manifest_glob))
if not manifests:
    print(f"{plugin_key} enabled; manifest missing")
    raise SystemExit(1)

print(f"enabled; manifest={manifests[-1]}")
PY
}

doctor_plugin_project_mcp_status() {
  local server="$1"
  local config_file="${ROOT}/.codex/config.toml"

  doctor_plugin_python - "$config_file" "$server" "$ROOT" <<'PY'
import pathlib
import sys
import tomllib

config_path = pathlib.Path(sys.argv[1])
server_name = sys.argv[2]
root = pathlib.Path(sys.argv[3])

if not config_path.exists():
    print("missing project config")
    raise SystemExit(1)

with config_path.open("rb") as handle:
    data = tomllib.load(handle)

servers = data.get("mcp_servers") or {}
server = servers.get(server_name)
if not isinstance(server, dict):
    print(f"missing [mcp_servers.{server_name}]")
    raise SystemExit(1)

if server_name == "supabase":
    url = server.get("url")
    token_env = server.get("bearer_token_env_var")
    if not isinstance(url, str) or "project_ref=vwxfvzutyufrkhfgoeaa" not in url:
        print("supabase MCP URL missing TRR project_ref")
        raise SystemExit(1)
    if token_env != "TRR_SUPABASE_ACCESS_TOKEN":
        print(f"supabase MCP token env mismatch: {token_env!r}")
        raise SystemExit(1)
    print("project_ref=vwxfvzutyufrkhfgoeaa; token_env=TRR_SUPABASE_ACCESS_TOKEN")
    raise SystemExit(0)

if server_name == "modal-ops":
    expected_command = str(root / "TRR-Backend/.venv/bin/python")
    expected_args = [str(root / "TRR-Backend/scripts/modal/modal_ops_mcp.py")]
    expected_env = {
        "MODAL_PROFILE": "admin-56995",
        "MODAL_PROFILE_NAME": "admin-56995",
        "MODAL_PROFILE_LABEL": "TRR Backend Jobs",
        "TRR_MODAL_APP_NAME": "trr-backend-jobs",
    }
    if server.get("command") != expected_command:
        print(f"modal command mismatch: {server.get('command')!r}")
        raise SystemExit(1)
    if server.get("args") != expected_args:
        print(f"modal args mismatch: {server.get('args')!r}")
        raise SystemExit(1)
    env = server.get("env") or {}
    for key, value in expected_env.items():
        if env.get(key) != value:
            print(f"modal env {key} mismatch: {env.get(key)!r}")
            raise SystemExit(1)
    if not pathlib.Path(expected_command).exists():
        print(f"modal python missing: {expected_command}")
        raise SystemExit(1)
    if not pathlib.Path(expected_args[0]).exists():
        print(f"modal MCP script missing: {expected_args[0]}")
        raise SystemExit(1)
    print("profile=admin-56995; app=trr-backend-jobs")
    raise SystemExit(0)

print(f"unknown project MCP server: {server_name}")
raise SystemExit(1)
PY
}

doctor_plugin_repair_project_mcp_config() {
  local server="$1"
  local config_file="${ROOT}/.codex/config.toml"

  doctor_plugin_python - "$config_file" "$server" "$ROOT" <<'PY'
import pathlib
import re
import sys

config_path = pathlib.Path(sys.argv[1])
server_name = sys.argv[2]
root = pathlib.Path(sys.argv[3])

if server_name == "supabase":
    block = """[mcp_servers.supabase]
url = "https://mcp.supabase.com/mcp?project_ref=vwxfvzutyufrkhfgoeaa&features=docs%2Caccount%2Cdatabase%2Cdebugging%2Cdevelopment%2Cfunctions%2Cbranching%2Cstorage"
bearer_token_env_var = "TRR_SUPABASE_ACCESS_TOKEN"

"""
elif server_name == "modal-ops":
    command = root / "TRR-Backend/.venv/bin/python"
    script = root / "TRR-Backend/scripts/modal/modal_ops_mcp.py"
    block = f"""[mcp_servers.modal-ops]
command = "{command}"
args = ["{script}"]
env = {{ MODAL_PROFILE = "admin-56995", MODAL_PROFILE_NAME = "admin-56995", MODAL_PROFILE_LABEL = "TRR Backend Jobs", TRR_MODAL_APP_NAME = "trr-backend-jobs" }}

"""
else:
    raise SystemExit(f"unsupported project MCP repair target: {server_name}")

text = config_path.read_text(encoding="utf-8") if config_path.exists() else ""
pattern = re.compile(rf"(?ms)^\[mcp_servers\.{re.escape(server_name)}\]\n.*?(?=^\[|\Z)")
if pattern.search(text):
    text = pattern.sub(block, text)
else:
    if text and not text.endswith("\n"):
        text += "\n"
    if text and not text.endswith("\n\n"):
        text += "\n"
    text += block

config_path.parent.mkdir(parents=True, exist_ok=True)
config_path.write_text(text, encoding="utf-8")
PY
}

doctor_plugin_context7_check() {
  local status
  status="$(context7_config_status)"
  DOCTOR_PLUGIN_STATUS="$status"
  DOCTOR_PLUGIN_LABEL="$(context7_status_label "$status")"
  DOCTOR_PLUGIN_REQUIRED=1
  if [[ "$status" != "wrapper_config_ok" ]]; then
    DOCTOR_PLUGIN_NEEDS_REPAIR=1
    DOCTOR_PLUGIN_REPAIR_HINT="make context7-repair"
  fi
}

doctor_plugin_context7_repair() {
  node "$(context7_repair_script)" --repair --reload >/dev/null
}

doctor_plugin_browser_check() {
  local status_output status_rc decision action reason
  if [[ ! -x "$ROOT/scripts/chrome-devtools-mcp-status.sh" ]]; then
    DOCTOR_PLUGIN_SKIPPED=1
    DOCTOR_PLUGIN_LABEL="status script missing"
    return 0
  fi

  set +e
  status_output="$(env CHROME_DEVTOOLS_MCP_STATUS_MODE=structured bash "$ROOT/scripts/chrome-devtools-mcp-status.sh" 2>/dev/null)"
  status_rc="$?"
  set -e
  if [[ "$status_rc" != "0" ]]; then
    DOCTOR_PLUGIN_SKIPPED=1
    DOCTOR_PLUGIN_LABEL="status check failed"
    return 0
  fi

  decision="$(chrome_devtools_transport_repair_classify "$status_output")"
  action="$(chrome_devtools_status_value "$decision" "repair_action")"
  reason="$(chrome_devtools_status_value "$decision" "repair_reason")"
  DOCTOR_PLUGIN_STATUS="$action"
  DOCTOR_PLUGIN_LABEL="$reason"
  DOCTOR_PLUGIN_REPAIR_HINT="make mcp-clean"
  if [[ "$action" == "repair" ]]; then
    DOCTOR_PLUGIN_NEEDS_REPAIR=1
  fi
}

doctor_plugin_browser_repair() {
  bash "$ROOT/scripts/chrome-devtools-mcp-clean-stale.sh" >/dev/null
}

doctor_plugin_supabase_check() {
  local label
  DOCTOR_PLUGIN_REQUIRED=1
  if label="$(doctor_plugin_project_mcp_status supabase)"; then
    DOCTOR_PLUGIN_LABEL="$label"
  else
    DOCTOR_PLUGIN_LABEL="$label"
    DOCTOR_PLUGIN_NEEDS_REPAIR=1
    DOCTOR_PLUGIN_REPAIR_HINT="WORKSPACE_DOCTOR_PLUGIN_REPAIR=1 bash scripts/doctor.sh"
  fi
}

doctor_plugin_supabase_repair() {
  doctor_plugin_repair_project_mcp_config supabase
}

doctor_plugin_modal_check() {
  local label
  DOCTOR_PLUGIN_REQUIRED=1
  if label="$(doctor_plugin_project_mcp_status modal-ops)"; then
    DOCTOR_PLUGIN_LABEL="$label"
  else
    DOCTOR_PLUGIN_LABEL="$label"
    DOCTOR_PLUGIN_NEEDS_REPAIR=1
    DOCTOR_PLUGIN_REPAIR_HINT="WORKSPACE_DOCTOR_PLUGIN_REPAIR=1 bash scripts/doctor.sh"
  fi
}

doctor_plugin_modal_repair() {
  doctor_plugin_repair_project_mcp_config modal-ops
}

doctor_plugin_scrapling_check() {
  local label
  if label="$(doctor_plugin_enabled_status "scrapling@local-plugins" "$HOME/.codex/plugins/cache/local-plugins/scrapling/*/.codex-plugin/plugin.json")"; then
    DOCTOR_PLUGIN_LABEL="$label"
  else
    DOCTOR_PLUGIN_LABEL="$label"
    DOCTOR_PLUGIN_NEEDS_REPAIR=1
    DOCTOR_PLUGIN_REPAIR_HINT="enable scrapling@local-plugins in ~/.codex/config.toml"
  fi
}

doctor_plugin_vercel_check() {
  local label
  if label="$(doctor_plugin_enabled_status "vercel@openai-curated" "$HOME/.codex/plugins/cache/openai-curated/vercel/*/.codex-plugin/plugin.json")"; then
    DOCTOR_PLUGIN_LABEL="$label"
  else
    DOCTOR_PLUGIN_LABEL="$label"
    DOCTOR_PLUGIN_NEEDS_REPAIR=1
    DOCTOR_PLUGIN_REPAIR_HINT="enable vercel@openai-curated in ~/.codex/config.toml"
  fi
}

doctor_plugin_decodo_check() {
  local label
  if label="$(doctor_plugin_enabled_status "decodo@local-plugins" "$HOME/.codex/plugins/cache/local-plugins/decodo/*/.codex-plugin/plugin.json")"; then
    DOCTOR_PLUGIN_LABEL="$label"
  else
    DOCTOR_PLUGIN_LABEL="$label"
    DOCTOR_PLUGIN_NEEDS_REPAIR=1
    DOCTOR_PLUGIN_REPAIR_HINT="enable decodo@local-plugins in ~/.codex/config.toml"
  fi
}

doctor_plugin_health() {
  if [[ "$DOCTOR_PLUGIN_SKIPPED" == "1" ]]; then
    echo "skipped"
  elif [[ "$DOCTOR_PLUGIN_NEEDS_REPAIR" == "1" ]]; then
    echo "needs_repair"
  else
    echo "ok"
  fi
}

doctor_plugin_tsv_value() {
  printf '%s' "${1:-}" | tr '\t\r\n' '   '
}

doctor_plugin_evaluate_entry() {
  local plugin="$1"
  local repair_enabled="${2:-0}"
  local check_func="doctor_plugin_${plugin}_check"
  local repair_func="doctor_plugin_${plugin}_repair"

  doctor_plugin_reset_state

  if ! declare -F "$check_func" >/dev/null 2>&1; then
    DOCTOR_PLUGIN_SKIPPED=1
    DOCTOR_PLUGIN_LABEL="registry entry has no check function"
    return 0
  fi

  "$check_func"
  if declare -F "$repair_func" >/dev/null 2>&1; then
    DOCTOR_PLUGIN_REPAIRABLE=1
  fi

  doctor_plugin_apply_live_mcp_validation "$plugin"

  if [[ "$DOCTOR_PLUGIN_NEEDS_REPAIR" == "1" && "$repair_enabled" == "1" && "$DOCTOR_PLUGIN_REPAIRABLE" == "1" ]]; then
    DOCTOR_PLUGIN_REPAIR_ATTEMPTED=1
    "$repair_func"
    DOCTOR_PLUGIN_LIVE_MCP_STATE="not_loaded"
    DOCTOR_PLUGIN_LIVE_MCP_ROWS=""
    doctor_plugin_reset_state
    "$check_func"
    DOCTOR_PLUGIN_REPAIRABLE=1
    doctor_plugin_apply_live_mcp_validation "$plugin"
    if [[ "$DOCTOR_PLUGIN_NEEDS_REPAIR" == "1" || "$DOCTOR_PLUGIN_SKIPPED" == "1" ]]; then
      DOCTOR_PLUGIN_REPAIR_FAILED=1
    else
      DOCTOR_PLUGIN_REPAIRED=1
    fi
  fi
}

doctor_run_plugin_repair_entry() {
  local plugin="$1"

  doctor_plugin_evaluate_entry "$plugin" "$WORKSPACE_DOCTOR_PLUGIN_REPAIR"

  if [[ "$DOCTOR_PLUGIN_SKIPPED" == "1" ]]; then
    echo "  ${plugin}: skipped (${DOCTOR_PLUGIN_LABEL})"
    return 0
  fi

  if [[ "$DOCTOR_PLUGIN_REPAIRED" == "1" ]]; then
    echo "  ${plugin}: OK after repair (${DOCTOR_PLUGIN_LABEL})"
    return 0
  fi

  if [[ "$DOCTOR_PLUGIN_NEEDS_REPAIR" != "1" ]]; then
    echo "  ${plugin}: OK (${DOCTOR_PLUGIN_LABEL})"
    return 0
  fi

  if [[ "$DOCTOR_PLUGIN_REPAIR_FAILED" == "1" ]]; then
    echo "[doctor] ERROR: ${plugin} repair did not restore plugin health: ${DOCTOR_PLUGIN_LABEL}" >&2
    if [[ "$DOCTOR_PLUGIN_REQUIRED" == "1" ]]; then
      exit 1
    fi
    return 0
  fi

  if [[ "$DOCTOR_PLUGIN_REQUIRED" == "1" ]]; then
    echo "[doctor] ERROR: ${plugin} needs repair: ${DOCTOR_PLUGIN_LABEL}" >&2
    echo "[doctor] Run: ${DOCTOR_PLUGIN_REPAIR_HINT:-repair command unavailable}, or rerun doctor with WORKSPACE_DOCTOR_PLUGIN_REPAIR=1 for opt-in self-heal." >&2
    exit 1
  fi

  echo "  ${plugin}: needs repair (${DOCTOR_PLUGIN_LABEL}; run ${DOCTOR_PLUGIN_REPAIR_HINT:-repair command unavailable} or set WORKSPACE_DOCTOR_PLUGIN_REPAIR=1)"
}

doctor_plugin_registry_run() {
  local doctor_plugin
  for doctor_plugin in "${DOCTOR_PLUGIN_REPAIR_REGISTRY[@]}"; do
    doctor_run_plugin_repair_entry "$doctor_plugin"
  done
}

doctor_plugin_registry_rows() {
  local repair_enabled="${1:-0}"
  local doctor_plugin health

  for doctor_plugin in "${DOCTOR_PLUGIN_REPAIR_REGISTRY[@]}"; do
    doctor_plugin_evaluate_entry "$doctor_plugin" "$repair_enabled"
    health="$(doctor_plugin_health)"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$(doctor_plugin_tsv_value "$doctor_plugin")" \
      "$(doctor_plugin_tsv_value "$health")" \
      "$(doctor_plugin_tsv_value "$DOCTOR_PLUGIN_LABEL")" \
      "$(doctor_plugin_tsv_value "$DOCTOR_PLUGIN_REQUIRED")" \
      "$(doctor_plugin_tsv_value "$DOCTOR_PLUGIN_SKIPPED")" \
      "$(doctor_plugin_tsv_value "$DOCTOR_PLUGIN_NEEDS_REPAIR")" \
      "$(doctor_plugin_tsv_value "$DOCTOR_PLUGIN_REPAIRABLE")" \
      "$(doctor_plugin_tsv_value "$repair_enabled")" \
      "$(doctor_plugin_tsv_value "$DOCTOR_PLUGIN_REPAIR_ATTEMPTED")" \
      "$(doctor_plugin_tsv_value "$DOCTOR_PLUGIN_REPAIRED")" \
      "$(doctor_plugin_tsv_value "$DOCTOR_PLUGIN_REPAIR_FAILED")" \
      "$(doctor_plugin_tsv_value "$DOCTOR_PLUGIN_REPAIR_HINT")" \
      "$(doctor_plugin_tsv_value "$DOCTOR_PLUGIN_LIVE_MCP_NAME")" \
      "$(doctor_plugin_tsv_value "$DOCTOR_PLUGIN_LIVE_MCP_STATUS")" \
      "$(doctor_plugin_tsv_value "$DOCTOR_PLUGIN_LIVE_MCP_LABEL")"
  done
}

doctor_plugin_registry_json() {
  local repair_enabled="${1:-0}"
  local registry_rows

  registry_rows="$(doctor_plugin_registry_rows "$repair_enabled")"
  DOCTOR_PLUGIN_REGISTRY_ROWS="$registry_rows" doctor_plugin_python - "$repair_enabled" <<'PY'
import json
import os
import sys

repair_enabled = sys.argv[1] == "1"
fields = [
    "name",
    "status",
    "label",
    "required",
    "skipped",
    "needs_repair",
    "repairable",
    "repair_enabled",
    "repair_attempted",
    "repaired",
    "repair_failed",
    "repair_hint",
    "live_mcp_name",
    "live_mcp_status",
    "live_mcp_label",
]
bool_fields = {
    "required",
    "skipped",
    "needs_repair",
    "repairable",
    "repair_enabled",
    "repair_attempted",
    "repaired",
    "repair_failed",
}

results = []
for line in os.environ.get("DOCTOR_PLUGIN_REGISTRY_ROWS", "").splitlines():
    line = line.rstrip("\n")
    if not line:
        continue
    parts = line.split("\t")
    parts += [""] * (len(fields) - len(parts))
    row = dict(zip(fields, parts))
    for key in bool_fields:
        row[key] = row[key] == "1"
    results.append(row)

overall = "ok"
if any(item["repair_failed"] for item in results):
    overall = "repair_failed"
elif any(item["needs_repair"] for item in results):
    overall = "needs_repair"

json.dump(
    {
        "overall_status": overall,
        "repair_enabled": repair_enabled,
        "results": results,
    },
    sys.stdout,
    separators=(",", ":"),
)
print()
PY
}
