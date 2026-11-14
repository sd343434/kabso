-- v1.54-social (D185, owner 2026-10-30): recharge agents «وكلاء الشحن» (CONVENTIONS §10.48, CP-028). Additive:
-- new types and tables, one nullable column on notifications, and the ledger sign rules extended. The runtime
-- role gets DML through the default privileges (20261016130000_per_database_runtime_group): no GRANT here.

CREATE TYPE "recharge_application_status" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');
CREATE TYPE "recharge_agent_status" AS ENUM ('APPROVED', 'ACTIVE', 'SUSPENDED');
CREATE TYPE "recharge_stock_reason" AS ENUM ('TOPUP', 'SALE', 'CHERRY_PURCHASE');
CREATE TYPE "recharge_cherry_request_status" AS ENUM ('PENDING', 'CONFIRMED', 'DECLINED', 'CANCELLED', 'EXPIRED');

-- An application «كن وكيل شحن». PRIVATE: read by admins only through `recharge-admin view` (audited). The two
-- pictures live under the private prefix `private/recharge-agents/<id>/`. `purged_at`: the retention step
-- deleted the pictures and the personal fields (they are then NULL); the status and dates stay.
CREATE TABLE "recharge_agent_applications" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "status" "recharge_application_status" NOT NULL DEFAULT 'PENDING',
    "full_name" VARCHAR(120),
    "phone" VARCHAR(16),
    "photo_key" VARCHAR(256),
    "selfie_key" VARCHAR(256),
    "locations" JSONB,
    "payment_methods" JSONB,
    "reject_reason" VARCHAR(500),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "decided_at" TIMESTAMPTZ(3),
    "purged_at" TIMESTAMPTZ(3),

    CONSTRAINT "recharge_agent_applications_pkey" PRIMARY KEY ("id")
);

-- One agent per user, from approval on. `code` / `code_number`: given at activation (the first top-up),
-- never changed. `stock_coins` ≥ 0. `daily_cherry_cap` NULL = RECHARGE_AGENT_CHERRY_DAILY_CAP. `availability`:
-- the weekly slots (JSON array) in `availability_time_zone`. `countries`: the application's countries (ISO,
-- upper case), copied at approval for the directory; `locations` / `payment_types` likewise (public parts).
CREATE TABLE "recharge_agents" (
    "user_id" UUID NOT NULL,
    "application_id" UUID NOT NULL,
    "status" "recharge_agent_status" NOT NULL DEFAULT 'APPROVED',
    "code" VARCHAR(16),
    "code_number" INTEGER,
    "stock_coins" BIGINT NOT NULL DEFAULT 0,
    "daily_cherry_cap" BIGINT,
    "countries" VARCHAR(2)[] NOT NULL,
    "locations" JSONB NOT NULL,
    "payment_types" JSONB NOT NULL,
    "availability" JSONB NOT NULL DEFAULT '[]',
    "availability_time_zone" VARCHAR(64) NOT NULL DEFAULT 'UTC',
    "suspend_reason" VARCHAR(500),
    "approved_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "activated_at" TIMESTAMPTZ(3),
    "suspended_at" TIMESTAMPTZ(3),
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "recharge_agents_pkey" PRIMARY KEY ("user_id")
);

-- The last code number given (one row). Updated in the activation's transaction: the row lock gives the numbers
-- in order, without gaps, never twice.
CREATE TABLE "recharge_agent_counter" (
    "id" SMALLINT NOT NULL,
    "last_number" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "recharge_agent_counter_pkey" PRIMARY KEY ("id")
);
INSERT INTO "recharge_agent_counter" ("id", "last_number") VALUES (1, 0);

-- Every change of an agent's stock (append-only), written with the stock in the same transaction.
CREATE TABLE "recharge_stock_ledger" (
    "id" UUID NOT NULL,
    "agent_user_id" UUID NOT NULL,
    "delta" BIGINT NOT NULL,
    "balance_after" BIGINT NOT NULL,
    "reason" "recharge_stock_reason" NOT NULL,
    "reference_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "recharge_stock_ledger_pkey" PRIMARY KEY ("id")
);

-- A wholesale top-up paid outside the app and recorded by an admin: the owner's price tier in force, the price
-- per 1 000 000 coins, the expected and the paid amount (minor units of `currency`).
CREATE TABLE "recharge_topups" (
    "id" UUID NOT NULL,
    "agent_user_id" UUID NOT NULL,
    "coins" BIGINT NOT NULL,
    "tier" VARCHAR(16) NOT NULL,
    "price_per_million_minor" INTEGER NOT NULL,
    "expected_minor" BIGINT NOT NULL,
    "paid_minor" BIGINT NOT NULL,
    "currency" CHAR(3) NOT NULL,
    "first" BOOLEAN NOT NULL,
    "note" VARCHAR(500),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "recharge_topups_pkey" PRIMARY KEY ("id")
);

-- A sale of coins from an agent's stock to a buyer, by the agent or an employee (`seller_user_id`).
-- `client_id`: the seller's Idempotency-Key.
CREATE TABLE "recharge_sales" (
    "id" UUID NOT NULL,
    "agent_user_id" UUID NOT NULL,
    "seller_user_id" UUID NOT NULL,
    "buyer_user_id" UUID NOT NULL,
    "client_id" UUID NOT NULL,
    "coins" BIGINT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "recharge_sales_pkey" PRIMARY KEY ("id")
);

-- An agent's employee: weekly `schedule` (JSON array of slots) in `time_zone`. One active employment per user.
CREATE TABLE "recharge_employees" (
    "id" UUID NOT NULL,
    "agent_user_id" UUID NOT NULL,
    "employee_user_id" UUID NOT NULL,
    "time_zone" VARCHAR(64) NOT NULL,
    "schedule" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "removed_at" TIMESTAMPTZ(3),

    CONSTRAINT "recharge_employees_pkey" PRIMARY KEY ("id")
);

-- A host's cherries sold to an agent (cash outside the app): created by one side, confirmed by the other.
-- The rate and the payout in force are stored with it. `client_id`: the creator's Idempotency-Key.
CREATE TABLE "recharge_cherry_requests" (
    "id" UUID NOT NULL,
    "agent_user_id" UUID NOT NULL,
    "host_user_id" UUID NOT NULL,
    "created_by" UUID NOT NULL,
    "client_id" UUID NOT NULL,
    "cherries" BIGINT NOT NULL,
    "coins" BIGINT NOT NULL,
    "payout_minor" BIGINT NOT NULL,
    "currency" CHAR(3) NOT NULL,
    "status" "recharge_cherry_request_status" NOT NULL DEFAULT 'PENDING',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "decided_at" TIMESTAMPTZ(3),

    CONSTRAINT "recharge_cherry_requests_pkey" PRIMARY KEY ("id")
);

-- The sale a RECHARGE_COINS_RECEIVED notification points at.
ALTER TABLE "notifications" ADD COLUMN "recharge_sale_id" UUID;

-- ---- Indexes, keys, rules -------------------------------------------------------------------------

CREATE INDEX "recharge_agent_applications_user_idx" ON "recharge_agent_applications"("user_id", "created_at" DESC);
CREATE UNIQUE INDEX "recharge_agent_applications_one_pending" ON "recharge_agent_applications"("user_id") WHERE status = 'PENDING';
CREATE INDEX "recharge_agent_applications_status_idx" ON "recharge_agent_applications"("status", "created_at");
CREATE UNIQUE INDEX "recharge_agents_code_key" ON "recharge_agents"("code");
CREATE UNIQUE INDEX "recharge_agents_code_number_key" ON "recharge_agents"("code_number");
CREATE UNIQUE INDEX "recharge_agents_application_key" ON "recharge_agents"("application_id");
CREATE INDEX "recharge_agents_countries_idx" ON "recharge_agents" USING GIN ("countries");
CREATE UNIQUE INDEX "recharge_stock_ledger_reference_once" ON "recharge_stock_ledger"("agent_user_id", "reason", "reference_id");
CREATE INDEX "recharge_stock_ledger_agent_created_idx" ON "recharge_stock_ledger"("agent_user_id", "created_at" DESC);
CREATE INDEX "recharge_topups_agent_idx" ON "recharge_topups"("agent_user_id", "created_at" DESC);
CREATE UNIQUE INDEX "recharge_sales_client_once" ON "recharge_sales"("seller_user_id", "client_id");
CREATE INDEX "recharge_sales_agent_created_idx" ON "recharge_sales"("agent_user_id", "created_at" DESC, "id" DESC);
CREATE INDEX "recharge_sales_seller_created_idx" ON "recharge_sales"("seller_user_id", "created_at" DESC, "id" DESC);
CREATE INDEX "recharge_sales_buyer_idx" ON "recharge_sales"("buyer_user_id");
CREATE UNIQUE INDEX "recharge_employees_one_active" ON "recharge_employees"("employee_user_id") WHERE removed_at IS NULL;
CREATE INDEX "recharge_employees_agent_idx" ON "recharge_employees"("agent_user_id", "created_at");
CREATE UNIQUE INDEX "recharge_cherry_requests_client_once" ON "recharge_cherry_requests"("created_by", "client_id");
CREATE INDEX "recharge_cherry_requests_agent_idx" ON "recharge_cherry_requests"("agent_user_id", "created_at" DESC, "id" DESC);
CREATE INDEX "recharge_cherry_requests_host_idx" ON "recharge_cherry_requests"("host_user_id", "created_at" DESC, "id" DESC);
CREATE INDEX "recharge_cherry_requests_pair_idx" ON "recharge_cherry_requests"("agent_user_id", "host_user_id", "status");
CREATE INDEX "notifications_recharge_sale_idx" ON "notifications"("recharge_sale_id") WHERE recharge_sale_id IS NOT NULL;

ALTER TABLE "recharge_agent_applications" ADD CONSTRAINT "recharge_agent_applications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "recharge_agents" ADD CONSTRAINT "recharge_agents_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "recharge_agents" ADD CONSTRAINT "recharge_agents_application_id_fkey" FOREIGN KEY ("application_id") REFERENCES "recharge_agent_applications"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "recharge_stock_ledger" ADD CONSTRAINT "recharge_stock_ledger_agent_user_id_fkey" FOREIGN KEY ("agent_user_id") REFERENCES "recharge_agents"("user_id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "recharge_topups" ADD CONSTRAINT "recharge_topups_agent_user_id_fkey" FOREIGN KEY ("agent_user_id") REFERENCES "recharge_agents"("user_id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "recharge_sales" ADD CONSTRAINT "recharge_sales_agent_user_id_fkey" FOREIGN KEY ("agent_user_id") REFERENCES "recharge_agents"("user_id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "recharge_sales" ADD CONSTRAINT "recharge_sales_seller_user_id_fkey" FOREIGN KEY ("seller_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "recharge_sales" ADD CONSTRAINT "recharge_sales_buyer_user_id_fkey" FOREIGN KEY ("buyer_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "recharge_employees" ADD CONSTRAINT "recharge_employees_agent_user_id_fkey" FOREIGN KEY ("agent_user_id") REFERENCES "recharge_agents"("user_id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "recharge_employees" ADD CONSTRAINT "recharge_employees_employee_user_id_fkey" FOREIGN KEY ("employee_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "recharge_cherry_requests" ADD CONSTRAINT "recharge_cherry_requests_agent_user_id_fkey" FOREIGN KEY ("agent_user_id") REFERENCES "recharge_agents"("user_id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "recharge_cherry_requests" ADD CONSTRAINT "recharge_cherry_requests_host_user_id_fkey" FOREIGN KEY ("host_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_recharge_sale_id_fkey" FOREIGN KEY ("recharge_sale_id") REFERENCES "recharge_sales"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "recharge_agent_applications" ADD CONSTRAINT "recharge_agent_applications_shape" CHECK (
  ((status = 'PENDING') = (decided_at IS NULL))
  AND (status = 'REJECTED' OR reject_reason IS NULL)
  AND (purged_at IS NOT NULL OR (full_name IS NOT NULL AND phone IS NOT NULL AND photo_key IS NOT NULL
       AND selfie_key IS NOT NULL AND locations IS NOT NULL AND payment_methods IS NOT NULL)));
ALTER TABLE "recharge_agents" ADD CONSTRAINT "recharge_agents_shape" CHECK (
  stock_coins BETWEEN 0 AND 9007199254740991
  AND (daily_cherry_cap IS NULL OR daily_cherry_cap >= 0)
  AND ((code IS NULL) = (code_number IS NULL)) AND ((code IS NULL) = (activated_at IS NULL))
  AND (code IS NULL OR code ~ '^coin[0-9]{4,}$')
  AND (status <> 'ACTIVE' OR code IS NOT NULL)
  AND ((status = 'SUSPENDED') = (suspended_at IS NOT NULL)));
ALTER TABLE "recharge_agent_counter" ADD CONSTRAINT "recharge_agent_counter_one" CHECK (id = 1 AND last_number >= 0);
ALTER TABLE "recharge_stock_ledger" ADD CONSTRAINT "recharge_stock_ledger_sign" CHECK (
  ((reason IN ('TOPUP', 'CHERRY_PURCHASE') AND delta > 0) OR (reason = 'SALE' AND delta < 0))
  AND balance_after BETWEEN 0 AND 9007199254740991);
ALTER TABLE "recharge_topups" ADD CONSTRAINT "recharge_topups_shape" CHECK (
  coins > 0 AND price_per_million_minor > 0 AND expected_minor >= 0 AND paid_minor >= 0);
ALTER TABLE "recharge_sales" ADD CONSTRAINT "recharge_sales_shape" CHECK (
  coins > 0 AND buyer_user_id <> seller_user_id AND buyer_user_id <> agent_user_id);
ALTER TABLE "recharge_employees" ADD CONSTRAINT "recharge_employees_shape" CHECK (employee_user_id <> agent_user_id);
ALTER TABLE "recharge_cherry_requests" ADD CONSTRAINT "recharge_cherry_requests_shape" CHECK (
  cherries > 0 AND coins >= 0 AND payout_minor >= 0 AND host_user_id <> agent_user_id
  AND created_by IN (host_user_id, agent_user_id)
  AND ((status = 'PENDING') = (decided_at IS NULL)));

-- RECHARGE_PURCHASE is a credit; RECHARGE_SALE (cherries) a debit (the rules of 20261214100000_me_programs and
-- 20261231110000_task_cherries, extended).
ALTER TABLE "wallet_ledger" DROP CONSTRAINT "wallet_ledger_reason_sign";
ALTER TABLE "wallet_ledger" ADD CONSTRAINT "wallet_ledger_reason_sign" CHECK (
  (reason IN ('ADMIN_GRANT', 'CP_REFUND', 'LUCKY_GIFT_WIN', 'LIVE_BOOST_REFUND', 'TASK_REWARD', 'CHECK_IN_REWARD',
              'EVENT_PRIZE', 'RECHARGE_PURCHASE') AND delta > 0)
  OR (reason IN ('ADMIN_REVOKE', 'BULLET_MESSAGE', 'FAMILY_CREATE', 'CP_REQUEST', 'CP_GIFT', 'LIVE_GIFT', 'LUCKY_GIFT',
                 'PREMIUM_USERNAME_RENT', 'PREMIUM_USERNAME_RENEW', 'LIVE_BOOST', 'DM_GIFT') AND delta < 0));
ALTER TABLE "cherry_ledger" DROP CONSTRAINT "cherry_ledger_reason_sign";
ALTER TABLE "cherry_ledger" ADD CONSTRAINT "cherry_ledger_reason_sign" CHECK (
  (reason IN ('GIFT_RECEIVED', 'AGENCY_COMMISSION', 'PARENT_COMMISSION', 'WITHDRAWAL_REFUND', 'TASK_REWARD')
      AND delta > 0)
  OR (reason IN ('GIFT_REVERSAL', 'AGENCY_COMMISSION_REVERSAL', 'PARENT_COMMISSION_REVERSAL', 'WITHDRAWAL_HOLD',
                 'RECHARGE_SALE') AND delta < 0));
