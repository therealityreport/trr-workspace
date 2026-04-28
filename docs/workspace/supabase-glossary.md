# Supabase Connection Glossary

Use these terms consistently in workspace plans, env docs, inventories, and
operator notes.

| Term | Meaning |
|---|---|
| Supavisor session mode | Pooler mode on port `5432`; a client session holds a server connection while checked out. This is TRR's default runtime lane. |
| Supavisor transaction mode | Pooler mode on port `6543`; connections can be reused after each transaction, but session state and prepared statements are unsafe unless verified. |
| Direct SQL | Application or tooling code that connects to Postgres and sends SQL directly. |
| Supabase REST/Auth/Storage API | HTTP API calls to Supabase services. These do not consume the same app Postgres holder as a direct SQL pool, though Supabase services still use database capacity internally. |
| Service role | High-privilege Supabase credential for trusted server code only. Never expose it to browser code or `NEXT_PUBLIC_*`. |
| Anon/public key | Public Supabase key suitable only for RLS-protected browser/client paths. Public does not mean privileged. |
| Vercel attached pool | Integration-managed `POSTGRES_*` and `SUPABASE_*` env values attached by Vercel/Supabase. TRR treats retained values as integration metadata unless explicitly promoted by the env contract. |
| App direct SQL | TRR-APP server code using the app Postgres helper directly. High-fanout or shared-schema paths should migrate behind backend APIs. |
| Backend aggregate endpoint | TRR-Backend route that composes shared data for the app so browser/admin pages do not fan out into many direct SQL reads. |
| Holder budget | The projected number of session-mode Postgres/Supavisor holders a local workspace can open at once. Normal `make dev` currently budgets `10` holders against an observed pool size of `15`. |
