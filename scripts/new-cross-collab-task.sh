#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<USAGE
Usage:
  $0 --repos TRR-Backend,TRR-APP --title "Task title" [--date YYYY-MM-DD]

Options:
  --repos  Comma-separated repos from: TRR-Backend, TRR-APP
  --title  Task title used in generated docs
  --date   Optional date override (default: today)
USAGE
}

REPOS=""
TITLE=""
DATE_OVERRIDE=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --repos)
      REPOS="${2:-}"
      shift 2
      ;;
    --title)
      TITLE="${2:-}"
      shift 2
      ;;
    --date)
      DATE_OVERRIDE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$REPOS" || -z "$TITLE" ]]; then
  usage
  exit 1
fi

DATE_VALUE="${DATE_OVERRIDE:-$(date +%Y-%m-%d)}"

is_valid_repo() {
  case "$1" in
    TRR-Backend|TRR-APP)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

next_task_number() {
  local repo="$1"
  local base="$ROOT/$repo/docs/cross-collab"

  mkdir -p "$base"
  local max="0"
  while IFS= read -r item; do
    local n
    n="${item#TASK}"
    if [[ "$n" =~ ^[0-9]+$ ]] && (( n > max )); then
      max="$n"
    fi
  done < <(ls -1 "$base" 2>/dev/null | rg '^TASK[0-9]+$' || true)

  echo $((max + 1))
}

create_task_docs() {
  local repo="$1"
  local task_no="$2"
  local task_dir="$ROOT/$repo/docs/cross-collab/TASK${task_no}"

  mkdir -p "$task_dir"

  cat > "$task_dir/PLAN.md" <<PLAN
# ${TITLE} — Task ${task_no} Plan

Repo: ${repo}
Last updated: ${DATE_VALUE}

## Goal
${TITLE}

## Status Snapshot
Not yet started.

## Scope

### Phase 1: Implement
Describe implementation details for ${repo}.

Files to change:
- 

## Out of Scope
- Items owned by other repos unless explicitly required.

## Locked Contracts
- Keep shared API/schema contracts synchronized across affected repos.

## Acceptance Criteria
1. ${repo} changes complete and validated.
2. Cross-repo dependency order is respected.
3. Fast checks pass for ${repo}.
4. Task docs remain synchronized.
PLAN

  cat > "$task_dir/OTHER_PROJECTS.md" <<OTHER
# Other Projects — Task ${task_no} (${TITLE})

Repo: ${repo}
Last updated: ${DATE_VALUE}

## Cross-Repo Snapshot
- TRR-Backend: TODO
- TRR-APP: TODO

## Responsibility Alignment
- TRR-Backend
  - TODO
- TRR-APP
  - TODO

## Dependency Order
1. TRR-Backend
2. TRR-APP

## Locked Contracts (Mirrored)
- Keep shared contracts aligned with owning repo PLAN.md.
OTHER

  cat > "$task_dir/STATUS.md" <<STATUS
# Status — Task ${task_no} (${TITLE})

Repo: ${repo}
Last updated: ${DATE_VALUE}

## Phase Status

| Phase | Description | Status | Notes |
|---|---|---|---|
| 1 | Implementation | Pending | Not started |

## Blockers
- None.

## Recent Activity
- ${DATE_VALUE}: Task scaffolding created.
STATUS

  echo "[new-task] Created ${task_dir}"
}

IFS=',' read -r -a repo_list <<< "$REPOS"
for repo in "${repo_list[@]}"; do
  repo="${repo## }"
  repo="${repo%% }"
  if ! is_valid_repo "$repo"; then
    echo "[new-task] ERROR: invalid repo '${repo}'." >&2
    exit 1
  fi
  task_no="$(next_task_number "$repo")"
  create_task_docs "$repo" "$task_no"
done

echo "[new-task] Done."
