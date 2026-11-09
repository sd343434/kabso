-- v1.110-social (D345, CONVENTIONS §10.144): coins from the stores «الشراء من المتجر». The catalogue (store product id →
-- coins), the verified purchases (one per store transaction), the store notifications applied once, Apple's consumption
-- requests, the automatic bans of refunded purchases and the one-row settings. A banned device remembers the refunded
-- purchase (lifted by the OWNER only). No GRANT: the runtime role gets DML through the default privileges
-- (20261016120000_runtime_role_grants).

CREATE TYPE "iap_platform" AS ENUM ('GOOGLE_PLAY', 'APP_STORE');
CREATE TYPE "iap_environment" AS ENUM ('PRODUCTION', 'SANDBOX');
CREATE TYPE "iap_purchase_status" AS ENUM ('CREDITED', 'REJECTED', 'REFUNDED');
CREATE TYPE "iap_consumption_status" AS ENUM ('PENDING', 'SENT', 'SKIPPED_NO_CONSENT', 'SKIPPED_UNKNOWN', 'FAILED');

CREATE TABLE "iap_products" (
    "id" UUID NOT NULL,
    "platform" "iap_platform" NOT NULL,
    "product_id" VARCHAR(150) NOT NULL,
    "coins" BIGINT NOT NULL,
    "reference_usd_cents" INTEGER,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "created_by_id" UUID,
    "updated_by_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "iap_products_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "iap_products_shape" CHECK (
        "product_id" ~ '^[A-Za-z0-9._]{1,150}$'
        AND "coins" BETWEEN 1 AND 1000000000000
        AND ("reference_usd_cents" IS NULL OR "reference_usd_cents" BETWEEN 1 AND 100000000)
        AND "sort_order" BETWEEN -100000 AND 100000)
);
CREATE UNIQUE INDEX "iap_products_platform_product_key" ON "iap_products" ("platform", "product_id");

CREATE TABLE "iap_purchases" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "platform" "iap_platform" NOT NULL,
    "store_product_id" UUID NOT NULL,
    "product_id" VARCHAR(150) NOT NULL,
    "coins" BIGINT NOT NULL,
    "transaction_id" VARCHAR(200) NOT NULL,
    "original_transaction_id" VARCHAR(200),
    "purchase_token" TEXT,
    "purchase_token_hash" CHAR(64),
    "environment" "iap_environment" NOT NULL,
    "status" "iap_purchase_status" NOT NULL,
    "reject_reason" VARCHAR(32),
    "device_hash" CHAR(64),
    "price_milli" BIGINT,
    "currency" CHAR(3),
    "purchased_at" TIMESTAMPTZ(3) NOT NULL,
    "credited_at" TIMESTAMPTZ(3),
    "consumed_at" TIMESTAMPTZ(3),
    "consent_version" VARCHAR(32) NOT NULL,
    "consent_at" TIMESTAMPTZ(3) NOT NULL,
    "consent_share_data" BOOLEAN NOT NULL,
    "consent_locale" VARCHAR(8),
    "refunded_at" TIMESTAMPTZ(3),
    "refund_source" VARCHAR(32),
    "refund_reason" VARCHAR(500),
    "refund_detail" JSONB,
    "coins_reversed" BIGINT NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "iap_purchases_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "iap_purchases_shape" CHECK (
        "coins" > 0
        AND "coins_reversed" BETWEEN 0 AND "coins"
        AND ("status" = 'CREDITED') = ("credited_at" IS NOT NULL AND "refunded_at" IS NULL)
        AND ("status" = 'REFUNDED') = ("refunded_at" IS NOT NULL)
        AND ("status" <> 'REJECTED' OR ("reject_reason" IS NOT NULL AND "credited_at" IS NULL))
        AND ("platform" <> 'GOOGLE_PLAY' OR ("purchase_token" IS NOT NULL AND "purchase_token_hash" IS NOT NULL)))
);
CREATE UNIQUE INDEX "iap_purchases_transaction_key" ON "iap_purchases" ("platform", "transaction_id");
CREATE UNIQUE INDEX "iap_purchases_token_key" ON "iap_purchases" ("platform", "purchase_token_hash");
CREATE INDEX "iap_purchases_user_idx" ON "iap_purchases" ("user_id", "created_at" DESC);
CREATE INDEX "iap_purchases_device_idx" ON "iap_purchases" ("device_hash") WHERE device_hash IS NOT NULL;
CREATE INDEX "iap_purchases_created_idx" ON "iap_purchases" ("created_at" DESC);
CREATE INDEX "iap_purchases_unconsumed_idx" ON "iap_purchases" ("platform", "consumed_at")
    WHERE consumed_at IS NULL AND status = 'CREDITED';
ALTER TABLE "iap_purchases" ADD CONSTRAINT "iap_purchases_user_id_fkey" FOREIGN KEY ("user_id")
    REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "iap_purchases" ADD CONSTRAINT "iap_purchases_store_product_id_fkey" FOREIGN KEY ("store_product_id")
    REFERENCES "iap_products" ("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "iap_notifications" (
    "id" UUID NOT NULL,
    "platform" "iap_platform" NOT NULL,
    "notification_id" VARCHAR(200) NOT NULL,
    "type" VARCHAR(64) NOT NULL,
    "subtype" VARCHAR(64),
    "transaction_id" VARCHAR(200),
    "outcome" VARCHAR(64) NOT NULL,
    "received_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "iap_notifications_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "iap_notifications_once" ON "iap_notifications" ("platform", "notification_id");
CREATE INDEX "iap_notifications_received_idx" ON "iap_notifications" ("received_at" DESC);

CREATE TABLE "iap_consumption_requests" (
    "id" UUID NOT NULL,
    "notification_id" VARCHAR(200) NOT NULL,
    "purchase_id" UUID,
    "transaction_id" VARCHAR(200) NOT NULL,
    "status" "iap_consumption_status" NOT NULL,
    "payload" JSONB,
    "context" JSONB,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "last_error" VARCHAR(300),
    "received_at" TIMESTAMPTZ(3) NOT NULL,
    "deadline_at" TIMESTAMPTZ(3) NOT NULL,
    "sent_at" TIMESTAMPTZ(3),
    CONSTRAINT "iap_consumption_requests_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "iap_consumption_requests_notification_key" ON "iap_consumption_requests" ("notification_id");
CREATE INDEX "iap_consumption_requests_pending_idx" ON "iap_consumption_requests" ("status", "deadline_at")
    WHERE status = 'PENDING';
ALTER TABLE "iap_consumption_requests" ADD CONSTRAINT "iap_consumption_requests_purchase_id_fkey"
    FOREIGN KEY ("purchase_id") REFERENCES "iap_purchases" ("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "iap_refund_bans" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "purchase_id" UUID NOT NULL,
    "reason" VARCHAR(500) NOT NULL,
    "account_banned" BOOLEAN NOT NULL,
    "devices_banned" INTEGER NOT NULL DEFAULT 0,
    "account_lifted_at" TIMESTAMPTZ(3),
    "account_lifted_by" UUID,
    "account_lift_reason" VARCHAR(500),
    "device_lifted_at" TIMESTAMPTZ(3),
    "device_lifted_by" UUID,
    "device_lift_reason" VARCHAR(500),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "iap_refund_bans_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "iap_refund_bans_purchase_key" ON "iap_refund_bans" ("purchase_id");
CREATE INDEX "iap_refund_bans_user_idx" ON "iap_refund_bans" ("user_id");
CREATE INDEX "iap_refund_bans_created_idx" ON "iap_refund_bans" ("created_at" DESC);
ALTER TABLE "iap_refund_bans" ADD CONSTRAINT "iap_refund_bans_user_id_fkey" FOREIGN KEY ("user_id")
    REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "iap_refund_bans" ADD CONSTRAINT "iap_refund_bans_purchase_id_fkey" FOREIGN KEY ("purchase_id")
    REFERENCES "iap_purchases" ("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "iap_settings" (
    "id" INTEGER NOT NULL DEFAULT 1,
    "once_per_account_device" BOOLEAN NOT NULL DEFAULT false,
    "updated_by_id" UUID,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "voided_polled_until" TIMESTAMPTZ(3),
    "voided_last_run_at" TIMESTAMPTZ(3),
    "voided_last_error" VARCHAR(300),
    CONSTRAINT "iap_settings_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "iap_settings_one_row" CHECK ("id" = 1)
);
INSERT INTO "iap_settings" ("id") VALUES (1) ON CONFLICT ("id") DO NOTHING;

-- A device banned because of a refunded store purchase (lifted by the OWNER only, §10.144.4).
ALTER TABLE "device_bans" ADD COLUMN "iap_purchase_id" UUID;
ALTER TABLE "device_bans" ADD CONSTRAINT "device_bans_iap_purchase_id_fkey" FOREIGN KEY ("iap_purchase_id")
    REFERENCES "iap_purchases" ("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- The ledger's sign rule: STORE_IAP is a credit, STORE_IAP_REVERSAL a debit. Extended in place (read from the
-- catalogue, not restated), as 20270408090200_custom_gifts did.
DO $$
DECLARE
  def text;
BEGIN
  SELECT pg_get_constraintdef(c.oid) INTO STRICT def
    FROM pg_constraint c
   WHERE c.conrelid = 'wallet_ledger'::regclass AND c.conname = 'wallet_ledger_reason_sign';
  ALTER TABLE "wallet_ledger" DROP CONSTRAINT "wallet_ledger_reason_sign";
  EXECUTE format('ALTER TABLE wallet_ledger ADD CONSTRAINT wallet_ledger_reason_sign CHECK ((%s) OR (reason::text = %L AND delta > 0) OR (reason::text = %L AND delta < 0))',
                 substring(def FROM '^CHECK \((.*)\)$'), 'STORE_IAP', 'STORE_IAP_REVERSAL');
END
$$;
