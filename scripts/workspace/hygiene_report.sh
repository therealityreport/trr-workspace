#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

section() {
  printf '\n== %s ==\n' "$1"
}

path_status() {
  local label="$1"
  local path="$2"

  printf '\n[%s] %s\n' "$label" "$path"
  if [[ ! -e "$path" ]]; then
    printf 'missing optional path\n'
    return 0
  fi
  if [[ ! -d "$path/.git" ]]; then
    printf 'not a git checkout\n'
    return 0
  fi

  git -C "$path" status --short --branch
}

artifact_size() {
  local path="$1"
  if [[ -e "$path" ]]; then
    du -sh "$path" 2>/dev/null || printf 'unavailable\t%s\n' "$path"
  else
    printf 'missing\t%s\n' "$path"
  fi
}

count_find_matches() {
  local root="$1"
  local kind="$2"
  local pattern="$3"

  if [[ ! -d "$root" ]]; then
    printf '0'
    return 0
  fi

  if [[ "$kind" == "dir" ]]; then
    find "$root" \
      -path "$ROOT_DIR/.git" -prune -o \
      -path "$ROOT_DIR/TRR-Backend/.git" -prune -o \
      -path "$ROOT_DIR/TRR-APP/.git" -prune -o \
      -path "$ROOT_DIR/screenalytics" -prune -o \
      -path "$ROOT_DIR/BRAVOTV" -prune -o \
      -path "$ROOT_DIR/.external" -prune -o \
      -path "$ROOT_DIR/data" -prune -o \
      -path "$ROOT_DIR/.logs" -prune -o \
      -path "$ROOT_DIR/.plan-work" -prune -o \
      -type d \( -name "node_modules" -o -name ".next" -o -name ".venv" -o -name ".worktrees" \) -prune -o \
      -type d -name "$pattern" -print 2>/dev/null | wc -l | tr -d ' '
  else
    find "$root" \
      -path "$ROOT_DIR/.git" -prune -o \
      -path "$ROOT_DIR/TRR-Backend/.git" -prune -o \
      -path "$ROOT_DIR/TRR-APP/.git" -prune -o \
      -path "$ROOT_DIR/screenalytics" -prune -o \
      -path "$ROOT_DIR/BRAVOTV" -prune -o \
      -path "$ROOT_DIR/.external" -prune -o \
      -path "$ROOT_DIR/data" -prune -o \
      -path "$ROOT_DIR/.logs" -prune -o \
      -path "$ROOT_DIR/.plan-work" -prune -o \
      -type d \( -name "node_modules" -o -name ".next" -o -name ".venv" -o -name ".worktrees" \) -prune -o \
      -type f -name "$pattern" -print 2>/dev/null | wc -l | tr -d ' '
  fi
}

untracked_non_ignored() {
  local label="$1"
  local path="$2"

  printf '\n[%s]\n' "$label"
  if [[ ! -d "$path/.git" ]]; then
    printf 'missing or not a git checkout\n'
    return 0
  fi

  local output
  output="$(git -C "$path" status --short --untracked-files=normal | grep -E '^\?\?' || true)"
  if [[ -n "$output" ]]; then
    printf '%s\n' "$output"
  else
    printf 'none\n'
  fi
}

section "Summary"
cat <<'SUMMARY'
This is a read-only TRR workspace hygiene report.
It checks active roots, large local artifacts, ignored runtime clutter
categories, and untracked non-ignored files.
No files were deleted.
SUMMARY

section "Git Status"
path_status "root workspace" "$ROOT_DIR"
path_status "TRR-Backend" "$ROOT_DIR/TRR-Backend"
path_status "TRR-APP" "$ROOT_DIR/TRR-APP"

section "Large Local Artifacts"
artifact_size "$ROOT_DIR/.logs"
artifact_size "$ROOT_DIR/TRR-Backend/.venv"
artifact_size "$ROOT_DIR/TRR-APP/apps/web/.next"
artifact_size "$ROOT_DIR/.plan-work"
artifact_size "$ROOT_DIR/.artifacts"
artifact_size "$ROOT_DIR/output"
artifact_size "$ROOT_DIR/TRR-Backend/.locks"

section "Ignored Runtime Categories"
printf 'Python cache dirs outside adjacent/evidence paths: %s\n' "$(count_find_matches "$ROOT_DIR" dir "__pycache__")"
printf 'Python bytecode files outside adjacent/evidence paths: %s\n' "$(count_find_matches "$ROOT_DIR" file "*.pyc")"
printf '.DS_Store files outside adjacent/evidence paths: %s\n' "$(count_find_matches "$ROOT_DIR" file ".DS_Store")"
printf 'TRR-Backend/.locks stores backend runtime lock state and is never a cleanup candidate.\n'
printf 'Cleanup candidates are later filtered through git check-ignore before deletion.\n'
printf 'retired screenalytics checkout, .logs, .plan-work, .artifacts, output, locks, dependency/build folders, env, cookies, secrets, and evidence paths are excluded from cleanup.\n'

section "Untracked Non-Ignored Items"
untracked_non_ignored "root workspace" "$ROOT_DIR"
untracked_non_ignored "TRR-Backend" "$ROOT_DIR/TRR-Backend"
untracked_non_ignored "TRR-APP" "$ROOT_DIR/TRR-APP"

section "Active-Root Search Guidance"
cat <<'GUIDANCE'
Default active-source search:
  rg "term" Makefile scripts profiles .codex docs/workspace TRR-Backend/api TRR-Backend/trr_backend TRR-Backend/tests TRR-APP/apps/web/src TRR-APP/apps/web/tests

Old plans under .plan-work are evidence only until the current task names them
and they are revalidated against live files and status.
GUIDANCE

section "Safety Result"
printf 'Report mode is read-only. No files were deleted.\n'
