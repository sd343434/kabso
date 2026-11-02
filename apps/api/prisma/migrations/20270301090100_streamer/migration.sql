-- v1.56-live (D213, CONVENTIONS §10.86): streamer lives. New columns only (no new table, so no GRANT:
-- the runtime role's table privileges already cover them). Existing rows get the defaults; nothing is
-- rewritten for existing lives (every new column is nullable or has a constant default).

-- The screen's orientation and the camera bubble (shown or hidden, its corner), and their version.
ALTER TABLE "live_rooms"
  ADD COLUMN "streamer_orientation" VARCHAR(16),
  ADD COLUMN "streamer_camera_visible" BOOLEAN,
  ADD COLUMN "streamer_camera_corner" VARCHAR(16),
  ADD COLUMN "streamer_version" INTEGER NOT NULL DEFAULT 0;

ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_streamer_fields" CHECK (
  (mode::text = 'STREAMER' AND streamer_orientation IN ('PORTRAIT', 'LANDSCAPE')
     AND streamer_camera_visible IS NOT NULL
     AND streamer_camera_corner IN ('TOP_LEFT', 'TOP_RIGHT', 'BOTTOM_LEFT', 'BOTTOM_RIGHT'))
  OR (mode::text <> 'STREAMER' AND streamer_orientation IS NULL AND streamer_camera_visible IS NULL
     AND streamer_camera_corner IS NULL));

-- A STREAMER has no guest seats (like SOLO before D174's fixed guests: seat_count stays null).
ALTER TABLE "live_rooms" DROP CONSTRAINT "live_rooms_seat_count_mode";
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_seat_count_mode" CHECK (
  (mode::text IN ('SOLO', 'PK', 'STREAMER') AND seat_count IS NULL)
  OR (mode::text = 'MULTI' AND seat_count IN (4, 6, 9, 12))
  OR (mode::text = 'AUDIO' AND seat_count IN (5, 10, 15, 20, 25))
  OR (mode::text = 'PODCAST' AND seat_count = 4));
