#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:${PATH}"
if [[ -n "${PORTLESS_PORT:-}" && "${PORTLESS_PORT}" != "443" ]]; then
  cat >&2 <<EOF
[portless-repair] ERROR: PORTLESS_PORT=${PORTLESS_PORT} would publish numbered TRR dev URLs.
[portless-repair] ERROR: unset PORTLESS_PORT and use clean Portless URLs:
  https://admin.trr.localhost
  https://trr.localhost
  https://api.trr.localhost/health/live
EOF
  exit 2
fi

if ! command -v portless >/dev/null 2>&1; then
  echo "[portless-repair] portless CLI was not found. Install/start Portless, then rerun make portless-repair." >&2
  exit 127
fi

echo "[portless-repair] Ensuring Portless proxy is running with wildcard host routing..."
existing_proxy_lines="$(pgrep -fl "portless proxy start" || true)"
if grep -Eq -- '--port[ =][0-9]+' <<<"$existing_proxy_lines"; then
  cat >&2 <<EOF
[portless-repair] ERROR: a Portless proxy is already running with an explicit numeric port.
[portless-repair] ERROR: stop that proxy, then rerun make dev-hybrid so clean URLs bind on the default Portless port.
[portless-repair] Existing proxy process:
${existing_proxy_lines}
EOF
  exit 2
fi
if pgrep -f "portless proxy start .*--wildcard" >/dev/null 2>&1; then
  echo "[portless-repair] Portless proxy is already running in wildcard mode."
else
  proxy_args=(--wildcard)
  portless proxy start "${proxy_args[@]}"
fi

echo "[portless-repair] Removing stale static TRR aliases so managed routes own clean URLs..."
for route in trr admin.trr api.trr wordle.trr; do
  if portless alias --remove "$route" >/dev/null 2>&1; then
    echo "[portless-repair] Removed static alias: $route"
  else
    echo "[portless-repair] No static alias to remove: $route"
  fi
done

if [[ "${PORTLESS_SYNC_HOSTS:-1}" == "0" ]]; then
  echo "[portless-repair] Skipping hosts sync because PORTLESS_SYNC_HOSTS=0."
else
  echo "[portless-repair] Syncing hosts for Portless clean URLs..."
  portless hosts sync
fi

routes="$(portless list || true)"
if grep -Eq 'https://(admin[.]trr|trr|api[.]trr)[.]localhost:[0-9]+' <<<"$routes"; then
  cat >&2 <<EOF
[portless-repair] ERROR: numeric TRR Portless routes are active. Clean URLs are required.
[portless-repair] Current Portless routes:
${routes:-  <none>}
EOF
  exit 2
fi
if ! grep -Eq 'https://trr[.]localhost[[:space:]]+->[[:space:]]+localhost:[0-9]+' <<<"$routes"; then
  if [[ "${PORTLESS_REPAIR_ALLOW_NO_ACTIVE_ROUTES:-0}" == "1" ]]; then
    cat <<EOF
[portless-repair] No active trr.localhost app route is running yet.
[portless-repair] Proxy, stale aliases, and hosts were prepared for a managed cold start.
EOF
    exit 0
  fi

  cat >&2 <<EOF
[portless-repair] ERROR: no active trr.localhost app route is running.
[portless-repair] Portless can repair hosts and proxy state, but admin.trr.localhost has no app target until the app route is registered.

[portless-repair] Start the normal TRR hybrid workspace:
  cd "$ROOT_DIR" && make dev-hybrid

[portless-repair] Then rerun:
  cd "$ROOT_DIR" && make portless-repair

[portless-repair] Current Portless routes:
${routes:-  <none>}
EOF
  exit 2
fi

echo "[portless-repair] Admin host routing is preserved through wildcard fallback; no admin.trr static alias is created."

echo "[portless-repair] Current routes:"
printf '%s\n' "$routes"

cat <<EOF

[portless-repair] Clean TRR URLs:
  Admin: https://admin.trr.localhost
  App:   https://trr.localhost
  API:   https://api.trr.localhost/health/live
  Wordle: https://wordle.trr.localhost

[portless-repair] Start the normal TRR hybrid workspace with:
  cd "$ROOT_DIR" && make dev-hybrid

[portless-repair] If Wordle or separate screen sessions are the target, use:
  cd "$ROOT_DIR" && make dev-portless
EOF
