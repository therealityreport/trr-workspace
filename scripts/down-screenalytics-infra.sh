#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -d "$ROOT/screenalytics" ]]; then
  echo "[down] local screenalytics infra is retired; no teardown is required."
  exit 0
fi

echo "[down] no screenalytics checkout found; nothing to tear down."
exit 0
