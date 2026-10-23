-- CP-012 (D95): live taps and the room score. The room's total score (`live_rooms.score`, which the
-- `popular` tab orders by), its parts (`live_room_scores`: taps, and support written by L3), and
-- each caller's counted taps per room (`live_room_tappers`: the 10-a-second and 10 000-a-live
-- limits, and the abuse watch). The runtime role gets DML through the default privileges
-- (20261016120000_runtime_role_grants), so this migration contains no GRANT.

-- DropIndex (the popular order moves from viewer_count to score, CONVENTIONS §10.4 v1.8-live)
DROP INDEX "live_rooms_live_cat_popular_idx";

-- DropIndex
DROP INDEX "live_rooms_live_popular_idx";

-- AlterTable
ALTER TABLE "live_rooms" ADD COLUMN     "score" BIGINT NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "live_room_scores" (
    "room_id" UUID NOT NULL,
    "tap_points" BIGINT NOT NULL DEFAULT 0,
    "support_points" BIGINT NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "live_room_scores_pkey" PRIMARY KEY ("room_id")
);

-- CreateTable
CREATE TABLE "live_room_tappers" (
    "room_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "counted" INTEGER NOT NULL DEFAULT 0,
    "last_batch_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "live_room_tappers_pkey" PRIMARY KEY ("room_id","user_id")
);

-- CreateIndex
CREATE INDEX "live_room_tappers_user_idx" ON "live_room_tappers"("user_id");

-- CreateIndex (tab=popular keyset)
CREATE INDEX "live_rooms_live_popular_idx" ON "live_rooms"("score" DESC, "started_at" DESC, "id" DESC) WHERE (status = 'LIVE'::live_room_status);

-- CreateIndex (tab=popular + category)
CREATE INDEX "live_rooms_live_cat_popular_idx" ON "live_rooms"("category_id", "score" DESC, "started_at" DESC, "id" DESC) WHERE (status = 'LIVE'::live_room_status);

-- AddForeignKey
ALTER TABLE "live_room_scores" ADD CONSTRAINT "live_room_scores_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_room_tappers" ADD CONSTRAINT "live_room_tappers_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_room_tappers" ADD CONSTRAINT "live_room_tappers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;


-- Points are never negative; a caller counts at most 10 000 taps in one room (CONVENTIONS §10.10).
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_score_nonneg" CHECK (score >= 0);
ALTER TABLE "live_room_scores" ADD CONSTRAINT "live_room_scores_nonneg" CHECK (tap_points >= 0 AND support_points >= 0);
ALTER TABLE "live_room_tappers" ADD CONSTRAINT "live_room_tappers_counted" CHECK (counted BETWEEN 0 AND 10000);
