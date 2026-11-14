-- v1.43-live (D195, CONVENTIONS §10.58, CP-038; owner «فعّل PK ثنائي ولا تنسَ التربل والدبل»): PK 1 v 1
-- battles between two SOLO video lives — invitations, the random queue, matches with their scores,
-- the four boosters, the PK points of each gift send, supporters, records and the host's settings. PK
-- points are never money: no wallet, cherry, score, ranking or level column is touched by them. The
-- runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group): no
-- GRANT here. New enum types only (no ALTER TYPE … ADD VALUE), so one migration.

-- CreateEnum
CREATE TYPE "pk_booster_kind" AS ENUM ('DOUBLE', 'DOUBLE_TURBO', 'TRIPLE', 'TRIPLE_TURBO');

-- CreateEnum
CREATE TYPE "pk_match_status" AS ENUM ('BATTLE', 'RESULT', 'CLOSED');

-- CreateEnum
CREATE TYPE "pk_match_source" AS ENUM ('INVITE', 'RANDOM');

-- CreateEnum
CREATE TYPE "pk_end_reason" AS ENUM ('TIME', 'FORFEIT', 'DISCONNECT', 'AWAY', 'ADMIN');

-- CreateEnum
CREATE TYPE "pk_side" AS ENUM ('A', 'B');

-- CreateEnum
CREATE TYPE "pk_invite_status" AS ENUM ('PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED', 'EXPIRED');

-- AlterTable
ALTER TABLE "gifts" ADD COLUMN     "pk_booster" "pk_booster_kind";

-- CreateTable
CREATE TABLE "pk_matches" (
    "id" UUID NOT NULL,
    "source" "pk_match_source" NOT NULL,
    "status" "pk_match_status" NOT NULL DEFAULT 'BATTLE',
    "room_a_id" UUID NOT NULL,
    "host_a_id" UUID NOT NULL,
    "room_b_id" UUID NOT NULL,
    "host_b_id" UUID NOT NULL,
    "score_a" BIGINT NOT NULL DEFAULT 0,
    "score_b" BIGINT NOT NULL DEFAULT 0,
    "started_at" TIMESTAMPTZ(3) NOT NULL,
    "battle_ends_at" TIMESTAMPTZ(3) NOT NULL,
    "ended_at" TIMESTAMPTZ(3),
    "result_ends_at" TIMESTAMPTZ(3),
    "closed_at" TIMESTAMPTZ(3),
    "end_reason" "pk_end_reason",
    "winner" "pk_side",
    "loser_cause" "pk_side",
    "a_left_at" TIMESTAMPTZ(3),
    "b_left_at" TIMESTAMPTZ(3),
    "a_mutes_b" BOOLEAN NOT NULL DEFAULT false,
    "b_mutes_a" BOOLEAN NOT NULL DEFAULT false,
    "seq" INTEGER NOT NULL DEFAULT 0,
    "pending_notice" BOOLEAN NOT NULL DEFAULT false,
    "admin_reason" VARCHAR(200),
    "top_a" JSONB,
    "top_b" JSONB,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk_matches_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pk_invites" (
    "id" UUID NOT NULL,
    "from_room_id" UUID NOT NULL,
    "from_host_id" UUID NOT NULL,
    "to_room_id" UUID NOT NULL,
    "to_host_id" UUID NOT NULL,
    "status" "pk_invite_status" NOT NULL DEFAULT 'PENDING',
    "created_at" TIMESTAMPTZ(3) NOT NULL,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "handled_at" TIMESTAMPTZ(3),
    "match_id" UUID,

    CONSTRAINT "pk_invites_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pk_queue" (
    "host_id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "joined_at" TIMESTAMPTZ(3) NOT NULL,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "pk_queue_pkey" PRIMARY KEY ("host_id")
);

-- CreateTable
CREATE TABLE "pk_boosts" (
    "id" UUID NOT NULL,
    "match_id" UUID NOT NULL,
    "side" "pk_side" NOT NULL,
    "kind" "pk_booster_kind" NOT NULL,
    "multiplier" SMALLINT NOT NULL,
    "gift_id" UUID NOT NULL,
    "gift_code" VARCHAR(40) NOT NULL,
    "sender_id" UUID NOT NULL,
    "starts_at" TIMESTAMPTZ(3) NOT NULL,
    "ends_at" TIMESTAMPTZ(3) NOT NULL,
    "replaced" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "pk_boosts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pk_gift_points" (
    "gift_id" UUID NOT NULL,
    "match_id" UUID NOT NULL,
    "side" "pk_side" NOT NULL,
    "sender_id" UUID NOT NULL,
    "coins" BIGINT NOT NULL,
    "multiplier" SMALLINT NOT NULL,
    "points" BIGINT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "pk_gift_points_pkey" PRIMARY KEY ("gift_id")
);

-- CreateTable
CREATE TABLE "pk_supporters" (
    "match_id" UUID NOT NULL,
    "side" "pk_side" NOT NULL,
    "user_id" UUID NOT NULL,
    "points" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "pk_supporters_pkey" PRIMARY KEY ("match_id","side","user_id")
);

-- CreateTable
CREATE TABLE "pk_host_records" (
    "host_id" UUID NOT NULL,
    "wins" INTEGER NOT NULL DEFAULT 0,
    "losses" INTEGER NOT NULL DEFAULT 0,
    "draws" INTEGER NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk_host_records_pkey" PRIMARY KEY ("host_id")
);

-- CreateTable
CREATE TABLE "pk_host_settings" (
    "host_id" UUID NOT NULL,
    "invites_enabled" BOOLEAN NOT NULL DEFAULT true,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk_host_settings_pkey" PRIMARY KEY ("host_id")
);

-- CreateIndex
CREATE INDEX "pk_matches_open_idx" ON "pk_matches"("status") WHERE (status <> 'CLOSED'::pk_match_status);

-- CreateIndex
CREATE INDEX "pk_matches_host_a_idx" ON "pk_matches"("host_a_id", "started_at" DESC);

-- CreateIndex
CREATE INDEX "pk_matches_host_b_idx" ON "pk_matches"("host_b_id", "started_at" DESC);

-- CreateIndex
CREATE INDEX "pk_matches_room_b_idx" ON "pk_matches"("room_b_id");

-- CreateIndex
CREATE UNIQUE INDEX "pk_matches_room_a_active" ON "pk_matches"("room_a_id") WHERE (status <> 'CLOSED'::pk_match_status);

-- CreateIndex
CREATE UNIQUE INDEX "pk_matches_room_b_active" ON "pk_matches"("room_b_id") WHERE (status <> 'CLOSED'::pk_match_status);

-- CreateIndex
CREATE UNIQUE INDEX "pk_invites_match_id_key" ON "pk_invites"("match_id");

-- CreateIndex
CREATE INDEX "pk_invites_pending_expiry_idx" ON "pk_invites"("expires_at") WHERE (status = 'PENDING'::pk_invite_status);

-- CreateIndex
CREATE INDEX "pk_invites_from_host_idx" ON "pk_invites"("from_host_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "pk_invites_to_host_idx" ON "pk_invites"("to_host_id");

-- CreateIndex
CREATE INDEX "pk_invites_to_room_idx" ON "pk_invites"("to_room_id");

-- CreateIndex
CREATE UNIQUE INDEX "pk_invites_one_out" ON "pk_invites"("from_room_id") WHERE (status = 'PENDING'::pk_invite_status);

-- CreateIndex
CREATE UNIQUE INDEX "pk_invites_one_in" ON "pk_invites"("to_room_id") WHERE (status = 'PENDING'::pk_invite_status);

-- CreateIndex
CREATE INDEX "pk_queue_joined_idx" ON "pk_queue"("joined_at");

-- CreateIndex
CREATE INDEX "pk_queue_room_idx" ON "pk_queue"("room_id");

-- CreateIndex
CREATE UNIQUE INDEX "pk_boosts_gift_id_key" ON "pk_boosts"("gift_id");

-- CreateIndex
CREATE INDEX "pk_boosts_match_side_idx" ON "pk_boosts"("match_id", "side", "ends_at");

-- CreateIndex
CREATE INDEX "pk_boosts_gift_code_idx" ON "pk_boosts"("gift_code");

-- CreateIndex
CREATE INDEX "pk_gift_points_match_idx" ON "pk_gift_points"("match_id", "side");

-- CreateIndex
CREATE INDEX "pk_supporters_rank_idx" ON "pk_supporters"("match_id", "side", "points" DESC);

-- CreateIndex
CREATE INDEX "pk_supporters_user_idx" ON "pk_supporters"("user_id");

-- AddForeignKey
ALTER TABLE "pk_matches" ADD CONSTRAINT "pk_matches_room_a_id_fkey" FOREIGN KEY ("room_a_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk_matches" ADD CONSTRAINT "pk_matches_room_b_id_fkey" FOREIGN KEY ("room_b_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk_matches" ADD CONSTRAINT "pk_matches_host_a_id_fkey" FOREIGN KEY ("host_a_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk_matches" ADD CONSTRAINT "pk_matches_host_b_id_fkey" FOREIGN KEY ("host_b_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk_invites" ADD CONSTRAINT "pk_invites_from_room_id_fkey" FOREIGN KEY ("from_room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk_invites" ADD CONSTRAINT "pk_invites_to_room_id_fkey" FOREIGN KEY ("to_room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk_invites" ADD CONSTRAINT "pk_invites_from_host_id_fkey" FOREIGN KEY ("from_host_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk_invites" ADD CONSTRAINT "pk_invites_to_host_id_fkey" FOREIGN KEY ("to_host_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk_invites" ADD CONSTRAINT "pk_invites_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "pk_matches"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk_queue" ADD CONSTRAINT "pk_queue_host_id_fkey" FOREIGN KEY ("host_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk_queue" ADD CONSTRAINT "pk_queue_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk_boosts" ADD CONSTRAINT "pk_boosts_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "pk_matches"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk_boosts" ADD CONSTRAINT "pk_boosts_gift_code_fkey" FOREIGN KEY ("gift_code") REFERENCES "gifts"("code") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk_gift_points" ADD CONSTRAINT "pk_gift_points_gift_id_fkey" FOREIGN KEY ("gift_id") REFERENCES "live_gifts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk_gift_points" ADD CONSTRAINT "pk_gift_points_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "pk_matches"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk_supporters" ADD CONSTRAINT "pk_supporters_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "pk_matches"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk_supporters" ADD CONSTRAINT "pk_supporters_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk_host_records" ADD CONSTRAINT "pk_host_records_host_id_fkey" FOREIGN KEY ("host_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk_host_settings" ADD CONSTRAINT "pk_host_settings_host_id_fkey" FOREIGN KEY ("host_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- A booster's activation gift is a paid, ordinary gift (never LUCKY or QUIPS).
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_pk_booster_kind"
  CHECK ("pk_booster" IS NULL OR ("category" NOT IN ('LUCKY', 'QUIPS') AND "price_coins" > 0));

ALTER TABLE "pk_matches" ADD CONSTRAINT "pk_matches_two_rooms" CHECK ("room_a_id" <> "room_b_id" AND "host_a_id" <> "host_b_id");
ALTER TABLE "pk_matches" ADD CONSTRAINT "pk_matches_scores_nonneg" CHECK ("score_a" >= 0 AND "score_b" >= 0);
ALTER TABLE "pk_matches" ADD CONSTRAINT "pk_matches_state" CHECK (
  ("status" = 'BATTLE' AND "ended_at" IS NULL AND "end_reason" IS NULL AND "winner" IS NULL)
  OR ("status" IN ('RESULT', 'CLOSED') AND "ended_at" IS NOT NULL AND "end_reason" IS NOT NULL));
ALTER TABLE "pk_matches" ADD CONSTRAINT "pk_matches_admin_reason_length" CHECK (char_length("admin_reason") BETWEEN 1 AND 200);
ALTER TABLE "pk_invites" ADD CONSTRAINT "pk_invites_two_rooms" CHECK ("from_room_id" <> "to_room_id" AND "from_host_id" <> "to_host_id");
ALTER TABLE "pk_boosts" ADD CONSTRAINT "pk_boosts_window" CHECK ("ends_at" >= "starts_at" AND "multiplier" >= 1);
ALTER TABLE "pk_gift_points" ADD CONSTRAINT "pk_gift_points_amounts" CHECK ("coins" >= 0 AND "multiplier" >= 1 AND "points" = "coins" * "multiplier");
ALTER TABLE "pk_supporters" ADD CONSTRAINT "pk_supporters_points_nonneg" CHECK ("points" >= 0);
ALTER TABLE "pk_host_records" ADD CONSTRAINT "pk_host_records_nonneg" CHECK ("wins" >= 0 AND "losses" >= 0 AND "draws" >= 0);
