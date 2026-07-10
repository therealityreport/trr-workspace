# TRR Cloudflare Account Pairing

TRR Cloudflare work must use the account that owns `thereality.report`.

| Field | Value |
|---|---|
| Account name | `Admin@thereality.report's Account` |
| Account ID | `73204b3e632bd7137a1bd2c867dc8ae8` |
| R2 endpoint | `https://73204b3e632bd7137a1bd2c867dc8ae8.r2.cloudflarestorage.com` |

Do not use the THB-BBL / `tommyhulihanbasketball.com` Cloudflare account for TRR.

## Token Names

- `TRR_CLOUDFLARE_API_TOKEN`: Cloudflare management/API token for MCP and account operations.
- R2 API Token: Cloudflare R2 token that creates an S3-compatible Access Key ID and Secret Access Key for object storage.

These are not interchangeable.

## Local Loading

The TRR management token is stored in macOS Keychain, not in repo files.

```sh
eval "$(/Users/thomashulihan/Projects/TRR/scripts/workspace/load-trr-cloudflare-token.sh)"
```

The inherited Cloudflare plugin reads this process environment variable. TRR
does not register a second project-local Cloudflare MCP; account safety comes
from loading `TRR_CLOUDFLARE_API_TOKEN` and verifying the account ID before
performing project work.

## Verify Pairing

```sh
curl -fsS \
  -H "Authorization: Bearer $TRR_CLOUDFLARE_API_TOKEN" \
  https://api.cloudflare.com/client/v4/accounts
```

The response should show only account ID `73204b3e632bd7137a1bd2c867dc8ae8`.
