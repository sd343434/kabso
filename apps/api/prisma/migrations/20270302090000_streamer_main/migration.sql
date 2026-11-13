-- v1.57-live (D247, CONVENTIONS §10.88): a STREAMER's main picture. `SCREEN` = the screen track with the camera
-- as the bubble (D213, every existing streamer live); `CAMERA` = the camera track alone as the picture (the web
-- studio's "camera only" layout, e.g. OBS Virtual Camera). A new nullable column only (no new table, so no GRANT);
-- the existing STREAMER rows get SCREEN before the CHECK is widened to require it.
ALTER TABLE "live_rooms" ADD COLUMN "streamer_main" VARCHAR(16);

UPDATE "live_rooms" SET "streamer_main" = 'SCREEN' WHERE mode::text = 'STREAMER';

-- The CHECK is re-created with explicit IS NOT NULL on every STREAMER field: `x IN (…)` is NULL (not false) for a NULL
-- x, and a CHECK that is NULL passes, so D213's version let a STREAMER keep a NULL orientation or corner.
ALTER TABLE "live_rooms" DROP CONSTRAINT "live_rooms_streamer_fields";
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_streamer_fields" CHECK (
  (mode::text = 'STREAMER'
     AND streamer_orientation IS NOT NULL AND streamer_orientation IN ('PORTRAIT', 'LANDSCAPE')
     AND streamer_camera_visible IS NOT NULL
     AND streamer_camera_corner IS NOT NULL
     AND streamer_camera_corner IN ('TOP_LEFT', 'TOP_RIGHT', 'BOTTOM_LEFT', 'BOTTOM_RIGHT')
     AND streamer_main IS NOT NULL AND streamer_main IN ('SCREEN', 'CAMERA'))
  OR (mode::text <> 'STREAMER' AND streamer_orientation IS NULL AND streamer_camera_visible IS NULL
     AND streamer_camera_corner IS NULL AND streamer_main IS NULL));
