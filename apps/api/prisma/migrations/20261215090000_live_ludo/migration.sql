-- D168 (owner 2026-11-02): Ludo «لودو» played inside a live room, CONVENTIONS §10.42.
-- Additive: one new table; no existing row changes. The runtime role gets DML through the default
-- privileges (20261016130000_per_database_runtime_group): no GRANT here. Free to play: nothing here
-- touches coins, the ledger or any reward.

-- CreateTable: one game in a live room (at most one LOBBY or PLAYING game per room).
CREATE TABLE "live_ludo_games" (
    "id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "status" VARCHAR(10) NOT NULL DEFAULT 'LOBBY',
    "mode" VARCHAR(10) NOT NULL,
    "max_players" SMALLINT NOT NULL,
    "state" JSONB NOT NULL,
    "version" INTEGER NOT NULL DEFAULT 0,
    "winner_user_id" UUID,
    "due_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "started_at" TIMESTAMPTZ(3),
    "ended_at" TIMESTAMPTZ(3),
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "live_ludo_games_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "live_ludo_games_status" CHECK (status IN ('LOBBY', 'PLAYING', 'FINISHED', 'ENDED')),
    CONSTRAINT "live_ludo_games_mode" CHECK (mode IN ('CLASSIC', 'QUICK')),
    CONSTRAINT "live_ludo_games_players" CHECK (max_players IN (2, 4)),
    CONSTRAINT "live_ludo_games_version" CHECK (version >= 0)
);

-- CreateIndex: one open game per room; the server's timer scan.
CREATE UNIQUE INDEX "live_ludo_games_one_open_per_room" ON "live_ludo_games"("room_id") WHERE (status IN ('LOBBY', 'PLAYING'));
CREATE INDEX "live_ludo_games_due_idx" ON "live_ludo_games"("due_at") WHERE (status = 'PLAYING');
CREATE INDEX "live_ludo_games_room_created_idx" ON "live_ludo_games"("room_id", "created_at");

-- AddForeignKey
ALTER TABLE "live_ludo_games" ADD CONSTRAINT "live_ludo_games_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "live_ludo_games" ADD CONSTRAINT "live_ludo_games_winner_user_id_fkey" FOREIGN KEY ("winner_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
