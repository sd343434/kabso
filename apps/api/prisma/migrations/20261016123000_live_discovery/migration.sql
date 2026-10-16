-- KL-037: contract v1.3 — live discovery, host lifecycle and follow
-- (docs/contracts/DB_PHASE2_DISCOVERY.md). Forward-only and additive: three new types, three new
-- tables, no change to an existing table and no backfill. No seed data (D37: no categories).
--
-- Runs as the migration role (KL-013). The runtime group `kabso_runtime` gets SELECT, INSERT,
-- UPDATE and DELETE on the new tables through the default privileges set by
-- 20261016120000_runtime_role_grants, so this migration contains no GRANT. None of the new tables
-- is append-only, so no REVOKE is needed either.
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

-- CreateEnum
CREATE TYPE "live_room_status" AS ENUM ('LIVE', 'ENDED');

-- CreateEnum
CREATE TYPE "live_room_mode" AS ENUM ('SOLO', 'PK', 'MULTI');

-- CreateEnum
CREATE TYPE "live_room_end_reason" AS ENUM ('HOST_ENDED', 'HEARTBEAT_TIMEOUT', 'HOST_SUSPENDED', 'ADMIN');

-- CreateTable
CREATE TABLE "live_categories" (
    "id" UUID NOT NULL,
    "slug" VARCHAR(32) NOT NULL,
    "name_ar" VARCHAR(40) NOT NULL,
    "name_en" VARCHAR(40) NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "live_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "live_rooms" (
    "id" UUID NOT NULL,
    "host_user_id" UUID NOT NULL,
    "title" VARCHAR(160) NOT NULL,
    "category_id" UUID,
    "status" "live_room_status" NOT NULL DEFAULT 'LIVE',
    "mode" "live_room_mode" NOT NULL DEFAULT 'SOLO',
    "started_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_heartbeat_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ended_at" TIMESTAMPTZ(3),
    "end_reason" "live_room_end_reason",
    "viewer_count" INTEGER NOT NULL DEFAULT 0,
    "cover_url" VARCHAR(2048),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "live_rooms_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "follows" (
    "follower_id" UUID NOT NULL,
    "followee_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "follows_pkey" PRIMARY KEY ("follower_id","followee_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "live_categories_slug_key" ON "live_categories"("slug");

-- Hand-written partial indexes (DB_PHASE2_DISCOVERY §2.2). They are also declared in
-- schema.prisma (preview feature `partialIndexes`) with the predicate exactly as PostgreSQL
-- stores it, so `prisma migrate dev` sees no drift and never generates a DROP INDEX for them.

-- At most one LIVE room per host (409 LIVE_ROOM_ALREADY_ACTIVE; a parallel go-live loses here).
CREATE UNIQUE INDEX "live_rooms_one_live_per_host" ON "live_rooms"("host_user_id") WHERE (status = 'LIVE'::live_room_status);

-- tab=popular keyset.
CREATE INDEX "live_rooms_live_popular_idx" ON "live_rooms"("viewer_count" DESC, "started_at" DESC, "id" DESC) WHERE (status = 'LIVE'::live_room_status);

-- tab=new keyset; tab=following ordering.
CREATE INDEX "live_rooms_live_new_idx" ON "live_rooms"("started_at" DESC, "id" DESC) WHERE (status = 'LIVE'::live_room_status);

-- tab=popular + category.
CREATE INDEX "live_rooms_live_cat_popular_idx" ON "live_rooms"("category_id", "viewer_count" DESC, "started_at" DESC, "id" DESC) WHERE (status = 'LIVE'::live_room_status);

-- tab=new / following + category.
CREATE INDEX "live_rooms_live_cat_new_idx" ON "live_rooms"("category_id", "started_at" DESC, "id" DESC) WHERE (status = 'LIVE'::live_room_status);

-- Stale sweeper (WHERE status = 'LIVE' AND last_heartbeat_at <= cutoff).
CREATE INDEX "live_rooms_live_heartbeat_idx" ON "live_rooms"("last_heartbeat_at") WHERE (status = 'LIVE'::live_room_status);

-- CreateIndex: the host's room history; FK lookups on user erasure.
CREATE INDEX "live_rooms_host_started_idx" ON "live_rooms"("host_user_id", "started_at" DESC);

-- CreateIndex: FK check when a category is deleted (normally never).
CREATE INDEX "live_rooms_category_id_idx" ON "live_rooms"("category_id");

-- CreateIndex: followerCount and a future followers list.
CREATE INDEX "follows_followee_id_created_at_idx" ON "follows"("followee_id", "created_at" DESC);

-- AddForeignKey: rooms are the host's content; hard erasure removes them.
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_host_user_id_fkey" FOREIGN KEY ("host_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey: categories are deactivated, never deleted, while rooms reference them.
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "live_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey: follows are deleted in both directions on hard erasure. (Soft delete,
-- status = DELETED, deletes them explicitly in the application: cascades do not fire on UPDATE.)
ALTER TABLE "follows" ADD CONSTRAINT "follows_follower_id_fkey" FOREIGN KEY ("follower_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "follows" ADD CONSTRAINT "follows_followee_id_fkey" FOREIGN KEY ("followee_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Hand-written CHECK constraints (not modelled by Prisma; enforced in the database as a
-- second line of defence behind application validation).

-- Category slug format — openapi CategorySlug.
ALTER TABLE "live_categories" ADD CONSTRAINT "live_categories_slug_format"
    CHECK ("slug" ~ '^[a-z0-9-]{2,32}$');

-- Category names: 1–40 characters after trimming.
ALTER TABLE "live_categories" ADD CONSTRAINT "live_categories_name_ar_length"
    CHECK (char_length(btrim("name_ar")) BETWEEN 1 AND 40);

ALTER TABLE "live_categories" ADD CONSTRAINT "live_categories_name_en_length"
    CHECK (char_length(btrim("name_en")) BETWEEN 1 AND 40);

-- End fields are consistent with the status.
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_end_state"
    CHECK (("status" = 'LIVE' AND "ended_at" IS NULL AND "end_reason" IS NULL)
        OR ("status" = 'ENDED' AND "ended_at" IS NOT NULL AND "end_reason" IS NOT NULL));

-- Time order: heartbeats and the end never precede the start.
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_time_order"
    CHECK ("last_heartbeat_at" >= "started_at" AND ("ended_at" IS NULL OR "ended_at" >= "started_at"));

-- Title: 1–80 graphemes / ≤ 160 code points are validated in the application (CONVENTIONS §10.3).
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_title_length"
    CHECK (char_length("title") BETWEEN 1 AND 160);

-- Always 0 in v1.3; written only by the future presence service.
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_viewer_count_nonneg"
    CHECK ("viewer_count" >= 0);

-- No self-follow (the API answers 400 first; this is the backstop).
ALTER TABLE "follows" ADD CONSTRAINT "follows_no_self_follow"
    CHECK ("follower_id" <> "followee_id");
