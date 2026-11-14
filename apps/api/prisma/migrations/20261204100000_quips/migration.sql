-- v1.32-live (D154, owner 2026-10-28): «إفيهات» quips and the per-category host share, CONVENTIONS
-- §10.33. Additive: new nullable columns on gifts and live_rooms, one new column on live_gifts
-- (backfilled), one new table, and relaxed CHECKs so a free quip (price 0) can be stored. The
-- runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group):
-- no GRANT here.

-- AlterTable: a QUIPS gift's bundled sound, its length in milliseconds and its line of text.
ALTER TABLE "gifts" ADD COLUMN "sound_key" VARCHAR(80),
ADD COLUMN "sound_ms" INTEGER,
ADD COLUMN "quip_text" VARCHAR(200);

-- The sound fields are set exactly for QUIPS gifts (the text stays optional: free sounds have none).
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_quip_fields" CHECK (
    ((category::text = 'QUIPS') = (sound_key IS NOT NULL AND sound_ms IS NOT NULL))
    AND (quip_text IS NULL OR category::text = 'QUIPS')
    AND (sound_ms IS NULL OR sound_ms BETWEEN 200 AND 15000)
    AND (sound_key IS NULL OR sound_key ~ '^[A-Za-z0-9][A-Za-z0-9_./-]{0,79}$')
    AND (quip_text IS NULL OR length(btrim(quip_text)) > 0));

-- A QUIPS gift may be free (price 0); every other gift still costs 1 … 1 000 000 coins.
ALTER TABLE "gifts" DROP CONSTRAINT "gifts_price_range";
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_price_range" CHECK (
    price_coins BETWEEN 1 AND 1000000 OR (price_coins = 0 AND category::text = 'QUIPS'));

-- AlterTable: the recipients' earnings share of each send, fixed at the time of the send (basis
-- points). Existing sends: a LUCKY send keeps the share its draws were made with (the audit row's
-- odds), every other send the owner's 65 % (D149).
ALTER TABLE "live_gifts" ADD COLUMN "host_share_bps" INTEGER;
UPDATE "live_gifts" g SET "host_share_bps" = COALESCE((d.odds->>'hostShareBps')::int, 1000)
  FROM "lucky_gift_draws" d WHERE d.gift_id = g.id;
UPDATE "live_gifts" SET "host_share_bps" = 6500 WHERE "host_share_bps" IS NULL;
ALTER TABLE "live_gifts" ALTER COLUMN "host_share_bps" SET NOT NULL;
ALTER TABLE "live_gifts" ADD CONSTRAINT "live_gifts_host_share" CHECK (host_share_bps BETWEEN 0 AND 10000);

-- A free quip is a send worth 0 coins (nothing charged, nothing counted); any other send is worth
-- more than 0. The source rule is unchanged.
ALTER TABLE "live_gifts" DROP CONSTRAINT "live_gifts_amounts";
ALTER TABLE "live_gifts" ADD CONSTRAINT "live_gifts_amounts" CHECK (
  unit_price >= 0 AND total_coins >= 0 AND ((unit_price = 0) = (total_coins = 0))
  AND ((source = 'COINS' AND coins_charged = total_coins) OR (source = 'BAG' AND coins_charged = 0)));
ALTER TABLE "live_gift_recipients" DROP CONSTRAINT "live_gift_recipients_coins_positive";
ALTER TABLE "live_gift_recipients" ADD CONSTRAINT "live_gift_recipients_coins_positive" CHECK (coins >= 0);

-- AlterTable: when the room's quip queue is free again (one quip plays at a time per room).
ALTER TABLE "live_rooms" ADD COLUMN "quip_busy_until" TIMESTAMPTZ(3);

-- CreateTable: the one free quip a person sent in a live (owner: one per viewer per live).
CREATE TABLE "live_free_quips" (
    "room_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "gift_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "live_free_quips_pkey" PRIMARY KEY ("room_id","user_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "live_free_quips_gift_id_key" ON "live_free_quips"("gift_id");

-- CreateIndex
CREATE INDEX "live_free_quips_user_idx" ON "live_free_quips"("user_id");

-- AddForeignKey
ALTER TABLE "live_free_quips" ADD CONSTRAINT "live_free_quips_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_free_quips" ADD CONSTRAINT "live_free_quips_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_free_quips" ADD CONSTRAINT "live_free_quips_gift_id_fkey" FOREIGN KEY ("gift_id") REFERENCES "live_gifts"("id") ON DELETE CASCADE ON UPDATE CASCADE;
