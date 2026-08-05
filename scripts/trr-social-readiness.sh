#!/bin/sh

set -eu

export TRR_ROOT=${TRR_ROOT:-/Users/thomashulihan/Projects/TRR}
export SCRAPLING_PLUGIN_ROOT=${SCRAPLING_PLUGIN_ROOT:-"$HOME/.codex/plugins/cache/local-plugins/scrapling/local"}
exec /Users/thomashulihan/.codex/bin/codex-scrapling-readiness "$@"
