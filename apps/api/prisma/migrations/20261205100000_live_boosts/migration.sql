-- v1.33-live (D154b, owner 2026-10-28): traffic cards «بطاقة الزيارات» (CP-014 part C, the room boost),
-- CONVENTIONS §10.34. Additive: two new tables and the wallet reason/sign rule extended; no existing row
-- changes. The runtime role gets DML through the default privileges
-- (20261016130000_per_database_runtime_group): no GRANT here.

-- CreateTable: one row per traffic card used on a live (bought with coins or taken from the buyer's
-- cards), scheduled when bought.
CREATE TABLE "live_boosts" (
    "id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "host_user_id" UUID NOT NULL,
    "buyer_id" UUID NOT NULL,
    "client_id" UUID NOT NULL,
    "minutes" INTEGER NOT NULL,
    "source" "live_boost_source" NOT NULL,
    "coins_charged" BIGINT NOT NULL,
    "slot" SMALLINT NOT NULL,
    "starts_at" TIMESTAMPTZ(3) NOT NULL,
    "ends_at" TIMESTAMPTZ(3) NOT NULL,
    "cancelled_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "live_boosts_pkey" PRIMARY KEY ("id")
);

-- CreateTable: the traffic cards a user holds, by length (admin rewards).
CREATE TABLE "live_boost_cards" (
    "user_id" UUID NOT NULL,
    "minutes" INTEGER NOT NULL,
    "quantity" INTEGER NOT NULL,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "live_boost_cards_pkey" PRIMARY KEY ("user_id","minutes")
);

-- CreateIndex
CREATE INDEX "live_boosts_ends_idx" ON "live_boosts"("ends_at") WHERE (cancelled_at IS NULL);

-- CreateIndex
CREATE INDEX "live_boosts_room_idx" ON "live_boosts"("room_id", "ends_at");

-- CreateIndex
CREATE INDEX "live_boosts_host_idx" ON "live_boosts"("host_user_id");

-- CreateIndex
CREATE UNIQUE INDEX "live_boosts_client_once" ON "live_boosts"("buyer_id", "client_id");

-- AddForeignKey
ALTER TABLE "live_boosts" ADD CONSTRAINT "live_boosts_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_boosts" ADD CONSTRAINT "live_boosts_host_user_id_fkey" FOREIGN KEY ("host_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_boosts" ADD CONSTRAINT "live_boosts_buyer_id_fkey" FOREIGN KEY ("buyer_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_boost_cards" ADD CONSTRAINT "live_boost_cards_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- ---- CHECKs (not expressible in schema.prisma) -------------------------------------------------
ALTER TABLE "live_boosts" ADD CONSTRAINT "live_boosts_shape" CHECK (
    minutes BETWEEN 1 AND 1440 AND slot >= 0 AND ends_at >= starts_at AND coins_charged >= 0
    AND ((source = 'COINS' AND coins_charged > 0) OR (source = 'CARD' AND coins_charged = 0)));
ALTER TABLE "live_boost_cards" ADD CONSTRAINT "live_boost_cards_shape" CHECK (
    minutes BETWEEN 1 AND 1440 AND quantity BETWEEN 0 AND 1000000);

-- Wallet: a LIVE_BOOST row is a debit, a LIVE_BOOST_REFUND a credit (the reason/sign rule of
-- 20261201100000_premium_usernames, extended).
ALTER TABLE "wallet_ledger" DROP CONSTRAINT "wallet_ledger_reason_sign";
ALTER TABLE "wallet_ledger" ADD CONSTRAINT "wallet_ledger_reason_sign" CHECK (
  (reason IN ('ADMIN_GRANT', 'CP_REFUND', 'LUCKY_GIFT_WIN', 'LIVE_BOOST_REFUND') AND delta > 0)
  OR (reason IN ('ADMIN_REVOKE', 'BULLET_MESSAGE', 'FAMILY_CREATE', 'CP_REQUEST', 'CP_GIFT', 'LIVE_GIFT', 'LUCKY_GIFT',
                 'PREMIUM_USERNAME_RENT', 'PREMIUM_USERNAME_RENEW', 'LIVE_BOOST') AND delta < 0));
