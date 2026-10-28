-- v1.28-live (D146, owner 2026-10-27): premium usernames (يوزر مميز) — monthly rental with coins,
-- admin grants, expiry with a 7-day grace period — and the stored username shape widened to 1–30
-- characters (1–2 character premium names). CONVENTIONS §6, §10.32. No GRANT (default privileges,
-- 20261016130000_per_database_runtime_group).

-- The stored username shape: 1–30 (was 3–30; the pattern already allowed 1). Existing names keep
-- passing; the stricter rule for new regular names is checked by the API (D146).
ALTER TABLE "user_profiles" DROP CONSTRAINT "user_profiles_username_format";
ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_username_format"
    CHECK ("username" ~ '^[a-z0-9](?:[a-z0-9._]{0,28}[a-z0-9])?$');

-- CreateEnum
CREATE TYPE "premium_username_tier" AS ENUM ('LEGEND', 'RUBY', 'GOLD', 'SILVER');
CREATE TYPE "premium_username_lease_status" AS ENUM ('ACTIVE', 'GRACE', 'ENDED');
CREATE TYPE "premium_username_source" AS ENUM ('RENT', 'GRANT');

-- AlterTable: the badge of the username shown now (set only while it is the user's premium name).
ALTER TABLE "user_profiles" ADD COLUMN "premium_tier" "premium_username_tier";

-- CreateTable
CREATE TABLE "premium_username_leases" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "username" VARCHAR(30) NOT NULL,
    "tier" "premium_username_tier" NOT NULL,
    "source" "premium_username_source" NOT NULL,
    "status" "premium_username_lease_status" NOT NULL DEFAULT 'ACTIVE',
    "regular_username" VARCHAR(30) NOT NULL,
    "started_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ(3),
    "grace_until" TIMESTAMPTZ(3),
    "reminded_days" INTEGER,
    "ended_at" TIMESTAMPTZ(3),
    "end_reason" VARCHAR(20),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "premium_username_leases_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "premium_username_payments" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "lease_id" UUID NOT NULL,
    "kind" VARCHAR(10) NOT NULL,
    "username" VARCHAR(30) NOT NULL,
    "price_coins" BIGINT NOT NULL,
    "period_days" INTEGER NOT NULL,
    "coins_after" BIGINT NOT NULL,
    "idempotency_key" UUID,
    "request_hash" CHAR(64),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "premium_username_payments_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "premium_username_tier_prices" (
    "tier" "premium_username_tier" NOT NULL,
    "monthly_coins" BIGINT NOT NULL,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "premium_username_tier_prices_pkey" PRIMARY KEY ("tier")
);

CREATE TABLE "premium_username_name_prices" (
    "username" VARCHAR(30) NOT NULL,
    "monthly_coins" BIGINT NOT NULL,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "premium_username_name_prices_pkey" PRIMARY KEY ("username")
);

CREATE TABLE "premium_username_reserved" (
    "name" VARCHAR(30) NOT NULL,
    "reason" VARCHAR(200),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "premium_username_reserved_pkey" PRIMARY KEY ("name")
);

-- AlterTable: the lease an EXPIRING / EXPIRED notification is about (deleted with it).
ALTER TABLE "notifications" ADD COLUMN "premium_lease_id" UUID;

-- CreateIndex
CREATE UNIQUE INDEX "premium_username_leases_one_holder" ON "premium_username_leases"("username") WHERE status = ANY (ARRAY['ACTIVE'::premium_username_lease_status, 'GRACE'::premium_username_lease_status]);
CREATE UNIQUE INDEX "premium_username_leases_one_active" ON "premium_username_leases"("user_id") WHERE status = 'ACTIVE'::premium_username_lease_status;
CREATE UNIQUE INDEX "premium_username_leases_regular_held" ON "premium_username_leases"("regular_username") WHERE status = 'ACTIVE'::premium_username_lease_status;
CREATE INDEX "premium_username_leases_due_idx" ON "premium_username_leases"("status", "expires_at");
CREATE INDEX "premium_username_leases_user_idx" ON "premium_username_leases"("user_id", "created_at" DESC);
CREATE UNIQUE INDEX "premium_username_payments_idempotency" ON "premium_username_payments"("user_id", "idempotency_key");
CREATE INDEX "notifications_premium_lease_idx" ON "notifications"("premium_lease_id") WHERE premium_lease_id IS NOT NULL;

-- AddForeignKey
ALTER TABLE "premium_username_leases" ADD CONSTRAINT "premium_username_leases_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "premium_username_payments" ADD CONSTRAINT "premium_username_payments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "premium_username_payments" ADD CONSTRAINT "premium_username_payments_lease_id_fkey" FOREIGN KEY ("lease_id") REFERENCES "premium_username_leases"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_premium_lease_id_fkey" FOREIGN KEY ("premium_lease_id") REFERENCES "premium_username_leases"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CHECKs: names of the premium shape (letters and digits, 1–30); prices positive and exact as JSON
-- numbers (§3); a GRACE lease has its end of grace; a payment is RENT or RENEW.
ALTER TABLE "premium_username_leases" ADD CONSTRAINT "premium_username_leases_format" CHECK (username ~ '^[a-z0-9]{1,30}$');
ALTER TABLE "premium_username_leases" ADD CONSTRAINT "premium_username_leases_grace" CHECK (status <> 'GRACE'::premium_username_lease_status OR grace_until IS NOT NULL);
ALTER TABLE "premium_username_payments" ADD CONSTRAINT "premium_username_payments_kind" CHECK (kind IN ('RENT', 'RENEW'));
ALTER TABLE "premium_username_payments" ADD CONSTRAINT "premium_username_payments_price_positive" CHECK (price_coins > 0);
ALTER TABLE "premium_username_tier_prices" ADD CONSTRAINT "premium_username_tier_prices_range" CHECK (monthly_coins BETWEEN 1 AND 1000000000);
ALTER TABLE "premium_username_name_prices" ADD CONSTRAINT "premium_username_name_prices_range" CHECK (monthly_coins BETWEEN 1 AND 1000000000);
ALTER TABLE "premium_username_name_prices" ADD CONSTRAINT "premium_username_name_prices_format" CHECK (username ~ '^[a-z0-9]{1,30}$');

-- Wallet ledger: renting and renewing a premium username take coins (the sign CHECK of
-- 20261127100000_lucky_gifts, extended).
ALTER TABLE "wallet_ledger" DROP CONSTRAINT "wallet_ledger_reason_sign";
ALTER TABLE "wallet_ledger" ADD CONSTRAINT "wallet_ledger_reason_sign" CHECK (
  (reason IN ('ADMIN_GRANT', 'CP_REFUND', 'LUCKY_GIFT_WIN') AND delta > 0)
  OR (reason IN ('ADMIN_REVOKE', 'BULLET_MESSAGE', 'FAMILY_CREATE', 'CP_REQUEST', 'CP_GIFT', 'LIVE_GIFT', 'LUCKY_GIFT',
                 'PREMIUM_USERNAME_RENT', 'PREMIUM_USERNAME_RENEW') AND delta < 0));

-- The owner's starting reserved list (the code also reserves the v1.0 names and anything containing
-- "kabso"); offensive words are added on the server with `premium-admin reserve add`, not here.
INSERT INTO "premium_username_reserved" ("name", "reason") VALUES
    ('allah', 'religious'),
    ('god', 'religious'),
    ('police', 'authority'),
    ('government', 'authority'),
    ('gov', 'authority'),
    ('superadmin', 'staff'),
    ('sysadmin', 'staff'),
    ('ceo', 'staff'),
    ('founder', 'staff'),
    ('agency', 'staff'),
    ('service', 'staff'),
    ('customerservice', 'staff'),
    ('verified', 'impersonation'),
    ('premium', 'impersonation');
