-- KL-049: contract v1.4 — media uploads (avatars, live-room covers) and the user-chosen country
-- (docs/contracts/DB_PHASE2_MEDIA.md §5). Forward-only and additive: three new types, one new
-- table, four nullable columns without defaults on existing tables (metadata-only, no rewrite) and
-- no backfill: no avatar, no cover and no country until the user sets one.
--
-- Runs as the migration role (KL-013 / KL-013b). The runtime group of this database
-- (`kabso_runtime_<database>`) gets SELECT, INSERT, UPDATE and DELETE on `media_objects` through
-- the default privileges set by 20261016130000_per_database_runtime_group, so this migration
-- contains no GRANT. `media_objects` is not append-only (status and moderation updates, cleanup
-- deletes), so no REVOKE either. The ALTER TABLEs keep the existing grants of `user_profiles` and
-- `live_rooms`. The enum types are usable through PUBLIC, as before. No function is created.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_roles r
     WHERE pg_has_role(current_user, r.oid, 'MEMBER')
       AND (r.rolsuper OR r.rolcreaterole OR r.rolbypassrls OR r.rolreplication)
  ) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL); "%" is or can become a superuser / CREATEROLE / BYPASSRLS / REPLICATION role', current_user;
  END IF;
END
$$;

-- CreateEnum
CREATE TYPE "media_purpose" AS ENUM ('AVATAR', 'ROOM_COVER');

-- CreateEnum
CREATE TYPE "media_status" AS ENUM ('AWAITING_UPLOAD', 'READY', 'FAILED', 'EXPIRED', 'DELETED');

-- CreateEnum
CREATE TYPE "media_moderation_status" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- CreateTable
CREATE TABLE "media_objects" (
    "id" UUID NOT NULL,
    "owner_user_id" UUID NOT NULL,
    "purpose" "media_purpose" NOT NULL,
    "status" "media_status" NOT NULL DEFAULT 'AWAITING_UPLOAD',
    "declared_content_type" VARCHAR(16) NOT NULL,
    "declared_bytes" INTEGER NOT NULL,
    "incoming_key" VARCHAR(200) NOT NULL,
    "upload_expires_at" TIMESTAMPTZ(3) NOT NULL,
    "detected_content_type" VARCHAR(16),
    "public_token" VARCHAR(32),
    "width" INTEGER,
    "height" INTEGER,
    "thumb_width" INTEGER,
    "thumb_height" INTEGER,
    "stored_bytes" INTEGER,
    "failure_issue" VARCHAR(16),
    "moderation_status" "media_moderation_status",
    "moderation_source" VARCHAR(32),
    "moderated_at" TIMESTAMPTZ(3),
    "completed_at" TIMESTAMPTZ(3),
    "attached_at" TIMESTAMPTZ(3),
    "detached_at" TIMESTAMPTZ(3),
    "deleted_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "media_objects_pkey" PRIMARY KEY ("id")
);

-- CreateIndex: storage key uniqueness.
CREATE UNIQUE INDEX "media_objects_incoming_key_key" ON "media_objects"("incoming_key");

-- CreateIndex
CREATE UNIQUE INDEX "media_objects_public_token_key" ON "media_objects"("public_token");

-- CreateIndex: owner lookups; erasure; the FK on user deletion.
CREATE INDEX "media_objects_owner_created_idx" ON "media_objects"("owner_user_id", "created_at" DESC);

-- Hand-written partial indexes (DB_PHASE2_MEDIA §2). Mirrored in schema.prisma (preview feature
-- `partialIndexes`) with the predicate exactly as PostgreSQL stores it.

-- Pending-upload cap (CONVENTIONS §7): a few rows per user.
CREATE INDEX "media_objects_owner_pending_idx" ON "media_objects"("owner_user_id") WHERE (status = 'AWAITING_UPLOAD'::media_status);

-- Cleanup: expire abandoned uploads.
CREATE INDEX "media_objects_awaiting_expiry_idx" ON "media_objects"("upload_expires_at") WHERE (status = 'AWAITING_UPLOAD'::media_status);

-- Cleanup: READY uploads that were never attached.
CREATE INDEX "media_objects_unattached_idx" ON "media_objects"("completed_at") WHERE ((status = 'READY'::media_status) AND (attached_at IS NULL));

-- Cleanup: grace-period deletion of detached avatars and covers.
CREATE INDEX "media_objects_detached_idx" ON "media_objects"("detached_at") WHERE ((status = 'READY'::media_status) AND (detached_at IS NOT NULL));

-- Re-queue for moderation once a provider is configured.
CREATE INDEX "media_objects_moderation_pending_idx" ON "media_objects"("completed_at") WHERE ((status = 'READY'::media_status) AND (moderation_status = 'PENDING'::media_moderation_status));

-- KL-049 addition (not in DB_PHASE2_MEDIA §2): cleanup deletes REJECTED images at once
-- (CONVENTIONS §11.6) without scanning the table.
CREATE INDEX "media_objects_rejected_idx" ON "media_objects"("moderated_at") WHERE ((status = 'READY'::media_status) AND (moderation_status = 'REJECTED'::media_moderation_status));

-- KL-049 addition (not in DB_PHASE2_MEDIA §2): removal of FAILED (7 days) and EXPIRED / DELETED
-- (30 days) rows (DB_PHASE2_MEDIA §4) without scanning the table.
CREATE INDEX "media_objects_terminal_idx" ON "media_objects"("updated_at") WHERE (status = ANY (ARRAY['FAILED'::media_status, 'EXPIRED'::media_status, 'DELETED'::media_status]));

-- AddForeignKey: an upload belongs to its owner; hard erasure removes the rows (the media module
-- deletes the storage objects first, DB_PHASE2_MEDIA §4).
ALTER TABLE "media_objects" ADD CONSTRAINT "media_objects_owner_user_id_fkey" FOREIGN KEY ("owner_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Hand-written CHECK constraints on media_objects (second line of defence behind the application).

ALTER TABLE "media_objects" ADD CONSTRAINT "media_objects_content_type"
    CHECK ("declared_content_type" IN ('image/jpeg', 'image/png', 'image/webp'));

-- The per-purpose limit (avatar 5 MiB, cover 10 MiB) is enforced in the application.
ALTER TABLE "media_objects" ADD CONSTRAINT "media_objects_declared_bytes"
    CHECK ("declared_bytes" BETWEEN 1 AND 10485760);

-- A READY row has everything a URL needs.
ALTER TABLE "media_objects" ADD CONSTRAINT "media_objects_ready_shape"
    CHECK ("status" <> 'READY' OR ("public_token" IS NOT NULL AND "width" IS NOT NULL AND "height" IS NOT NULL
        AND "thumb_width" IS NOT NULL AND "thumb_height" IS NOT NULL
        AND "completed_at" IS NOT NULL AND "moderation_status" IS NOT NULL));

-- A FAILED row records why.
ALTER TABLE "media_objects" ADD CONSTRAINT "media_objects_failed_shape"
    CHECK ("status" <> 'FAILED' OR "failure_issue" IS NOT NULL);

-- Detached only after attached.
ALTER TABLE "media_objects" ADD CONSTRAINT "media_objects_attach_order"
    CHECK ("detached_at" IS NULL OR "attached_at" IS NOT NULL);

-- AlterTable: nullable, no default → metadata-only (no table rewrite).
ALTER TABLE "user_profiles" ADD COLUMN "avatar_media_id" UUID,
ADD COLUMN "country" CHAR(2);

-- AlterTable
ALTER TABLE "live_rooms" ADD COLUMN "cover_media_id" UUID,
ADD COLUMN "country" CHAR(2);

-- Constraints on the existing tables: added NOT VALID, then validated. The new columns are all
-- null, so validation is instant and takes only a SHARE UPDATE EXCLUSIVE lock.

-- Membership in the vendored country list is checked in the application (CONVENTIONS §11.7).
ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_country_format"
    CHECK ("country" ~ '^[A-Z]{2}$') NOT VALID;
ALTER TABLE "user_profiles" VALIDATE CONSTRAINT "user_profiles_country_format";

ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_country_format"
    CHECK ("country" ~ '^[A-Z]{2}$') NOT VALID;
ALTER TABLE "live_rooms" VALIDATE CONSTRAINT "live_rooms_country_format";

-- AddForeignKey: a rejected or purged image detaches itself (SET NULL).
ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_avatar_media_id_fkey" FOREIGN KEY ("avatar_media_id") REFERENCES "media_objects"("id") ON DELETE SET NULL ON UPDATE CASCADE NOT VALID;
ALTER TABLE "user_profiles" VALIDATE CONSTRAINT "user_profiles_avatar_media_id_fkey";

-- AddForeignKey
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_cover_media_id_fkey" FOREIGN KEY ("cover_media_id") REFERENCES "media_objects"("id") ON DELETE SET NULL ON UPDATE CASCADE NOT VALID;
ALTER TABLE "live_rooms" VALIDATE CONSTRAINT "live_rooms_cover_media_id_fkey";

-- CreateIndex: an upload is attached at most once (also serves the FK).
CREATE UNIQUE INDEX "user_profiles_avatar_media_id_key" ON "user_profiles"("avatar_media_id");

-- CreateIndex
CREATE UNIQUE INDEX "live_rooms_cover_media_id_key" ON "live_rooms"("cover_media_id");

-- Country filter: tab=new / following + country; per-country counts (GROUP BY country).
CREATE INDEX "live_rooms_live_country_new_idx" ON "live_rooms"("country", "started_at" DESC, "id" DESC) WHERE ((status = 'LIVE'::live_room_status) AND (country IS NOT NULL));

-- Country filter: tab=popular + country.
CREATE INDEX "live_rooms_live_country_popular_idx" ON "live_rooms"("country", "viewer_count" DESC, "started_at" DESC, "id" DESC) WHERE ((status = 'LIVE'::live_room_status) AND (country IS NOT NULL));
