# Migration Ownership Policy

Shared-schema changes are backend-owned. New migrations that touch `admin`,
`core`, `firebase_surveys`, or `social` should live under
`TRR-Backend/supabase/migrations`.

## Ordering

- Prefer timestamped backend migration names when creating new shared-schema
  migrations.
- Do not reuse a numeric prefix unless the ordering exception is documented in
  the migration file and in the related plan or ledger. For legacy app
  migrations, document the exception in
  `docs/workspace/app-migration-ownership-allowlist.txt` with:
  `# duplicate-prefix: <migration-dir>:<prefix> <ordering note>`.
- App migrations are allowed only for app-local schema or for legacy entries in
  `docs/workspace/app-migration-ownership-allowlist.txt`.

## Current Legacy Exceptions

- `TRR-APP/apps/web/db/migrations:000` is a legacy app-local create/seed pair.
  Full filename sorting applies `000_create_surveys_table.sql` before
  `000_seed_surveys.sql`.
- `TRR-APP/apps/web/db/migrations:022` is a mixed legacy pair. The admin season
  cast role migration is backend-owned shared-schema backlog and is skipped by
  the app runner; `022_link_brand_shows_to_trr.sql` remains a historical
  app-local/editor lane copy until runner cleanup removes or retires it.

## Local Checks

```bash
python3 scripts/migration-ownership-lint.py
python3 scripts/migration-ownership-lint.py --list-current
python3 scripts/migration-ownership-lint.py --list-duplicate-prefixes
```

If a new TRR-APP migration appears in the lint output, either move the shared
schema change to TRR-Backend migrations or add a temporary allowlist entry with
a linked cleanup owner and review date.

If a duplicate prefix appears in `--list-duplicate-prefixes`, rename the new
file before it lands. Only legacy duplicates may be documented as exceptions.
