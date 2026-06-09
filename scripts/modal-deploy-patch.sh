#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="${TRR_MODAL_BACKEND_DIR:-$ROOT/TRR-Backend}"
SLICE_DOC="modal-deploy-slices/backend-model-lock-runtime.md"
MODE="list"
PATCH_OUT=""

APPROVED_FILES=(
  ".env.example"
  "requirements.modal.lean.lock.txt"
  "requirements.modal.vision.lock.txt"
  "tests/clients/test_computer_use.py"
  "tests/repositories/test_social_season_analytics.py"
  "trr_backend/clients/computer_use.py"
  "trr_backend/socials/instagram/runtimes/browser_use_runtime.py"
  "trr_backend/socials/social_season_analytics_impl.py"
)

usage() {
  cat <<'USAGE'
Usage: scripts/modal-deploy-patch.sh [option]

Safely lists or exports the active Modal deploy-slice diff without creating
branches or worktrees. The exported patch is filtered to the approved eight
backend files only, so unrelated dirty files in the shared checkout are not
included.

Default:
  --list              Show the active slice, approved files, and dirty status.

Options:
  --help              Show this help text.
  --list              Dry-run/list mode. Writes no files.
  --manifest          Emit a JSON manifest for the active deploy slice.
  --stdout            Print the approved-file patch to stdout.
  --patch PATH        Write the approved-file patch to PATH.

Active slice doc:
  modal-deploy-slices/backend-model-lock-runtime.md

Examples:
  scripts/modal-deploy-patch.sh --list
  scripts/modal-deploy-patch.sh --manifest
  scripts/modal-deploy-patch.sh --patch /tmp/trr-modal-backend-model-lock-runtime.patch
USAGE
}

die() {
  echo "modal-deploy-patch: ERROR: $*" >&2
  exit 1
}

repo_status() {
  git -C "$ROOT" status --short -- "$@"
}

backend_status() {
  git -C "$BACKEND_DIR" status --short -- "$@"
}

approved_backend_status() {
  backend_status "${APPROVED_FILES[@]}"
}

all_backend_status() {
  git -C "$BACKEND_DIR" status --short
}

unrelated_backend_status() {
  python3 - "$BACKEND_DIR" "${APPROVED_FILES[@]}" <<'PY'
from __future__ import annotations

import subprocess
import sys

backend_dir = sys.argv[1]
approved = set(sys.argv[2:])
result = subprocess.run(
    ["git", "-C", backend_dir, "status", "--short"],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
)
for line in result.stdout.splitlines():
    path = line[3:] if len(line) > 3 else ""
    if path not in approved:
        print(line)
PY
}

workspace_unrelated_status() {
  python3 - "$ROOT" <<'PY'
from __future__ import annotations

import subprocess
import sys

root = sys.argv[1]
allowed_prefixes = (
    "TRR-Backend/",
    "docs/workspace/modal-safe-backend-deploy-set.md",
    "modal-deploy-slices/",
    "scripts/modal-deploy-patch.sh",
)
result = subprocess.run(
    ["git", "-C", root, "status", "--short"],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
)
for line in result.stdout.splitlines():
    path = line[3:] if len(line) > 3 else ""
    if not path.startswith(allowed_prefixes):
        print(line)
PY
}

emit_patch() {
  git -C "$BACKEND_DIR" diff \
    --no-ext-diff \
    --src-prefix=a/TRR-Backend/ \
    --dst-prefix=b/TRR-Backend/ \
    -- "${APPROVED_FILES[@]}"
}

emit_manifest() {
  python3 - "$ROOT" "$BACKEND_DIR" "$SLICE_DOC" "${APPROVED_FILES[@]}" <<'PY'
from __future__ import annotations

import json
import subprocess
import sys

root, backend_dir, slice_doc = sys.argv[1:4]
approved = list(sys.argv[4:])

def run(args: list[str]) -> list[str]:
    result = subprocess.run(args, check=True, text=True, stdout=subprocess.PIPE)
    return result.stdout.splitlines()

payload = {
    "slice": "backend-model-lock-runtime",
    "slice_doc": slice_doc,
    "backend_dir": backend_dir,
    "approved_files": [f"TRR-Backend/{path}" for path in approved],
    "approved_status": run(["git", "-C", backend_dir, "status", "--short", "--", *approved]),
    "unrelated_backend_status": [],
    "workspace_unrelated_status": [],
    "sql": {
        "included": False,
        "note": "No SQL, direct-SQL, or Supabase migration changes are part of this slice.",
    },
}

approved_set = set(approved)
for line in run(["git", "-C", backend_dir, "status", "--short"]):
    path = line[3:] if len(line) > 3 else ""
    if path not in approved_set:
        payload["unrelated_backend_status"].append(line)

allowed_prefixes = (
    "TRR-Backend/",
    "docs/workspace/modal-safe-backend-deploy-set.md",
    "modal-deploy-slices/",
    "scripts/modal-deploy-patch.sh",
)
for line in run(["git", "-C", root, "status", "--short"]):
    path = line[3:] if len(line) > 3 else ""
    if not path.startswith(allowed_prefixes):
        payload["workspace_unrelated_status"].append(line)

print(json.dumps(payload, indent=2))
PY
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --list)
      MODE="list"
      shift
      ;;
    --manifest)
      MODE="manifest"
      shift
      ;;
    --stdout)
      MODE="stdout"
      shift
      ;;
    --patch)
      [[ $# -ge 2 ]] || die "--patch requires an output path"
      MODE="patch"
      PATCH_OUT="$2"
      shift 2
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

git -C "$BACKEND_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
  die "backend repo not found at $BACKEND_DIR"
[[ -f "$ROOT/$SLICE_DOC" ]] || die "active slice doc not found: $SLICE_DOC"

case "$MODE" in
  list)
    echo "Active Modal deploy slice: $SLICE_DOC"
    echo
    echo "Approved backend files:"
    for path in "${APPROVED_FILES[@]}"; do
      echo "  TRR-Backend/$path"
    done
    echo
    echo "Approved-file dirty status:"
    approved_backend_status || true
    echo
    echo "Unrelated backend dirty status:"
    unrelated_backend_status || true
    echo
    echo "Unrelated workspace dirty status:"
    workspace_unrelated_status || true
    echo
    echo "Dry run only. Use --patch PATH or --stdout to export the approved-file patch."
    ;;
  manifest)
    emit_manifest
    ;;
  stdout)
    emit_patch
    ;;
  patch)
    [[ -n "$PATCH_OUT" ]] || die "missing patch output path"
    mkdir -p "$(dirname "$PATCH_OUT")"
    emit_patch > "$PATCH_OUT"
    echo "Wrote approved Modal deploy patch: $PATCH_OUT"
    echo "Patch source: $SLICE_DOC"
    ;;
  *)
    die "internal error: unsupported mode $MODE"
    ;;
esac
