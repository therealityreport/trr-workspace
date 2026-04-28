# Index Advisor Social Hot Path Baseline - 2026-04-28

This note records the starting point for the TRR social hot-path `index_advisor` workflow. It is evidence-only and does not approve any index creation or index removal.

## Live Extension State

Read-only check against the configured TRR database reported:

| Check | Result |
| --- | --- |
| Installed extension | `index_advisor` |
| Installed schema | `extensions` |
| Installed version | `0.2.0` |
| Available default version | `0.2.0` |
| Available installed version | `0.2.0` |

Command shape:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python - <<'PY'
import os
from pathlib import Path
from dotenv import load_dotenv
import psycopg2

load_dotenv(Path(".env"), override=False)
dsn = os.getenv("TRR_DB_SESSION_URL") or os.getenv("TRR_DB_URL") or os.getenv("TRR_DB_FALLBACK_URL")
assert dsn, "TRR DB URL is required"
with psycopg2.connect(dsn, connect_timeout=10) as conn:
    conn.set_session(readonly=True, autocommit=False)
    with conn.cursor() as cur:
        cur.execute("""
            select e.extname, n.nspname, e.extversion
            from pg_extension e
            join pg_namespace n on n.oid = e.extnamespace
            where e.extname = 'index_advisor'
        """)
        print("installed=", cur.fetchall())
        cur.execute("""
            select name, default_version, installed_version
            from pg_available_extensions
            where name = 'index_advisor'
        """)
        print("available=", cur.fetchall())
PY
```

Output:

```text
installed= [('index_advisor', 'extensions', '0.2.0')]
available= [('index_advisor', '0.2.0', '0.2.0')]
```

## Repo Gap

Before this workflow was added, `rg "index_advisor"` showed no backend migration, static test, helper script, or workspace command for `index_advisor`.

The live database already had the extension, but the repository did not make that state reproducible for local reset or future Supabase environments.

## Scope Guard

- Advisor recommendations are review inputs only.
- Do not execute advisor-returned `CREATE INDEX` statements from the helper.
- Do not drop indexes as part of this workflow.
- Every candidate index still needs route ownership, existing-index review, EXPLAIN evidence, RLS/grants review, and explicit approval before DDL.
