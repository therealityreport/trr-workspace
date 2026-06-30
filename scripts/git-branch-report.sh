#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DEFAULT_BRANCH="${TRR_GIT_DEFAULT_BRANCH:-main}"
DEFAULT_REMOTE="${TRR_GIT_DEFAULT_REMOTE:-origin}"
QUIET_CLEAN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet-clean)
      QUIET_CLEAN=1
      shift
      ;;
    --help|-h)
      cat <<'EOF'
Usage: bash scripts/git-branch-report.sh [--quiet-clean]

Reports local or remote branch refs outside main. The script is read-only and
does not fetch, merge, delete, or create branch refs.
EOF
      exit 0
      ;;
    *)
      echo "[git-branch-report] ERROR: unknown argument $1" >&2
      exit 2
      ;;
  esac
done

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[git-branch-report] ERROR: $ROOT is not a Git worktree" >&2
  exit 1
fi

if ! git rev-parse --verify --quiet "$DEFAULT_BRANCH" >/dev/null; then
  echo "[git-branch-report] ERROR: default branch '$DEFAULT_BRANCH' does not exist locally" >&2
  exit 1
fi

current_branch="$(git branch --show-current 2>/dev/null || true)"
if [[ -z "$current_branch" ]]; then
  current_branch="(detached)"
fi

local_branches=()
while IFS= read -r branch; do
  local_branches+=("$branch")
done < <(git for-each-ref refs/heads --format='%(refname:short)' | LC_ALL=C sort)

remote_branches=()
while IFS= read -r branch; do
  remote_branches+=("$branch")
done < <(git for-each-ref refs/remotes --format='%(refname:short)' | LC_ALL=C sort)

extra_local=()
for branch in "${local_branches[@]}"; do
  [[ "$branch" == "$DEFAULT_BRANCH" ]] && continue
  extra_local+=("$branch")
done

extra_remote=()
for branch in "${remote_branches[@]}"; do
  [[ "$branch" == "$DEFAULT_REMOTE" ]] && continue
  [[ "$branch" == */HEAD ]] && continue
  [[ "$branch" == "${DEFAULT_REMOTE}/${DEFAULT_BRANCH}" ]] && continue
  extra_remote+=("$branch")
done

if [[ "${#extra_local[@]}" -eq 0 && "${#extra_remote[@]}" -eq 0 ]]; then
  if [[ "$QUIET_CLEAN" != "1" ]]; then
    echo "[git-branch-report] OK: only ${DEFAULT_BRANCH} local and ${DEFAULT_REMOTE}/${DEFAULT_BRANCH} remote refs are present."
  fi
  exit 0
fi

echo "[git-branch-report] WARNING: extra branch refs exist in this workspace."
echo "[git-branch-report] current=${current_branch} default=${DEFAULT_BRANCH} remote=${DEFAULT_REMOTE}/${DEFAULT_BRANCH}"
echo "[git-branch-report] Keep docs/plans and implementation edits on the current branch unless the user says: create a new branch named <branch>."

describe_ref() {
  local ref="$1"
  local label="$2"
  local upstream main_only ref_only tree_status history_status changed_files

  upstream="$(git for-each-ref "refs/heads/${ref}" --format='%(upstream:short)' 2>/dev/null || true)"
  if [[ -z "$upstream" ]]; then
    upstream="-"
  fi

  read -r main_only ref_only < <(git rev-list --left-right --count "${DEFAULT_BRANCH}...${ref}" 2>/dev/null || printf '?\t?')

  if git diff --quiet "$DEFAULT_BRANCH" "$ref" --; then
    tree_status="same-as-${DEFAULT_BRANCH}"
  else
    tree_status="differs-from-${DEFAULT_BRANCH}"
  fi

  if git merge-base --is-ancestor "$ref" "$DEFAULT_BRANCH" >/dev/null 2>&1; then
    history_status="ancestor-of-${DEFAULT_BRANCH}"
  else
    history_status="not-ancestor-of-${DEFAULT_BRANCH}"
  fi

  echo "[git-branch-report] ${label}: ${ref} upstream=${upstream} ${DEFAULT_BRANCH}_only=${main_only} ref_only=${ref_only} tree=${tree_status} history=${history_status}"

  if [[ "$tree_status" != "same-as-${DEFAULT_BRANCH}" ]]; then
    changed_files="$(git diff --name-only "$DEFAULT_BRANCH" "$ref" -- | sed -n '1,8p' | paste -sd ',' - | sed 's/,/, /g')"
    if [[ -n "$changed_files" ]]; then
      echo "[git-branch-report] ${label}: ${ref} changed_files=${changed_files}"
    fi
  fi
}

if [[ "${#extra_local[@]}" -gt 0 ]]; then
  for branch in "${extra_local[@]}"; do
    describe_ref "$branch" "local"
  done
fi

if [[ "${#extra_remote[@]}" -gt 0 ]]; then
  for branch in "${extra_remote[@]}"; do
    describe_ref "$branch" "remote"
  done
fi

echo "[git-branch-report] Cleanup rule: keep desired content on ${DEFAULT_BRANCH}, then delete redundant refs. This report does not delete anything."
