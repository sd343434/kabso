-- v1.20-live (owner D105, 2026-10-26): kicking someone out of a live (CONVENTIONS §10.20). The host
-- or a moderator kicks a person out of one live: one row per room and user, which keeps them from
-- the media session, the chat, bullets, taps and seat requests of that live until it ends (a new
-- live is a new room). Rows are removed 30 days after their room ended, with the chat mutes. The
-- runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group),
-- so this migration contains no GRANT.

-- CreateTable
CREATE TABLE "live_room_kicks" (
    "room_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "kicked_by_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "live_room_kicks_pkey" PRIMARY KEY ("room_id","user_id")
);

-- CreateIndex
CREATE INDEX "live_room_kicks_user_idx" ON "live_room_kicks"("user_id");

-- CreateIndex
CREATE INDEX "live_room_kicks_kicked_by_idx" ON "live_room_kicks"("kicked_by_id");

-- AddForeignKey
ALTER TABLE "live_room_kicks" ADD CONSTRAINT "live_room_kicks_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_room_kicks" ADD CONSTRAINT "live_room_kicks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_room_kicks" ADD CONSTRAINT "live_room_kicks_kicked_by_id_fkey" FOREIGN KEY ("kicked_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Nobody kicks themselves (CONVENTIONS §10.20).
ALTER TABLE "live_room_kicks" ADD CONSTRAINT "live_room_kicks_not_self" CHECK (kicked_by_id IS DISTINCT FROM user_id);
