-- v1.27-live (D132, owner 2026-10-27): lucky gifts, CONVENTIONS §10.27. Additive: three new tables,
-- no existing row changes. The runtime role gets DML through the default privileges
-- (20261016130000_per_database_runtime_group): no GRANT here.

-- CreateTable: the daily protection — one row per day (LUCKY_GIFT_DAY_TIME_ZONE), locked by every
-- lucky send: the day's lucky spend and the coins paid out (paid never exceeds RTP × spend; the
-- service enforces the ratio, the CHECK the signs).
CREATE TABLE "lucky_gift_days" (
    "day" DATE NOT NULL,
    "spend_coins" BIGINT NOT NULL DEFAULT 0,
    "paid_coins" BIGINT NOT NULL DEFAULT 0,
    "sends" INTEGER NOT NULL DEFAULT 0,
    "draws" BIGINT NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "lucky_gift_days_pkey" PRIMARY KEY ("day")
);

-- CreateTable: the audit row of one lucky send (every winning draw, the table used, the budget).
CREATE TABLE "lucky_gift_draws" (
    "gift_id" UUID NOT NULL,
    "sender_id" UUID NOT NULL,
    "gift_code" VARCHAR(40) NOT NULL,
    "unit_price" INTEGER NOT NULL,
    "quantity" INTEGER NOT NULL,
    "recipients" INTEGER NOT NULL,
    "draws" INTEGER NOT NULL,
    "odds" JSONB NOT NULL,
    "wins" JSONB NOT NULL,
    "coins_won" BIGINT NOT NULL,
    "top_multiplier" INTEGER,
    "downgraded" INTEGER NOT NULL,
    "budget_day" DATE NOT NULL,
    "budget_before" BIGINT NOT NULL,
    "budget_after" BIGINT NOT NULL,
    "spend_after" BIGINT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "lucky_gift_draws_pkey" PRIMARY KEY ("gift_id")
);

-- CreateTable: the one-time 18+ statement (accounts have no birth date; pending legal review).
CREATE TABLE "lucky_gift_age_confirmations" (
    "user_id" UUID NOT NULL,
    "confirmed_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "lucky_gift_age_confirmations_pkey" PRIMARY KEY ("user_id")
);

-- CreateIndex: the admin's latest wins.
CREATE INDEX "lucky_gift_draws_created_idx" ON "lucky_gift_draws"("created_at" DESC);

-- CreateIndex
CREATE INDEX "lucky_gift_draws_sender_idx" ON "lucky_gift_draws"("sender_id", "created_at" DESC);

-- AddForeignKey
ALTER TABLE "lucky_gift_draws" ADD CONSTRAINT "lucky_gift_draws_gift_id_fkey" FOREIGN KEY ("gift_id") REFERENCES "live_gifts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "lucky_gift_draws" ADD CONSTRAINT "lucky_gift_draws_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "lucky_gift_age_confirmations" ADD CONSTRAINT "lucky_gift_age_confirmations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- ---- CHECKs (not expressible in schema.prisma) -------------------------------------------------
ALTER TABLE "lucky_gift_days" ADD CONSTRAINT "lucky_gift_days_amounts" CHECK (spend_coins >= 0 AND paid_coins >= 0 AND sends >= 0 AND draws >= 0);
ALTER TABLE "lucky_gift_draws" ADD CONSTRAINT "lucky_gift_draws_amounts" CHECK (
    unit_price >= 1 AND quantity >= 1 AND recipients >= 1 AND draws = quantity * recipients
    AND coins_won >= 0 AND downgraded >= 0 AND (top_multiplier IS NULL OR top_multiplier >= 2)
    AND budget_after >= 0 AND budget_before >= 0 AND spend_after >= 0);

-- Wallet ledger: a lucky charge takes coins, a lucky win gives them (the sign CHECK of
-- 20261112100000_live_gifts, extended).
ALTER TABLE "wallet_ledger" DROP CONSTRAINT "wallet_ledger_reason_sign";
ALTER TABLE "wallet_ledger" ADD CONSTRAINT "wallet_ledger_reason_sign" CHECK (
  (reason IN ('ADMIN_GRANT', 'CP_REFUND', 'LUCKY_GIFT_WIN') AND delta > 0)
  OR (reason IN ('ADMIN_REVOKE', 'BULLET_MESSAGE', 'FAMILY_CREATE', 'CP_REQUEST', 'CP_GIFT', 'LIVE_GIFT', 'LUCKY_GIFT') AND delta < 0));
