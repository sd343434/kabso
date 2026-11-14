-- v1.23-live (CP-020, D108, 2026-10-26): live gifts, CONVENTIONS §10.23. Owned by the `gifts` module.
-- The catalogue (`gifts`) is managed only with the `gift-admin` CLI and starts EMPTY: the owner
-- supplies the art later, so this migration seeds no gift (an empty catalogue is valid). Gifts are
-- never deleted, only disabled, so sends and stock keep their gift. The runtime role gets DML through
-- the default privileges (20261016130000_per_database_runtime_group): no GRANT here. Admin changes
-- and stock grants are audited (`gift.*` in audit_logs).

-- CreateEnum: the catalogue tabs (شائعة / مناسبات / مرح); the fourth tab, الحقيبة, is the user's stock.
CREATE TYPE "gift_category" AS ENUM ('POPULAR', 'EVENT', 'FUN');

-- CreateEnum: the corner badge of a gift in the panel.
CREATE TYPE "gift_badge" AS ENUM ('NONE', 'NEW', 'EVENT');

-- CreateEnum: how a send was paid.
CREATE TYPE "live_gift_source" AS ENUM ('COINS', 'BAG');

-- CreateTable
CREATE TABLE "gifts" (
    "code" VARCHAR(40) NOT NULL,
    "category" "gift_category" NOT NULL,
    "name_ar" VARCHAR(60) NOT NULL,
    "name_en" VARCHAR(60) NOT NULL,
    "price_coins" INTEGER NOT NULL,
    "asset_key" VARCHAR(80) NOT NULL,
    "animation_key" VARCHAR(80),
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "badge" "gift_badge" NOT NULL DEFAULT 'NONE',
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "gifts_pkey" PRIMARY KEY ("code")
);

-- CreateTable: the gift bag (الحقيبة): gifts a user owns and may send without coins.
CREATE TABLE "user_gift_stock" (
    "user_id" UUID NOT NULL,
    "gift_code" VARCHAR(40) NOT NULL,
    "quantity" INTEGER NOT NULL,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_gift_stock_pkey" PRIMARY KEY ("user_id","gift_code")
);

-- CreateTable: one send (one gift code × quantity to 1 … 25 recipients).
CREATE TABLE "live_gifts" (
    "id" UUID NOT NULL,
    "sender_id" UUID NOT NULL,
    "client_id" UUID NOT NULL,
    "room_id" UUID,
    "gift_code" VARCHAR(40) NOT NULL,
    "quantity" INTEGER NOT NULL,
    "source" "live_gift_source" NOT NULL,
    "unit_price" INTEGER NOT NULL,
    "total_coins" BIGINT NOT NULL,
    "coins_charged" BIGINT NOT NULL,
    "recipients_key" TEXT NOT NULL,
    "combo_id" UUID NOT NULL,
    "combo_count" INTEGER NOT NULL,
    "combo_quantity" BIGINT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "live_gifts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "live_gift_recipients" (
    "gift_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "position" SMALLINT NOT NULL,
    "coins" BIGINT NOT NULL,

    CONSTRAINT "live_gift_recipients_pkey" PRIMARY KEY ("gift_id","user_id")
);

-- CreateIndex
CREATE INDEX "gifts_category_sort_idx" ON "gifts"("category", "sort_order");

-- CreateIndex
CREATE INDEX "user_gift_stock_gift_idx" ON "user_gift_stock"("gift_code");

-- CreateIndex: a retry with the same clientId by the same sender is the same send.
CREATE UNIQUE INDEX "live_gifts_client_once" ON "live_gifts"("sender_id", "client_id");

-- CreateIndex: the sender's latest send in a room (combos).
CREATE INDEX "live_gifts_sender_room_idx" ON "live_gifts"("sender_id", "room_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "live_gifts_room_idx" ON "live_gifts"("room_id", "created_at");

-- CreateIndex
CREATE INDEX "live_gifts_gift_idx" ON "live_gifts"("gift_code");

-- CreateIndex
CREATE INDEX "live_gift_recipients_user_idx" ON "live_gift_recipients"("user_id");

-- AddForeignKey
ALTER TABLE "user_gift_stock" ADD CONSTRAINT "user_gift_stock_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey: gifts are disabled, never deleted.
ALTER TABLE "user_gift_stock" ADD CONSTRAINT "user_gift_stock_gift_code_fkey" FOREIGN KEY ("gift_code") REFERENCES "gifts"("code") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_gifts" ADD CONSTRAINT "live_gifts_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_gifts" ADD CONSTRAINT "live_gifts_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_gifts" ADD CONSTRAINT "live_gifts_gift_code_fkey" FOREIGN KEY ("gift_code") REFERENCES "gifts"("code") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_gift_recipients" ADD CONSTRAINT "live_gift_recipients_gift_id_fkey" FOREIGN KEY ("gift_id") REFERENCES "live_gifts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_gift_recipients" ADD CONSTRAINT "live_gift_recipients_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- ---- CHECKs (not expressible in schema.prisma) -------------------------------------------------
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_code_format" CHECK (code ~ '^[a-z0-9][a-z0-9_]{0,39}$');
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_price_range" CHECK (price_coins BETWEEN 1 AND 1000000);
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_names_present" CHECK (length(btrim(name_ar)) > 0 AND length(btrim(name_en)) > 0);
ALTER TABLE "user_gift_stock" ADD CONSTRAINT "user_gift_stock_quantity_range" CHECK (quantity BETWEEN 0 AND 1000000000);
ALTER TABLE "live_gifts" ADD CONSTRAINT "live_gifts_quantity_positive" CHECK (quantity > 0);
ALTER TABLE "live_gifts" ADD CONSTRAINT "live_gifts_amounts" CHECK (
  unit_price > 0 AND total_coins > 0
  AND ((source = 'COINS' AND coins_charged = total_coins) OR (source = 'BAG' AND coins_charged = 0)));
ALTER TABLE "live_gifts" ADD CONSTRAINT "live_gifts_combo" CHECK (combo_count >= 1 AND combo_quantity >= quantity);
ALTER TABLE "live_gift_recipients" ADD CONSTRAINT "live_gift_recipients_coins_positive" CHECK (coins > 0);

-- Wallet: a LIVE_GIFT ledger row is a debit (the reason/sign rule of 20261110100000_families_cp_medals).
ALTER TABLE "wallet_ledger" DROP CONSTRAINT "wallet_ledger_reason_sign";
ALTER TABLE "wallet_ledger" ADD CONSTRAINT "wallet_ledger_reason_sign" CHECK (
  (reason IN ('ADMIN_GRANT', 'CP_REFUND') AND delta > 0)
  OR (reason IN ('ADMIN_REVOKE', 'BULLET_MESSAGE', 'FAMILY_CREATE', 'CP_REQUEST', 'CP_GIFT', 'LIVE_GIFT') AND delta < 0));

-- ---- The Contribution list counts gifts (CONVENTIONS §10.12, §10.23) ---------------------------
-- `live_room_tappers` becomes the row of everyone who gave something to a live: counted taps (1 point
-- each) and, from now on, the coin value of the gifts they sent there (`support_coins`, 100 points a
-- coin). `points` is the total the list orders by and `points_at` when it was reached (ties). A
-- person who only sent gifts never tapped: `last_batch_at` (the taps counting rule) may be null.
ALTER TABLE "live_room_tappers" ALTER COLUMN "last_batch_at" DROP NOT NULL;
ALTER TABLE "live_room_tappers" ADD COLUMN "support_coins" BIGINT NOT NULL DEFAULT 0;
ALTER TABLE "live_room_tappers" ADD COLUMN "points" BIGINT NOT NULL DEFAULT 0;
ALTER TABLE "live_room_tappers" ADD COLUMN "points_at" TIMESTAMPTZ(3);
UPDATE "live_room_tappers" SET "points" = "counted", "points_at" = "last_batch_at";
ALTER TABLE "live_room_tappers" ALTER COLUMN "points_at" SET NOT NULL;
ALTER TABLE "live_room_tappers" ADD CONSTRAINT "live_room_tappers_points" CHECK (support_coins >= 0 AND points = counted + support_coins * 100);

-- The list's index follows the new order (points desc, who reached it first, user id).
DROP INDEX "live_room_tappers_room_rank_idx";
CREATE INDEX "live_room_tappers_room_rank_idx" ON "live_room_tappers"("room_id", "points" DESC, "points_at", "user_id");
