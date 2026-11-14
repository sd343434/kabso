-- v1.47-live (D212, CONVENTIONS §10.69): podcast lives. New columns only (no new table, so no GRANT:
-- the runtime role's table privileges already cover them). Existing rows get the defaults; nothing
-- is rewritten for existing lives (every new column is nullable or has a constant default).

-- Episode number (per host), topic chip, questions open/closed and the question duration.
ALTER TABLE "live_rooms"
  ADD COLUMN "episode_number" INTEGER,
  ADD COLUMN "podcast_topic" VARCHAR(32),
  ADD COLUMN "questions_open" BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN "question_seconds" SMALLINT;

-- Episode numbers are unique per host (NULLs — every non-podcast live — never collide).
CREATE UNIQUE INDEX "live_rooms_host_episode_key" ON "live_rooms"("host_user_id", "episode_number");

ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_podcast_fields" CHECK (
  (mode::text = 'PODCAST' AND episode_number >= 1 AND podcast_topic IS NOT NULL
     AND (question_seconds IS NULL OR question_seconds IN (60, 120, 180, 300)))
  OR (mode::text <> 'PODCAST' AND episode_number IS NULL AND podcast_topic IS NULL
     AND question_seconds IS NULL));

-- A PODCAST has 4 tiles (the host and 3 speakers).
ALTER TABLE "live_rooms" DROP CONSTRAINT "live_rooms_seat_count_mode";
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_seat_count_mode" CHECK (
  (mode::text IN ('SOLO', 'PK') AND seat_count IS NULL)
  OR (mode::text = 'MULTI' AND seat_count IN (4, 6, 9, 12))
  OR (mode::text = 'AUDIO' AND seat_count IN (5, 10, 15, 20, 25))
  OR (mode::text = 'PODCAST' AND seat_count = 4));

-- A podcast question's end (the sweeper moves the speaker back to the listeners then).
ALTER TABLE "live_room_seats" ADD COLUMN "demote_at" TIMESTAMPTZ(3);
CREATE INDEX "live_room_seats_demote_idx" ON "live_room_seats"("demote_at") WHERE demote_at IS NOT NULL;

-- A raised hand's short question and the host's «لاحقاً».
ALTER TABLE "live_seat_requests"
  ADD COLUMN "question" VARCHAR(320),
  ADD COLUMN "deferred_at" TIMESTAMPTZ(3);

-- Announced podcast episodes (the hub's «بودكاست» tab lists them; reminders are unchanged).
ALTER TABLE "live_schedule_slots"
  ADD COLUMN "mode" "live_room_mode",
  ADD COLUMN "podcast_topic" VARCHAR(32);
ALTER TABLE "live_schedule_slots" ADD CONSTRAINT "live_schedule_slots_podcast_fields" CHECK (
  (mode IS NULL AND podcast_topic IS NULL)
  OR (mode::text = 'PODCAST' AND podcast_topic IS NOT NULL));
CREATE INDEX "live_schedule_slots_mode_starts_idx" ON "live_schedule_slots"("mode", "starts_at") WHERE mode IS NOT NULL;
