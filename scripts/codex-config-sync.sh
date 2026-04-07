#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
USER_CONFIG_FILE="${CODEX_CONFIG_FILE:-${CODEX_HOME_DIR}/config.toml}"
USER_AGENTS_FILE="${CODEX_HOME_DIR}/AGENTS.md"
PROJECT_CONFIG_FILE="${ROOT}/.codex/config.toml"
USER_CONFIG_TEMPLATE_PATH="${ROOT}/config/codex/user-bootstrap.toml.tmpl"

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
  scripts/codex-config-sync.sh bootstrap
  scripts/codex-config-sync.sh validate

Description:
  Bootstraps minimal user-level Codex files under ~/.codex and validates the
  tracked project-local Codex configuration for the TRR workspace.
USAGE
}

backup_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  local backup="${file}.bak.repo-template-${timestamp}"
  cp "$file" "$backup"
  echo "[codex-config-sync] Backup: ${backup}"
}

render_user_template_to() {
  local destination="$1"
  sed \
    -e "s|__TRR_ROOT__|${ROOT}|g" \
    -e "s|__HOME__|${HOME}|g" \
    "$USER_CONFIG_TEMPLATE_PATH" >"$destination"
}

write_default_user_agents() {
  local destination="$1"
  cat >"$destination" <<'EOF'
# User Codex preferences

Use this file only for personal, cross-project preferences.
Do not put project-specific policy, repo instructions, or workspace-specific MCP settings here.
EOF
}

user_config_contains_disallowed_trr_settings() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  rg -q 'codex-chrome-devtools-mcp\.sh|vwxfvzutyufrkhfgoeaa|^\[mcp_servers\.(supabase|awslabs-[^]]+|awsknowledge|awsiac)\]' "$file"
}

user_config_has_expected_bootstrap_state() {
  local file="$1"
  local python_bin="$2"
  [[ -f "$file" ]] || return 1
  "$python_bin" - "$file" "$ROOT" <<'PY' >/dev/null 2>&1
import pathlib
import sys
import tomllib

path = pathlib.Path(sys.argv[1])
workspace_root = sys.argv[2]
with path.open("rb") as handle:
    data = tomllib.load(handle)

projects = data.get("projects") or {}
trusted_project = (projects.get(workspace_root) or {}).get("trust_level")
if trusted_project != "trusted":
    raise SystemExit(1)

servers = data.get("mcp_servers") or {}
global_chrome_wrapper = str(path.parent / "bin" / "codex-chrome-devtools-mcp-global.sh")
required_disabled_skill_names = {
    "code-reviewer",
    "context7-cli",
    "figma-designer",
    "modal-platform",
    "senior-architect",
    "senior-backend",
    "senior-devops",
    "senior-frontend",
    "senior-fullstack",
    "senior-qa",
    "skillcreator",
    "social-ingestion-reliability",
}
required_disabled_skill_paths = {
    str(path.parent / "skills" / skill_name) for skill_name in required_disabled_skill_names
}
required_disabled_skill_paths.update(
    {
        str(pathlib.Path.home() / ".agents" / "skills" / "frontend-design" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "angular-architect" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "architecture-designer" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "atlassian-mcp" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "chromedevtools-expert" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "cloud-architect" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "cpp-pro" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "csharp-developer" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "devops-engineer" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "django-expert" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "dotnet-core-expert" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "embedded-systems" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "fastapi-expert" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "flutter-expert" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "fullstack-guardian" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "game-developer" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "java-architect" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "kotlin-specialist" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "kubernetes-specialist" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "laravel-specialist" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "monitoring-expert" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "nestjs-expert" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "nextjs-developer" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "rails-expert" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "rust-engineer" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "salesforce-developer" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "security-reviewer" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "secure-code-guardian" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "shopify-expert" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "spring-boot-engineer" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "swift-expert" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "terraform-engineer" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "test-master" / "SKILL.md"),
        str(path.parent / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "wordpress-pro" / "SKILL.md"),
    }
)
required = {
    "chrome-devtools": {
        "command": global_chrome_wrapper,
        "env": {
            "CODEX_CHROME_MODE": "shared",
            "CODEX_CHROME_HEADLESS": "1",
            "CODEX_CHROME_AUTO_LAUNCH": "1",
            "CODEX_CHROME_SEED_PROFILE_DIR": str(pathlib.Path.home() / ".chrome-profiles" / "codex-agent"),
        },
        "enabled": True,
        "startup_timeout_sec": 45,
        "tool_timeout_sec": 120,
    },
    "figma": {"url": "https://mcp.figma.com/mcp", "enabled": True},
    "figma-desktop": {"url": "http://127.0.0.1:3845/mcp", "enabled": False},
    "playwright": {"command": "npx", "args": ["-y", "@playwright/mcp", "--isolated"], "enabled": False},
    "github": {"url": "https://api.githubcopilot.com/mcp", "bearer_token_env_var": "GITHUB_PAT"},
    "context7": {"command": "npx", "args": ["-y", "@upstash/context7-mcp"], "enabled": True},
}

for name, expectations in required.items():
    server = servers.get(name)
    if not isinstance(server, dict):
        raise SystemExit(1)
    for key, value in expectations.items():
        if server.get(key) != value:
            raise SystemExit(1)

for name in servers:
    if name in {"supabase", "awsknowledge", "awsiac"} or name.startswith("awslabs-"):
        raise SystemExit(1)

plugins = data.get("plugins") or {}
skills = data.get("skills") or {}
skill_configs = skills.get("config") or []
normalized_skill_paths = set()
for entry in skill_configs:
    if not isinstance(entry, dict):
        raise SystemExit(1)
    skill_path = entry.get("path")
    if not isinstance(skill_path, str):
        raise SystemExit(1)
    normalized_skill_paths.add(skill_path)
    if skill_path in required_disabled_skill_paths and entry.get("enabled") is not False:
        raise SystemExit(1)

if not required_disabled_skill_paths.issubset(normalized_skill_paths):
    raise SystemExit(1)
PY
}

merge_user_config_to() {
  local source_file="$1"
  local destination="$2"
  local python_bin="$3"

  "$python_bin" - "$source_file" "$destination" "$ROOT" <<'PY'
from __future__ import annotations

import json
import pathlib
import re
import sys
import tomllib
from collections.abc import Mapping

source = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
workspace_root = sys.argv[3]


def load_existing(path: pathlib.Path) -> dict:
    if not path.exists():
        return {}
    try:
        with path.open("rb") as handle:
            data = tomllib.load(handle)
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def format_key(key: str) -> str:
    return key if re.fullmatch(r"[A-Za-z0-9_-]+", key) else json.dumps(key)


def format_value(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return str(value)
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        return "[" + ", ".join(format_value(item) for item in value) + "]"
    if isinstance(value, Mapping):
        items = ", ".join(f"{format_key(str(k))} = {format_value(v)}" for k, v in value.items())
        return "{ " + items + " }"
    raise TypeError(f"Unsupported TOML value: {type(value).__name__}")


def emit_table(lines: list[str], table_path: list[str], mapping: Mapping[str, object]) -> None:
    scalars = []
    nested = []
    for key, value in mapping.items():
        if isinstance(value, Mapping):
            nested.append((key, value))
        else:
            scalars.append((key, value))

    if table_path:
        if lines and lines[-1] != "":
            lines.append("")
        lines.append("[" + ".".join(format_key(part) for part in table_path) + "]")

    for key, value in scalars:
        lines.append(f"{format_key(str(key))} = {format_value(value)}")

    for key, value in nested:
        emit_table(lines, [*table_path, str(key)], value)


data = load_existing(source)
projects = data.get("projects")
if not isinstance(projects, dict):
    projects = {}
data["projects"] = projects
project_settings = projects.get(workspace_root)
if not isinstance(project_settings, dict):
    project_settings = {}
projects[workspace_root] = project_settings
project_settings["trust_level"] = "trusted"

servers = data.get("mcp_servers")
if not isinstance(servers, dict):
    servers = {}
data["mcp_servers"] = servers

for name in list(servers):
    if name in {"supabase", "awsknowledge", "awsiac"} or name.startswith("awslabs-"):
        servers.pop(name, None)

required_servers = {
    "chrome-devtools": {
        "command": f"{pathlib.Path.home()}/.codex/bin/codex-chrome-devtools-mcp-global.sh",
        "env": {
            "CODEX_CHROME_MODE": "shared",
            "CODEX_CHROME_HEADLESS": "1",
            "CODEX_CHROME_AUTO_LAUNCH": "1",
            "CODEX_CHROME_SEED_PROFILE_DIR": str(pathlib.Path.home() / ".chrome-profiles" / "codex-agent"),
        },
        "enabled": True,
        "startup_timeout_sec": 45,
        "tool_timeout_sec": 120,
    },
    "figma": {"url": "https://mcp.figma.com/mcp", "enabled": True},
    "figma-desktop": {"url": "http://127.0.0.1:3845/mcp", "enabled": False},
    "playwright": {"command": "npx", "args": ["-y", "@playwright/mcp", "--isolated"], "enabled": False},
    "github": {"url": "https://api.githubcopilot.com/mcp", "bearer_token_env_var": "GITHUB_PAT"},
    "context7": {"command": "npx", "args": ["-y", "@upstash/context7-mcp"], "enabled": True},
}
for name, required in required_servers.items():
    server = servers.get(name)
    if not isinstance(server, dict):
        server = {}
        servers[name] = server
    server.update(required)

required_disabled_skill_names = [
    "context7-cli",
    "modal-platform",
    "senior-architect",
    "senior-devops",
    "senior-fullstack",
    "senior-backend",
    "senior-frontend",
    "senior-qa",
    "code-reviewer",
    "skillcreator",
    "social-ingestion-reliability",
    "figma-designer",
]
required_disabled_skill_paths = {
    str(pathlib.Path.home() / ".codex" / "skills" / skill_name): False
    for skill_name in required_disabled_skill_names
}
required_disabled_skill_paths.update(
    {
        str(pathlib.Path.home() / ".agents" / "skills" / "frontend-design" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "angular-architect" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "architecture-designer" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "atlassian-mcp" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "chromedevtools-expert" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "cloud-architect" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "cpp-pro" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "csharp-developer" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "devops-engineer" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "django-expert" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "dotnet-core-expert" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "embedded-systems" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "fastapi-expert" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "flutter-expert" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "fullstack-guardian" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "game-developer" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "java-architect" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "kotlin-specialist" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "kubernetes-specialist" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "laravel-specialist" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "monitoring-expert" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "nestjs-expert" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "nextjs-developer" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "rails-expert" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "rust-engineer" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "salesforce-developer" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "security-reviewer" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "secure-code-guardian" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "shopify-expert" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "spring-boot-engineer" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "swift-expert" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "terraform-engineer" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "test-master" / "SKILL.md"): False,
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "wordpress-pro" / "SKILL.md"): False,
    }
)
skills = data.get("skills")
if not isinstance(skills, dict):
    skills = {}
data["skills"] = skills
skill_configs = skills.get("config")
if not isinstance(skill_configs, list):
    skill_configs = []

skill_entries_by_path: dict[str, dict] = {}
retained_skill_entries: list[dict] = []
for entry in skill_configs:
    if isinstance(entry, Mapping) and isinstance(entry.get("path"), str):
        normalized = dict(entry)
        retained_skill_entries.append(normalized)
        skill_entries_by_path[normalized["path"]] = normalized

for skill_path, enabled in required_disabled_skill_paths.items():
    entry = skill_entries_by_path.get(skill_path)
    if entry is None:
        entry = {"path": skill_path}
        retained_skill_entries.append(entry)
        skill_entries_by_path[skill_path] = entry
    entry["enabled"] = enabled

skills["config"] = sorted(retained_skill_entries, key=lambda item: str(item.get("path", "")))

lines: list[str] = [
    "# Personal Codex defaults live here.",
    "# Keep TRR-specific settings in the trusted project-local `.codex/config.toml`.",
]
emit_table(lines, [], data)
destination.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

user_agents_contains_disallowed_trr_markers() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  rg -q '/Users/thomashulihan/Projects/TRR|codex-chrome-devtools-mcp\.sh|vwxfvzutyufrkhfgoeaa' "$file"
}

bootstrap_user_files() {
  local rendered
  local rendered_agents
  local python_bin

  python_bin="$(resolve_python_311_bin)"

  mkdir -p "$CODEX_HOME_DIR"

  if [[ ! -f "$USER_CONFIG_TEMPLATE_PATH" ]]; then
    echo "[codex-config-sync] ERROR: template not found: ${USER_CONFIG_TEMPLATE_PATH}" >&2
    exit 1
  fi

  if [[ ! -f "$USER_CONFIG_FILE" ]] \
    || user_config_contains_disallowed_trr_settings "$USER_CONFIG_FILE" \
    || ! user_config_has_expected_bootstrap_state "$USER_CONFIG_FILE" "$python_bin"; then
    backup_file "$USER_CONFIG_FILE"
    rendered="$(mktemp "${USER_CONFIG_FILE}.tmp.XXXXXX")"
    if [[ -f "$USER_CONFIG_FILE" ]]; then
      merge_user_config_to "$USER_CONFIG_FILE" "$rendered" "$python_bin"
    else
      render_user_template_to "$rendered"
    fi
    mv "$rendered" "$USER_CONFIG_FILE"
    echo "[codex-config-sync] Bootstrapped user config -> ${USER_CONFIG_FILE}"
  else
    echo "[codex-config-sync] Preserved existing user config -> ${USER_CONFIG_FILE}"
  fi

  if [[ ! -s "$USER_AGENTS_FILE" ]] || user_agents_contains_disallowed_trr_markers "$USER_AGENTS_FILE"; then
    backup_file "$USER_AGENTS_FILE"
    rendered_agents="$(mktemp "${USER_AGENTS_FILE}.tmp.XXXXXX")"
    write_default_user_agents "$rendered_agents"
    mv "$rendered_agents" "$USER_AGENTS_FILE"
    echo "[codex-config-sync] Bootstrapped user AGENTS -> ${USER_AGENTS_FILE}"
  else
    echo "[codex-config-sync] Preserved existing user AGENTS -> ${USER_AGENTS_FILE}"
  fi
}

validate_config() {
    local expected_wrapper="${ROOT}/scripts/codex-chrome-devtools-mcp.sh"
    local expected_global_wrapper="${HOME}/.codex/bin/codex-chrome-devtools-mcp-global.sh"
    local python_bin
    python_bin="$(resolve_python_311_bin)"

  "$python_bin" - "$PROJECT_CONFIG_FILE" "$USER_CONFIG_FILE" "$USER_AGENTS_FILE" "$expected_wrapper" "$expected_global_wrapper" "$ROOT" <<'PY'
import pathlib
import sys
import tomllib

project_config_path = pathlib.Path(sys.argv[1])
user_config_path = pathlib.Path(sys.argv[2])
user_agents_path = pathlib.Path(sys.argv[3])
expected_wrapper = sys.argv[4]
expected_global_wrapper = sys.argv[5]
workspace_root = sys.argv[6]

if not project_config_path.exists():
    raise SystemExit(f"[codex-config-sync] ERROR: project config file not found: {project_config_path}")

with project_config_path.open("rb") as handle:
    data = tomllib.load(handle)

required_servers = {
    "supabase": {
        "url": "https://mcp.supabase.com/mcp?project_ref=vwxfvzutyufrkhfgoeaa&features=docs%2Caccount%2Cdatabase%2Cdebugging%2Cdevelopment%2Cfunctions%2Cbranching%2Cstorage",
        "bearer_token_env_var": "SUPABASE_ACCESS_TOKEN",
    },
}
required_user_servers = {
    "figma": {"url": "https://mcp.figma.com/mcp", "enabled": True},
    "figma-desktop": {"url": "http://127.0.0.1:3845/mcp", "enabled": False},
    "chrome-devtools": {
        "command": expected_global_wrapper,
        "env": {
            "CODEX_CHROME_MODE": "shared",
            "CODEX_CHROME_HEADLESS": "1",
            "CODEX_CHROME_AUTO_LAUNCH": "1",
            "CODEX_CHROME_SEED_PROFILE_DIR": str(pathlib.Path.home() / ".chrome-profiles" / "codex-agent"),
        },
        "enabled": True,
        "startup_timeout_sec": 45,
        "tool_timeout_sec": 120,
    },
    "playwright": {"command": "npx", "args": ["-y", "@playwright/mcp", "--isolated"], "enabled": False},
    "github": {"url": "https://api.githubcopilot.com/mcp", "bearer_token_env_var": "GITHUB_PAT"},
    "context7": {"command": "npx", "args": ["-y", "@upstash/context7-mcp"], "enabled": True},
}
required_top_level = {
    "model": "gpt-5.4",
    "model_reasoning_effort": "high",
    "personality": "pragmatic",
    "approval_policy": "never",
    "sandbox_mode": "danger-full-access",
    "web_search": "cached",
    "project_doc_max_bytes": 65536,
    "project_doc_fallback_filenames": [],
}
required_agents = {
    "pr_explorer": "./agents/pr_explorer.toml",
    "reviewer": "./agents/reviewer.toml",
    "docs_researcher": "./agents/docs_researcher.toml",
    "code_mapper": "./agents/code_mapper.toml",
    "browser_debugger": "./agents/browser_debugger.toml",
    "ui_fixer": "./agents/ui_fixer.toml",
}
required_disabled_skill_paths = {
    str(pathlib.Path.home() / ".codex" / "skills" / skill_name)
    for skill_name in (
        "context7-cli",
        "modal-platform",
        "senior-architect",
        "senior-devops",
        "senior-fullstack",
        "senior-backend",
        "senior-frontend",
        "senior-qa",
        "code-reviewer",
        "skillcreator",
        "social-ingestion-reliability",
        "figma-designer",
    )
}
required_disabled_skill_paths.update(
    {
        str(pathlib.Path.home() / ".agents" / "skills" / "frontend-design" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "angular-architect" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "architecture-designer" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "atlassian-mcp" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "chromedevtools-expert" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "cloud-architect" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "cpp-pro" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "csharp-developer" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "devops-engineer" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "django-expert" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "dotnet-core-expert" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "embedded-systems" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "fastapi-expert" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "flutter-expert" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "fullstack-guardian" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "game-developer" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "java-architect" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "kotlin-specialist" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "kubernetes-specialist" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "laravel-specialist" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "monitoring-expert" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "nestjs-expert" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "nextjs-developer" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "rails-expert" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "rust-engineer" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "salesforce-developer" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "security-reviewer" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "secure-code-guardian" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "shopify-expert" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "spring-boot-engineer" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "swift-expert" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "terraform-engineer" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "test-master" / "SKILL.md"),
        str(pathlib.Path.home() / ".codex" / "skills" / "fullstack-dev-skills" / "fullstack-dev-skills" / "0.4.9" / "skills" / "wordpress-pro" / "SKILL.md"),
    }
)

errors = []
servers = data.get("mcp_servers") or {}
agents = data.get("agents") or {}

for key, value in required_top_level.items():
    actual = data.get(key)
    if actual != value:
        errors.append(f"expected {key}={value!r}, found {actual!r}")

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
unexpected = sorted(name for name in servers if name not in required_servers)
for name in unexpected:
    errors.append(f"[mcp_servers.{name}] is no longer allowed in the tracked project config")

if agents.get("max_threads") != 6:
    errors.append(f"[agents] expected max_threads=6, found {agents.get('max_threads')!r}")
if agents.get("max_depth") != 1:
    errors.append(f"[agents] expected max_depth=1, found {agents.get('max_depth')!r}")
for agent_name, config_file in required_agents.items():
    agent_settings = agents.get(agent_name)
    if not isinstance(agent_settings, dict):
        errors.append(f"missing [agents.{agent_name}]")
        continue
    if agent_settings.get("config_file") != config_file:
        errors.append(
            f"[agents.{agent_name}] expected config_file={config_file!r}, found {agent_settings.get('config_file')!r}"
        )
    elif not (project_config_path.parent / config_file).exists():
        errors.append(f"[agents.{agent_name}] config file not found: {project_config_path.parent / config_file}")

if not user_config_path.exists():
    errors.append(f"user config file not found: {user_config_path}")
else:
    with user_config_path.open("rb") as handle:
        user_data = tomllib.load(handle)
    user_projects = user_data.get("projects") or {}
    trusted_project = (user_projects.get(workspace_root) or {}).get("trust_level")
    if trusted_project != "trusted":
        errors.append(f"user config must trust {workspace_root!r}; found {trusted_project!r}")

    user_servers = user_data.get("mcp_servers") or {}
    for name, expectations in required_user_servers.items():
        server = user_servers.get(name)
        if not isinstance(server, dict):
            errors.append(f"user config missing [mcp_servers.{name}]")
            continue
        for key, value in expectations.items():
            actual = server.get(key)
            if actual != value:
                errors.append(f"user [mcp_servers.{name}] expected {key}={value!r}, found {actual!r}")

    user_config_text = user_config_path.read_text(encoding="utf-8")
    if expected_wrapper in user_config_text or "vwxfvzutyufrkhfgoeaa" in user_config_text:
        errors.append(f"user config should not contain TRR-local MCP settings: {user_config_path}")

    user_skills = user_data.get("skills") or {}
    user_skill_configs = user_skills.get("config") or []
    normalized_skill_paths = set()
    for entry in user_skill_configs:
        if not isinstance(entry, dict):
            errors.append("user skills.config entries must be objects")
            continue
        skill_path = entry.get("path")
        if not isinstance(skill_path, str):
            errors.append("user skills.config entries must include string paths")
            continue
        normalized_skill_paths.add(skill_path)
        if skill_path in required_disabled_skill_paths and entry.get("enabled") is not False:
            errors.append(f"user skills.config must disable {skill_path}")
    missing_disabled_skills = sorted(required_disabled_skill_paths - normalized_skill_paths)
    if missing_disabled_skills:
        errors.append(f"user skills.config missing disabled TRR aliases: {missing_disabled_skills}")

for name in sorted(name for name in servers if name.startswith(legacy_prefix) or name in {legacy_knowledge, legacy_iac}):
    errors.append(f"[mcp_servers.{name}] is no longer allowed in the tracked project config")

if user_config_path.exists():
    with user_config_path.open("rb") as handle:
        user_data = tomllib.load(handle)
    user_servers = user_data.get("mcp_servers") or {}
    for name in sorted(name for name in user_servers if name.startswith(legacy_prefix) or name in {legacy_knowledge, legacy_iac}):
        errors.append(f"user [mcp_servers.{name}] is no longer allowed in ~/.codex/config.toml")

if not user_agents_path.exists():
    errors.append(f"user AGENTS file not found: {user_agents_path}")
else:
    user_agents_text = user_agents_path.read_text(encoding="utf-8").strip()
    if not user_agents_text:
        errors.append(f"user AGENTS file is empty: {user_agents_path}")
    if workspace_root in user_agents_text or "codex-chrome-devtools-mcp.sh" in user_agents_text or "vwxfvzutyufrkhfgoeaa" in user_agents_text:
        errors.append(f"user AGENTS file should not contain TRR workspace policy: {user_agents_path}")

if errors:
    for message in errors:
        print(f"[codex-config-sync] ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)

print(f"[codex-config-sync] Validation OK: project={project_config_path} user={user_config_path}")
PY
}

bootstrap_template() {
  bootstrap_user_files
  validate_config
}

case "${1:-}" in
  bootstrap|install)
    bootstrap_template
    ;;
  validate)
    validate_config
    ;;
  *)
    usage
    exit 1
    ;;
esac
