-- D258 (CONVENTIONS §10.94.5): a VIP's daily coins, claimed at most once a day (the day in LIVE_RANKINGS_TIME_ZONE);
-- the wallet ledger row's reference is this row.
CREATE TABLE "vip_daily_coin_claims" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "day" DATE NOT NULL,
    "tier_id" UUID NOT NULL,
    "coins" BIGINT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "vip_daily_coin_claims_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "vip_daily_coin_claims_coins_check" CHECK ("coins" >= 1)
);

CREATE UNIQUE INDEX "vip_daily_coin_claims_user_day_key" ON "vip_daily_coin_claims"("user_id", "day");

ALTER TABLE "vip_daily_coin_claims" ADD CONSTRAINT "vip_daily_coin_claims_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "vip_daily_coin_claims" ADD CONSTRAINT "vip_daily_coin_claims_tier_id_fkey" FOREIGN KEY ("tier_id") REFERENCES "vip_tiers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- The runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group).

-- `VIP_DAILY_COINS` is a credit: the reason-sign CHECK is re-added with it (as 20270305090100_vip did).
ALTER TABLE "wallet_ledger" DROP CONSTRAINT "wallet_ledger_reason_sign";
ALTER TABLE "wallet_ledger" ADD CONSTRAINT "wallet_ledger_reason_sign" CHECK (
  (reason IN ('ADMIN_GRANT', 'CP_REFUND', 'LUCKY_GIFT_WIN', 'LIVE_BOOST_REFUND', 'TASK_REWARD', 'CHECK_IN_REWARD',
              'EVENT_PRIZE', 'RECHARGE_PURCHASE', 'CARD_TOPUP', 'CARD_TOPUP_RESTORE', 'RECHARGE_ORDER',
              'VIP_DAILY_COINS') AND delta > 0)
  OR (reason IN ('ADMIN_REVOKE', 'BULLET_MESSAGE', 'FAMILY_CREATE', 'CP_REQUEST', 'CP_GIFT', 'LIVE_GIFT', 'LUCKY_GIFT',
                 'PREMIUM_USERNAME_RENT', 'PREMIUM_USERNAME_RENEW', 'LIVE_BOOST', 'DM_GIFT', 'CARD_TOPUP_REVERSAL',
                 'VIP_PURCHASE')
      AND delta < 0)
  OR (reason = 'ADMIN_ADJUSTMENT' AND delta <> 0));

-- A VIP's free public message of the day (DAILY_BULLET, §10.94.4) is stored with cost 0.
ALTER TABLE "live_bullets" DROP CONSTRAINT "live_bullets_cost_positive";
ALTER TABLE "live_bullets" ADD CONSTRAINT "live_bullets_cost_non_negative" CHECK (cost >= 0);
