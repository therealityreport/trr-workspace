#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:${PATH}"
PORTLESS_PUBLIC_PORT_SUFFIX=""
if [[ -n "${PORTLESS_PORT:-}" && "${PORTLESS_PORT}" != "443" ]]; then
  PORTLESS_PUBLIC_PORT_SUFFIX=":${PORTLESS_PORT}"
fi

if ! command -v portless >/dev/null 2>&1; then
  echo "[portless-repair] portless CLI was not found. Install/start Portless, then rerun make portless-repair." >&2
  exit 127
fi

echo "[portless-repair] Ensuring Portless proxy is running with wildcard host routing..."
if pgrep -f "portless proxy start .*--wildcard" >/dev/null 2>&1; then
  echo "[portless-repair] Portless proxy is already running in wildcard mode."
else
  proxy_args=(--wildcard)
  if [[ -n "${PORTLESS_PORT:-}" && "${PORTLESS_PORT}" != "443" ]]; then
    proxy_args+=(--port "$PORTLESS_PORT" --https)
  fi
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
if ! grep -Eq 'https://trr[.]localhost(:[0-9]+)?[[:space:]]+->[[:space:]]+localhost:[0-9]+' <<<"$routes"; then
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

[portless-repair] Start the managed TRR app route:
  cd "$ROOT_DIR" && make dev-portless

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
  Admin: https://admin.trr.localhost${PORTLESS_PUBLIC_PORT_SUFFIX}
  App:   https://trr.localhost${PORTLESS_PUBLIC_PORT_SUFFIX}
  API:   https://api.trr.localhost${PORTLESS_PUBLIC_PORT_SUFFIX}/health/live
  Wordle: https://wordle.trr.localhost${PORTLESS_PUBLIC_PORT_SUFFIX}

[portless-repair] Start TRR through managed Portless routes with:
  cd "$ROOT_DIR" && make dev-portless
EOF
