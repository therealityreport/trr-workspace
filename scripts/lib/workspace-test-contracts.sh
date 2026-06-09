#!/usr/bin/env bash

trr_workspace_pytest_contracts() {
  local root="$1"
  python3 -m pytest -q \
    "$root/scripts/test_env_hygiene.py" \
    "$root/scripts/test_instagram_auth_freshness.py" \
    "$root/scripts/test_modal_billing_guardrail.py" \
    "$root/scripts/test_workspace_app_env_projection.py"
}
