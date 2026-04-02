#!/usr/bin/env bash
set -euo pipefail

SEED_PROFILE_DIR="${CODEX_CHROME_SEED_PROFILE_DIR:-${HOME}/.chrome-profiles/codex-agent}"
TARGET_GLOB="${HOME}/.chrome-profiles/codex-chat-*"

if [[ ! -d "$SEED_PROFILE_DIR" ]]; then
  echo "[chrome-agent] ERROR: Seed profile not found: ${SEED_PROFILE_DIR}" >&2
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "[chrome-agent] ERROR: rsync is required for seed sync." >&2
  exit 1
fi

shopt -s nullglob
targets=($TARGET_GLOB)
shopt -u nullglob

if [[ "${#targets[@]}" -eq 0 ]]; then
  echo "[chrome-agent] No isolated codex chat profiles found to sync."
  exit 0
fi

for target in "${targets[@]}"; do
  echo "[chrome-agent] Syncing ${target} from ${SEED_PROFILE_DIR}"
  rsync -a \
    --exclude='Cache/' \
    --exclude='Code Cache/' \
    --exclude='GPUCache/' \
    --exclude='GrShaderCache/' \
    --exclude='DawnCache/' \
    --exclude='ShaderCache/' \
    --exclude='Crashpad/' \
    --exclude='Singleton*' \
    "${SEED_PROFILE_DIR}/" \
    "${target}/"
done

echo "[chrome-agent] Seed sync complete."
