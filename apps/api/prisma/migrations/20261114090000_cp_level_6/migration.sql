-- Owner D113 (2026-10-26): CP gets a sixth tier, ثنائي أبدي / Eternal couple at 52 000 CP points
-- (`CP_TIERS`, CONVENTIONS §10.21). The level check widens to 1–6, and a couple that already holds
-- 52 000 points or more moves up now (the next gain would do it anyway). Like any tier change
-- (`bumpRoomsSeatingBothIn`, D111), every LIVE room where both partners are present gets a new seat
-- version so apps refetch `LiveSeats.couples`.
ALTER TABLE "cp_couples" DROP CONSTRAINT "cp_couples_level_range";
ALTER TABLE "cp_couples" ADD CONSTRAINT "cp_couples_level_range" CHECK (level BETWEEN 1 AND 6);

WITH moved AS (
  UPDATE "cp_couples" SET "level" = 6
   WHERE "points" >= 52000 AND "level" < 6
  RETURNING "user_a_id", "user_b_id", "ended_at"
)
UPDATE "live_rooms" r SET "seats_version" = r."seats_version" + 1
 WHERE r."status" = 'LIVE'
   AND EXISTS (
     SELECT 1 FROM moved m
      WHERE m."ended_at" IS NULL
        AND (r."host_user_id" = m."user_a_id"
             OR EXISTS (SELECT 1 FROM "live_room_seats" s WHERE s."room_id" = r."id" AND s."user_id" = m."user_a_id"))
        AND (r."host_user_id" = m."user_b_id"
             OR EXISTS (SELECT 1 FROM "live_room_seats" s WHERE s."room_id" = r."id" AND s."user_id" = m."user_b_id")));
