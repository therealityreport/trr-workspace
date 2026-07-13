#!/usr/bin/env bash

trr_portless_agent_noninteractive() {
  [[ "${CI:-}" == "1" || "${CODEX_CI:-}" == "1" || ! -t 0 ]]
}

trr_portless_has_passwordless_sudo() {
  command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1
}

trr_portless_proxy_lines() {
  pgrep -fl "portless proxy start" || true
}

trr_portless_has_wildcard_proxy() {
  pgrep -f "portless proxy start .*--wildcard" >/dev/null 2>&1
}

trr_portless_has_disallowed_numeric_proxy_port() {
  local proxy_lines="${1:-}"
  if grep -E -- '(^|[[:space:]])(--port[ =]|-p[[:space:]])[0-9]+' <<<"$proxy_lines" \
    | grep -Ev -- '(^|[[:space:]])(--port[ =]|-p[[:space:]])443([[:space:]]|$)' \
      >/dev/null; then
    return 0
  fi
  return 1
}

trr_portless_print_clean_urls() {
  local label="${1:-portless}"
  cat >&2 <<EOF
[${label}] Clean TRR URLs:
  Admin: https://admin.trr.localhost
  App:   https://trr.localhost
  API:   https://api.trr.localhost/health/live
EOF
}

trr_portless_print_status_command() {
  local label="${1:-portless}"
  local root_dir="${2:-$(pwd)}"
  cat >&2 <<EOF
[${label}] Diagnose current Portless state with:
  cd "$root_dir" && make portless-status
EOF
}

trr_portless_require_cli_and_clean_proxy_config() {
  local label="${1:-portless}"
  export PATH="/opt/homebrew/bin:${PATH}"
  if [[ -n "${PORTLESS_PORT:-}" && "${PORTLESS_PORT}" != "443" ]]; then
    cat >&2 <<EOF
[${label}] ERROR: PORTLESS_PORT=${PORTLESS_PORT} would publish numbered TRR dev URLs.
[${label}] ERROR: unset PORTLESS_PORT and use clean Portless URLs.
EOF
    trr_portless_print_clean_urls "$label"
    return 2
  fi

  if ! command -v portless >/dev/null 2>&1; then
    echo "[${label}] ERROR: the portless CLI was not found." >&2
    echo "[${label}] ERROR: install or repair Portless, then rerun make dev-hybrid." >&2
    return 127
  fi

  local existing_proxy_lines
  existing_proxy_lines="$(trr_portless_proxy_lines)"
  if trr_portless_has_disallowed_numeric_proxy_port "$existing_proxy_lines"; then
    cat >&2 <<EOF
[${label}] ERROR: a Portless proxy is already running with an explicit numeric port.
[${label}] ERROR: stop that proxy, then rerun make dev-hybrid so clean URLs bind on the default Portless port.
[${label}] Existing proxy process:
${existing_proxy_lines}
EOF
    return 2
  fi
}

trr_portless_require_proxy_start_allowed() {
  local label="${1:-portless}"
  local root_dir="${2:-$(pwd)}"
  trr_portless_require_cli_and_clean_proxy_config "$label" || return $?

  if trr_portless_has_wildcard_proxy; then
    return 0
  fi

  if [[ "${TRR_PORTLESS_ALLOW_PROXY_START:-0}" == "1" ]]; then
    if trr_portless_agent_noninteractive && ! trr_portless_has_passwordless_sudo; then
      cat >&2 <<EOF
[${label}] ERROR: TRR_PORTLESS_ALLOW_PROXY_START=1 was set, but this non-interactive shell cannot satisfy Portless sudo.
[${label}] Portless needs administrator approval to bind the local HTTPS wildcard proxy on port 443.
EOF
      trr_portless_print_clean_urls "$label"
      cat >&2 <<EOF

[${label}] Run the repair from an interactive terminal where macOS can ask for your password:
  cd "$root_dir" && make portless-repair
  cd "$root_dir" && make dev-hybrid

[${label}] Then rerun the Browser smoke test.
EOF
      return 2
    fi
    return 0
  fi

  if trr_portless_agent_noninteractive; then
    cat >&2 <<EOF
[${label}] ERROR: Portless wildcard proxy is not running.
[${label}] Browser tests require the clean TRR admin host before they open the app.
EOF
    trr_portless_print_clean_urls "$label"
    cat >&2 <<EOF

[${label}] This Codex/non-interactive shell will not start Portless automatically because binding HTTPS on port 443 can require sudo.
[${label}] Start or repair Portless from an interactive terminal, then rerun the Browser test:
  cd "$root_dir" && make portless-repair
  cd "$root_dir" && make dev-hybrid

[${label}] To print the current proxy, service, and route state:
  cd "$root_dir" && make portless-status

[${label}] To intentionally let this shell start the proxy, rerun with:
  TRR_PORTLESS_ALLOW_PROXY_START=1 make dev-hybrid
EOF
    return 2
  fi
}

trr_portless_require_browser_routes() {
  local label="${1:-browser-smoke}"
  local root_dir="${2:-$(pwd)}"
  trr_portless_require_cli_and_clean_proxy_config "$label" || return $?

  if ! trr_portless_has_wildcard_proxy; then
    cat >&2 <<EOF
[${label}] ERROR: Portless wildcard proxy is not running, so Browser tests cannot use admin.trr.localhost.
EOF
    trr_portless_print_clean_urls "$label"
    cat >&2 <<EOF

[${label}] Start the normal TRR hybrid workspace first:
  cd "$root_dir" && make dev-hybrid
EOF
    trr_portless_print_status_command "$label" "$root_dir"
    return 2
  fi

  local routes
  routes="$(portless list 2>&1 || true)"
  if grep -Eq "https://(admin[.]trr|trr|api[.]trr)[.]localhost:[0-9]+" <<<"$routes"; then
    cat >&2 <<EOF
[${label}] ERROR: numeric TRR Portless routes are active. Browser tests require clean URLs.
[${label}] Current Portless routes:
${routes:-  <none>}
EOF
    return 2
  fi
  if grep -Eq "https://admin[.]trr[.]localhost(:[0-9]+)?[[:space:]]+->[[:space:]]+" <<<"$routes"; then
    cat >&2 <<EOF
[${label}] ERROR: admin.trr.localhost is registered as its own Portless route.
[${label}] ERROR: admin routing must remain wildcard fallback through trr.localhost.
[${label}] Current Portless routes:
${routes:-  <none>}
EOF
    return 2
  fi
  if ! grep -Eq "https://trr[.]localhost[[:space:]]+->[[:space:]]+(localhost|127[.]0[.]0[.]1):[0-9]+" <<<"$routes"; then
    cat >&2 <<EOF
[${label}] ERROR: no active trr.localhost Portless app route is running.
[${label}] Portless itself is ready, but the TRR app has not connected to Portless yet.
[${label}] In plain terms: the clean web address exists, but there is no running app behind it.
[${label}] Current Portless routes:
${routes:-  <none>}

[${label}] Start the normal TRR hybrid workspace:
  cd "$root_dir" && make dev-hybrid
EOF
    trr_portless_print_status_command "$label" "$root_dir"
    return 2
  fi
  if ! grep -Eq "https://api[.]trr[.]localhost[[:space:]]+->[[:space:]]+(localhost|127[.]0[.]0[.]1):[0-9]+" <<<"$routes"; then
    cat >&2 <<EOF
[${label}] ERROR: no active api.trr.localhost Portless API route is running.
[${label}] Browser tests need the API route before opening the admin app.
[${label}] Current Portless routes:
${routes:-  <none>}

[${label}] Start the normal TRR hybrid workspace:
  cd "$root_dir" && make dev-hybrid
EOF
    trr_portless_print_status_command "$label" "$root_dir"
    return 2
  fi
}
