-- v1.134-social (D381, owner 2026-11-11: VIP perks phase 2 — gifts, CP, support, rockets, voice), CONVENTIONS §10.171.
--
-- 1. Wallet ledger reasons VIP_SCHEDULED_GIFT (a scheduled gift's coins held, a debit) and VIP_SCHEDULED_GIFT_RELEASE
--    (given back on delivery, cancellation or failure, a credit); the sign rule extended in place.
-- 2. `cp_requests.cost` may be 0: a FREE_CP_REQUEST holder's free request (nothing charged, nothing refunded).
-- 3. A voice clip (LIVE_CHAT_VOICE, DM_VOICE) may last up to 600 s: LONGER_VOICE holders (the API checks the member's
--    own limit; everyone else keeps 30 s).
-- 4. `reports.priority` (0 · 1 PRIORITY_SUPPORT · 2 safety reason), back-filled for the open queue's order.
-- 5. `wa_conversations.priority` (the linked account holds PRIORITY_SUPPORT).
-- 6. `vip_rocket_grants`: MONTHLY_ROCKETS, one grant per member and month.
-- 7. `vip_scheduled_gifts`: SCHEDULED_GIFT «هدية مؤجلة».
--
-- New tables get their runtime grants from the default privileges (KL-013, migration 20261016130000).
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

-- 1. The ledger reasons and their sign (read from the catalogue, not restated, as 20270417090100_store_iap did).
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'VIP_SCHEDULED_GIFT';
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'VIP_SCHEDULED_GIFT_RELEASE';
DO $$
DECLARE
  def text;
BEGIN
  SELECT pg_get_constraintdef(c.oid) INTO STRICT def
    FROM pg_constraint c
   WHERE c.conrelid = 'wallet_ledger'::regclass AND c.conname = 'wallet_ledger_reason_sign';
  ALTER TABLE "wallet_ledger" DROP CONSTRAINT "wallet_ledger_reason_sign";
  EXECUTE format('ALTER TABLE wallet_ledger ADD CONSTRAINT wallet_ledger_reason_sign CHECK ((%s) OR (reason::text = %L AND delta > 0) OR (reason::text = %L AND delta < 0))',
                 substring(def FROM '^CHECK \((.*)\)$'), 'VIP_SCHEDULED_GIFT_RELEASE', 'VIP_SCHEDULED_GIFT');
END
$$;

-- 2. A free CP request costs 0.
ALTER TABLE "cp_requests" DROP CONSTRAINT "cp_requests_cost_positive";
ALTER TABLE "cp_requests" ADD CONSTRAINT "cp_requests_cost_nonnegative" CHECK (cost >= 0);

-- 3. Voice clips up to 600 s (LONGER_VOICE's largest value); the rest of the rule as 20270406090000 left it.
ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_duration_shape";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_duration_shape" CHECK (
  (kind IN ('LIVE_CHAT_VOICE', 'DM_VOICE') AND duration_ms BETWEEN 1 AND 600000)
  OR (kind IN ('REEL_VIDEO', 'PROFILE_COVER_VIDEO') AND duration_ms BETWEEN 1 AND 60000)
  OR (kind = 'POST_VIDEO' AND duration_ms BETWEEN 1 AND 180000)
  OR (kind = 'LEVEL_RAISE_VIDEO' AND duration_ms BETWEEN 1 AND 90000)
  OR (kind = 'BANNER_VIDEO' AND duration_ms BETWEEN 1 AND 30000)
  OR (kind = 'HOME_BANNER' AND (duration_ms IS NULL OR duration_ms BETWEEN 1 AND 10000))
  OR (kind NOT IN ('LIVE_CHAT_VOICE', 'DM_VOICE', 'REEL_VIDEO', 'POST_VIDEO', 'LEVEL_RAISE_VIDEO', 'PROFILE_COVER_VIDEO',
                   'BANNER_VIDEO', 'HOME_BANNER')
      AND duration_ms IS NULL));

-- 4. The reports' priority; the safety reasons of every existing report (from anyone) first.
ALTER TABLE "reports" ADD COLUMN "priority" SMALLINT NOT NULL DEFAULT 0;
ALTER TABLE "reports" ADD CONSTRAINT "reports_priority_range" CHECK ("priority" BETWEEN 0 AND 2);
UPDATE "reports" SET "priority" = 2 WHERE "reason" IN ('NUDITY', 'VIOLENCE', 'ILLEGAL');
CREATE INDEX "reports_status_priority_idx" ON "reports"("status", "priority" DESC, "created_at", "id");

-- 5. The WhatsApp inbox's priority.
ALTER TABLE "wa_conversations" ADD COLUMN "priority" BOOLEAN NOT NULL DEFAULT false;

-- 6. MONTHLY_ROCKETS' grants.
CREATE TABLE "vip_rocket_grants" (
    "user_id" UUID NOT NULL,
    "month" DATE NOT NULL,
    "tier_id" UUID,
    "stage" SMALLINT NOT NULL,
    "minutes" INTEGER NOT NULL,
    "count" INTEGER NOT NULL,
    "granted_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "vip_rocket_grants_pkey" PRIMARY KEY ("user_id", "month"),
    CONSTRAINT "vip_rocket_grants_shape" CHECK (
      "stage" BETWEEN 1 AND 4 AND "minutes" > 0 AND "count" BETWEEN 1 AND 30
      AND "month" = date_trunc('month', "month")::date)
);
ALTER TABLE "vip_rocket_grants" ADD CONSTRAINT "vip_rocket_grants_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- 7. Scheduled gifts.
CREATE TYPE "vip_scheduled_gift_status" AS ENUM ('PENDING', 'DELIVERED', 'CANCELLED', 'FAILED');
CREATE TABLE "vip_scheduled_gifts" (
    "id" UUID NOT NULL,
    "sender_id" UUID NOT NULL,
    "recipient_id" UUID,
    "client_id" UUID NOT NULL,
    "gift_code" VARCHAR(40) NOT NULL,
    "quantity" INTEGER NOT NULL,
    "unit_price" INTEGER NOT NULL,
    "coins_held" BIGINT NOT NULL,
    "deliver_at" TIMESTAMPTZ(3) NOT NULL,
    "status" "vip_scheduled_gift_status" NOT NULL DEFAULT 'PENDING',
    "failure" VARCHAR(64),
    "dm_message_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "handled_at" TIMESTAMPTZ(3),

    CONSTRAINT "vip_scheduled_gifts_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "vip_scheduled_gifts_shape" CHECK (
      "quantity" > 0 AND "unit_price" > 0 AND "coins_held" = "unit_price"::bigint * "quantity"
      AND "sender_id" <> "recipient_id"),
    CONSTRAINT "vip_scheduled_gifts_handled" CHECK (("status" = 'PENDING') = ("handled_at" IS NULL)),
    CONSTRAINT "vip_scheduled_gifts_outcome" CHECK (
      ("status" = 'FAILED') = ("failure" IS NOT NULL) AND ("dm_message_id" IS NULL OR "status" = 'DELIVERED'))
);
CREATE UNIQUE INDEX "vip_scheduled_gifts_client_once" ON "vip_scheduled_gifts"("sender_id", "client_id");
CREATE INDEX "vip_scheduled_gifts_due_idx" ON "vip_scheduled_gifts"("deliver_at") WHERE status = 'PENDING'::vip_scheduled_gift_status;
CREATE INDEX "vip_scheduled_gifts_sender_idx" ON "vip_scheduled_gifts"("sender_id", "created_at" DESC);
CREATE INDEX "vip_scheduled_gifts_recipient_idx" ON "vip_scheduled_gifts"("recipient_id");
ALTER TABLE "vip_scheduled_gifts" ADD CONSTRAINT "vip_scheduled_gifts_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "vip_scheduled_gifts" ADD CONSTRAINT "vip_scheduled_gifts_recipient_id_fkey" FOREIGN KEY ("recipient_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
