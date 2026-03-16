#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/screenalytics"

if ! command -v docker >/dev/null 2>&1; then
  echo "[down] docker not found; no local dev-local infra to tear down."
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  echo "[down] docker daemon not running; no local dev-local infra to tear down."
  exit 0
fi

docker compose -f infra/docker/compose.yaml down --remove-orphans
