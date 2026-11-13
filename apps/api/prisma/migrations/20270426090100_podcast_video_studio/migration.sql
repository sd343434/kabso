-- v1.114-live (D363, CONVENTIONS §10.157, owner scope extension 2026-11-11): the video podcast's studio — backstage
-- «خلف الكواليس», the host's manual control, the episode's segments and the listener question on screen.
-- One new column with a constant default (no rewrite) and one new table, which the schema's default privileges give
-- the runtime role (20261016120000_runtime_role_grants). Audio podcasts and every other room are unchanged.

-- An accepted guest of a video podcast waits backstage until the host brings them on air.
ALTER TABLE "live_room_seats" ADD COLUMN "backstage" BOOLEAN NOT NULL DEFAULT false;

-- One row per video podcast (created on the first change, or at go-live with segments).
CREATE TABLE "live_podcast_studios" (
    "room_id" UUID NOT NULL,
    "seq" INTEGER NOT NULL DEFAULT 0,
    "pin_user_id" UUID,
    "layout" VARCHAR(16),
    "segments" JSONB NOT NULL DEFAULT '[]',
    "segment_index" SMALLINT,
    "segment_started_at" TIMESTAMPTZ(3),
    "closing" BOOLEAN NOT NULL DEFAULT false,
    "on_screen_request_id" UUID,
    "answer_user_id" UUID,
    "on_screen_at" TIMESTAMPTZ(3),
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    CONSTRAINT "live_podcast_studios_pkey" PRIMARY KEY ("room_id"),
    -- The layouts the host may lock; at most 8 segments; a segment index is never negative.
    CONSTRAINT "live_podcast_studios_shape" CHECK (
      (layout IS NULL OR layout IN ('SPEAKER', 'SPLIT', 'HOT_SEAT'))
      AND jsonb_typeof(segments) = 'array' AND jsonb_array_length(segments) <= 8
      AND (segment_index IS NULL OR segment_index >= 0)
      AND seq >= 0)
);
CREATE INDEX "live_podcast_studios_on_screen_idx" ON "live_podcast_studios"("on_screen_request_id");
ALTER TABLE "live_podcast_studios" ADD CONSTRAINT "live_podcast_studios_room_id_fkey"
  FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "live_podcast_studios" ADD CONSTRAINT "live_podcast_studios_on_screen_request_id_fkey"
  FOREIGN KEY ("on_screen_request_id") REFERENCES "live_seat_requests"("id") ON DELETE SET NULL ON UPDATE CASCADE;
