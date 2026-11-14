-- v1.114-live (D363, CONVENTIONS §10.157): the video podcast «بودكاست فيديو» with an automatic director.
-- New columns have constant defaults or are nullable (no rewrite of existing rows); one new table, which the schema's
-- default privileges give the runtime role (20261016120000_runtime_role_grants). Audio podcasts are unchanged.

-- A video podcast: the host and speakers publish the camera too (false = audio, every existing room).
ALTER TABLE "live_rooms" ADD COLUMN "podcast_video" BOOLEAN NOT NULL DEFAULT false;

-- Re-created with the flag: true only on a PODCAST (the D212 rules unchanged).
ALTER TABLE "live_rooms" DROP CONSTRAINT "live_rooms_podcast_fields";
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_podcast_fields" CHECK (
  (mode::text = 'PODCAST' AND episode_number >= 1 AND podcast_topic IS NOT NULL
     AND (question_seconds IS NULL OR question_seconds IN (60, 120, 180, 300)))
  OR (mode::text <> 'PODCAST' AND episode_number IS NULL AND podcast_topic IS NULL
     AND question_seconds IS NULL AND NOT podcast_video));

-- Announced video episodes.
ALTER TABLE "live_schedule_slots" ADD COLUMN "podcast_video" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "live_schedule_slots" DROP CONSTRAINT "live_schedule_slots_podcast_fields";
ALTER TABLE "live_schedule_slots" ADD CONSTRAINT "live_schedule_slots_podcast_fields" CHECK (
  (mode IS NULL AND podcast_topic IS NULL AND NOT podcast_video)
  OR (mode::text = 'PODCAST' AND podcast_topic IS NOT NULL));

-- The guest's lower-third title (1–40 code points after the chat text rules; 160 bytes of room) on the invitation
-- and, once accepted, on the seat; the hand seated «في الكرسي الساخن».
ALTER TABLE "live_seat_invites" ADD COLUMN "guest_title" VARCHAR(160);
ALTER TABLE "live_room_seats"
  ADD COLUMN "guest_title" VARCHAR(160),
  ADD COLUMN "hot_seat_request_id" UUID;
ALTER TABLE "live_room_seats" ADD CONSTRAINT "live_room_seats_hot_seat_request_id_fkey"
  FOREIGN KEY ("hot_seat_request_id") REFERENCES "live_seat_requests"("id") ON DELETE SET NULL ON UPDATE CASCADE;
-- One hot seat per room at a time (the service checks it under the room lock; this is the backstop).
CREATE UNIQUE INDEX "live_room_seats_one_hot_seat" ON "live_room_seats"("room_id") WHERE hot_seat_request_id IS NOT NULL;

-- Upvotes: one per person and question.
CREATE TABLE "live_question_votes" (
    "request_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "live_question_votes_pkey" PRIMARY KEY ("request_id", "user_id")
);
CREATE INDEX "live_question_votes_user_idx" ON "live_question_votes"("user_id");
ALTER TABLE "live_question_votes" ADD CONSTRAINT "live_question_votes_request_id_fkey"
  FOREIGN KEY ("request_id") REFERENCES "live_seat_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "live_question_votes" ADD CONSTRAINT "live_question_votes_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
