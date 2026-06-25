#!/bin/sh

set -eu

export TRR_ROOT=${TRR_ROOT:-/Users/thomashulihan/Projects/TRR}
exec /Users/thomashulihan/.codex/bin/codex-scrapling-readiness "$@"
