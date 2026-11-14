-- v1.35-live (D154d, owner 2026-10-28): the host's data center «مركز البيانات», CONVENTIONS §10.36.
-- Additive: one new table, filled after the fact by the API's summariser (every ended live, the
-- older ones included, a batch at a time); no existing row changes. The runtime role gets DML through
-- the default privileges (20261016130000_per_database_runtime_group): no GRANT here.

-- CreateTable: one ended live, summarised once.
CREATE TABLE "live_summaries" (
    "room_id" UUID NOT NULL,
    "host_user_id" UUID NOT NULL,
    "started_at" TIMESTAMPTZ(3) NOT NULL,
    "ended_at" TIMESTAMPTZ(3) NOT NULL,
    "duration_seconds" INTEGER NOT NULL,
    "peak_viewers" INTEGER NOT NULL,
    "unique_viewers" INTEGER NOT NULL,
    "gift_count" INTEGER NOT NULL,
    "gift_coins" BIGINT NOT NULL,
    "earnings_coins" BIGINT NOT NULL,
    "new_followers" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "live_summaries_pkey" PRIMARY KEY ("room_id")
);

-- CreateIndex
CREATE INDEX "live_summaries_host_started_idx" ON "live_summaries"("host_user_id", "started_at");

-- AddForeignKey
ALTER TABLE "live_summaries" ADD CONSTRAINT "live_summaries_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_summaries" ADD CONSTRAINT "live_summaries_host_user_id_fkey" FOREIGN KEY ("host_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "live_summaries" ADD CONSTRAINT "live_summaries_amounts" CHECK (
    duration_seconds >= 0 AND peak_viewers >= 0 AND unique_viewers >= 0 AND gift_count >= 0
    AND gift_coins >= 0 AND earnings_coins >= 0 AND new_followers >= 0 AND ended_at >= started_at);
