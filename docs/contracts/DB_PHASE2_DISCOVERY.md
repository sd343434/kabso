# Kabso Live — Phase 2 slice 1 data design: live discovery and follow

Status: **proposed with contract v1.3 (KL-036), awaiting CTO approval.** This is a design note.
The Prisma schema and migration are built in KL-037 by Backend (A3), which starts only after
KL-013 (least-privilege DB roles) has merged. HTTP behaviour is defined in
[`CONVENTIONS.md`](CONVENTIONS.md) §10 and [`openapi.yaml`](openapi.yaml).

Conventions are the same as Phase 1 (`apps/api/prisma/schema.prisma`):
- snake_case tables and columns via `@@map` / `@map`;
- UUIDv7 ids (`@default(uuid(7)) @db.Uuid`);
- `timestamptz(3)`;
- Prisma enums mapped to Postgres enums;
- hand-written CHECK constraints and partial indexes in the migration SQL, each with a comment
  (Prisma does not model them).

## 1. Ownership

Each module owns its tables (SYSTEM_ARCHITECTURE §3). Other modules go through the owning
module's service, never its tables directly.

| Table | Owning module | Readers (through the owner's service) |
| ----- | ------------- | ------------------------------------- |
| `live_categories` | `live` | — |
| `live_rooms` | `live` | `users` (`liveRoomId` on the public profile) |
| `follows` | `social` (follow graph; KL-037 may call the Nest module `follows`) | `live` (Following tab), `users` (counts, `isFollowing`) |

The Following query needs data from both modules. `live` asks `social` for nothing per row.
Instead, the `live` repository runs a single SQL statement that joins `follows`, a documented
**read-only** exception, so the list can paginate in the database. The exception is limited to
that one query.

## 2. Tables

### 2.1 `live_categories`

| Column | Type | Null | Default | Notes |
| ------ | ---- | ---- | ------- | ----- |
| `id` | `uuid` | no | uuid v7 (app) | PK |
| `slug` | `varchar(32)` | no | — | Unique. CHECK `slug ~ '^[a-z0-9-]{2,32}$'` (`live_categories_slug_format`) |
| `name_ar` | `varchar(40)` | no | — | CHECK `char_length(btrim(name_ar)) BETWEEN 1 AND 40` |
| `name_en` | `varchar(40)` | no | — | Same CHECK |
| `sort_order` | `integer` | no | `0` | Ascending; ties broken by `slug` |
| `is_active` | `boolean` | no | `true` | Rows are deactivated, never deleted (rooms reference them) |
| `created_at` | `timestamptz(3)` | no | `now()` | |
| `updated_at` | `timestamptz(3)` | no | `@updatedAt` | |

- **Indexes:**
  - `live_categories_slug_key` UNIQUE (`slug`).
  - The table is tiny (≤ 100 active rows), so the list query is a sequential scan with a sort,
    and it needs no extra index.
- **Seed:** none. The owner has chosen no categories (D36 Q7, D37). Do **not** add a seed
  migration or fixtures to the production seed path. Test fixtures insert their own rows.
- **Future admin management** (out of scope for v1.3):
  - ADMIN-role endpoints in the `admin` module that call `live`'s service;
  - audit actions `admin.live_category.create|update|deactivate`;
  - the ≤ 100 active-rows cap is enforced in that service (CONVENTIONS §10.1).

### 2.2 `live_rooms`

| Column | Type | Null | Default | Notes |
| ------ | ---- | ---- | ------- | ----- |
| `id` | `uuid` | no | uuid v7 (app) | PK |
| `host_user_id` | `uuid` | no | — | FK → `users.id` ON DELETE CASCADE (rooms are the host's content; hard erasure removes them) |
| `title` | `varchar(160)` | no | — | Validated in the application (1–80 graphemes, CONVENTIONS §10.3). CHECK `char_length(title) BETWEEN 1 AND 160` |
| `category_id` | `uuid` | yes | — | FK → `live_categories.id` ON DELETE RESTRICT |
| `status` | enum `live_room_status` (`LIVE`, `ENDED`) | no | `LIVE` | |
| `mode` | enum `live_room_mode` (`SOLO`, `PK`, `MULTI`) | no | `SOLO` | Only `SOLO` is created in v1.3 |
| `started_at` | `timestamptz(3)` | no | `now()` | |
| `last_heartbeat_at` | `timestamptz(3)` | no | `now()` | Set to `started_at` on creation |
| `ended_at` | `timestamptz(3)` | yes | — | |
| `end_reason` | enum `live_room_end_reason` (`HOST_ENDED`, `HEARTBEAT_TIMEOUT`, `HOST_SUSPENDED`, `ADMIN`) | yes | — | |
| `viewer_count` | `integer` | no | `0` | CHECK `viewer_count >= 0`. **Always 0 in v1.3**: no realtime presence exists. Written only by the future presence service |
| `cover_url` | `varchar(2048)` | yes | — | **Always null in v1.3** (no upload) |
| `created_at` | `timestamptz(3)` | no | `now()` | |
| `updated_at` | `timestamptz(3)` | no | `@updatedAt` | |

**CHECK constraints** (hand-written):

- `live_rooms_end_state`: the end fields are consistent with the status.
  ```sql
  (status = 'LIVE'  AND ended_at IS NULL     AND end_reason IS NULL)
  OR
  (status = 'ENDED' AND ended_at IS NOT NULL AND end_reason IS NOT NULL)
  ```
- `live_rooms_time_order`:
  ```sql
  last_heartbeat_at >= started_at AND (ended_at IS NULL OR ended_at >= started_at)
  ```
- `live_rooms_title_length` and `live_rooms_viewer_count_nonneg`, as listed in the table above.

**Indexes:**
- Prisma cannot express a `WHERE` clause on an index here, so every partial index is hand-written
  SQL in the migration. KL-037 must check whether Prisma 7.10 supports partial indexes natively.
  If it does not, every later `prisma migrate dev` diff must be reviewed for spurious `DROP INDEX`
  statements on these indexes, as is already done for the CHECKs.
- The staleness predicate (`last_heartbeat_at > now() - interval`) is a residual filter on top of
  these indexes. The set of LIVE rooms is small, and the sweeper keeps stale rows out of it.

| Name | Definition | Serves |
| ---- | ---------- | ------ |
| `live_rooms_one_live_per_host` | UNIQUE (`host_user_id`) WHERE `status = 'LIVE'` | One LIVE room per host (409 `LIVE_ROOM_ALREADY_ACTIVE`); lookup of a host's live room (`liveRoomId`, Following join) |
| `live_rooms_live_popular_idx` | (`viewer_count` DESC, `started_at` DESC, `id` DESC) WHERE `status = 'LIVE'` | `tab=popular` keyset |
| `live_rooms_live_new_idx` | (`started_at` DESC, `id` DESC) WHERE `status = 'LIVE'` | `tab=new` keyset; `tab=following` ordering |
| `live_rooms_live_cat_popular_idx` | (`category_id`, `viewer_count` DESC, `started_at` DESC, `id` DESC) WHERE `status = 'LIVE'` | `popular` + `category` |
| `live_rooms_live_cat_new_idx` | (`category_id`, `started_at` DESC, `id` DESC) WHERE `status = 'LIVE'` | `new` / `following` + `category` |
| `live_rooms_live_heartbeat_idx` | (`last_heartbeat_at`) WHERE `status = 'LIVE'` | Sweeper (`WHERE status='LIVE' AND last_heartbeat_at <= now() - stale`) |
| `live_rooms_host_started_idx` | (`host_user_id`, `started_at` DESC) | The host's room history (future profile/analytics); FK lookups on user erasure |
| `live_rooms_category_id_idx` | (`category_id`) | FK check when a category is deleted (normally never) |

**State transitions** (all are single `UPDATE … WHERE status = 'LIVE'` statements, so concurrent
end, timeout and suspension resolve to exactly one winner):

```text
(insert) ──► LIVE ──host end──────► ENDED (HOST_ENDED,        ended_at = now())
                  ──stale sweep───► ENDED (HEARTBEAT_TIMEOUT, ended_at = last_heartbeat_at)
                  ──suspension────► ENDED (HOST_SUSPENDED,    ended_at = now())
                  ──admin (later)─► ENDED (ADMIN,             ended_at = now())
```

- **Heartbeat:**
  ```sql
  UPDATE live_rooms
  SET last_heartbeat_at = now()
  WHERE id = $1 AND host_user_id = $caller AND status = 'LIVE'
    AND last_heartbeat_at > now() - $stale
  ```
  - 0 rows → re-read the room.
  - If it is not the caller's room (or does not exist), the result is 404.
  - If it is the caller's room and is LIVE but stale, end it (`HEARTBEAT_TIMEOUT`) and return
    409 `LIVE_ROOM_ENDED`. If it is already ENDED, return 409.
  - A late heartbeat therefore never revives a room that lists have already hidden. This keeps
    "stale is never LIVE" (CONVENTIONS §10.2) exact, independent of sweeper timing.
- **Go-live** runs in one transaction:
  1. End the caller's stale LIVE room, if any.
  2. Insert the new room.
  3. If the partial unique index raises a violation, return 409.

### 2.3 `follows`

| Column | Type | Null | Default | Notes |
| ------ | ---- | ---- | ------- | ----- |
| `follower_id` | `uuid` | no | — | FK → `users.id` ON DELETE CASCADE |
| `followee_id` | `uuid` | no | — | FK → `users.id` ON DELETE CASCADE |
| `created_at` | `timestamptz(3)` | no | `now()` | |

- **PK:** (`follower_id`, `followee_id`). It also serves "whom do I follow" (Following tab,
  `followingCount`, `isFollowing`).
- **CHECK** `follows_no_self_follow`: `follower_id <> followee_id`.
- **Index** `follows_followee_id_created_at_idx`: (`followee_id`, `created_at` DESC). It serves
  `followerCount` and a future followers list.
- **Writes:**
  - Follow: `INSERT … ON CONFLICT DO NOTHING`.
  - Unfollow: `DELETE … WHERE follower_id = $1 AND followee_id = $2`.
  - Both are idempotent at the database level.
  - The target's ACTIVE status and `is_private` are checked in the same transaction as the write.
- **Counts:** `count(*)` on these indexes at read time in v1.3.
  - Switch to denormalized counters (a `user_stats` table updated in the same transaction) when a
    profile's follower count makes this read measurably slow. That threshold is to be measured;
    it is not set by this design.

## 3. Retention and privacy

- **No new personal data beyond user content:**
  - room titles are user-authored public text;
  - follows are a public social graph (exposed today only as counts and `isFollowing`).
  - No IP, device or location columns.
- **`live_rooms`:** ENDED rows are kept. Later slices (gifts, earnings, moderation) will
  reference rooms. They are removed by cascade on hard user erasure. The KL-014 retention job
  decides on any time-based purge of old ENDED rooms of active users. Proposal: none before Phase
  8, when financial references make the rows evidentiary.
- **`follows`:**
  - deleted in both directions when a user is hard-deleted (cascade);
  - the soft-delete flow (`status = DELETED`) must also delete them explicitly, because cascade
    does not fire on soft delete (KL-037 + KL-014);
  - kept while an account is suspended, so they are restored when it is unsuspended.
- **`live_categories`:** configuration data with no PII.
- **Audit (CONVENTIONS §10.3):** `live.room.start`, `live.room.end`, `live.room.timeout` in
  `audit_logs`, with `target_type = 'live_room'` and `target_id` the room id. Follows are not
  audited per edge.

## 4. Migration plan (KL-037)

- **One forward-only, additive migration**, e.g. `<timestamp>_live_discovery`, containing:
  1. `CREATE TYPE live_room_status`, `live_room_mode`, `live_room_end_reason`.
  2. `CREATE TABLE live_categories`, `live_rooms`, `follows`, with PKs, FKs and defaults.
  3. The hand-written CHECK constraints (§2), each preceded by a comment, in the style of
     `20261015132258_init`.
  4. The hand-written partial indexes (§2.2) and the regular indexes.
- **Locks:** adding FKs that reference `users` takes a short `SHARE ROW EXCLUSIVE` lock on
  `users`. The new tables are empty, so validation is instant. No existing table is altered and
  there is no backfill, which meets the DEPLOYMENT.md expand/contract rules trivially.
- **Rollback:** before any production data exists, a down script drops the three tables and the
  three types. After launch, roll forward only (the standard DEPLOYMENT.md policy).
- **No seed data** (§2.1).
- **Config** (env schema, Zod, fail-fast; KL-037):

  | Variable | Default | Allowed range |
  | -------- | ------- | ------------- |
  | `LIVE_HOSTING_ENABLED` | `false` | — |
  | `LIVE_HEARTBEAT_INTERVAL_SECONDS` | `15` | 5–60 |
  | `LIVE_HEARTBEAT_STALE_SECONDS` | `45` | ≥ 2 × interval |
  | `LIVE_SWEEP_INTERVAL_SECONDS` | `15` | — |
  | cursor HMAC key | derived from an existing server secret via HKDF with a distinct label (the same pattern as `REGISTRATION_CODE_KEY` / `RATE_LIMIT_KEY_SECRET`) | — |

  KL-037 picks the source secret; A7 reviews it.
- **Sweeper:**
  - a periodic job in the API process, every `LIVE_SWEEP_INTERVAL_SECONDS`;
  - one `UPDATE … WHERE status='LIVE' AND last_heartbeat_at <= now() - stale RETURNING id`;
  - safe to run concurrently on several pods, because the `WHERE status='LIVE'` guard makes it
    idempotent;
  - it writes `live.room.timeout` audit rows for the returned ids.

## 5. Runtime DB role grants (coordination with KL-013)

KL-013 is being built in parallel. Its design (DEPLOYMENT.md §5.1) has the following parts:
- a `kabso_migrator` role that owns the schema and runs every migration;
- a DML-only `kabso_app` runtime role;
- `ALTER DEFAULT PRIVILEGES FOR ROLE kabso_migrator IN SCHEMA public GRANT SELECT, INSERT,
  UPDATE, DELETE ON TABLES TO kabso_app` (plus sequences).

What that means for this slice:

1. **No explicit GRANT is needed** in the `live_discovery` migration, **provided it runs as
   `kabso_migrator`**: default privileges apply automatically to the three new tables. This is
   why KL-037 depends on KL-013 being merged; it must not land before it.
2. **None of the new tables is append-only**, so no `REVOKE` is needed (unlike `audit_logs`).
   The `live` module needs UPDATE on `live_rooms` (heartbeat, end, sweep). `social` needs INSERT
   and DELETE on `follows`; it never UPDATEs `follows`, but a column-level revoke is not worth the
   complexity.
3. **Enum types:** Postgres grants `USAGE` on new types to `PUBLIC` by default, so `kabso_app`
   can use `live_room_*` without a grant. KL-013 must not revoke type usage from `PUBLIC` without
   adding explicit grants.
4. **Verification:** KL-037 extends the KL-013 negative/positive role tests (CI runs e2e as
   `kabso_app`) with these checks:
   - `kabso_app` can `SELECT/INSERT/UPDATE/DELETE` on `live_rooms`, `follows` and
     `live_categories`;
   - `TRUNCATE live_rooms` and `ALTER TABLE follows …` fail.
5. **If KL-013 slips** and the migration would have to run as the old owner role, KL-037 adds
   explicit `GRANT SELECT, INSERT, UPDATE, DELETE ON live_categories, live_rooms, follows TO
   kabso_app` guarded by a role-existence check. The CTO must approve this; it is the fallback,
   not the plan.
6. **Seeding categories later** via an ops script is DML. Under KL-013 it runs as `kabso_app`
   or as the migrator, never as the bootstrap admin.

## 6. Open points for review

- Partial-index support in Prisma 7.10 (§2.2) — A3 to verify. Hand-written SQL is the fallback.
- Counter denormalization threshold (§2.3) — measure in KL-037 load tests.
- Time-based purge of old ENDED rooms — KL-014.
