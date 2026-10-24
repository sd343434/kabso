-- CP-014 parts A and B (D97): editing a live and the Contribution list. The live's topic
-- (`live_rooms.topic`, null = none; a new live starts without one), the room info version
-- (`live_rooms.info_version`, increased in the same transaction as every change of the title,
-- category or topic and written into the media room's metadata as `roomInfoVersion`), and an
-- index for the top 50 contributors of a room (`live_room_tappers`: counted taps, highest first,
-- then who reached the total first, then user id). The runtime role gets DML through the default
-- privileges (20261016120000_runtime_role_grants), so this migration contains no GRANT.

-- AlterTable
ALTER TABLE "live_rooms" ADD COLUMN     "info_version" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "topic" VARCHAR(100);

-- CreateIndex (the Contribution list of a room, CONVENTIONS §10.12)
CREATE INDEX "live_room_tappers_room_rank_idx" ON "live_room_tappers"("room_id", "counted" DESC, "last_batch_at", "user_id");

-- 1–100 code points (CONVENTIONS §10.12; char_length counts code points); an empty topic is NULL.
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_topic_length" CHECK (topic IS NULL OR char_length(topic) BETWEEN 1 AND 100);
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_info_version_nonneg" CHECK (info_version >= 0);
