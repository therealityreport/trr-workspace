#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || $# -eq 0 ]]; then
  cat <<'USAGE'
Usage:
  ./scripts/render-trr.sh preflight --service-id ID --commit SHA
  ./scripts/render-trr.sh deploy --service-id ID --commit SHA --previous-deploy-id DEPLOY_ID
  ./scripts/render-trr.sh status --service-id ID --deploy-id DEPLOY_ID --commit SHA
  ./scripts/render-trr.sh rollback --service-id ID --deploy-id DEPLOY_ID --commit SHA

Deploy requires TRR_RENDER_ALLOW_MUTATION=1 after current-chat approval.
Rollback additionally requires TRR_RENDER_ALLOW_ROLLBACK=1.
USAGE
  exit 0
fi

case "$1" in
  preflight|deploy|status|rollback) ;;
  *)
    echo "render-trr: ERROR: expected preflight, deploy, status, or rollback." >&2
    exit 2
    ;;
esac

exec python3 "$ROOT/scripts/render_trr.py" "$@"
