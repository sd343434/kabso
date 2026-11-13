-- v1.118-live (D391, CONVENTIONS §10.180, CP-041 phase 2; the owner approved CP-041 on 2026-11-13): «PK رباعي» —
-- PK 2 v 2 (format TEAMS) started by invitation. An organiser's lobby (`pk4_lobbies`, PK4_LOBBY_SECONDS) with an
-- invitation per place (`pk4_invites`, 2 = the teammate, 3–4 = the opponents, PK4_INVITE_TTL_SECONDS), the match
-- (`pk4_matches`, team sums) and its four places (`pk4_seats`: each host's own PK points, out / absence, mutes; one open
-- place per room while `active`), the team boosters (`pk4_boosts`), the PK points of each gift send (`pk4_gift_points`,
-- one row per send), the supporters per team (`pk4_supporters`) and the once-per-match record writes
-- (`pk4_point_events`; the record itself stays `pk_host_records`). PK 1 v 1's tables are not touched. The `format`
-- column, places 1–4 and teams A / B are ready for FREE_FOR_ALL and random matching (later phases). PK points are never
-- money: no wallet, cherry, score, ranking or level column is touched. New enum types only (the reused `pk_side`,
-- `pk_match_status`, `pk_end_reason` and `pk_booster_kind` exist), so one migration. The runtime role gets DML through
-- the default privileges (20261016130000_per_database_runtime_group): no GRANT here.

-- CreateEnum
CREATE TYPE "pk4_format" AS ENUM ('TEAMS', 'FREE_FOR_ALL');

-- CreateEnum
CREATE TYPE "pk4_lobby_status" AS ENUM ('OPEN', 'STARTED', 'CANCELLED', 'EXPIRED');

-- CreateEnum
CREATE TYPE "pk4_invite_status" AS ENUM ('PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED', 'EXPIRED', 'LEFT');

-- CreateTable
CREATE TABLE "pk4_lobbies" (
    "id" UUID NOT NULL,
    "format" "pk4_format" NOT NULL,
    "status" "pk4_lobby_status" NOT NULL DEFAULT 'OPEN',
    "organiser_room_id" UUID NOT NULL,
    "organiser_host_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "closed_at" TIMESTAMPTZ(3),
    "match_id" UUID,

    CONSTRAINT "pk4_lobbies_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pk4_invites" (
    "id" UUID NOT NULL,
    "lobby_id" UUID NOT NULL,
    "seat" SMALLINT NOT NULL,
    "team" "pk_side" NOT NULL,
    "to_room_id" UUID NOT NULL,
    "to_host_id" UUID NOT NULL,
    "status" "pk4_invite_status" NOT NULL DEFAULT 'PENDING',
    "created_at" TIMESTAMPTZ(3) NOT NULL,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "handled_at" TIMESTAMPTZ(3),

    CONSTRAINT "pk4_invites_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pk4_matches" (
    "id" UUID NOT NULL,
    "lobby_id" UUID,
    "format" "pk4_format" NOT NULL,
    "status" "pk_match_status" NOT NULL DEFAULT 'BATTLE',
    "organiser_room_id" UUID NOT NULL,
    "started_at" TIMESTAMPTZ(3) NOT NULL,
    "battle_ends_at" TIMESTAMPTZ(3) NOT NULL,
    "ended_at" TIMESTAMPTZ(3),
    "result_ends_at" TIMESTAMPTZ(3),
    "closed_at" TIMESTAMPTZ(3),
    "end_reason" "pk_end_reason",
    "winner_team" "pk_side",
    "loser_cause" "pk_side",
    "score_a" BIGINT NOT NULL DEFAULT 0,
    "score_b" BIGINT NOT NULL DEFAULT 0,
    "round_seconds" INTEGER NOT NULL,
    "connected_at" TIMESTAMPTZ(3),
    "seq" INTEGER NOT NULL DEFAULT 0,
    "pending_notice" BOOLEAN NOT NULL DEFAULT false,
    "admin_reason" VARCHAR(200),
    "top_a" JSONB,
    "top_b" JSONB,
    "effective" BOOLEAN,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk4_matches_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pk4_seats" (
    "match_id" UUID NOT NULL,
    "seat" SMALLINT NOT NULL,
    "team" "pk_side" NOT NULL,
    "room_id" UUID NOT NULL,
    "host_id" UUID NOT NULL,
    "score" BIGINT NOT NULL DEFAULT 0,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "left_at" TIMESTAMPTZ(3),
    "out_at" TIMESTAMPTZ(3),
    "out_reason" "pk_end_reason",
    "muted_room_ids" UUID[] DEFAULT ARRAY[]::UUID[],

    CONSTRAINT "pk4_seats_pkey" PRIMARY KEY ("match_id","seat")
);

-- CreateTable
CREATE TABLE "pk4_boosts" (
    "id" UUID NOT NULL,
    "match_id" UUID NOT NULL,
    "team" "pk_side" NOT NULL,
    "kind" "pk_booster_kind" NOT NULL,
    "multiplier" SMALLINT NOT NULL,
    "gift_id" UUID NOT NULL,
    "gift_code" VARCHAR(40) NOT NULL,
    "sender_id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "starts_at" TIMESTAMPTZ(3) NOT NULL,
    "ends_at" TIMESTAMPTZ(3) NOT NULL,
    "replaced" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "pk4_boosts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pk4_gift_points" (
    "gift_id" UUID NOT NULL,
    "match_id" UUID NOT NULL,
    "seat" SMALLINT NOT NULL,
    "team" "pk_side" NOT NULL,
    "sender_id" UUID NOT NULL,
    "coins" BIGINT NOT NULL,
    "multiplier" SMALLINT NOT NULL,
    "points" BIGINT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "pk4_gift_points_pkey" PRIMARY KEY ("gift_id")
);

-- CreateTable
CREATE TABLE "pk4_supporters" (
    "match_id" UUID NOT NULL,
    "team" "pk_side" NOT NULL,
    "user_id" UUID NOT NULL,
    "points" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "pk4_supporters_pkey" PRIMARY KEY ("match_id","team","user_id")
);

-- CreateTable
CREATE TABLE "pk4_point_events" (
    "match_id" UUID NOT NULL,
    "host_id" UUID NOT NULL,
    "kind" VARCHAR(16) NOT NULL,
    "points" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk4_point_events_pkey" PRIMARY KEY ("match_id","host_id","kind")
);

-- CreateIndex
CREATE UNIQUE INDEX "pk4_lobbies_match_id_key" ON "pk4_lobbies"("match_id");

-- CreateIndex
CREATE INDEX "pk4_lobbies_open_expiry_idx" ON "pk4_lobbies"("expires_at") WHERE (status = 'OPEN'::pk4_lobby_status);

-- CreateIndex
CREATE INDEX "pk4_lobbies_host_idx" ON "pk4_lobbies"("organiser_host_id");

-- CreateIndex
CREATE UNIQUE INDEX "pk4_lobbies_one_open" ON "pk4_lobbies"("organiser_room_id") WHERE (status = 'OPEN'::pk4_lobby_status);

-- CreateIndex
CREATE INDEX "pk4_invites_pending_expiry_idx" ON "pk4_invites"("expires_at") WHERE (status = 'PENDING'::pk4_invite_status);

-- CreateIndex
CREATE INDEX "pk4_invites_to_room_idx" ON "pk4_invites"("to_room_id", "status");

-- CreateIndex
CREATE INDEX "pk4_invites_to_host_idx" ON "pk4_invites"("to_host_id");

-- CreateIndex
CREATE UNIQUE INDEX "pk4_invites_one_per_seat" ON "pk4_invites"("lobby_id", "seat") WHERE (status IN ('PENDING'::pk4_invite_status, 'ACCEPTED'::pk4_invite_status));

-- CreateIndex
CREATE UNIQUE INDEX "pk4_invites_one_in" ON "pk4_invites"("to_room_id") WHERE (status = 'PENDING'::pk4_invite_status);

-- CreateIndex
CREATE UNIQUE INDEX "pk4_matches_lobby_id_key" ON "pk4_matches"("lobby_id");

-- CreateIndex
CREATE INDEX "pk4_matches_open_idx" ON "pk4_matches"("status") WHERE (status <> 'CLOSED'::pk_match_status);

-- CreateIndex
CREATE INDEX "pk4_seats_host_idx" ON "pk4_seats"("host_id");

-- CreateIndex
CREATE INDEX "pk4_seats_room_idx" ON "pk4_seats"("room_id");

-- CreateIndex
CREATE UNIQUE INDEX "pk4_seats_room_active" ON "pk4_seats"("room_id") WHERE (active);

-- CreateIndex
CREATE UNIQUE INDEX "pk4_boosts_gift_id_key" ON "pk4_boosts"("gift_id");

-- CreateIndex
CREATE INDEX "pk4_boosts_match_team_idx" ON "pk4_boosts"("match_id", "team", "ends_at");

-- CreateIndex
CREATE INDEX "pk4_boosts_gift_code_idx" ON "pk4_boosts"("gift_code");

-- CreateIndex
CREATE INDEX "pk4_gift_points_match_idx" ON "pk4_gift_points"("match_id", "team");

-- CreateIndex
CREATE INDEX "pk4_supporters_rank_idx" ON "pk4_supporters"("match_id", "team", "points" DESC);

-- CreateIndex
CREATE INDEX "pk4_supporters_user_idx" ON "pk4_supporters"("user_id");

-- CreateIndex
CREATE INDEX "pk4_point_events_host_idx" ON "pk4_point_events"("host_id", "created_at" DESC);

-- AddForeignKey
ALTER TABLE "pk4_lobbies" ADD CONSTRAINT "pk4_lobbies_organiser_room_id_fkey" FOREIGN KEY ("organiser_room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk4_lobbies" ADD CONSTRAINT "pk4_lobbies_organiser_host_id_fkey" FOREIGN KEY ("organiser_host_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk4_invites" ADD CONSTRAINT "pk4_invites_lobby_id_fkey" FOREIGN KEY ("lobby_id") REFERENCES "pk4_lobbies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk4_invites" ADD CONSTRAINT "pk4_invites_to_room_id_fkey" FOREIGN KEY ("to_room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk4_invites" ADD CONSTRAINT "pk4_invites_to_host_id_fkey" FOREIGN KEY ("to_host_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk4_seats" ADD CONSTRAINT "pk4_seats_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "pk4_matches"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk4_seats" ADD CONSTRAINT "pk4_seats_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk4_seats" ADD CONSTRAINT "pk4_seats_host_id_fkey" FOREIGN KEY ("host_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk4_boosts" ADD CONSTRAINT "pk4_boosts_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "pk4_matches"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk4_boosts" ADD CONSTRAINT "pk4_boosts_gift_code_fkey" FOREIGN KEY ("gift_code") REFERENCES "gifts"("code") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk4_gift_points" ADD CONSTRAINT "pk4_gift_points_gift_id_fkey" FOREIGN KEY ("gift_id") REFERENCES "live_gifts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk4_gift_points" ADD CONSTRAINT "pk4_gift_points_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "pk4_matches"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk4_supporters" ADD CONSTRAINT "pk4_supporters_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "pk4_matches"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk4_supporters" ADD CONSTRAINT "pk4_supporters_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk4_point_events" ADD CONSTRAINT "pk4_point_events_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "pk4_matches"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk4_point_events" ADD CONSTRAINT "pk4_point_events_host_id_fkey" FOREIGN KEY ("host_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- The places: 1 is the organiser, 2 the teammate, 3–4 the opponents (an invitation is never for place 1).
ALTER TABLE "pk4_invites" ADD CONSTRAINT "pk4_invites_seat_check" CHECK ("seat" BETWEEN 2 AND 4);
ALTER TABLE "pk4_seats" ADD CONSTRAINT "pk4_seats_seat_check" CHECK ("seat" BETWEEN 1 AND 4);
