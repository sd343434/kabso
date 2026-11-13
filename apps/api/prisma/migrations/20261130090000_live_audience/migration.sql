-- v1.27.6-live (D140, owner 2026-10-27): the host's end-of-live statistics (CONVENTIONS §10.31).
-- Additive: one table and one column. No GRANT (default privileges,
-- 20261016130000_per_database_runtime_group). No backfill: lives started before this migration
-- keep peak_viewer_count NULL (no audience record), which the statistics report as "not recorded".

-- AlterTable: the most viewers at once. Added without a default so existing rows stay NULL; new
-- rooms start at 0.
ALTER TABLE "live_rooms" ADD COLUMN "peak_viewer_count" INTEGER;
ALTER TABLE "live_rooms" ALTER COLUMN "peak_viewer_count" SET DEFAULT 0;
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_peak_viewer_count_min" CHECK (peak_viewer_count IS NULL OR peak_viewer_count >= 0);

-- CreateTable: everyone who watched a live (aggregated by the statistics only).
CREATE TABLE "live_room_audience" (
    "room_id" UUID NOT NULL,
    "identity" VARCHAR(80) NOT NULL,
    "user_id" UUID,
    "first_joined_at" TIMESTAMPTZ(3) NOT NULL,
    "watch_ms" BIGINT NOT NULL DEFAULT 0,
    "open_since" TIMESTAMPTZ(3),

    CONSTRAINT "live_room_audience_pkey" PRIMARY KEY ("room_id","identity"),
    CONSTRAINT "live_room_audience_watch_ms_min" CHECK (watch_ms >= 0)
);

-- CreateIndex
CREATE INDEX "live_room_audience_user_idx" ON "live_room_audience"("user_id");

-- AddForeignKey
ALTER TABLE "live_room_audience" ADD CONSTRAINT "live_room_audience_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_room_audience" ADD CONSTRAINT "live_room_audience_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
