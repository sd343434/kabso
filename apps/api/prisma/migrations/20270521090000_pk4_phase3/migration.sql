-- v1.119-live (D395, CONVENTIONS §10.181, CP-041 phases 3–4; the owner asked for all of it, «أ و ب»): «PK رباعي» —
-- FREE_FOR_ALL «الكل ضد الكل» (each host alone, places 1–4), a start with two or three hosts (the organiser's
-- «ابدأ الآن», or the lobby's time running out with two or more in), the 4-way random queue (four hosts, TEAMS or
-- FREE_FOR_ALL), «PK أحكام» for four (one dare for the losing side) and «جولة أخرى» for four (every present host
-- accepts). Additive only: new columns with defaults that keep every phase-2 row as it was (TEAMS, NORMAL, four
-- players, an invitation), two new tables and one primary key widened (the supporters of a FREE_FOR_ALL host).
-- PK 1 v 1's tables are not touched. PK points are never money. The runtime role gets DML on the new tables through
-- the default privileges (20261016130000_per_database_runtime_group): no GRANT here.

-- The lobby's type: «PK أحكام» (DARES) or a normal 4-way PK.
ALTER TABLE "pk4_lobbies" ADD COLUMN "type" "pk_type" NOT NULL DEFAULT 'NORMAL';

-- The match: its type, how it started, how many hosts play (2–4), the rematch chain and an open rematch offer
-- (who asked, until when, which rooms accepted), and FREE_FOR_ALL's frozen supporters per place.
ALTER TABLE "pk4_matches"
    ADD COLUMN "type" "pk_type" NOT NULL DEFAULT 'NORMAL',
    ADD COLUMN "source" VARCHAR(8) NOT NULL DEFAULT 'INVITE',
    ADD COLUMN "player_count" SMALLINT NOT NULL DEFAULT 4,
    ADD COLUMN "rematch_of" UUID,
    ADD COLUMN "rematch_root_id" UUID,
    ADD COLUMN "rematch_count" INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN "rematch_by_room_id" UUID,
    ADD COLUMN "rematch_expires_at" TIMESTAMPTZ(3),
    ADD COLUMN "rematch_accepted" UUID[] NOT NULL DEFAULT ARRAY[]::UUID[],
    ADD COLUMN "top_seats" JSONB;

ALTER TABLE "pk4_matches" ADD CONSTRAINT "pk4_matches_source_check" CHECK ("source" IN ('INVITE', 'RANDOM', 'REMATCH'));
ALTER TABLE "pk4_matches" ADD CONSTRAINT "pk4_matches_player_count_check" CHECK ("player_count" BETWEEN 2 AND 4);

-- CreateIndex
CREATE INDEX "pk4_matches_rematch_root_idx" ON "pk4_matches"("rematch_root_id");

-- A place's final place (1–4) in a FREE_FOR_ALL match (equal scores share one); null in TEAMS and while it runs.
ALTER TABLE "pk4_seats" ADD COLUMN "place" SMALLINT;
ALTER TABLE "pk4_seats" ADD CONSTRAINT "pk4_seats_place_check" CHECK ("place" IS NULL OR "place" BETWEEN 1 AND 4);

-- FREE_FOR_ALL: a booster is the host's own (its place); TEAMS keeps null (the team's).
ALTER TABLE "pk4_boosts" ADD COLUMN "seat" SMALLINT;

-- CreateIndex
CREATE INDEX "pk4_boosts_match_seat_idx" ON "pk4_boosts"("match_id", "seat", "ends_at");

-- FREE_FOR_ALL: a supporter of one host (place); TEAMS keeps 0 (the team's, from both rooms).
ALTER TABLE "pk4_supporters" ADD COLUMN "seat" SMALLINT NOT NULL DEFAULT 0;
ALTER TABLE "pk4_supporters" DROP CONSTRAINT "pk4_supporters_pkey";
ALTER TABLE "pk4_supporters" ADD CONSTRAINT "pk4_supporters_pkey" PRIMARY KEY ("match_id", "team", "seat", "user_id");
DROP INDEX "pk4_supporters_rank_idx";

-- CreateIndex
CREATE INDEX "pk4_supporters_rank_idx" ON "pk4_supporters"("match_id", "team", "seat", "points" DESC);

-- CreateTable: the dare of a 4-way «PK أحكام» — one dare for the losing side (TEAMS: the losing team's hosts;
-- FREE_FOR_ALL: the lowest place still on air), judged by the winning side (TEAMS: the winning team; FREE_FOR_ALL: the
-- first place). Any losing host answers for the side and any winning host judges.
CREATE TABLE "pk4_match_dares" (
    "match_id" UUID NOT NULL,
    "loser_seats" SMALLINT[] NOT NULL,
    "loser_host_ids" UUID[] NOT NULL,
    "winner_seats" SMALLINT[] NOT NULL,
    "winner_host_ids" UUID[] NOT NULL,
    "option_ids" UUID[] NOT NULL,
    "drawn" SMALLINT NOT NULL,
    "dare_id" UUID NOT NULL,
    "status" "pk_dare_status" NOT NULL DEFAULT 'DECIDING',
    "cause" "pk_dare_cause",
    "reveal_at" TIMESTAMPTZ(3) NOT NULL,
    "decide_by" TIMESTAMPTZ(3) NOT NULL,
    "started_at" TIMESTAMPTZ(3),
    "ends_at" TIMESTAMPTZ(3),
    "finished_at" TIMESTAMPTZ(3),
    "points" INTEGER NOT NULL DEFAULT 0,
    "answered_by" UUID,
    "judged_by" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk4_match_dares_pkey" PRIMARY KEY ("match_id")
);

-- CreateIndex
CREATE INDEX "pk4_match_dares_open_idx" ON "pk4_match_dares"("status") WHERE (finished_at IS NULL);

-- AddForeignKey
ALTER TABLE "pk4_match_dares" ADD CONSTRAINT "pk4_match_dares_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "pk4_matches"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk4_match_dares" ADD CONSTRAINT "pk4_match_dares_dare_id_fkey" FOREIGN KEY ("dare_id") REFERENCES "pk_dares"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "pk4_match_dares" ADD CONSTRAINT "pk4_match_dares_drawn_check" CHECK ("drawn" BETWEEN 0 AND 2);

-- CreateTable: the 4-way random queue «مطابقة عشوائية» (PK4_RANDOM_WAIT_SECONDS): one wait per host, for a format and a
-- type; four compatible waiters are matched (the longest waits first).
CREATE TABLE "pk4_queue" (
    "host_id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "format" "pk4_format" NOT NULL,
    "type" "pk_type" NOT NULL DEFAULT 'NORMAL',
    "joined_at" TIMESTAMPTZ(3) NOT NULL,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "pk4_queue_pkey" PRIMARY KEY ("host_id")
);

-- CreateIndex
CREATE INDEX "pk4_queue_wait_idx" ON "pk4_queue"("format", "type", "joined_at");

-- CreateIndex
CREATE INDEX "pk4_queue_room_idx" ON "pk4_queue"("room_id");

-- AddForeignKey
ALTER TABLE "pk4_queue" ADD CONSTRAINT "pk4_queue_host_id_fkey" FOREIGN KEY ("host_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pk4_queue" ADD CONSTRAINT "pk4_queue_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;
