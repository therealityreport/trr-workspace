#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODE="dry-run"

usage() {
  cat <<'USAGE'
Usage:
  scripts/workspace/hygiene_clean.sh [--dry-run]

This command is dry-run only and deletes nothing.

The report is limited to ignored __pycache__ directories, .pyc files, and
.DS_Store files outside excluded evidence, adjacent, .locks, env, and secret
paths.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      MODE="dry-run"
      ;;
    --confirm-delete)
      printf 'Confirmed deletion is not supported by this workspace hygiene command. Use --dry-run only.\n' >&2
      exit 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n\n' "$arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "${TRR_WORKSPACE_HYGIENE_CONFIRM_DELETE:-}" == "1" ]]; then
  printf 'TRR_WORKSPACE_HYGIENE_CONFIRM_DELETE is ignored because this command is dry-run only.\n' >&2
  exit 2
fi

section() {
  printf '\n== %s ==\n' "$1"
}

size_kb() {
  local path="$1"
  if [[ -d "$path" ]]; then
    du -sk "$path" 2>/dev/null | awk '{print $1}'
  elif [[ -f "$path" ]]; then
    local bytes
    bytes="$(stat -f %z "$path" 2>/dev/null || stat -c %s "$path" 2>/dev/null || printf '0')"
    printf '%s\n' $(((bytes + 1023) / 1024))
  else
    printf '0\n'
  fi
}

artifact_summary() {
  local label="$1"
  local path="$2"
  if [[ -e "$path" ]]; then
    printf '%s: ' "$label"
    du -sh "$path" 2>/dev/null | awk '{print $1}'
  else
    printf '%s: missing\n' "$label"
  fi
}

git_ignored() {
  local repo="$1"
  local path="$2"
  local rel
  rel="${path#$repo/}"
  [[ "$rel" != "$path" ]] || return 1
  git -C "$repo" check-ignore -q -- "$rel"
}

add_candidates_for_repo() {
  local label="$1"
  local repo="$2"
  shift 2

  [[ -d "$repo" ]] || return 0

  while IFS= read -r -d '' path; do
    if git_ignored "$repo" "$path"; then
      CANDIDATES+=("$path")
      CANDIDATE_LABELS+=("$label")
    else
      SKIPPED+=("$path")
    fi
  done < <(
    find "$repo" "$@" \
      -path "$repo/.git" -prune -o \
      -path "$repo/.logs" -prune -o \
      -path "$repo/.plan-work" -prune -o \
      -path "$repo/.artifacts" -prune -o \
      -path "$repo/output" -prune -o \
      -path "$repo/.venv" -prune -o \
      -path "$repo/node_modules" -prune -o \
      -path "$repo/.worktrees" -prune -o \
      -type d \( -name "node_modules" -o -name ".next" -o -name ".venv" -o -name ".worktrees" \) -prune -o \
      -path "$repo/.env" -prune -o \
      -path "$repo/.env.*" -prune -o \
      -path "$repo/.secrets" -prune -o \
      -path "$repo/secrets" -prune -o \
      -path "$repo/cookies" -prune -o \
      -path "$repo/evidence" -prune -o \
      \( -type d -name "__pycache__" -print0 -prune \) -o \
      \( -type f \( -name "*.pyc" -o -name ".DS_Store" \) -print0 \) 2>/dev/null
  )
}

CANDIDATES=()
CANDIDATE_LABELS=()
SKIPPED=()

section "Summary"
printf 'Dry-run mode. No files will be deleted.\n'
printf 'Allowed candidate types: ignored __pycache__ directories, .pyc files, and .DS_Store files.\n'
printf 'Excluded areas: retired screenalytics checkout, BRAVOTV, .external, data, .logs, .plan-work, .artifacts, output, TRR-Backend/.locks, node_modules, .next, .venv, .worktrees, env, cookies, secrets, and evidence paths.\n'
printf 'TRR-Backend/.locks contains backend runtime lock files and is never deleted by this command.\n'

section "Before Size Summary"
artifact_summary ".logs" "$ROOT_DIR/.logs"
artifact_summary "TRR-Backend/.venv" "$ROOT_DIR/TRR-Backend/.venv"
artifact_summary "TRR-APP/apps/web/.next" "$ROOT_DIR/TRR-APP/apps/web/.next"
artifact_summary ".plan-work" "$ROOT_DIR/.plan-work"

add_candidates_for_repo "root workspace" "$ROOT_DIR" \
  -path "$ROOT_DIR/TRR-Backend" -prune -o \
  -path "$ROOT_DIR/TRR-APP" -prune -o \
  -path "$ROOT_DIR/screenalytics" -prune -o \
  -path "$ROOT_DIR/BRAVOTV" -prune -o \
  -path "$ROOT_DIR/.external" -prune -o \
  -path "$ROOT_DIR/data" -prune -o
add_candidates_for_repo "TRR-Backend" "$ROOT_DIR/TRR-Backend" \
  -path "$ROOT_DIR/TRR-Backend/.locks" -prune -o
add_candidates_for_repo "TRR-APP" "$ROOT_DIR/TRR-APP"

section "Cleanup Candidates"
total_kb=0
if [[ "${#CANDIDATES[@]}" -eq 0 ]]; then
  printf 'No ignored cleanup candidates found.\n'
else
  for idx in "${!CANDIDATES[@]}"; do
    path="${CANDIDATES[$idx]}"
    label="${CANDIDATE_LABELS[$idx]}"
    kb="$(size_kb "$path")"
    total_kb=$((total_kb + kb))
    printf '[%s] %s KB %s\n' "$label" "$kb" "${path#$ROOT_DIR/}"
  done
fi
printf 'Estimated candidate size: %s KB\n' "$total_kb"

if [[ "${#SKIPPED[@]}" -gt 0 ]]; then
  section "Skipped Non-Ignored Matches"
  printf 'These matched the conservative patterns but are not ignored, so they are protected:\n'
  for path in "${SKIPPED[@]}"; do
    printf '%s\n' "${path#$ROOT_DIR/}"
  done
fi

section "Safety Result"
printf 'Dry-run complete. No files were deleted.\n'
