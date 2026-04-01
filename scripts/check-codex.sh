#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULES_FILE="${ROOT}/.codex/rules/default.rules"

resolve_python_311_bin() {
  local candidate path
  for candidate in python3.11 python3 python; do
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
      printf '%s\n' "$path"
      return 0
    fi
  done

  echo "[check-codex] ERROR: Python 3.11+ is required." >&2
  exit 1
}

fail() {
  echo "[check-codex] ERROR: $*" >&2
  exit 1
}

if ! command -v codex >/dev/null 2>&1; then
  fail "Codex CLI is not available on PATH"
fi

PYTHON_BIN="$(resolve_python_311_bin)"

bash "${ROOT}/scripts/codex-config-sync.sh" validate

if [[ ! -f "$RULES_FILE" ]]; then
  fail "Missing rules file: ${RULES_FILE}"
fi

reset_policy="$(codex execpolicy check --pretty --rules "$RULES_FILE" -- git reset --hard)"
"$PYTHON_BIN" - <<'PY' "$reset_policy"
import json
import sys

payload = json.loads(sys.argv[1])
decision = payload.get("decision")
if decision != "forbidden":
    raise SystemExit(f"[check-codex] ERROR: expected git reset --hard to be forbidden, found {decision!r}")
PY

bootstrap_policy="$(codex execpolicy check --pretty --rules "$RULES_FILE" -- bash scripts/codex-config-sync.sh bootstrap)"
"$PYTHON_BIN" - <<'PY' "$bootstrap_policy"
import json
import sys

payload = json.loads(sys.argv[1])
decision = payload.get("decision")
if decision != "prompt":
    raise SystemExit(f"[check-codex] ERROR: expected bootstrap command to prompt, found {decision!r}")
PY

force_push_policy="$(codex execpolicy check --pretty --rules "$RULES_FILE" -- git push --force origin main)"
"$PYTHON_BIN" - <<'PY' "$force_push_policy"
import json
import sys

payload = json.loads(sys.argv[1])
decision = payload.get("decision")
if decision != "forbidden":
    raise SystemExit(f"[check-codex] ERROR: expected git push --force to be forbidden, found {decision!r}")
PY

deploy_policy="$(codex execpolicy check --pretty --rules "$RULES_FILE" -- vercel deploy --prod)"
"$PYTHON_BIN" - <<'PY' "$deploy_policy"
import json
import sys

payload = json.loads(sys.argv[1])
decision = payload.get("decision")
if decision != "prompt":
    raise SystemExit(f"[check-codex] ERROR: expected vercel deploy --prod to prompt, found {decision!r}")
PY

safe_policy="$(codex execpolicy check --pretty --rules "$RULES_FILE" -- git status)"
"$PYTHON_BIN" - <<'PY' "$safe_policy"
import json
import sys

payload = json.loads(sys.argv[1])
decision = payload.get("decision")
if decision not in {None, "allow", "allowed"}:
    raise SystemExit(f"[check-codex] ERROR: expected git status to be allowed, found {decision!r}")
PY

bash_force_push_policy="$(codex execpolicy check --pretty --rules "$RULES_FILE" -- bash -lc 'git push --force origin main')"
"$PYTHON_BIN" - <<'PY' "$bash_force_push_policy"
import json
import sys

payload = json.loads(sys.argv[1])
decision = payload.get("decision")
if decision not in {None, "forbidden"}:
    raise SystemExit(f"[check-codex] ERROR: unexpected decision for bash -lc wrapped git push --force: {decision!r}")
PY

global_mcp_state="$(cd "$HOME" && codex mcp list --json)"
workspace_mcp_state="$(cd "$ROOT" && codex mcp list --json)"
"$PYTHON_BIN" - <<'PY' "$global_mcp_state" "$workspace_mcp_state"
import json
import pathlib
import sys
import tomllib

GLOBAL_EXPECTED = {"chrome-devtools", "figma", "figma-console", "figma-desktop", "github", "playwright", "context7"}
WORKSPACE_REQUIRED = GLOBAL_EXPECTED | {"supabase"}
DISALLOWED = {"awsknowledge", "awsiac", "supabase"}
GLOBAL_CHROME_COMMAND = f"{pathlib.Path.home()}/.codex/bin/codex-chrome-devtools-mcp-global.sh"
GLOBAL_FIGMA_CONSOLE_COMMAND = f"{pathlib.Path.home()}/.codex/bin/codex-figma-console-mcp.sh"
WORKSPACE_CHROME_COMMAND = GLOBAL_CHROME_COMMAND
CODEX_PROFILE_DIR = str(pathlib.Path.home() / ".chrome-profiles" / "codex-agent")
USER_CONFIG_FILE = pathlib.Path.home() / ".codex" / "config.toml"
BROWSER_AGENT_FILE = pathlib.Path.cwd() / ".codex" / "agents" / "browser_debugger.toml"

def extract_servers(payload: str) -> dict[str, dict]:
    data = json.loads(payload)
    if isinstance(data, dict):
        if "servers" in data and isinstance(data["servers"], list):
            data = data["servers"]
        elif "mcp_servers" in data and isinstance(data["mcp_servers"], list):
            data = data["mcp_servers"]
        else:
            data = list(data.values())
    servers: dict[str, dict] = {}
    if not isinstance(data, list):
        raise SystemExit(f"[check-codex] ERROR: unexpected codex mcp list payload: {type(data).__name__}")
    for entry in data:
        if isinstance(entry, str):
            servers[entry] = {"name": entry}
        elif isinstance(entry, dict):
            name = entry.get("name")
            if isinstance(name, str) and name:
                servers[name] = entry
    return servers

global_servers = extract_servers(sys.argv[1])
workspace_servers = extract_servers(sys.argv[2])
global_names = set(global_servers)
workspace_names = set(workspace_servers)

missing_global = sorted(GLOBAL_EXPECTED - global_names)
if missing_global:
    raise SystemExit(f"[check-codex] ERROR: global MCPs missing from codex mcp list: {missing_global}")

unexpected_global = sorted(name for name in global_names if name in DISALLOWED or name.startswith("awslabs-"))
if unexpected_global:
    raise SystemExit(f"[check-codex] ERROR: global codex mcp list contains disallowed project-local/AWS MCPs: {unexpected_global}")

missing_workspace = sorted(WORKSPACE_REQUIRED - workspace_names)
if missing_workspace:
    raise SystemExit(f"[check-codex] ERROR: workspace MCPs missing from trusted TRR activation: {missing_workspace}")

unexpected_workspace = sorted(name for name in workspace_names if name.startswith("awslabs-") or name in {"awsknowledge", "awsiac"})
if unexpected_workspace:
    raise SystemExit(f"[check-codex] ERROR: workspace codex mcp list contains disallowed AWS MCPs: {unexpected_workspace}")

global_chrome = global_servers.get("chrome-devtools") or {}
workspace_chrome = workspace_servers.get("chrome-devtools") or {}

global_command = (((global_chrome.get("transport") or {}).get("command")) if isinstance(global_chrome, dict) else None)
workspace_command = (((workspace_chrome.get("transport") or {}).get("command")) if isinstance(workspace_chrome, dict) else None)
if global_command != GLOBAL_CHROME_COMMAND:
    raise SystemExit(f"[check-codex] ERROR: global chrome-devtools command mismatch: expected {GLOBAL_CHROME_COMMAND!r}, found {global_command!r}")
if workspace_command != WORKSPACE_CHROME_COMMAND:
    raise SystemExit(f"[check-codex] ERROR: workspace chrome-devtools command mismatch: expected {WORKSPACE_CHROME_COMMAND!r}, found {workspace_command!r}")

figma_console = global_servers.get("figma-console") or {}
figma_console_enabled = figma_console.get("enabled")
figma_console_command = (((figma_console.get("transport") or {}).get("command")) if isinstance(figma_console, dict) else None)
if figma_console_command != GLOBAL_FIGMA_CONSOLE_COMMAND:
    raise SystemExit(f"[check-codex] ERROR: global figma-console command mismatch: expected {GLOBAL_FIGMA_CONSOLE_COMMAND!r}, found {figma_console_command!r}")
if figma_console_enabled not in {True, False}:
    raise SystemExit(f"[check-codex] ERROR: unexpected figma-console enabled state: {figma_console_enabled!r}")

with USER_CONFIG_FILE.open("rb") as handle:
    user_config = tomllib.load(handle)
user_chrome_env = (((user_config.get("mcp_servers") or {}).get("chrome-devtools") or {}).get("env") or {})
expected_chrome_env = {
    "CODEX_CHROME_MODE": "shared",
    "CODEX_CHROME_HEADLESS": "1",
    "CODEX_CHROME_AUTO_LAUNCH": "1",
    "CODEX_CHROME_SEED_PROFILE_DIR": CODEX_PROFILE_DIR,
}
for key, value in expected_chrome_env.items():
    if user_chrome_env.get(key) != value:
        raise SystemExit(f"[check-codex] ERROR: ~/.codex/config.toml chrome-devtools env {key} mismatch: expected {value!r}, found {user_chrome_env.get(key)!r}")

with BROWSER_AGENT_FILE.open("rb") as handle:
    browser_agent = tomllib.load(handle)
qa_chrome_env = (((browser_agent.get("mcp_servers") or {}).get("chrome-devtools")) or {}).get("env") or {}
for key, value in expected_chrome_env.items():
    if qa_chrome_env.get(key) != value:
        raise SystemExit(f"[check-codex] ERROR: browser_debugger agent chrome-devtools env {key} mismatch: expected {value!r}, found {qa_chrome_env.get(key)!r}")
PY

echo "[check-codex] OK"
