-- v1.42-live (D170, CONVENTIONS §10.44): the host of a video live is away (the app in the
-- background, the camera off) since this time; null while present. The sweeper ends a LIVE room
-- away for LIVE_HOST_AWAY_TIMEOUT_SECONDS (default 300) with HOST_AWAY_TIMEOUT.
ALTER TABLE "live_rooms" ADD COLUMN "host_away_since" TIMESTAMPTZ(3);

-- The sweeper's scan: only LIVE rooms whose host is away (a handful at any time).
CREATE INDEX "live_rooms_live_host_away_idx" ON "live_rooms"("host_away_since")
  WHERE status = 'LIVE'::live_room_status AND host_away_since IS NOT NULL;
