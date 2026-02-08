# TRR Supabase Database Schema — Consolidated Reference (v2)

> Updated 2026-02-08. Reflects migrations 0001-0102 (current), planned migrations 0103-0106 (screenalytics unification), and owner-approved schema cleanup decisions.

---

## Schemas

| Schema | Purpose | Access |
|--------|---------|--------|
| `core` | TV metadata — shows, seasons, episodes, people, credits, media, external IDs, source snapshots | Public read, service_role write |
| `social` | User discussions + scraped social media content | Public read, authenticated write (discussions), service_role write (scrapes) |
| `surveys` | User surveys, rankings, predictions with live aggregates | Public read questions, authenticated write responses |
| `pipeline` | Data pipeline run tracking | service_role only |
| `screenalytics` | ML video analysis pipeline | service_role only |
| `admin` | Audit logs and admin tools | service_role only |

> **`games` schema**: DROPPED. All 7 tables removed (zero code references). Future games (bravodle, realitease, quizzes) will get a fresh schema design. Rankings/predictions go in `surveys`.

---

## Legend

- **STATUS**: `KEEP` = active, `MODIFY` = active with approved column changes, `DEPRECATE` = bridge layer still active / planned for removal, `DROP` = to be removed, `ADD` = new table from unification plan
- FK references shown as `-> table(col)`
- `~~column~~` = column to be DROPPED
- `+ column` = column to be ADDED
- jsonb = JSON binary (PostgreSQL structured data type that stores nested objects/arrays)

---

## Change Log (Owner Decisions)

| Decision | Details |
|----------|---------|
| Drop singular show columns | `network`, `streaming` dropped; `networks[]`, `streaming_providers[]` kept |
| Consolidate most_recent_episode | 6 columns -> single `most_recent_episode jsonb` keyed by source |
| Drop show social IDs | `facebook_id`, `instagram_id`, `twitter_id` removed from shows |
| Drop resolution flags | `needs_imdb_resolution`, `needs_tmdb_resolution` removed (pipeline concern) |
| Enrich core.people | Add multi-source fields: birthday, gender, biography, place_of_birth, homepage, profile_image_url |
| Expand people_overrides | Add tiktok_handle, twitter_handle, youtube_handle |
| Drop cast_memberships + episode_cast | Superseded; only credits + credit_occurrences kept |
| Drop show_cast + episode_appearances | Superseded by credits; rich fields migrated to credit_occurrences |
| Enrich credit_occurrences | Add air_year, credit_text, attributes, is_archive_footage from episode_appearances |
| Add cast summary view | View for per-show totals by season/episode |
| Add social columns to dimension tables | facebook_id, instagram_id, twitter_id, tiktok_id on networks + watch providers |
| Add Reddit scrape tables | Future addition; extend scrape_jobs.platform CHECK |
| Drop games schema | All 7 tables removed; fresh design later |

---

## 1. `core` Schema — Entity Tables

### core.shows `MODIFY`

```
id                            uuid PK DEFAULT gen_random_uuid()
name                          text NOT NULL
description                   text
premiere_date                 date

-- Counts
show_total_seasons            integer
show_total_episodes           integer

-- External IDs (vendor)
imdb_id                       text
tmdb_id                       integer
tvdb_id                       integer
tvrage_id                     integer
wikidata_id                   text
external_ids                  jsonb NOT NULL DEFAULT '{}'

-- Most recent episode (multi-source)
+ most_recent_episode         jsonb NOT NULL DEFAULT '{}'
                              -- keyed by source: {"imdb": {"season": 3, "episode": 12, "title": "...",
                              --   "air_date": "2025-03-15", "imdb_id": "tt1234567"},
                              --   "tmdb": {"season": 3, "episode": 12, "title": "...", "air_date": "..."}}

-- Primary images (will migrate to media_links)
primary_tmdb_poster_path      text
primary_tmdb_backdrop_path    text
primary_tmdb_logo_path        text
primary_poster_image_id       uuid -> core.show_images(id) ON DELETE SET NULL
primary_backdrop_image_id     uuid -> core.show_images(id) ON DELETE SET NULL
primary_logo_image_id         uuid -> core.show_images(id) ON DELETE SET NULL

-- Classification arrays
genres                        text[]
keywords                      text[]
tags                          text[]
networks                      text[]
streaming_providers           text[]
listed_on                     text[]           -- source of streaming provider info
alternative_names             text[]

-- Timestamps
created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()  -- auto-trigger

-- DROPPED COLUMNS:
-- ~~network~~                text              (use networks[] instead)
-- ~~streaming~~              text              (use streaming_providers[] instead)
-- ~~most_recent_episode~~    text              (consolidated into jsonb)
-- ~~most_recent_episode_season~~               (consolidated into jsonb)
-- ~~most_recent_episode_number~~               (consolidated into jsonb)
-- ~~most_recent_episode_title~~                (consolidated into jsonb)
-- ~~most_recent_episode_air_date~~             (consolidated into jsonb)
-- ~~most_recent_episode_imdb_id~~              (consolidated into jsonb)
-- ~~facebook_id~~            text              (shows don't need social IDs)
-- ~~instagram_id~~           text              (shows don't need social IDs)
-- ~~twitter_id~~             text              (shows don't need social IDs)
-- ~~needs_tmdb_resolution~~  boolean           (pipeline concern, not entity data)
-- ~~needs_imdb_resolution~~  boolean           (pipeline concern, not entity data)
```

### core.seasons `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
show_id                       uuid NOT NULL -> core.shows(id) CASCADE
show_name                     text                    -- auto-populated via trigger
name                          text
title                         text
season_number                 integer NOT NULL CHECK (>= 0)
overview                      text
air_date                      date                    -- season date range
premiere_date                 date                    -- season start date

-- TMDb identifiers
tmdb_series_id                integer
imdb_series_id                text
tmdb_season_id                integer
tmdb_season_object_id         text

-- Media
poster_path                   text
url_original_poster           text GENERATED (tmdb original URL)

-- External IDs
external_tvdb_id              integer
external_wikidata_id          text
external_ids                  jsonb NOT NULL DEFAULT '{}'

-- Metadata
language                      text NOT NULL DEFAULT 'en-US'  -- used for TMDb media retrieval
fetched_at                    timestamptz NOT NULL DEFAULT now()
created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()

UNIQUE (show_id, season_number)
```

### core.episodes `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
show_id                       uuid NOT NULL -> core.shows(id) CASCADE
season_id                     uuid NOT NULL -> core.seasons(id) CASCADE
show_name                     text                    -- auto-populated via trigger
title                         text
season_number                 integer NOT NULL CHECK (>= 0)
episode_number                integer NOT NULL CHECK (>= 0)
air_date                      date
synopsis                      text
overview                      text

-- IMDb enrichment
imdb_episode_id               text
imdb_rating                   numeric
imdb_vote_count               integer
imdb_primary_image_url        text
imdb_primary_image_caption    text
imdb_primary_image_width      integer
imdb_primary_image_height     integer

-- TMDb enrichment
tmdb_series_id                integer
tmdb_episode_id               integer
episode_type                  text
production_code               text
runtime                       integer
still_path                    text
url_original_still            text GENERATED (tmdb original URL)
tmdb_vote_average             numeric
tmdb_vote_count               integer

-- External IDs
external_ids                  jsonb NOT NULL DEFAULT '{}'

-- Metadata
fetched_at                    timestamptz NOT NULL DEFAULT now()
created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()

UNIQUE (season_id, episode_number)
UNIQUE (show_id, season_number, episode_number)
```

### core.people `MODIFY`

```
id                            uuid PK DEFAULT gen_random_uuid()
full_name                     text NOT NULL
known_for                     text
external_ids                  jsonb NOT NULL DEFAULT '{}'

-- Multi-source canonical fields (keyed by source, e.g. {"tmdb": "1990-05-15", "fandom": "May 15, 1990"})
+ birthday                    jsonb NOT NULL DEFAULT '{}'
+ gender                      jsonb NOT NULL DEFAULT '{}'     -- {"tmdb": 2, "fandom": "Female"}
+ biography                   jsonb NOT NULL DEFAULT '{}'     -- {"tmdb": "...", "fandom": "..."}
+ place_of_birth              jsonb NOT NULL DEFAULT '{}'     -- {"tmdb": "Los Angeles, CA", "fandom": "LA"}
+ homepage                    jsonb NOT NULL DEFAULT '{}'     -- {"tmdb": "https://..."}
+ profile_image_url           jsonb NOT NULL DEFAULT '{}'     -- {"tmdb": "/path.jpg", "fandom": "https://..."}

created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()
```

---

## 2. `core` Schema — Credits (Canonical Model)

### core.credits `KEEP`

> One row per person-show-credit. Links a person to a show with their credit role.

```
id                            uuid PK DEFAULT gen_random_uuid()
show_id                       uuid NOT NULL -> core.shows(id) CASCADE
person_id                     uuid NOT NULL -> core.people(id) CASCADE
credit_category               text NOT NULL           -- 'Self', 'cast', 'crew', 'guest'
role                          text
billing_order                 integer
source_type                   text NOT NULL            -- CHECK IN (fullcredits_html, credits_graphql_paginated, ...)
metadata                      jsonb NOT NULL DEFAULT '{}'
created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()

UNIQUE (show_id, person_id, credit_category, COALESCE(role,''), source_type)
```

### core.credit_occurrences `MODIFY`

> One row per person-episode appearance. Tracks which episodes each credited person appeared in.

```
credit_id                     uuid NOT NULL -> core.credits(id) CASCADE
episode_id                    uuid NOT NULL -> core.episodes(id) CASCADE
appearance_type               text NOT NULL DEFAULT 'appears'

-- Rich fields (migrated from episode_appearances)
+ air_year                    integer
+ credit_text                 text
+ attributes                  jsonb NOT NULL DEFAULT '[]'
+ is_archive_footage          boolean NOT NULL DEFAULT false

created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()

PK (credit_id, episode_id)
```

### VIEW: cast_summary (planned)

> Materialized view or regular view for per-show cast totals.

```sql
-- Provides: person_id, show_id, credit_category, total_episodes,
--           episodes_by_season (jsonb), first_appearance, last_appearance,
--           billing_order
-- Source: JOIN credits + credit_occurrences + episodes
```

---

## 3. `core` Schema — Legacy Cast Tables `DROP`

> **All four tables below are being DROPPED.** Their data has been / will be migrated to `credits` + `credit_occurrences`. Rich fields from `episode_appearances` are preserved as new columns on `credit_occurrences`.

### ~~core.cast_memberships~~ `DROP` — superseded by core.credits

### ~~core.episode_cast~~ `DROP` — superseded by core.credit_occurrences

### ~~core.show_cast~~ `DROP` — superseded by core.credits

### ~~core.episode_appearances~~ `DROP` — superseded by core.credit_occurrences (rich fields migrated)

---

## 4. `core` Schema — Media System

### core.media_assets `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
media_type                    text NOT NULL DEFAULT 'image'
source                        text NOT NULL
source_asset_id               text
source_url                    text
sha256                        text
content_type                  text
bytes                         bigint
width                         integer
height                        integer
caption                       text
alt_text                      text
hosted_bucket                 text
hosted_key                    text
hosted_url                    text
hosted_etag                   text
hosted_at                     timestamptz
hosted_sha256                 text
hosted_content_type           text
hosted_bytes                  bigint
metadata                      jsonb NOT NULL DEFAULT '{}'
created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()
fetched_at                    timestamptz

UNIQUE (source, source_asset_id) WHERE source_asset_id IS NOT NULL
UNIQUE (source, source_url) WHERE source_url IS NOT NULL
UNIQUE (sha256) WHERE sha256 IS NOT NULL
```

### core.media_links `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
entity_type                   text NOT NULL            -- 'show', 'season', 'episode', 'person'
entity_id                     uuid NOT NULL
media_asset_id                uuid NOT NULL -> core.media_assets(id) CASCADE
kind                          text NOT NULL             -- 'poster', 'backdrop', 'logo', 'profile', etc.
position                      integer
is_primary                    boolean NOT NULL DEFAULT false
context                       jsonb NOT NULL DEFAULT '{}'
created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()

UNIQUE (entity_type, entity_id, kind) WHERE is_primary = true
```

### core.media_uploads `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
uploader_user_id              uuid
entity_type                   text NOT NULL
entity_id                     uuid NOT NULL
kind                          text NOT NULL
original_filename             text
content_type                  text NOT NULL
expected_bytes                bigint
caption                       text
alt_text                      text
make_primary                  boolean NOT NULL DEFAULT false
status                        text NOT NULL DEFAULT 'initiated'
                              -- CHECK IN (initiated, uploaded, finalized, failed, expired, canceled)
error                         text
expires_at                    timestamptz NOT NULL DEFAULT (now() + interval '1 hour')
s3_bucket                     text NOT NULL
s3_temp_key                   text NOT NULL
media_asset_id                uuid -> core.media_assets(id) SET NULL
media_link_id                 uuid -> core.media_links(id) SET NULL
created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()
```

### core.media_scrape_exclusions `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
entity_type                   text NOT NULL
entity_id                     uuid NOT NULL
source_page_url               text
source_image_url              text NOT NULL
source_image_url_canonical    text NOT NULL
reason                        text
created_at                    timestamptz NOT NULL DEFAULT now()
created_by                    text

UNIQUE (entity_type, entity_id, source_image_url_canonical)
```

---

## 5. `core` Schema — Legacy Image Tables `DEPRECATE`

> These tables have **bridge triggers** (migration 0080) that auto-sync writes into `media_assets` + `media_links`. Planned for removal once all code migrates to the media system. No column changes needed — they'll be dropped entirely when the migration is complete.

### core.show_images `DEPRECATE`

```
id, show_id, source, kind, iso_639_1, file_path, width, height, aspect_ratio,
vote_average, vote_count, fetched_at,
hosted_bucket, hosted_key, hosted_url, hosted_sha256, hosted_content_type, hosted_bytes, hosted_etag, hosted_at
CHECK kind IN ('poster', 'backdrop', 'logo')
```

### core.season_images `DEPRECATE`

```
id, show_id, season_id, tmdb_series_id, season_number, source, kind, iso_639_1,
file_path, url_original (GENERATED), width, height, aspect_ratio, fetched_at,
hosted_*, archived_at, archived_by_firebase_uid, archived_reason
```

### core.episode_images `DEPRECATE`

```
id, show_id, season_id, episode_id, tmdb_series_id, season_number, episode_number,
source, kind, iso_639_1, file_path, url, url_original (GENERATED), source_image_id,
width, height, aspect_ratio, caption, position, metadata, fetch_method, fetched_from_url, fetched_at,
hosted_*, archived_at, archived_by_firebase_uid, archived_reason,
created_at, updated_at
```

### core.person_images `DEPRECATE`

```
id, person_id, source, url, width, height, caption, is_primary, created_at, updated_at
UNIQUE (person_id, source, url)
```

### core.cast_photos `DEPRECATE`

```
id, person_id, imdb_person_id, source, source_image_id, viewer_id,
mediaindex_url_path, mediaviewer_url_path, url, url_path, width, height,
caption, gallery_index, gallery_total, people_imdb_ids, people_names,
title_imdb_ids, title_names, fetched_at, updated_at, metadata,
source_page_url, image_url, thumb_url, file_name, alt_text,
context_section, context_type, season, position, image_url_canonical,
hosted_*, archived_at, archived_by_firebase_uid, archived_reason
UNIQUE (person_id, source, source_image_id)
UNIQUE (person_id, source, image_url_canonical)
```

---

## 6. `core` Schema — Cast Enrichment (Source-Specific)

> These tables store raw per-source enrichment data. Each source provides unique data. The canonical multi-source fields on `core.people` are derived from these.

### core.cast_tmdb `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
person_id                     uuid NOT NULL -> core.people(id) CASCADE  UNIQUE
tmdb_id                       integer NOT NULL UNIQUE
name                          text
also_known_as                 text[]
biography                     text
birthday                      date
deathday                      date
gender                        smallint DEFAULT 0
adult                         boolean DEFAULT true
homepage                      text
known_for_department          text
place_of_birth                text
popularity                    numeric(10,3) DEFAULT 0
profile_path                  text
imdb_id                       text
freebase_mid                  text
freebase_id                   text
tvrage_id                     integer
wikidata_id                   text
facebook_id                   text
instagram_id                  text
tiktok_id                     text
twitter_id                    text
youtube_id                    text
fetched_at                    timestamptz DEFAULT now()
created_at                    timestamptz DEFAULT now()
updated_at                    timestamptz DEFAULT now()
```

### core.cast_fandom `KEEP`

> Fandom data is show-specific — a person can have different fandom pages per show/franchise.

```
id                            uuid PK DEFAULT gen_random_uuid()
person_id                     uuid NOT NULL -> core.people(id) CASCADE
source                        text NOT NULL
source_url                    text NOT NULL
page_title                    text
page_revision_id              bigint
scraped_at                    timestamptz NOT NULL DEFAULT now()
full_name                     text
birthdate                     text
birthdate_display             text
gender                        text
resides_in                    text
hair_color                    text
eye_color                     text
height_display                text
weight_display                text
romances                      text[]
family                        jsonb
friends                       jsonb
enemies                       jsonb
installment                   text
installment_url               text
main_seasons_display          text
summary                       text
taglines                      jsonb
reunion_seating               jsonb
trivia                        jsonb
infobox_raw                   jsonb
raw_html_sha256               text

UNIQUE (person_id, source)
```

---

## 7. `core` Schema — Sources & External IDs

### core.sources `KEEP`

```
id                            text PK
                              -- 'imdb', 'tmdb', 'wikidata', 'tvdb', 'tvrage', 'fandom',
                              -- 'facebook', 'instagram', 'twitter', 'tiktok', 'youtube'
category                      text NOT NULL      -- 'vendor' or 'social'
aliases                       text[] DEFAULT '{}'
created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()
```

### core.show_external_ids `KEEP`

```
id                            bigserial PK
show_id                       uuid NOT NULL -> core.shows(id) CASCADE
source_id                     text NOT NULL -> core.sources(id)
external_id                   text NOT NULL
is_primary                    boolean NOT NULL DEFAULT true
valid_from                    date
valid_to                      date
observed_at                   timestamptz NOT NULL DEFAULT now()
created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()
```

### core.season_external_ids `KEEP` — same shape with season_id FK

### core.episode_external_ids `KEEP` — same shape with episode_id FK

### core.person_external_ids `KEEP` — same shape with person_id FK

### core.external_id_conflicts `KEEP`

```
entity_type                   text NOT NULL
entity_id                     uuid NOT NULL
source_id                     text NOT NULL
external_id                   text NOT NULL
conflict_reason               text NOT NULL
detected_at                   timestamptz NOT NULL DEFAULT now()
payload                       jsonb
```

---

## 8. `core` Schema — Source Snapshots (per entity type)

Each entity type has a `*_source_latest` + `*_source_history` pair. Same shape for all:

### core.show_source_latest / show_source_history `KEEP`

```
-- _latest (upsert):
show_id, source_id, variant (DEFAULT 'default'), fetched_at, fetch_method,
status (CHECK 'success'|'error'), error, payload (jsonb), payload_sha256,
created_at, updated_at
UNIQUE (show_id, source_id, variant)

-- _history (append-only):
id (bigserial PK), show_id, source_id, variant, fetched_at, fetch_method,
status, error, payload, payload_sha256, created_at
```

### core.season_source_latest / season_source_history `KEEP` — same with season_id
### core.episode_source_latest / episode_source_history `KEEP` — same with episode_id
### core.person_source_latest / person_source_history `KEEP` — same with person_id

---

## 9. `core` Schema — Dimension Tables

### core.tmdb_networks `MODIFY`

```
id                            integer PK
name                          text NOT NULL
origin_country                text
tmdb_logo_path                text
hosted_logo_key               text
hosted_logo_url               text
hosted_logo_sha256            text
hosted_logo_content_type      text
hosted_logo_bytes             bigint
hosted_logo_etag              text
hosted_logo_at                timestamptz

-- Social IDs (manually maintained)
+ facebook_id                 text
+ instagram_id                text
+ twitter_id                  text
+ tiktok_id                   text

created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()
```

### core.tmdb_production_companies `KEEP` — same shape as tmdb_networks (without social IDs)

### core.tmdb_watch_providers `MODIFY`

```
provider_id                   integer PK
provider_name                 text NOT NULL
display_priority              integer
tmdb_logo_path                text
hosted_logo_key               text
hosted_logo_url               text
hosted_logo_sha256            text
hosted_logo_content_type      text
hosted_logo_bytes             bigint
hosted_logo_etag              text
hosted_logo_at                timestamptz

-- Social IDs (manually maintained)
+ facebook_id                 text
+ instagram_id                text
+ twitter_id                  text
+ tiktok_id                   text

created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()
```

### core.show_watch_providers `KEEP`

```
show_id                       uuid NOT NULL -> core.shows(id) CASCADE
region                        text NOT NULL
offer_type                    text NOT NULL
provider_id                   integer NOT NULL -> core.tmdb_watch_providers(provider_id) CASCADE
display_priority              integer
link                          text
fetched_at                    timestamptz
created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()

PK (show_id, region, offer_type, provider_id)
```

---

## 10. `core` Schema — Overrides

### core.people_overrides `MODIFY`

```
id                            uuid PK DEFAULT gen_random_uuid()
person_id                     uuid NOT NULL -> core.people(id) CASCADE  UNIQUE
full_name_override            text
instagram_handle              text
+ tiktok_handle               text
+ twitter_handle              text
+ youtube_handle              text
external_ids_override         jsonb NOT NULL DEFAULT '{}'
notes                         text
created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()
```

### core.show_cast_overrides `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
show_id                       uuid NOT NULL -> core.shows(id) CASCADE
person_id                     uuid NOT NULL -> core.people(id) CASCADE
credit_category               text NOT NULL DEFAULT 'Self'
friend_of                     boolean
role_override                 text
billing_order_override        integer
notes_override                text
tags_override                 text[]
created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()

UNIQUE (show_id, person_id, credit_category)
```

---

## 11. `social` Schema — Discussions

### social.threads `KEEP`

```
id                            uuid PK
episode_id                    uuid NOT NULL -> core.episodes(id) CASCADE
title                         text NOT NULL
type                          text NOT NULL CHECK IN ('episode_live', 'post_episode', 'spoilers', 'general')
created_by                    uuid -> auth.users(id) SET NULL
is_locked                     boolean NOT NULL DEFAULT false
created_at                    timestamptz NOT NULL DEFAULT now()
```

### social.posts `KEEP`

```
id                            uuid PK
thread_id                     uuid NOT NULL -> social.threads(id) CASCADE
parent_post_id                uuid -> social.posts(id) CASCADE
user_id                       uuid -> auth.users(id) SET NULL
body                          text NOT NULL
created_at                    timestamptz NOT NULL DEFAULT now()
edited_at                     timestamptz
```

### social.reactions `KEEP`

```
post_id                       uuid NOT NULL -> social.posts(id) CASCADE
user_id                       uuid NOT NULL -> auth.users(id) CASCADE
reaction                      text NOT NULL CHECK IN ('upvote','downvote','lol','shade','fire','heart')
created_at                    timestamptz NOT NULL DEFAULT now()

PK (post_id, user_id, reaction)
```

---

## 12. `social` Schema — Direct Messages

### social.dm_conversations `KEEP`

```
id                            uuid PK
is_group                      boolean NOT NULL DEFAULT false
direct_key                    text UNIQUE
created_at                    timestamptz NOT NULL DEFAULT now()
last_message_at               timestamptz
```

### social.dm_members `KEEP`

```
conversation_id               uuid NOT NULL -> social.dm_conversations(id) CASCADE
user_id                       uuid NOT NULL -> auth.users(id) CASCADE
role                          text NOT NULL DEFAULT 'member'
joined_at                     timestamptz NOT NULL DEFAULT now()

PK (conversation_id, user_id)
```

### social.dm_messages `KEEP`

```
id                            uuid PK
conversation_id               uuid NOT NULL -> social.dm_conversations(id) CASCADE
sender_id                     uuid NOT NULL -> auth.users(id) CASCADE
body                          text NOT NULL
created_at                    timestamptz NOT NULL DEFAULT now()
```

### social.dm_read_receipts `KEEP`

```
conversation_id               uuid NOT NULL -> social.dm_conversations(id) CASCADE
user_id                       uuid NOT NULL -> auth.users(id) CASCADE
last_read_message_id          uuid -> social.dm_messages(id)
last_read_at                  timestamptz

PK (conversation_id, user_id)
```

---

## 13. `social` Schema — Scrape Tables

### social.scrape_jobs `MODIFY`

```
id                            uuid PK DEFAULT gen_random_uuid()
platform                      text NOT NULL CHECK IN ('instagram', 'tiktok', 'youtube', 'twitter', + 'reddit')
job_type                      text NOT NULL CHECK IN ('posts', 'comments', 'search', 'replies')
config                        jsonb NOT NULL DEFAULT '{}'
status                        text NOT NULL DEFAULT 'pending'
items_found                   integer
error_message                 text
started_at                    timestamptz
completed_at                  timestamptz
created_at                    timestamptz NOT NULL DEFAULT now()
show_id                       uuid -> core.shows(id) SET NULL
person_id                     uuid -> core.people(id) SET NULL
```

### social.instagram_posts `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
shortcode                     text NOT NULL UNIQUE
media_id                      text
username                      text
user_id                       text
caption                       text
media_type                    text
media_urls                    jsonb
likes                         integer
comments_count                integer
views                         integer
posted_at                     timestamptz
scraped_at                    timestamptz NOT NULL DEFAULT now()
raw_data                      jsonb
show_id                       uuid -> core.shows(id) SET NULL
person_id                     uuid -> core.people(id) SET NULL
```

### social.instagram_comments `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
comment_id                    text NOT NULL UNIQUE
post_id                       uuid NOT NULL -> social.instagram_posts(id) CASCADE
parent_comment_id             uuid -> social.instagram_comments(id)
username                      text
user_id                       text
text                          text
likes                         integer
is_reply                      boolean NOT NULL DEFAULT false
reply_count                   integer
created_at                    timestamptz
scraped_at                    timestamptz NOT NULL DEFAULT now()
raw_data                      jsonb
```

### social.tiktok_posts `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
video_id                      text NOT NULL UNIQUE
aweme_id                      text
username                      text
user_id                       text
nickname                      text
description                   text
hashtags                      jsonb
music_info                    jsonb
likes                         integer
comments_count                integer
shares                        integer
views                         integer
duration_seconds              integer
posted_at                     timestamptz
scraped_at                    timestamptz NOT NULL DEFAULT now()
raw_data                      jsonb
show_id                       uuid -> core.shows(id) SET NULL
person_id                     uuid -> core.people(id) SET NULL
```

### social.tiktok_comments `KEEP` — same pattern as instagram_comments

### social.youtube_videos `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
video_id                      text NOT NULL UNIQUE
channel_id                    text
channel_title                 text
title                         text
description                   text
duration                      text
duration_seconds              integer
views                         integer
likes                         integer
comments_count                integer
thumbnail_url                 text
published_at                  timestamptz
scraped_at                    timestamptz NOT NULL DEFAULT now()
raw_data                      jsonb
show_id                       uuid -> core.shows(id) SET NULL
person_id                     uuid -> core.people(id) SET NULL
```

### social.youtube_comments `KEEP` — same pattern as instagram_comments

### social.twitter_tweets `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
tweet_id                      text NOT NULL UNIQUE
username                      text
display_name                  text
user_verified                 boolean
text                          text
hashtags                      jsonb
mentions                      jsonb
media_urls                    jsonb
likes                         integer
retweets                      integer
replies_count                 integer
quotes                        integer
views                         integer
is_reply                      boolean NOT NULL DEFAULT false
is_retweet                    boolean NOT NULL DEFAULT false
is_quote                      boolean NOT NULL DEFAULT false
reply_to_tweet_id             text
quoted_tweet_id               text
created_at                    timestamptz
scraped_at                    timestamptz NOT NULL DEFAULT now()
raw_data                      jsonb
show_id                       uuid -> core.shows(id) SET NULL
person_id                     uuid -> core.people(id) SET NULL
```

### social.reddit_posts `ADD` (future)

```
id                            uuid PK DEFAULT gen_random_uuid()
post_id                       text NOT NULL UNIQUE
subreddit                     text NOT NULL
author                        text
title                         text
body                          text
url                           text
score                         integer
upvote_ratio                  real
comments_count                integer
flair                         text
is_self                       boolean NOT NULL DEFAULT true
posted_at                     timestamptz
scraped_at                    timestamptz NOT NULL DEFAULT now()
raw_data                      jsonb
show_id                       uuid -> core.shows(id) SET NULL
person_id                     uuid -> core.people(id) SET NULL
```

### social.reddit_comments `ADD` (future) — same pattern as other comment tables

---

## 14. `surveys` Schema

> Actively being implemented. Also handles rankings and predictions (formerly in games schema).

### surveys.surveys `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
show_id                       uuid -> core.shows(id) SET NULL
season_id                     uuid -> core.seasons(id) SET NULL
episode_id                    uuid -> core.episodes(id) SET NULL
title                         text NOT NULL
description                   text
status                        text NOT NULL DEFAULT 'draft' CHECK IN ('draft', 'published', 'archived')
starts_at                     timestamptz
ends_at                       timestamptz
config                        jsonb NOT NULL DEFAULT '{}'
slug                          text UNIQUE WHERE slug IS NOT NULL
created_at                    timestamptz NOT NULL DEFAULT now()
```

### surveys.questions `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
survey_id                     uuid NOT NULL -> surveys.surveys(id) CASCADE
question_order                integer NOT NULL
prompt                        text NOT NULL
question_type                 text NOT NULL CHECK IN ('single_choice', 'multiple_choice', 'free_text', 'numeric')
config                        jsonb NOT NULL DEFAULT '{}'
created_at                    timestamptz NOT NULL DEFAULT now()

UNIQUE (survey_id, question_order)
```

### surveys.options `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
question_id                   uuid NOT NULL -> surveys.questions(id) CASCADE
option_order                  integer NOT NULL
label                         text NOT NULL
value                         text
created_at                    timestamptz NOT NULL DEFAULT now()

UNIQUE (question_id, option_order)
```

### surveys.responses `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
survey_id                     uuid NOT NULL -> surveys.surveys(id) CASCADE
user_id                       uuid -> auth.users(id) SET NULL
submitted_at                  timestamptz
metadata                      jsonb NOT NULL DEFAULT '{}'
created_at                    timestamptz NOT NULL DEFAULT now()

UNIQUE (survey_id, id)
```

### surveys.answers `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
survey_id                     uuid NOT NULL -> surveys.surveys(id) CASCADE
response_id                   uuid NOT NULL -> surveys.responses(id) CASCADE
question_id                   uuid NOT NULL -> surveys.questions(id) CASCADE
answer                        jsonb NOT NULL
created_at                    timestamptz NOT NULL DEFAULT now()

UNIQUE (response_id, question_id)
```

### surveys.aggregates `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
survey_id                     uuid NOT NULL -> surveys.surveys(id) CASCADE
question_id                   uuid NOT NULL -> surveys.questions(id) CASCADE
aggregate                     jsonb NOT NULL DEFAULT '{}'
updated_at                    timestamptz NOT NULL DEFAULT now()

UNIQUE (survey_id, question_id)
```

---

## 15. `games` Schema `DROP`

> All 7 tables dropped (zero code references). Future games (bravodle, realitease, quizzes) will get a fresh schema design. Rankings and predictions will use the surveys schema.

~~games.games, games.questions, games.options, games.answer_keys, games.sessions, games.responses, games.stats~~

---

## 16. `pipeline` Schema

### pipeline.runs `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
name                          text NOT NULL
status                        text NOT NULL DEFAULT 'pending'
                              CHECK IN ('pending', 'running', 'success', 'failed', 'cancelled')
config                        jsonb NOT NULL DEFAULT '{}'
started_at                    timestamptz
completed_at                  timestamptz
error_message                 text
error_stage                   text
created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()
```

### pipeline.run_stages `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
run_id                        uuid NOT NULL -> pipeline.runs(id) CASCADE
stage_name                    text NOT NULL
stage_order                   integer NOT NULL
status                        text NOT NULL DEFAULT 'pending'
                              CHECK IN ('pending', 'running', 'skipped', 'success', 'failed')
input_hash                    text
output_hash                   text
manifest_key                  text
started_at                    timestamptz
completed_at                  timestamptz
duration_ms                   integer
items_processed               integer
items_skipped                 integer
items_failed                  integer
error_message                 text
error_details                 jsonb
created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()

UNIQUE (run_id, stage_name)
```

---

## 17. `screenalytics` Schema — Existing (v2)

### screenalytics.video_assets `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
episode_id                    uuid -> core.episodes(id) CASCADE
season_id                     uuid -> core.seasons(id) CASCADE
show_id                       uuid -> core.shows(id) CASCADE
media_asset_id                uuid -> core.media_assets(id) SET NULL
source_url                    text
duration_seconds              numeric
metadata                      jsonb NOT NULL DEFAULT '{}'
created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()

CHECK (episode_id OR season_id OR show_id IS NOT NULL)
CHECK (media_asset_id OR source_url IS NOT NULL)
```

### screenalytics.runs_v2 `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
video_asset_id                uuid NOT NULL -> screenalytics.video_assets(id) RESTRICT
status                        text NOT NULL DEFAULT 'pending'
                              CHECK IN ('pending', 'running', 'success', 'failed', 'cancelled')
run_config_json               jsonb NOT NULL DEFAULT '{}'
config_hash                   text
candidate_cast_snapshot_json  jsonb NOT NULL DEFAULT '[]'
manifest_key                  text
started_at                    timestamptz
completed_at                  timestamptz
error_message                 text
created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()
```

### screenalytics.run_artifacts `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
run_id                        uuid NOT NULL -> screenalytics.runs_v2(id) CASCADE
artifact_key                  text NOT NULL
artifact_kind                 text NOT NULL
s3_key                        text NOT NULL
schema_version                text
content_type                  text
checksum_sha256               text
row_count                     bigint
created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()

UNIQUE (run_id, artifact_key)
```

### screenalytics.run_person_metrics `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
run_id                        uuid NOT NULL -> screenalytics.runs_v2(id) CASCADE
person_id                     uuid NOT NULL -> core.people(id) RESTRICT
screen_time_seconds           numeric NOT NULL DEFAULT 0
frame_count                   integer NOT NULL DEFAULT 0
confidence_avg                numeric
metadata                      jsonb NOT NULL DEFAULT '{}'
created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()

UNIQUE (run_id, person_id)
```

### screenalytics.unknown_clusters `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
run_id                        uuid NOT NULL -> screenalytics.runs_v2(id) CASCADE
cluster_id                    text NOT NULL
track_count                   integer NOT NULL DEFAULT 0
preview_s3_key                text
assigned_person_id            uuid -> core.people(id) RESTRICT
assigned_by                   text
assigned_at                   timestamptz
metadata                      jsonb NOT NULL DEFAULT '{}'
created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()

UNIQUE (run_id, cluster_id)
```

---

## 18. `screenalytics` Schema — Planned Additions (Migrations 0103-0106)

> These tables currently live in screenalytics' local Docker Postgres. The unification plan moves them to Supabase.

### screenalytics.face_bank_images `ADD` (0103)

```
image_id                      uuid PK DEFAULT gen_random_uuid()
person_id                     uuid NOT NULL -> core.people(id) CASCADE
media_asset_id                uuid -> core.media_assets(id)
s3_original_key               text NOT NULL
s3_aligned_key                text
s3_embedding_key              text
quality_score                 real
is_seed                       boolean NOT NULL DEFAULT false
approved                      boolean
approved_at                   timestamptz
approved_by                   text
created_at                    timestamptz NOT NULL DEFAULT now()
```

### screenalytics.video_asset_cast_candidates `ADD` (0104)

```
video_asset_id                uuid NOT NULL -> screenalytics.video_assets(id) CASCADE
person_id                     uuid NOT NULL -> core.people(id) CASCADE
source                        text NOT NULL
confidence                    real
credit_category               text
billing_order                 integer
role                          text
added_at                      timestamptz NOT NULL DEFAULT now()

PK (video_asset_id, person_id)
```

### screenalytics.runs (v1) `ADD` (0105)

```
run_id                        text PK
ep_id                         text NOT NULL
created_at                    timestamptz NOT NULL DEFAULT now()
label                         text
stage_state_json              jsonb
config_json                   jsonb
```

### screenalytics.job_runs `ADD` (0105)

```
job_run_id                    uuid PK DEFAULT gen_random_uuid()
run_id                        text NOT NULL -> screenalytics.runs(run_id) CASCADE
ep_id                         text NOT NULL
job_name                      text NOT NULL
request_json                  jsonb
status                        text NOT NULL DEFAULT 'pending'
started_at                    timestamptz
finished_at                   timestamptz
error_text                    text
artifact_index_json           jsonb
metrics_json                  jsonb
```

### screenalytics.identity_locks `ADD` (0105)

```
ep_id                         text NOT NULL
run_id                        text NOT NULL -> screenalytics.runs(run_id) CASCADE
identity_id                   text NOT NULL
locked                        boolean NOT NULL DEFAULT false
locked_at                     timestamptz
locked_by                     text
reason                        text

PK (ep_id, run_id, identity_id)
```

### screenalytics.suggestion_batches `ADD` (0105)

```
batch_id                      uuid PK DEFAULT gen_random_uuid()
ep_id                         text NOT NULL
run_id                        text NOT NULL -> screenalytics.runs(run_id) CASCADE
created_at                    timestamptz NOT NULL DEFAULT now()
generator_version             text
generator_config_json         jsonb
summary_json                  jsonb
```

### screenalytics.suggestions `ADD` (0105)

```
suggestion_id                 uuid PK DEFAULT gen_random_uuid()
batch_id                      uuid NOT NULL -> screenalytics.suggestion_batches(batch_id) CASCADE
ep_id                         text NOT NULL
run_id                        text NOT NULL
type                          text NOT NULL
target_identity_id            text NOT NULL
suggested_person_id           uuid
confidence                    real
evidence_json                 jsonb
created_at                    timestamptz NOT NULL DEFAULT now()
dismissed                     boolean NOT NULL DEFAULT false
dismissed_at                  timestamptz
```

### screenalytics.suggestion_applies `ADD` (0105)

```
apply_id                      uuid PK DEFAULT gen_random_uuid()
batch_id                      uuid -> screenalytics.suggestion_batches(batch_id)
suggestion_id                 uuid -> screenalytics.suggestions(suggestion_id)
ep_id                         text NOT NULL
run_id                        text NOT NULL
applied_at                    timestamptz NOT NULL DEFAULT now()
applied_by                    text
changes_json                  jsonb
```

### screenalytics.outbox_events `ADD` (0106)

```
event_id                      uuid PK DEFAULT gen_random_uuid()
event_type                    text NOT NULL
aggregate_id                  text NOT NULL
payload_json                  jsonb
created_at                    timestamptz NOT NULL DEFAULT now()
delivered_at                  timestamptz
delivery_attempts             integer NOT NULL DEFAULT 0
last_error                    text
```

---

## 19. `admin` Schema

### admin.image_audit_log `KEEP`

```
id                            uuid PK DEFAULT gen_random_uuid()
image_type                    text NOT NULL CHECK IN ('cast', 'episode', 'season')
image_id                      uuid NOT NULL
action                        text NOT NULL CHECK IN ('archive', 'unarchive', 'delete', 'reassign', 'copy_reassign')
performed_by_firebase_uid     text NOT NULL
performed_at                  timestamptz NOT NULL DEFAULT now()
details                       jsonb
```

### admin.cast_photo_people_tags `KEEP`

```
cast_photo_id                 uuid PK -> core.cast_photos(id) CASCADE
people_names                  text[]
people_ids                    text[]
people_count                  integer
people_count_source           text CHECK IN ('manual', 'auto')
detector                      text
created_at                    timestamptz NOT NULL DEFAULT now()
updated_at                    timestamptz NOT NULL DEFAULT now()
created_by_firebase_uid       text
updated_by_firebase_uid       text
```

---

## Summary: Table Count by Status

| Status | Count | Details |
|--------|-------|---------|
| **KEEP** | ~47 | Active tables, no changes needed |
| **MODIFY** | ~6 | Active tables with approved column changes (shows, people, credit_occurrences, people_overrides, tmdb_networks, tmdb_watch_providers, scrape_jobs) |
| **ADD** | ~10 | Screenalytics unification (8) + Reddit scrape tables (2, future) |
| **DEPRECATE** | ~5 | Legacy image tables with bridge layers (show_images, season_images, episode_images, person_images, cast_photos) |
| **DROP** | 11 | games.* (7) + legacy cast tables (4: cast_memberships, episode_cast, show_cast, episode_appearances) |

**Target state: ~63 tables across 6 schemas** (games schema removed)

---

## Migration Sequence for Schema Changes

The following changes require new Supabase migrations (after 0102):

1. **0103-0106**: Screenalytics unification (already planned)
2. **0107**: Drop `games.*` schema (7 tables)
3. **0108**: Drop legacy cast tables (`cast_memberships`, `episode_cast`, `show_cast`, `episode_appearances`) — requires data migration to `credits` + `credit_occurrences` first
4. **0109**: Modify `core.shows` — drop singular columns, consolidate most_recent_episode, drop social IDs
5. **0110**: Enrich `core.people` — add multi-source jsonb fields
6. **0111**: Enrich `core.credit_occurrences` — add rich fields from episode_appearances
7. **0112**: Add social columns to `tmdb_networks` + `tmdb_watch_providers`
8. **0113**: Add social handles to `people_overrides`
9. **0114**: Extend `scrape_jobs.platform` CHECK for reddit
10. **Future**: Add `social.reddit_posts` + `social.reddit_comments`
11. **Future**: Drop legacy image tables (after media system migration complete)
