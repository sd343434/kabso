# Kabso Live — Phase 2 data design: media uploads and countries

Status: **proposed with contract v1.4.0 (KL-048, owner decision D44), awaiting CTO approval.**
This is a design note. The Prisma schema and migration are built by Backend (A3) in the
implementation task that follows KL-048. HTTP behaviour is defined in
[`CONVENTIONS.md`](CONVENTIONS.md) §11 and [`openapi.yaml`](openapi.yaml). It extends
[`DB_PHASE2_DISCOVERY.md`](DB_PHASE2_DISCOVERY.md) and uses the same conventions:
- snake_case tables and columns via `@@map` / `@map`;
- UUIDv7 ids;
- `timestamptz(3)`;
- Prisma enums mapped to Postgres enums;
- hand-written CHECK constraints and partial indexes in the migration SQL, each with a comment.

No storage provider, CDN or moderation provider is activated by this design. Everything here
works, and is tested, with `MEDIA_UPLOADS_ENABLED=false`.

## 1. Ownership

| Table / column | Owning module | Readers (through the owner's service) |
| -------------- | ------------- | ------------------------------------- |
| `media_objects` | `media` (new) | `users` (avatar URL and moderation state), `live` (cover URL and state) |
| `user_profiles.avatar_media_id` | `users`; the attach step calls `media` in the same transaction | `live` (host summary) |
| `user_profiles.country` | `users` | `live` (copied at go-live) |
| `live_rooms.cover_media_id`, `live_rooms.country` | `live` | — |

**Read-only cross-module exceptions** (as in DB_PHASE2_DISCOVERY §1 and D42 item 3):
- The room list and room detail `LEFT JOIN media_objects` twice: once for the cover
  (`live_rooms.cover_media_id`) and once for the host avatar (`user_profiles.avatar_media_id`).
  The joins read only the public token, sizes and moderation state, so a page is one query.
- The public profile and `Me` do the same for the avatar.
- `PATCH /me` with a country change updates the caller's LIVE room's `country` in the same
  transaction (CONVENTIONS §11.8). This is a **write** across modules. It goes through a `live`
  service method (`syncHostCountry(userId, country)`) inside the `users` transaction, not a
  direct table write.

## 2. Table `media_objects`

One row per declared upload. Its `id` is the `uploadId` of the API.

| Column | Type | Null | Default | Notes |
| ------ | ---- | ---- | ------- | ----- |
| `id` | `uuid` | no | uuid v7 (app) | PK; the `uploadId` |
| `owner_user_id` | `uuid` | no | — | FK → `users.id` ON DELETE CASCADE (see §4 for the order of storage deletion) |
| `purpose` | enum `media_purpose` (`AVATAR`, `ROOM_COVER`) | no | — | API values `avatar`, `room_cover` |
| `status` | enum `media_status` (`AWAITING_UPLOAD`, `READY`, `FAILED`, `EXPIRED`, `DELETED`) | no | `AWAITING_UPLOAD` | CONVENTIONS §11.3 |
| `declared_content_type` | `varchar(16)` | no | — | CHECK in (`image/jpeg`, `image/png`, `image/webp`) |
| `declared_bytes` | `integer` | no | — | CHECK `declared_bytes BETWEEN 1 AND 10485760`; the per-purpose limit is enforced in the app |
| `incoming_key` | `varchar(200)` | no | — | Unique. `in/<id>/<128-bit random, base64url>` in the private bucket |
| `upload_expires_at` | `timestamptz(3)` | no | — | End of the presigned URL's validity |
| `detected_content_type` | `varchar(16)` | yes | — | From magic bytes at `complete` |
| `public_token` | `varchar(32)` | yes | — | Unique. 128-bit CSPRNG value, base64url (22 chars). Public keys are `<a\|c>/<public_token>/<size>.webp`. Not derived from `id` or the owner |
| `width`, `height` | `integer` | yes | — | Main derivative (avatar 512², cover 960×1280, or smaller if the source was smaller) |
| `thumb_width`, `thumb_height` | `integer` | yes | — | Thumbnail derivative |
| `stored_bytes` | `integer` | yes | — | Sum of the derivative sizes (cost accounting) |
| `failure_issue` | `varchar(16)` | yes | — | `too_big`, `too_small` or `invalid_format` when `FAILED` |
| `moderation_status` | enum `media_moderation_status` (`PENDING`, `APPROVED`, `REJECTED`) | yes | — | Set to `PENDING` at `complete` |
| `moderation_source` | `varchar(32)` | yes | — | Adapter that decided (`allow_all`, or a provider name). Null while `PENDING` |
| `moderated_at` | `timestamptz(3)` | yes | — | |
| `completed_at` | `timestamptz(3)` | yes | — | |
| `attached_at` | `timestamptz(3)` | yes | — | Set once, never cleared. It enforces "attached at most once" |
| `detached_at` | `timestamptz(3)` | yes | — | When it stopped being the avatar or cover. It starts the grace period |
| `deleted_at` | `timestamptz(3)` | yes | — | When the storage objects were removed |
| `created_at` | `timestamptz(3)` | no | `now()` | |
| `updated_at` | `timestamptz(3)` | no | `@updatedAt` | |

**CHECK constraints** (hand-written):
- `media_objects_content_type`, `media_objects_declared_bytes`: as in the table.
- `media_objects_ready_shape`: a READY row has everything a URL needs.
  ```sql
  status <> 'READY' OR (public_token IS NOT NULL AND width IS NOT NULL AND height IS NOT NULL
    AND thumb_width IS NOT NULL AND thumb_height IS NOT NULL
    AND completed_at IS NOT NULL AND moderation_status IS NOT NULL)
  ```
- `media_objects_failed_shape`: `status <> 'FAILED' OR failure_issue IS NOT NULL`.
- `media_objects_attach_order`: `detached_at IS NULL OR attached_at IS NOT NULL`.

**Indexes:**

| Name | Definition | Serves |
| ---- | ---------- | ------ |
| `media_objects_incoming_key_key` | UNIQUE (`incoming_key`) | Key uniqueness |
| `media_objects_public_token_key` | UNIQUE (`public_token`) | Key uniqueness |
| `media_objects_owner_pending_idx` | (`owner_user_id`) WHERE `status = 'AWAITING_UPLOAD'` | Pending-upload cap (§7); a few rows per user |
| `media_objects_owner_created_idx` | (`owner_user_id`, `created_at` DESC) | Owner lookups; erasure; FK on user delete |
| `media_objects_awaiting_expiry_idx` | (`upload_expires_at`) WHERE `status = 'AWAITING_UPLOAD'` | Cleanup: expire abandoned uploads |
| `media_objects_unattached_idx` | (`completed_at`) WHERE `status = 'READY' AND attached_at IS NULL` | Cleanup: unattached READY uploads |
| `media_objects_detached_idx` | (`detached_at`) WHERE `status = 'READY' AND detached_at IS NOT NULL` | Cleanup: grace-period deletion |
| `media_objects_moderation_pending_idx` | (`completed_at`) WHERE `status = 'READY' AND moderation_status = 'PENDING'` | Re-queue for moderation when a provider is configured |

**Writes:**
- **Attach** (avatar or cover), in one transaction with the profile or room update:
  ```sql
  UPDATE media_objects SET attached_at = now()
  WHERE id = $1 AND owner_user_id = $caller AND purpose = $purpose
    AND status = 'READY' AND attached_at IS NULL
    AND moderation_status <> 'REJECTED'
  RETURNING id
  ```
  0 rows → 400 `invalid_value` (one message for every reason). Then set `avatar_media_id` or
  `cover_media_id`. If an earlier image was attached there, set its `detached_at = now()`.
- **Reject:** set `moderation_status = 'REJECTED'`, null the referencing column with
  `WHERE avatar_media_id = $id` (or `cover_media_id`), set `detached_at`, and queue deletion at
  once (no grace period).
- **Concurrency:** `complete` takes the row with `SELECT … FOR UPDATE` on the `AWAITING_UPLOAD`
  row, so two concurrent completes process the image once. The loser waits and then returns the
  winner's result (idempotent).

## 3. Changes to existing tables

### 3.1 `user_profiles`

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `avatar_media_id` | `uuid` | yes | FK → `media_objects.id` ON DELETE SET NULL. UNIQUE (`user_profiles_avatar_media_id_key`) |
| `country` | `char(2)` | yes | CHECK `country ~ '^[A-Z]{2}$'` (`user_profiles_country_format`). Membership in the vendored list is checked in the app (CONVENTIONS §11.7); the list changes only by contract patch, so no FK table |
| `avatar_url` (existing) | `varchar(2048)` | yes | **Kept and unused.** Always null today, because no endpoint ever wrote it. It is not read in v1.4. It is dropped in a later contract-phase migration (expand/contract, DEPLOYMENT.md) |

### 3.2 `live_rooms`

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `cover_media_id` | `uuid` | yes | FK → `media_objects.id` ON DELETE SET NULL. UNIQUE (`live_rooms_cover_media_id_key`) |
| `country` | `char(2)` | yes | Copy of the host's `user_profiles.country` at go-live, kept in sync while LIVE (CONVENTIONS §11.8). CHECK `country ~ '^[A-Z]{2}$'` |
| `cover_url` (existing) | `varchar(2048)` | yes | **Kept and unused**, as for `avatar_url` |

**Decision: URLs are computed, not stored.** The response fields `avatarUrl`, `avatarThumbUrl`,
`coverUrl` and `coverThumbUrl` are built at read time from `MEDIA_PUBLIC_BASE_URL` and
`public_token`, and filtered by the visibility rule (CONVENTIONS §11.5). Reasons:
- moderation visibility needs the media row in any case;
- moving to another CDN host or provider changes one setting, with no rewrite of stored URLs;
- the server can never return a stored URL that points outside the allowed base (§11.10).

The v1.3 response shapes are unchanged: the URL fields keep their names and types.

**New partial indexes on `live_rooms`** (country filter and `GET /live/countries`):

| Name | Definition | Serves |
| ---- | ---------- | ------ |
| `live_rooms_live_country_new_idx` | (`country`, `started_at` DESC, `id` DESC) WHERE `status = 'LIVE' AND country IS NOT NULL` | `new` / `following` + `country`; per-country counts (`GROUP BY country`) |
| `live_rooms_live_country_popular_idx` | (`country`, `viewer_count` DESC, `started_at` DESC, `id` DESC) WHERE `status = 'LIVE' AND country IS NOT NULL` | `popular` + `country` |

- `category` and `country` together: the country index is used, and `category_id` is a residual
  filter. Per-country LIVE sets are small.
- The freshness predicate and the ACTIVE-host join stay residual filters, as in
  DB_PHASE2_DISCOVERY §2.2.
- The counts query is one `SELECT country, count(*) … GROUP BY country` with the list predicate.
  It may be cached in process for ≤ `LIVE_HEARTBEAT_INTERVAL_SECONDS`.

**Country sync on `PATCH /me`:**
```sql
UPDATE live_rooms SET country = $new
WHERE host_user_id = $caller AND status = 'LIVE'
```
This runs in the same transaction as the profile update. `ENDED` rows are not touched.

## 4. Retention, privacy and cleanup (feeds PP-08)

- **New personal data:**
  - **Images** are user content and public once approved. They have no metadata: EXIF/GPS is
    stripped and originals are deleted at `complete`.
  - **`country`** is public profile data that the user chose. No history is kept: the audit
    action `users.country.update` records only that it changed, never the value.
  - No IP, device or location columns are added.
- **Cleanup job** (CONVENTIONS §11.6): every `MEDIA_CLEANUP_INTERVAL_SECONDS`, in batches of at
  most `MEDIA_CLEANUP_BATCH_SIZE` rows, each batch in its own short transaction with
  `FOR UPDATE SKIP LOCKED`. Runs do not overlap within a process and are safe across pods.
  - **Storage first, row second.** The job deletes the storage objects, then marks the row
    `DELETED` (`deleted_at`). If a storage delete fails, the row is left as it was and retried
    on the next run, so no object loses its only reference.
  - Ended-room covers: rooms with `status = 'ENDED' AND ended_at <
    now() - MEDIA_ENDED_ROOM_COVER_TTL_HOURS` and a non-null `cover_media_id` are detached first,
    then deleted as above.
  - `FAILED` rows are removed 7 days after `created_at`. `EXPIRED` and `DELETED` rows are removed
    30 days after `updated_at`; they are kept only for abuse analysis.
- **Account soft delete** (`status = DELETED`, KL-014): the `AccountLifecycleService` calls
  `MediaService.purgeUser`. That detaches the avatar and the covers of the user's rooms and
  deletes all of the user's objects within 24 h. Suspension keeps the media; the profile is
  404 anyway.
- **Hard erasure:** `MediaService.purgeUser` runs **before** the `users` row is deleted. The
  cascade on `owner_user_id` then removes the rows. A missed object is caught by the weekly
  reconciliation below.
- **Weekly reconciliation:** list both buckets and delete objects that have no live row and are
  older than 7 days. This needs `ListBucket` on both buckets for the server credential; listing
  stays closed to the public.
- **Bucket lifecycle rule:** the incoming bucket expires every object after 1 day.

## 5. Migration plan

- **One forward-only, additive migration**, e.g. `<timestamp>_media_and_countries`, containing:
  1. `CREATE TYPE media_purpose`, `media_status`, `media_moderation_status`.
  2. `CREATE TABLE media_objects` with its PK, FK, CHECKs and indexes (§2).
  3. `ALTER TABLE user_profiles ADD COLUMN avatar_media_id uuid NULL, ADD COLUMN country char(2)
     NULL`, and `ALTER TABLE live_rooms ADD COLUMN cover_media_id uuid NULL, ADD COLUMN country
     char(2) NULL`. These are nullable with no default, so they are metadata-only changes with no
     table rewrite.
  4. The CHECKs and FKs on the existing tables, added `NOT VALID`, then `VALIDATE CONSTRAINT`.
     The new columns are all null, so validation is instant and takes only a `SHARE UPDATE
     EXCLUSIVE` lock.
  5. The unique and partial indexes on `user_profiles` and `live_rooms`. Before launch the
     tables are small, so plain `CREATE INDEX` in the migration is acceptable. After launch, an
     index on a large table goes into its own migration with `CREATE INDEX CONCURRENTLY`
     (outside a transaction), per DEPLOYMENT.md.
- **No backfill.** Every new column starts null, which matches the contract: no avatar, no
  cover and no country until the user sets one.
- **Rollback:** before production data exists, a down script drops the indexes, constraints and
  columns, the table and the types. After launch, roll forward only.
- **Prisma:** partial indexes and CHECKs are declared the same way as in the `live_discovery`
  migration. Every later `prisma migrate dev` diff is reviewed for spurious `DROP` statements.
- **Config** (env schema, Zod, fail-fast). Secrets have no default and no example value. They
  come from the secret manager (PP-09) and are never committed (D40).

  | Variable | Default | Validation |
  | -------- | ------- | ---------- |
  | `MEDIA_UPLOADS_ENABLED` | `false` | `true` requires every storage variable below; otherwise the API refuses to boot |
  | `MEDIA_MODERATION_PROVIDER` | `none` | `none` \| `allow_all` (refused at boot when `NODE_ENV=production`); provider adapters are added by contract patch |
  | `MEDIA_STORAGE_ENDPOINT` | unset (the SDK's AWS default) | Absolute URL; `https` in production |
  | `MEDIA_STORAGE_REGION` | unset | Required when enabled (some providers use a fixed value such as `auto`) |
  | `MEDIA_STORAGE_FORCE_PATH_STYLE` | `false` | Boolean |
  | `MEDIA_STORAGE_INCOMING_BUCKET` | unset | Required when enabled; must differ from the public bucket |
  | `MEDIA_STORAGE_PUBLIC_BUCKET` | unset | Required when enabled |
  | `MEDIA_STORAGE_ACCESS_KEY_ID` | — (secret) | Required when enabled |
  | `MEDIA_STORAGE_SECRET_ACCESS_KEY` | — (secret) | Required when enabled; never logged |
  | `MEDIA_PUBLIC_BASE_URL` | unset | Required when enabled. Absolute URL without query or fragment. In production: `https`, and a host different from the API's |
  | `MEDIA_UPLOAD_URL_TTL_SECONDS` | `600` | 60–900 |
  | `MEDIA_MAX_PENDING_PER_USER` | `5` | 1–20 |
  | `MEDIA_DAILY_BYTES_PER_USER` | `104857600` (100 MiB) | 10 MiB – 1 GiB |
  | `MEDIA_PROCESS_MAX_CONCURRENCY` | `2` | 1–16 (per process) |
  | `MEDIA_PROCESS_TIMEOUT_MS` | `10000` | 1000–60000 |
  | `MEDIA_UNATTACHED_TTL_HOURS` | `24` | 1–168 |
  | `MEDIA_DELETE_GRACE_HOURS` | `24` | 1–168 |
  | `MEDIA_ENDED_ROOM_COVER_TTL_HOURS` | `24` | 0–168 |
  | `MEDIA_CLEANUP_INTERVAL_SECONDS` | `300` | 60–3600 |
  | `MEDIA_CLEANUP_BATCH_SIZE` | `500` | 1–5000 (named like `LIVE_SWEEP_BATCH_SIZE`, D43) |

  `GET /media/config` reports `uploadsEnabled = MEDIA_UPLOADS_ENABLED`; the limits in CONVENTIONS
  §11.2 are constants of the contract, not settings.
- **Vendored data:** the country code list and the CLDR 48 `ar`/`en` territory names, with
  their sha256 recorded next to them (CONVENTIONS §11.7). Nothing is downloaded at build time or
  at runtime.

## 6. Runtime DB role grants (KL-013)

The same rules as DB_PHASE2_DISCOVERY §5 apply:

1. Run as `kabso_migrator`, the migration needs **no explicit GRANT**. Default privileges give
   `kabso_app` DML on `media_objects`. The `ALTER TABLE` on `user_profiles` and `live_rooms`
   keeps their existing grants.
2. `media_objects` is **not** append-only. The `media` module updates status and moderation
   fields, and the cleanup job deletes rows. No `REVOKE` is needed.
3. The new enum types get `USAGE` through `PUBLIC`, as before.
4. **Verification:** the role tests are extended:
   - `kabso_app` can `SELECT/INSERT/UPDATE/DELETE` on `media_objects`;
   - `TRUNCATE media_objects` and `ALTER TABLE media_objects …` fail.

## 7. Open points for review

- Whether image processing runs in-process with a concurrency cap (this design) or in a separate
  sandboxed worker (A7 review item, CONVENTIONS §11.13).
- Whether denormalized URL columns are ever needed for read performance. Measure the two
  `LEFT JOIN`s in the PP-32 load test before adding any.
- When to drop the unused `avatar_url` / `cover_url` columns (a contract-phase migration after
  v1.4 ships).
