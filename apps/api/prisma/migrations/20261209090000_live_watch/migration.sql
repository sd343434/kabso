-- v1.38-live (D154i, owner 2026-10-28): YouTube watch-together «يوتيوب», CONVENTIONS §10.39.
-- Additive: two new tables; no existing row changes. The runtime role gets DML through the default
-- privileges (20261016130000_per_database_runtime_group): no GRANT here. The server keeps only the
-- sync state (which video, playing or paused, where) — every phone streams from YouTube itself.

-- CreateTable: the video a live is watching together (one per live).
CREATE TABLE "live_watch" (
    "room_id" UUID NOT NULL,
    "video_id" VARCHAR(11) NOT NULL,
    "title" VARCHAR(400) NOT NULL,
    "channel" VARCHAR(200),
    "playing" BOOLEAN NOT NULL,
    "position_ms" INTEGER NOT NULL,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "live_watch_pkey" PRIMARY KEY ("room_id"),
    CONSTRAINT "live_watch_shape" CHECK (video_id ~ '^[A-Za-z0-9_-]{11}$' AND position_ms >= 0)
);

-- CreateTable: viewers' suggestions, for the host to play or turn down.
CREATE TABLE "live_watch_suggestions" (
    "id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "video_id" VARCHAR(11) NOT NULL,
    "title" VARCHAR(400) NOT NULL,
    "channel" VARCHAR(200),
    "status" VARCHAR(10) NOT NULL DEFAULT 'PENDING',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "decided_at" TIMESTAMPTZ(3),

    CONSTRAINT "live_watch_suggestions_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "live_watch_suggestions_status" CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    CONSTRAINT "live_watch_suggestions_video" CHECK (video_id ~ '^[A-Za-z0-9_-]{11}$')
);

-- CreateIndex
CREATE INDEX "live_watch_suggestions_pending_idx" ON "live_watch_suggestions"("room_id", "created_at") WHERE (status = 'PENDING');
CREATE INDEX "live_watch_suggestions_user_idx" ON "live_watch_suggestions"("user_id");

-- AddForeignKey
ALTER TABLE "live_watch" ADD CONSTRAINT "live_watch_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "live_watch_suggestions" ADD CONSTRAINT "live_watch_suggestions_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "live_watch_suggestions" ADD CONSTRAINT "live_watch_suggestions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
