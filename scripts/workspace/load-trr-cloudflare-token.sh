#!/usr/bin/env bash
set -euo pipefail

token="$(security find-generic-password -a TRR_CLOUDFLARE_API_TOKEN -s co.thomashulihan.trr.cloudflare-api-token -w)"
escaped="$(printf '%s' "$token" | sed "s/'/'\\\\''/g")"
printf "export TRR_CLOUDFLARE_API_TOKEN='%s'\n" "$escaped"
