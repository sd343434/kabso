-- v1.56-social (D187, owner 2026-10-30): the daily recharge badges «شارات الشحن اليومي» (CONVENTIONS §10.50).
-- Additive: two new tables. The runtime role gets DML through the default privileges
-- (20261016130000_per_database_runtime_group): no GRANT here.

-- The coins a person RECEIVED from recharges (a recharge agent's sale; later a website top-up) per calendar day
-- in RECHARGE_BADGE_TIME_ZONE, and the tier the day reached (0: none). Written in the recharge's transaction.
CREATE TABLE "recharge_daily_totals" (
    "user_id" UUID NOT NULL,
    "day" DATE NOT NULL,
    "coins" BIGINT NOT NULL DEFAULT 0,
    "tier" SMALLINT NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "recharge_daily_totals_pkey" PRIMARY KEY ("user_id", "day"),
    CONSTRAINT "recharge_daily_totals_coins_check" CHECK ("coins" >= 0),
    CONSTRAINT "recharge_daily_totals_tier_check" CHECK ("tier" BETWEEN 0 AND 5)
);

-- One row per person: the badge shown (tier 1–5) until `badge_until` (the moment the tier was reached + 24 h),
-- and the day it was reached for. Read with every UserSummary; shown only while `badge_until` is in the future.
CREATE TABLE "recharge_badges" (
    "user_id" UUID NOT NULL,
    "badge_tier" SMALLINT NOT NULL,
    "badge_until" TIMESTAMPTZ(3) NOT NULL,
    "badge_day" DATE NOT NULL,
    "reached_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "recharge_badges_pkey" PRIMARY KEY ("user_id"),
    CONSTRAINT "recharge_badges_tier_check" CHECK ("badge_tier" BETWEEN 1 AND 5),
    CONSTRAINT "recharge_badges_until_check" CHECK ("badge_until" > "reached_at")
);

ALTER TABLE "recharge_daily_totals" ADD CONSTRAINT "recharge_daily_totals_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "recharge_badges" ADD CONSTRAINT "recharge_badges_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
