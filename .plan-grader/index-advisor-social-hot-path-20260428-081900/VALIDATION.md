# VALIDATION

## Files Inspected

- `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-index-advisor-social-hot-path-plan.md`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/hot_path_explain/README.md`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/db/hot_path_explain/hot_path_explain.sql`
- `/Users/thomashulihan/Projects/TRR/TRR-Backend/supabase/migrations/`
- `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-supabase-advisor-performance-remediation-plan.md`
- `/Users/thomashulihan/Documents/Codex/2026-04-21-create-a-rubric-for-scoring-an/implementation-plan-rubric.md`

## Commands Run

```bash
rg -n "index_advisor|CREATE EXTENSION|create extension|extensions\\.index_advisor|hypopg" \
  /Users/thomashulihan/Projects/TRR/TRR-Backend/supabase \
  /Users/thomashulihan/Projects/TRR/TRR-Backend/tests \
  /Users/thomashulihan/Projects/TRR/docs \
  /Users/thomashulihan/Projects/TRR/scripts
```

Result: no existing `index_advisor` migration/script/doc usage found.

```bash
/Users/thomashulihan/Projects/TRR/TRR-Backend/.venv/bin/python - <<'PY'
import os
from pathlib import Path
from dotenv import load_dotenv
import psycopg2

load_dotenv(Path('/Users/thomashulihan/Projects/TRR/TRR-Backend/.env'), override=False)
dsn = os.getenv('TRR_DB_SESSION_URL') or os.getenv('TRR_DB_URL') or os.getenv('TRR_DB_FALLBACK_URL')
with psycopg2.connect(dsn, connect_timeout=10) as conn:
    with conn.cursor() as cur:
        cur.execute("""
            select e.extname, n.nspname
            from pg_extension e
            join pg_namespace n on n.oid = e.extnamespace
            where e.extname = 'index_advisor'
        """)
        installed = cur.fetchall()
        cur.execute("""
            select name, default_version, installed_version
            from pg_available_extensions
            where name = 'index_advisor'
        """)
        available = cur.fetchall()
print({'installed': installed, 'available': available})
PY
```

Result: `{'installed': [('index_advisor', 'extensions')], 'available': [('index_advisor', '0.2.0', '0.2.0')]}`

## Evidence Gaps

- Did not run a live `index_advisor(query text)` call during grading. That belongs in plan execution after the helper exists.
- Did not inspect Supabase extension docs during this grading pass because the prior turn already verified the live DB and source plan captured the needed current-state facts.

## Recommended Validation During Execution

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db/test_index_advisor_extension_sql.py
.venv/bin/python -m py_compile scripts/db/index_advisor_social_hot_paths.py
.venv/bin/python scripts/db/index_advisor_social_hot_paths.py --dry-run
.venv/bin/python scripts/db/index_advisor_social_hot_paths.py --output-date 2026-04-28
```

## Assumptions

- The current `.env` DB target is the intended TRR runtime/dev database for read-only validation.
- Generated advisor reports should be checked in only when tied to an approved dated review run.
