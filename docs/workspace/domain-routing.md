# Domain routing

Use product terms for navigation; API names, schema names and compatibility
aliases remain owned by their current implementations. This index routes work
and does not replace contracts or establish deployed readiness. The three Git
owners remain in [CONTEXT-MAP](../../CONTEXT-MAP.md).

| Product term / scope | API or route vocabulary | Persisted entities / inputs | Canonical implementation owner and entry point | Existing authority |
|---|---|---|---|---|
| Catalog: shows, seasons, episodes, people, cast/credits, brands | Backend `/shows`, `/admin/brands`; app show/person/brand pages | `core.shows`, `core.people`, related catalog tables; brand administration uses `admin` data | TRR-Backend: [shows router](../../TRR-Backend/api/routers/shows.py), [brands router](../../TRR-Backend/api/routers/admin_brands.py) | [Runtime ownership](backend-runtime-ownership.md), [migration ledger](api-migration-ledger.md) |
| Social: accounts/profiles, posts/comments, ingest/backfill, analytics | Backend `/admin/socials`; app `social`, `social-media` route aliases | `social` provider snapshots, catalog posts, scrape runs/jobs | TRR-Backend: [social routers](../../TRR-Backend/api/routers/socials/), [social implementation](../../TRR-Backend/trr_backend/socials/) | [Social glossary](../../TRR-Backend/CONTEXT.md), [Instagram ADR](../../TRR-Backend/docs/adr/0001-adaptive-instagram-scrape-control-plane.md), [social dashboard](social-profile-dashboard.md) |
| Media: discovery, mirroring, image/video variants, vision | Backend media assets/links and watcher routes; app proxies | `core.media_assets`, `core.media_links`; hosted objects | TRR-Backend: [media assets router](../../TRR-Backend/api/routers/admin_media_assets.py), [media services](../../TRR-Backend/trr_backend/media/) | [Runtime ownership](backend-runtime-ownership.md), [migration ledger](api-migration-ledger.md) |
| Community: legacy surveys | Backend `/surveys` | `surveys` surveys/questions/options/answers; Supabase identity | TRR-Backend: [surveys router](../../TRR-Backend/api/routers/surveys.py) | [Migration ownership](migration-ownership-policy.md), [runtime ownership](backend-runtime-ownership.md) |
| Community: normalized surveys and survey runs | App `/api/surveys`, admin normalized surveys | `firebase_surveys`, Firebase user identity | TRR-APP: [survey repositories](../../TRR-APP/apps/web/src/lib/server/surveys/), [schema authority](../../TRR-APP/apps/web/src/lib/server/surveys/survey-schema.ts) | [App direct-SQL inventory](app-direct-sql-inventory.md), [migration ownership](migration-ownership-policy.md) |
| Community: messaging / DMs | Backend `/dms`, realtime DM events | `social.dm_conversations`, `dm_members`, `dm_messages`, `dm_read_receipts` | TRR-Backend: [DM router](../../TRR-Backend/api/routers/dms.py), [realtime events](../../TRR-Backend/api/realtime/events.py) | [Runtime ownership](backend-runtime-ownership.md), [auth posture](auth-posture.md) |
| Games: Bravodle, Realitease gameplay | App `/bravodle`, `/realitease`; game completion adapter | Firestore game/analytics collections; completion persistence is a separate server concern | TRR-APP: [Bravodle](../../TRR-APP/apps/web/src/lib/bravodle/manager.ts), [Realitease](../../TRR-APP/apps/web/src/lib/realitease/manager.ts) | [Route/feature inventory](web-app-route-feature-inventory.md), [Firestore rules](../../TRR-APP/firestore.rules) |
| Games: Flashback shared administration | Backend v2 `/admin/flashback`; app proxies and gameplay | Shared quiz/event records via backend repository | TRR-Backend: [Flashback API](../../TRR-Backend/api/routers/v2/admin_flashback.py), [repository](../../TRR-Backend/trr_backend/repositories/admin_flashback.py); TRR-APP owns [gameplay](../../TRR-APP/apps/web/src/lib/flashback/manager.ts) | [Migration ledger](api-migration-ledger.md), [route/feature inventory](web-app-route-feature-inventory.md) |
| Design: design-docs/editor, fonts | App `/api/design-docs` and admin editor | Editor configuration and runtime-imported generated font inputs | TRR-APP: [design-docs pipeline](../../TRR-APP/apps/web/src/lib/admin/design-docs-pipeline.ts), [brand fonts](../../TRR-APP/apps/web/src/lib/fonts/brand-fonts/index.ts) | [Route/feature inventory](web-app-route-feature-inventory.md), [app direct-SQL inventory](app-direct-sql-inventory.md) |
| Design: shared typography administration | Backend v2 `/admin/typography`; app proxy | Typography sets/assignments owned by backend repository | TRR-Backend: [typography router](../../TRR-Backend/api/routers/v2/admin_typography.py), [repository](../../TRR-Backend/trr_backend/repositories/admin_typography.py) | [Migration ledger](api-migration-ledger.md) |
| Operations: auth, environment, deployment, capacity | Workspace operator commands; backend/app enforce their own runtime edges | Environment contract, deployment identities, task/release evidence | Workspace: [commands](dev-commands.md); execution placement follows [runtime ownership](backend-runtime-ownership.md) | [Environment contract](env-contract.md), [deployment targets](deployment-targets.json), [capacity](runtime-capacity.json), [auth posture](auth-posture.md) |

Long-running social/media ingestion and durable shared jobs follow the backend
and Modal placement rules in the runtime authority. App-local survey scheduling
remains with its [scheduler](../../TRR-APP/apps/web/src/lib/server/surveys/survey-run-scheduler.ts).
A product label alone does not authorize moving SQL, jobs or API contracts.

## Names and retained references

Use lowercase kebab-case for new domain documentation/web feature directories,
Python snake_case for modules, and PascalCase for exported React components.
Preserve established `socials`, `social`/`social-media`, `people`/`person`, public
URLs, import wrappers, applied migrations and history. Naming changes require
an owner-bound behavior-preserving packet, not a mechanical vocabulary sweep.

[Vue Wordle](../../TRR-APP/apps/vue-wordle/README.md) is a retained reference-only
sandbox with its own installation/CI boundary and lifecycle criteria. It is not
supported game CI. [Research disposition](research-disposition.md) classifies
historical scratch/research references; the [output ledger](output-disposition.json)
remains the sole row-level output disposition authority.
