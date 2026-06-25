#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_PATH="${ROOT}/.codex/config.toml"

python3 - "$CONFIG_PATH" <<'PY'
from __future__ import annotations

import sys
import tomllib
from pathlib import Path

config_path = Path(sys.argv[1])
data = tomllib.loads(config_path.read_text(encoding="utf-8"))
server = (data.get("mcp_servers") or {}).get("next-devtools") or {}

errors: list[str] = []
if server.get("command") != "npx":
    errors.append('expected command = "npx"')
if server.get("args") != ["-y", "next-devtools-mcp@latest"]:
    errors.append('expected args = ["-y", "next-devtools-mcp@latest"]')
if (server.get("env") or {}).get("NEXT_TELEMETRY_DISABLED") != "1":
    errors.append('expected NEXT_TELEMETRY_DISABLED = "1"')

timeout = server.get("startup_timeout_ms")
if not isinstance(timeout, int) or timeout < 20000:
    errors.append("expected startup_timeout_ms >= 20000")

if errors:
    for error in errors:
        print(f"[next-devtools-mcp-status] ERROR: {error}", file=sys.stderr)
    raise SystemExit(1)

print("[next-devtools-mcp-status] Config OK: next-devtools MCP is registered for TRR.")
PY

if ! command -v npx >/dev/null 2>&1; then
  echo "[next-devtools-mcp-status] ERROR: npx is not available on PATH." >&2
  exit 1
fi

if [ "${NEXT_DEVTOOLS_MCP_STATUS_SKIP_SMOKE:-0}" = "1" ]; then
  echo "[next-devtools-mcp-status] Smoke skipped by NEXT_DEVTOOLS_MCP_STATUS_SKIP_SMOKE=1."
  exit 0
fi

echo "[next-devtools-mcp-status] npx available. Runtime MCP discovery requires a running Next.js dev server."
