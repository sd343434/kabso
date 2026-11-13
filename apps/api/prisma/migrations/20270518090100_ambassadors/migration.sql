-- v1.140-social (D390, coordinator brief from the owner's «برنامج سفراء Kabso», CONVENTIONS §10.179).
--
-- 1. `ambassador_settings` (one row, inserted here): the master switch — OFF until the OWNER turns it on in the
--    panel — and every number of the programme (the attribution window, the hold, the activity rule, the monthly
--    cap, the fraud limits and the levels with their commission and monthly reward). Proposed defaults for the owner.
-- 2. `ambassadors`: one row per ambassador (approved application or appointed by the team); status ACTIVE / FROZEN,
--    the level, the review flag.
-- 3. `ambassador_applications`: «انضم إلى برنامج السفراء» — one PENDING per person (partial unique index).
-- 4. `ambassador_referrals`: a D217 referral that took the ambassador track (the inviter was an ambassador when the
--    code was applied) — the precedence: such a referral earns no D217 inviter reward (§10.179.3).
-- 5. `ambassador_commissions`: one row per qualifying top-up (unique per recharge), PENDING → CREDITED / VOID /
--    REVERSED; CHECK `ambassador_commissions_shape`.
-- 6. `ambassador_months`: the monthly evaluation (one row per ambassador and month: the stats, the level change and
--    the target reward).
-- 7. `ambassador_flags`: velocity / IP-cluster / self-payment signals that put an ambassador under review.
-- 8. `ambassador_campaigns` and `ambassador_campaign_members`: campaigns and events coordinated with the team.
-- 9. The ledgers' sign rules: AMBASSADOR_COMMISSION credit, AMBASSADOR_COMMISSION_REVERSAL debit (cherries);
--    AMBASSADOR_REWARD credit (coins).
--
-- New tables get their runtime grants from the default privileges (KL-013, migration 20261016130000).
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

CREATE TYPE "ambassador_status" AS ENUM ('ACTIVE', 'FROZEN');
CREATE TYPE "ambassador_application_status" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED');
CREATE TYPE "ambassador_referral_status" AS ENUM ('PENDING', 'ACTIVE', 'VOID');
CREATE TYPE "ambassador_commission_status" AS ENUM ('PENDING', 'CREDITED', 'VOID', 'REVERSED');

-- 1. The settings (OFF by default).
CREATE TABLE "ambassador_settings" (
    "id" SMALLINT NOT NULL DEFAULT 1,
    "enabled" BOOLEAN NOT NULL DEFAULT false,
    "attribution_window_days" INTEGER NOT NULL DEFAULT 90,
    "hold_days" INTEGER NOT NULL DEFAULT 14,
    "min_active_days" INTEGER NOT NULL DEFAULT 3,
    "min_active_topup_coins" BIGINT NOT NULL DEFAULT 100000,
    "monthly_cap_cherries" BIGINT NOT NULL DEFAULT 50000000,
    "velocity_max_per_day" INTEGER NOT NULL DEFAULT 30,
    "ip_cluster_max" INTEGER NOT NULL DEFAULT 3,
    "ip_cluster_window_days" INTEGER NOT NULL DEFAULT 30,
    "levels" JSONB NOT NULL DEFAULT '[{"code":"BRONZE","minActiveReferrals":0,"minTopupCoins":0,"commissionBps":300,"reward":{"kind":"NONE"}},{"code":"SILVER","minActiveReferrals":5,"minTopupCoins":3000000,"commissionBps":500,"reward":{"kind":"COINS","amount":100000}},{"code":"GOLD","minActiveReferrals":15,"minTopupCoins":15000000,"commissionBps":700,"reward":{"kind":"VIP_DAYS","amount":7,"vipTier":"VIP_1"}},{"code":"DIAMOND","minActiveReferrals":40,"minTopupCoins":60000000,"commissionBps":1000,"reward":{"kind":"COINS","amount":1000000}}]',
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_by_id" UUID,

    CONSTRAINT "ambassador_settings_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "ambassador_settings_one" CHECK ("id" = 1),
    CONSTRAINT "ambassador_settings_shape" CHECK (
        "attribution_window_days" BETWEEN 1 AND 3650
        AND "hold_days" BETWEEN 0 AND 365
        AND "min_active_days" BETWEEN 0 AND 365
        AND "min_active_topup_coins" >= 0
        AND "monthly_cap_cherries" >= 0
        AND "velocity_max_per_day" BETWEEN 0 AND 100000
        AND "ip_cluster_max" BETWEEN 0 AND 100000
        AND "ip_cluster_window_days" BETWEEN 1 AND 365
        AND jsonb_typeof("levels") = 'array' AND jsonb_array_length("levels") BETWEEN 1 AND 10)
);
ALTER TABLE "ambassador_settings" ADD CONSTRAINT "ambassador_settings_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
INSERT INTO "ambassador_settings" ("id") VALUES (1);

-- 3. The applications (before `ambassadors`, which points at the approved one).
CREATE TABLE "ambassador_applications" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "status" "ambassador_application_status" NOT NULL DEFAULT 'PENDING',
    "country" CHAR(2) NOT NULL,
    "links" VARCHAR(200)[] NOT NULL,
    "audience_size" INTEGER NOT NULL,
    "motivation" VARCHAR(1000) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "decided_at" TIMESTAMPTZ(3),
    "decided_by_id" UUID,
    "reject_reason" VARCHAR(500),

    CONSTRAINT "ambassador_applications_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "ambassador_applications_shape" CHECK (
        "country" ~ '^[A-Z]{2}$'
        AND cardinality("links") BETWEEN 1 AND 5
        AND "audience_size" BETWEEN 0 AND 1000000000
        AND char_length(btrim("motivation")) BETWEEN 1 AND 1000
        AND ("status" = 'PENDING') = ("decided_at" IS NULL)
        AND ("status" = 'REJECTED') = ("reject_reason" IS NOT NULL))
);
CREATE UNIQUE INDEX "ambassador_applications_one_pending" ON "ambassador_applications"("user_id") WHERE ("status" = 'PENDING'::ambassador_application_status);
CREATE INDEX "ambassador_applications_user_idx" ON "ambassador_applications"("user_id", "created_at" DESC);
CREATE INDEX "ambassador_applications_status_idx" ON "ambassador_applications"("status", "created_at" DESC);
ALTER TABLE "ambassador_applications" ADD CONSTRAINT "ambassador_applications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ambassador_applications" ADD CONSTRAINT "ambassador_applications_decided_by_id_fkey" FOREIGN KEY ("decided_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- 2. The ambassadors.
CREATE TABLE "ambassadors" (
    "user_id" UUID NOT NULL,
    "status" "ambassador_status" NOT NULL DEFAULT 'ACTIVE',
    "level" VARCHAR(16) NOT NULL,
    "source" VARCHAR(16) NOT NULL,
    "application_id" UUID,
    "appointed_by_id" UUID,
    "country" CHAR(2),
    "activated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "level_changed_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "frozen_at" TIMESTAMPTZ(3),
    "frozen_reason" VARCHAR(500),
    "frozen_by_id" UUID,
    "under_review" BOOLEAN NOT NULL DEFAULT false,
    "review_reason" VARCHAR(32),
    "review_at" TIMESTAMPTZ(3),

    CONSTRAINT "ambassadors_pkey" PRIMARY KEY ("user_id"),
    CONSTRAINT "ambassadors_shape" CHECK (
        "source" IN ('APPLICATION', 'APPOINTED')
        AND ("source" = 'APPLICATION') = ("application_id" IS NOT NULL)
        AND ("status" = 'FROZEN') = ("frozen_at" IS NOT NULL)
        AND ("frozen_at" IS NULL OR "frozen_reason" IS NOT NULL)
        AND "under_review" = ("review_reason" IS NOT NULL)
        AND ("country" IS NULL OR "country" ~ '^[A-Z]{2}$'))
);
CREATE INDEX "ambassadors_status_idx" ON "ambassadors"("status", "activated_at" DESC);
ALTER TABLE "ambassadors" ADD CONSTRAINT "ambassadors_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ambassadors" ADD CONSTRAINT "ambassadors_application_id_fkey" FOREIGN KEY ("application_id") REFERENCES "ambassador_applications"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "ambassadors" ADD CONSTRAINT "ambassadors_appointed_by_id_fkey" FOREIGN KEY ("appointed_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "ambassadors" ADD CONSTRAINT "ambassadors_frozen_by_id_fkey" FOREIGN KEY ("frozen_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- 4. The ambassador-track referrals.
CREATE TABLE "ambassador_referrals" (
    "referral_id" UUID NOT NULL,
    "ambassador_user_id" UUID NOT NULL,
    "invitee_user_id" UUID NOT NULL,
    "status" "ambassador_referral_status" NOT NULL DEFAULT 'PENDING',
    "window_until" TIMESTAMPTZ(3) NOT NULL,
    "invitee_ip" VARCHAR(64),
    "active_at" TIMESTAMPTZ(3),
    "active_month" CHAR(7),
    "voided_at" TIMESTAMPTZ(3),
    "void_reason" VARCHAR(32),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ambassador_referrals_pkey" PRIMARY KEY ("referral_id"),
    CONSTRAINT "ambassador_referrals_shape" CHECK (
        "ambassador_user_id" <> "invitee_user_id"
        AND ("status" = 'ACTIVE') = ("active_at" IS NOT NULL AND "active_month" IS NOT NULL)
        AND ("status" = 'VOID') = ("voided_at" IS NOT NULL AND "void_reason" IS NOT NULL))
);
CREATE UNIQUE INDEX "ambassador_referrals_invitee_key" ON "ambassador_referrals"("invitee_user_id");
CREATE INDEX "ambassador_referrals_ambassador_idx" ON "ambassador_referrals"("ambassador_user_id", "created_at" DESC);
CREATE INDEX "ambassador_referrals_pending_idx" ON "ambassador_referrals"("created_at") WHERE ("status" = 'PENDING'::ambassador_referral_status);
ALTER TABLE "ambassador_referrals" ADD CONSTRAINT "ambassador_referrals_referral_id_fkey" FOREIGN KEY ("referral_id") REFERENCES "referrals"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ambassador_referrals" ADD CONSTRAINT "ambassador_referrals_ambassador_user_id_fkey" FOREIGN KEY ("ambassador_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ambassador_referrals" ADD CONSTRAINT "ambassador_referrals_invitee_user_id_fkey" FOREIGN KEY ("invitee_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- 5. The commissions (one per qualifying top-up).
CREATE TABLE "ambassador_commissions" (
    "id" UUID NOT NULL,
    "ambassador_user_id" UUID NOT NULL,
    "invitee_user_id" UUID NOT NULL,
    "referral_id" UUID NOT NULL,
    "recharge_reason" VARCHAR(24) NOT NULL,
    "recharge_reference" VARCHAR(64) NOT NULL,
    "coins" BIGINT NOT NULL,
    "level" VARCHAR(16) NOT NULL,
    "rate_bps" INTEGER NOT NULL,
    "cherries" BIGINT NOT NULL,
    "capped_cherries" BIGINT NOT NULL DEFAULT 0,
    "month" CHAR(7) NOT NULL,
    "status" "ambassador_commission_status" NOT NULL DEFAULT 'PENDING',
    "hold_until" TIMESTAMPTZ(3) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "credited_at" TIMESTAMPTZ(3),
    "voided_at" TIMESTAMPTZ(3),
    "void_reason" VARCHAR(32),
    "reversed_at" TIMESTAMPTZ(3),
    "reversal_shortfall" BIGINT,

    CONSTRAINT "ambassador_commissions_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "ambassador_commissions_shape" CHECK (
        "coins" > 0 AND "cherries" >= 0 AND "capped_cherries" >= 0
        AND "rate_bps" BETWEEN 0 AND 5000
        AND "recharge_reason" IN ('CARD_TOPUP', 'RECHARGE_PURCHASE', 'RECHARGE_ORDER', 'STORE_IAP')
        AND ("status" = 'CREDITED') = ("credited_at" IS NOT NULL AND "reversed_at" IS NULL)
        AND ("status" = 'VOID') = ("voided_at" IS NOT NULL AND "void_reason" IS NOT NULL)
        AND ("status" = 'REVERSED') = ("reversed_at" IS NOT NULL)
        AND ("status" <> 'CREDITED' OR "cherries" > 0))
);
CREATE UNIQUE INDEX "ambassador_commissions_recharge_key" ON "ambassador_commissions"("recharge_reason", "recharge_reference");
CREATE INDEX "ambassador_commissions_ambassador_idx" ON "ambassador_commissions"("ambassador_user_id", "created_at" DESC);
CREATE INDEX "ambassador_commissions_month_idx" ON "ambassador_commissions"("ambassador_user_id", "month");
CREATE INDEX "ambassador_commissions_due_idx" ON "ambassador_commissions"("hold_until") WHERE ("status" = 'PENDING'::ambassador_commission_status);
ALTER TABLE "ambassador_commissions" ADD CONSTRAINT "ambassador_commissions_ambassador_user_id_fkey" FOREIGN KEY ("ambassador_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ambassador_commissions" ADD CONSTRAINT "ambassador_commissions_invitee_user_id_fkey" FOREIGN KEY ("invitee_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ambassador_commissions" ADD CONSTRAINT "ambassador_commissions_referral_id_fkey" FOREIGN KEY ("referral_id") REFERENCES "ambassador_referrals"("referral_id") ON DELETE CASCADE ON UPDATE CASCADE;

-- 6. The monthly evaluation.
CREATE TABLE "ambassador_months" (
    "ambassador_user_id" UUID NOT NULL,
    "month" CHAR(7) NOT NULL,
    "active_referrals" INTEGER NOT NULL,
    "topup_coins" BIGINT NOT NULL,
    "commission_cherries" BIGINT NOT NULL,
    "level_before" VARCHAR(16) NOT NULL,
    "level_after" VARCHAR(16) NOT NULL,
    "met_level" VARCHAR(16),
    "reward" JSONB,
    "reward_status" VARCHAR(8) NOT NULL,
    "evaluated_at" TIMESTAMPTZ(3) NOT NULL,
    "granted_at" TIMESTAMPTZ(3),

    CONSTRAINT "ambassador_months_pkey" PRIMARY KEY ("ambassador_user_id", "month"),
    CONSTRAINT "ambassador_months_shape" CHECK (
        "month" ~ '^[0-9]{4}-[0-9]{2}$'
        AND "active_referrals" >= 0 AND "topup_coins" >= 0 AND "commission_cherries" >= 0
        AND "reward_status" IN ('NONE', 'GRANTED', 'HELD')
        AND ("reward_status" = 'GRANTED') = ("granted_at" IS NOT NULL)
        AND ("reward_status" = 'NONE') = ("reward" IS NULL))
);
ALTER TABLE "ambassador_months" ADD CONSTRAINT "ambassador_months_ambassador_user_id_fkey" FOREIGN KEY ("ambassador_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- 7. The review signals.
CREATE TABLE "ambassador_flags" (
    "id" UUID NOT NULL,
    "ambassador_user_id" UUID NOT NULL,
    "kind" VARCHAR(16) NOT NULL,
    "detail" JSONB NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "cleared_at" TIMESTAMPTZ(3),
    "cleared_by_id" UUID,

    CONSTRAINT "ambassador_flags_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "ambassador_flags_kind" CHECK ("kind" IN ('VELOCITY', 'IP_CLUSTER', 'SELF_PAYMENT'))
);
CREATE INDEX "ambassador_flags_ambassador_idx" ON "ambassador_flags"("ambassador_user_id", "created_at" DESC);
ALTER TABLE "ambassador_flags" ADD CONSTRAINT "ambassador_flags_ambassador_user_id_fkey" FOREIGN KEY ("ambassador_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ambassador_flags" ADD CONSTRAINT "ambassador_flags_cleared_by_id_fkey" FOREIGN KEY ("cleared_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- 8. Campaigns and events.
CREATE TABLE "ambassador_campaigns" (
    "id" UUID NOT NULL,
    "title" VARCHAR(120) NOT NULL,
    "country" CHAR(2),
    "starts_on" DATE NOT NULL,
    "ends_on" DATE NOT NULL,
    "notes" VARCHAR(2000) NOT NULL DEFAULT '',
    "created_by_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ambassador_campaigns_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "ambassador_campaigns_shape" CHECK (
        char_length(btrim("title")) BETWEEN 1 AND 120
        AND "ends_on" >= "starts_on"
        AND ("country" IS NULL OR "country" ~ '^[A-Z]{2}$'))
);
CREATE INDEX "ambassador_campaigns_dates_idx" ON "ambassador_campaigns"("starts_on" DESC);
ALTER TABLE "ambassador_campaigns" ADD CONSTRAINT "ambassador_campaigns_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "ambassador_campaign_members" (
    "campaign_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,

    CONSTRAINT "ambassador_campaign_members_pkey" PRIMARY KEY ("campaign_id", "user_id")
);
ALTER TABLE "ambassador_campaign_members" ADD CONSTRAINT "ambassador_campaign_members_campaign_id_fkey" FOREIGN KEY ("campaign_id") REFERENCES "ambassador_campaigns"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ambassador_campaign_members" ADD CONSTRAINT "ambassador_campaign_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- 9. The ledgers' sign rules (extended in place, read from the catalogue, as 20270319090100 / 20270501090100).
DO $$
DECLARE
  def text;
BEGIN
  SELECT pg_get_constraintdef(c.oid) INTO STRICT def
    FROM pg_constraint c
   WHERE c.conrelid = 'cherry_ledger'::regclass AND c.conname = 'cherry_ledger_reason_sign';
  ALTER TABLE "cherry_ledger" DROP CONSTRAINT "cherry_ledger_reason_sign";
  EXECUTE format('ALTER TABLE cherry_ledger ADD CONSTRAINT cherry_ledger_reason_sign CHECK ((%s) OR (reason::text = %L AND delta > 0) OR (reason::text = %L AND delta < 0))',
                 substring(def FROM '^CHECK \((.*)\)$'), 'AMBASSADOR_COMMISSION', 'AMBASSADOR_COMMISSION_REVERSAL');
  SELECT pg_get_constraintdef(c.oid) INTO STRICT def
    FROM pg_constraint c
   WHERE c.conrelid = 'wallet_ledger'::regclass AND c.conname = 'wallet_ledger_reason_sign';
  ALTER TABLE "wallet_ledger" DROP CONSTRAINT "wallet_ledger_reason_sign";
  EXECUTE format('ALTER TABLE wallet_ledger ADD CONSTRAINT wallet_ledger_reason_sign CHECK ((%s) OR (reason::text = %L AND delta > 0))',
                 substring(def FROM '^CHECK \((.*)\)$'), 'AMBASSADOR_REWARD');
END
$$;
