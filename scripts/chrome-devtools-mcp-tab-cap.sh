#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"
source "${ROOT}/scripts/lib/chrome-runtime.sh"

usage() {
  cat <<'USAGE' >&2
Usage:
  scripts/chrome-devtools-mcp-tab-cap.sh trim <port> <session-file> [wrapper-pid]
  scripts/chrome-devtools-mcp-tab-cap.sh watch <port> <session-file> [wrapper-pid]

Description:
  Enforces the isolated-session Chrome tab cap for Codex-managed Chrome.
USAGE
  exit 1
}

COMMAND="${1:-}"
PORT="${2:-}"
SESSION_FILE="${3:-}"
WRAPPER_PID_OVERRIDE="${4:-}"
TAB_CAP="${CODEX_CHROME_TAB_CAP:-3}"
TAB_TARGET="${CODEX_CHROME_TAB_TARGET:-1}"
WATCH_INTERVAL="${CODEX_CHROME_TAB_WATCH_INTERVAL_SEC:-2}"
PAGE_ORDER_FILE=""

if [[ -z "$COMMAND" || -z "$PORT" || -z "$SESSION_FILE" ]]; then
  usage
fi

if [[ ! "$PORT" =~ ^[0-9]+$ ]]; then
  echo "[chrome-devtools-tab-cap] ERROR: port must be numeric: ${PORT}" >&2
  exit 1
fi

mkdir -p "$LOG_DIR"
PAGE_ORDER_FILE="${SESSION_FILE%.env}.pages"

read_session_value() {
  local key="$1"
  if [[ ! -f "$SESSION_FILE" ]]; then
    return 0
  fi
  sed -n "s/^${key}=//p" "$SESSION_FILE" | head -n 1
}

write_session_file() {
  local working_tab_id="$1"
  local page_count="$2"
  local wrapper_pid="${3:-}"
  local profile_dir="${4:-}"
  local headless="${5:-0}"
  local mode="${6:-isolated}"
  local last_trim_at

  last_trim_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if [[ -z "$wrapper_pid" ]]; then
    wrapper_pid="$(read_session_value "WRAPPER_PID")"
  fi
  if [[ -z "$profile_dir" ]]; then
    profile_dir="$(read_session_value "PROFILE_DIR")"
  fi
  if [[ -z "$headless" ]]; then
    headless="$(read_session_value "HEADLESS")"
  fi
  if [[ -z "$mode" ]]; then
    mode="$(read_session_value "MODE")"
  fi

  cat >"$SESSION_FILE" <<EOF
MODE=${mode}
PORT=${PORT}
PROFILE_DIR=${profile_dir}
HEADLESS=${headless}
WRAPPER_PID=${wrapper_pid}
TAB_TARGET=${TAB_TARGET}
TAB_CAP=${TAB_CAP}
WORKING_TAB_ID=${working_tab_id}
LAST_PAGE_COUNT=${page_count}
LAST_TRIM_AT=${last_trim_at}
EOF
}

page_metadata() {
  local port="$1"
  chrome_page_targets_tsv "$port" 2>/dev/null || true
}

merge_order_file() {
  local metadata_file="$1"
  python3 - <<'PY' "$PAGE_ORDER_FILE" "$metadata_file"
import pathlib
import sys

order_path = pathlib.Path(sys.argv[1])
metadata_path = pathlib.Path(sys.argv[2])

existing_order = []
if order_path.exists():
    existing_order = [line.strip() for line in order_path.read_text().splitlines() if line.strip()]

current_ids = []
for line in metadata_path.read_text().splitlines():
    if not line.strip():
        continue
    current_ids.append(line.split("\t", 1)[0].strip())

current_set = set(current_ids)
merged = [target_id for target_id in existing_order if target_id in current_set]
seen = set(merged)
for target_id in current_ids:
    if target_id and target_id not in seen:
        merged.append(target_id)
        seen.add(target_id)

order_path.write_text("".join(f"{target_id}\n" for target_id in merged))
PY
}

pick_working_tab() {
  local metadata_file="$1"
  local current_working

  current_working="$(read_session_value "WORKING_TAB_ID")"
  if [[ -n "$current_working" ]] && awk -F $'\t' -v target="$current_working" '$1 == target { found = 1 } END { exit(found ? 0 : 1) }' "$metadata_file"; then
    printf '%s\n' "$current_working"
    return 0
  fi

  awk -F $'\t' '
    function disposable(url) {
      return url ~ /^chrome-error:\/\// || url ~ /^devtools:\/\// || url ~ /^chrome:\/\/newtab/ || url == "" || url == "about:blank"
    }
    !disposable($2) && $1 != "" { print $1; exit }
  ' "$metadata_file"
}

trim_tabs_once() {
  local metadata
  local metadata_file
  local page_count
  local working_tab_id
  local wrapper_pid
  local profile_dir
  local headless
  local mode
  local closed_any=0

  metadata="$(page_metadata "$PORT")"
  metadata_file="$(mktemp "${LOG_DIR}/chrome-tab-metadata.${PORT}.XXXXXX")"
  printf '%s\n' "$metadata" >"$metadata_file"

  page_count="$(printf '%s\n' "$metadata" | sed '/^$/d' | wc -l | tr -d ' ')"
  wrapper_pid="${WRAPPER_PID_OVERRIDE:-$(read_session_value "WRAPPER_PID")}"
  profile_dir="$(read_session_value "PROFILE_DIR")"
  headless="$(read_session_value "HEADLESS")"
  mode="$(read_session_value "MODE")"

  if [[ "$page_count" == "0" ]]; then
    write_session_file "" "0" "$wrapper_pid" "$profile_dir" "$headless" "$mode"
    rm -f "$metadata_file"
    return 0
  fi

  merge_order_file "$metadata_file"
  working_tab_id="$(pick_working_tab "$metadata_file")"
  if [[ -z "$working_tab_id" ]]; then
    working_tab_id="$(awk -F $'\t' 'NF { print $1; exit }' "$metadata_file")"
  fi

  while (( page_count > TAB_CAP )); do
    local candidate_id=""
    candidate_id="$(
      python3 - <<'PY' "$PAGE_ORDER_FILE" "$metadata_file" "$working_tab_id"
import pathlib
import sys

order_path = pathlib.Path(sys.argv[1])
metadata_path = pathlib.Path(sys.argv[2])
working_tab_id = sys.argv[3].strip()

order = [line.strip() for line in order_path.read_text().splitlines() if line.strip()] if order_path.exists() else []
meta = {}
for line in metadata_path.read_text().splitlines():
    if not line.strip():
        continue
    parts = line.split("\t")
    target_id = parts[0].strip()
    url = parts[1].strip() if len(parts) > 1 else ""
    meta[target_id] = url

order = [target_id for target_id in order if target_id in meta]
recent = set(order[-2:])
protected = set(recent)
if working_tab_id:
    protected.add(working_tab_id)

def disposable(url: str) -> bool:
    return (
        url.startswith("chrome-error://")
        or url.startswith("devtools://")
        or url.startswith("chrome://newtab")
        or url in {"", "about:blank"}
    )

for disposable_only in (True, False):
    for target_id in order:
        if target_id in protected:
            continue
        url = meta.get(target_id, "")
        if disposable_only and not disposable(url):
            continue
        print(target_id)
        raise SystemExit(0)
raise SystemExit(1)
PY
    )" || true

    if [[ -z "$candidate_id" ]]; then
      break
    fi

    if chrome_close_target "$PORT" "$candidate_id"; then
      closed_any=1
      python3 - <<'PY' "$PAGE_ORDER_FILE" "$candidate_id"
import pathlib
import sys

order_path = pathlib.Path(sys.argv[1])
target_id = sys.argv[2].strip()
if not order_path.exists():
    raise SystemExit(0)
remaining = [line.strip() for line in order_path.read_text().splitlines() if line.strip() and line.strip() != target_id]
order_path.write_text("".join(f"{entry}\n" for entry in remaining))
PY
    else
      break
    fi

    metadata="$(page_metadata "$PORT")"
    printf '%s\n' "$metadata" >"$metadata_file"
    page_count="$(printf '%s\n' "$metadata" | sed '/^$/d' | wc -l | tr -d ' ')"
    merge_order_file "$metadata_file"
    if [[ "$working_tab_id" == "$candidate_id" ]]; then
      working_tab_id="$(pick_working_tab "$metadata_file")"
    fi
  done

  write_session_file "$working_tab_id" "$page_count" "$wrapper_pid" "$profile_dir" "$headless" "$mode"
  rm -f "$metadata_file"

  if [[ "$closed_any" == "1" ]]; then
    echo "[chrome-devtools-tab-cap] Trimmed isolated Chrome session on port ${PORT} to ${page_count} tab(s)." >&2
  fi
}

watch_tabs() {
  # Capture the wrapper's start time at launch to detect PID recycling.
  local _wrapper_start_time=""
  if [[ -n "${WRAPPER_PID_OVERRIDE:-}" ]]; then
    _wrapper_start_time="$(ps -o lstart= -p "$WRAPPER_PID_OVERRIDE" 2>/dev/null | xargs)"
  fi
  while true; do
    if [[ -n "${WRAPPER_PID_OVERRIDE:-}" ]]; then
      if ! kill -0 "$WRAPPER_PID_OVERRIDE" 2>/dev/null; then
        exit 0
      fi
      # Guard against PID recycling: if the process at WRAPPER_PID has a
      # different start time than when we launched, it's a different process.
      if [[ -n "$_wrapper_start_time" ]]; then
        local _current_start
        _current_start="$(ps -o lstart= -p "$WRAPPER_PID_OVERRIDE" 2>/dev/null | xargs)"
        if [[ -n "$_current_start" && "$_current_start" != "$_wrapper_start_time" ]]; then
          exit 0
        fi
      fi
    fi
    if [[ -f "$SESSION_FILE" ]]; then
      local live_wrapper_pid
      live_wrapper_pid="$(read_session_value "WRAPPER_PID")"
      if [[ -n "$live_wrapper_pid" ]] && ! kill -0 "$live_wrapper_pid" 2>/dev/null; then
        exit 0
      fi
    fi
    if ! chrome_endpoint_reachable "$PORT"; then
      sleep "$WATCH_INTERVAL"
      continue
    fi
    trim_tabs_once
    sleep "$WATCH_INTERVAL"
  done
}

case "$COMMAND" in
  trim)
    trim_tabs_once
    ;;
  watch)
    watch_tabs
    ;;
  *)
    usage
    ;;
esac
