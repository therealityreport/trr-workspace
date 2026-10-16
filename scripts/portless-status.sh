#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:${PATH}"
source "$ROOT_DIR/scripts/lib/portless-startup-check.sh"

status_tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/trr-portless-status.XXXXXX")"
trap 'rm -rf "$status_tmp_dir"' EXIT
version_out="$status_tmp_dir/version.out"
version_err="$status_tmp_dir/version.err"
service_out="$status_tmp_dir/service.out"
service_err="$status_tmp_dir/service.err"
routes_out="$status_tmp_dir/routes.out"
routes_err="$status_tmp_dir/routes.err"

echo "[portless-status] Clean TRR URLs:"
echo "  Admin: https://admin.trr.localhost"
echo "  App:   https://trr.localhost"
echo "  API:   https://api.trr.localhost/health/live"
echo ""

if ! command -v portless >/dev/null 2>&1; then
  echo "[portless-status] ERROR: portless CLI was not found." >&2
  echo "[portless-status] Install or repair Portless, then rerun make dev-hybrid." >&2
  exit 127
fi

echo "[portless-status] CLI:"
if portless --version >"$version_out" 2>"$version_err"; then
  sed 's/^/  version: /' "$version_out"
else
  echo "  version: unavailable"
  sed 's/^/  /' "$version_err" || true
fi

echo ""
echo "[portless-status] Service:"
if portless service status >"$service_out" 2>"$service_err"; then
  sed 's/^/  /' "$service_out"
else
  echo "  service status unavailable"
  sed 's/^/  /' "$service_err" || true
fi

echo ""
echo "[portless-status] Proxy process:"
proxy_lines="$(trr_portless_proxy_lines)"
wildcard_proxy_ready=0
if trr_portless_has_wildcard_proxy; then
  wildcard_proxy_ready=1
fi
if [[ -n "$proxy_lines" ]]; then
  printf '%s\n' "$proxy_lines" | sed 's/^/  /'
elif [[ "$wildcard_proxy_ready" == "1" ]]; then
  echo "  Project Manager managed router is ready on HTTPS 443 with localhost wildcard routing"
else
  echo "  no ready wildcard proxy found"
fi

echo ""
echo "[portless-status] Routes:"
if portless list >"$routes_out" 2>"$routes_err"; then
  sed 's/^/  /' "$routes_out"
else
  echo "  route list unavailable"
  sed 's/^/  /' "$routes_err" || true
fi

echo ""
echo "[portless-status] Browser-test readiness:"
routes="$(portless list 2>/dev/null || true)"
if [[ "$wildcard_proxy_ready" != "1" ]]; then
  echo "  blocked: wildcard proxy is not running"
elif ! grep -Eq "https://trr[.]localhost[[:space:]]+->[[:space:]]+(localhost|127[.]0[.]0[.]1):[0-9]+" <<<"$routes"; then
  echo "  blocked: trr.localhost app route is missing"
elif ! grep -Eq "https://api[.]trr[.]localhost[[:space:]]+->[[:space:]]+(localhost|127[.]0[.]0[.]1):[0-9]+" <<<"$routes"; then
  echo "  blocked: api.trr.localhost API route is missing"
elif grep -Eq "https://admin[.]trr[.]localhost(:[0-9]+)?[[:space:]]+->[[:space:]]+" <<<"$routes"; then
  echo "  blocked: admin.trr.localhost is a static route; it must use wildcard fallback"
elif grep -Eq "https://(admin[.]trr|trr|api[.]trr)[.]localhost:[0-9]+" <<<"$routes"; then
  echo "  blocked: numbered TRR routes are active"
else
  echo "  ready: clean app and API routes are registered; admin uses wildcard fallback"
fi

echo ""
echo "[portless-status] Next commands:"
echo "  cd \"$ROOT_DIR\" && make portless-repair"
echo "  cd \"$ROOT_DIR\" && make dev-hybrid"
