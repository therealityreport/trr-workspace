#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/screenalytics"

if ! command -v docker >/dev/null 2>&1; then
  echo "[down] docker not found; no explicit dev-local fallback infra to tear down."
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  echo "[down] docker daemon not running; no explicit dev-local fallback infra to tear down."
  exit 0
fi

docker compose -f infra/docker/compose.yaml down --remove-orphans
