# Plan 018: Refresh the Supabase JWT issuer and audience decision

> **Executor instructions**: This is a decision-refresh plan. Do not change auth
> behavior unless the code and docs prove the old compatibility carve-out is no
> longer needed.
>
> **Drift check**: `git -C TRR-Backend diff --stat 8ea7aa1a..HEAD -- trr_backend/security/jwt.py tests/security/test_jwt.py README.md .env.example`

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: security
- **Planned at**: TRR-Backend `8ea7aa1a`, 2026-07-07

## Why this matters

JWT verification disables PyJWT's built-in issuer and audience checks, then
performs a manual issuer/project-ref check with a legacy `service_role`
`iss="supabase"` carve-out. The README documents that decision. This should be
periodically revalidated because auth assumptions age poorly.

## Current state

- `trr_backend/security/jwt.py:143` sets `verify_aud: False`.
- `trr_backend/security/jwt.py:145` sets `verify_iss: False`.
- `trr_backend/security/jwt.py:167` manually rejects unexpected issuers except
  legacy service-role tokens with `iss="supabase"`.
- `tests/security/test_jwt.py` includes a test that accepts the legacy
  service-role issuer.
- `README.md:138` documents this compatibility behavior.

## Scope

**In scope**:
- `trr_backend/security/jwt.py`
- `tests/security/test_jwt.py`
- `README.md` / `.env.example` docs if the decision remains

**Out of scope**:
- Rotating secrets.
- Changing Supabase project configuration.

## Steps

1. Confirm which token issuers are currently accepted in tests and production
   docs.
2. Add tests that pin the intended issuer/audience behavior explicitly.
3. If legacy `iss="supabase"` is still required, leave behavior unchanged and
   add a dated comment/doc note naming the reason and revisit condition.
4. If it is no longer required, remove the carve-out and update tests/docs.

## Commands

Run from `TRR-Backend/`:

```bash
.venv/bin/python -m pytest tests/security/test_jwt.py -q
ruff check trr_backend/security/jwt.py tests/security/test_jwt.py
```

## Done criteria

- The JWT issuer/audience decision is explicit in tests.
- Docs match the behavior.
- No accidental auth expansion is introduced.
