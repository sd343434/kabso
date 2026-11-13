-- v1.37-live (D154h, owner 2026-10-28): stickers on a live «ملصقات», CONVENTIONS §10.38.
-- Additive: two new tables; no existing row changes. The runtime role gets DML through the default
-- privileges (20261016130000_per_database_runtime_group): no GRANT here.

-- CreateTable: sticker art added by admins (packs beyond the built-in Kabi pack, which is in the code).
CREATE TABLE "live_sticker_art" (
    "key" VARCHAR(64) NOT NULL,
    "pack" VARCHAR(32) NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "live_sticker_art_pkey" PRIMARY KEY ("key"),
    CONSTRAINT "live_sticker_art_key_shape" CHECK (key ~ '^[a-z0-9]+_[a-z0-9_]+$')
);

-- CreateTable: the stickers on a live now (≤ 3), replaced whole by the host.
CREATE TABLE "live_stickers" (
    "room_id" UUID NOT NULL,
    "id" UUID NOT NULL,
    "position" SMALLINT NOT NULL,
    "art_key" VARCHAR(64),
    "text" VARCHAR(160),
    "x" DOUBLE PRECISION NOT NULL,
    "y" DOUBLE PRECISION NOT NULL,
    "scale" DOUBLE PRECISION NOT NULL,
    "rotation" DOUBLE PRECISION NOT NULL,

    CONSTRAINT "live_stickers_pkey" PRIMARY KEY ("room_id","id"),
    CONSTRAINT "live_stickers_position_key" UNIQUE ("room_id","position"),
    CONSTRAINT "live_stickers_shape" CHECK (
        position BETWEEN 0 AND 2
        AND ((art_key IS NULL) <> ("text" IS NULL))
        AND x BETWEEN 0 AND 1 AND y BETWEEN 0 AND 1
        AND scale BETWEEN 0.25 AND 4
        AND rotation BETWEEN -3.15 AND 3.15)
);

-- AddForeignKey
ALTER TABLE "live_stickers" ADD CONSTRAINT "live_stickers_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;
