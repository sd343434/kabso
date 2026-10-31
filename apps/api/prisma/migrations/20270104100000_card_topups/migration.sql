-- v1.59-social (D190, owner 2026-10-31): card top-ups on the Kabso website through Stripe Checkout (CONVENTIONS
-- §10.53, CP-033). New types and tables; the coin balance may now go below 0 (a reversed purchase whose coins
-- were already spent: a debt), only through `CARD_TOPUP_REVERSAL`. The runtime role gets DML through the default
-- privileges (20261016130000_per_database_runtime_group): no GRANT here. Payment rows outlive a hard user
-- deletion attempt (ON DELETE RESTRICT): they are the money trail.

CREATE TYPE "topup_order_status" AS ENUM ('PENDING', 'AWAITING_FUNDS', 'PAID', 'EXPIRED', 'FAILED');
CREATE TYPE "topup_case_kind" AS ENUM ('REFUND', 'EARLY_FRAUD_WARNING', 'DISPUTE');
CREATE TYPE "topup_case_status" AS ENUM ('OPEN', 'CLOSED');

-- The buyer accepted «العملات رقمية وغير قابلة للاسترداد» (the statement and its version as shown, the time, the IP
-- and the user agent) BEFORE the Checkout session was created. One row per checkout attempt.
CREATE TABLE "topup_terms_acceptances" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "terms_version" VARCHAR(32) NOT NULL,
    "terms_text" VARCHAR(300) NOT NULL,
    "locale" VARCHAR(5) NOT NULL,
    "ip" VARCHAR(64),
    "user_agent" VARCHAR(512),
    "accepted_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "topup_terms_acceptances_pkey" PRIMARY KEY ("id")
);

-- One website purchase. The price is the server's (`amount_minor`, from the package); coins are credited once,
-- only by the webhook (`credited_at`). `refunded_minor` (cumulative, from Stripe), `fraud_warning_at`,
-- `dispute_*` describe what happened after; `coins_reversed` is how many of the coins are taken back now.
CREATE TABLE "topup_orders" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "terms_acceptance_id" UUID NOT NULL,
    "package_id" VARCHAR(32) NOT NULL,
    "coins" BIGINT NOT NULL,
    "amount_minor" INTEGER NOT NULL,
    "currency" CHAR(3) NOT NULL,
    "payment_method_types" VARCHAR(32)[] NOT NULL,
    "status" "topup_order_status" NOT NULL DEFAULT 'PENDING',
    "stripe_session_id" VARCHAR(255),
    "stripe_payment_intent_id" VARCHAR(255),
    "stripe_charge_id" VARCHAR(255),
    "payment_method_type" VARCHAR(32),
    "credited_at" TIMESTAMPTZ(3),
    "refunded_minor" INTEGER NOT NULL DEFAULT 0,
    "fraud_warning_at" TIMESTAMPTZ(3),
    "auto_refund_id" VARCHAR(255),
    "dispute_id" VARCHAR(255),
    "dispute_status" VARCHAR(32),
    "dispute_amount_minor" INTEGER NOT NULL DEFAULT 0,
    "evidence_submitted_at" TIMESTAMPTZ(3),
    "coins_reversed" BIGINT NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "topup_orders_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "topup_orders_coins_check" CHECK ("coins" > 0 AND "coins" <= 9007199254740991),
    CONSTRAINT "topup_orders_amount_check" CHECK ("amount_minor" > 0),
    CONSTRAINT "topup_orders_refunded_check" CHECK ("refunded_minor" BETWEEN 0 AND "amount_minor"),
    CONSTRAINT "topup_orders_dispute_amount_check" CHECK ("dispute_amount_minor" BETWEEN 0 AND "amount_minor"),
    CONSTRAINT "topup_orders_reversed_check" CHECK ("coins_reversed" BETWEEN 0 AND "coins")
);

-- A buyer frozen from card purchases after a refund, an early-fraud warning or a dispute (one row per user). Gifts
-- need a positive balance anyway. Lifted by `payments-admin unfreeze` or when a won dispute leaves nothing reversed.
CREATE TABLE "topup_freezes" (
    "user_id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "reason" "topup_case_kind" NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "topup_freezes_pkey" PRIMARY KEY ("user_id")
);

-- An admin case: the team decides about the host cherries (never clawed back automatically). `gifts`: the sends
-- funded by the purchase's coins (FIFO attribution), with recipients and cherries, for `economy-admin reverse-gift`.
CREATE TABLE "topup_cases" (
    "id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "kind" "topup_case_kind" NOT NULL,
    "stripe_object_id" VARCHAR(255) NOT NULL,
    "status" "topup_case_status" NOT NULL DEFAULT 'OPEN',
    "outcome" VARCHAR(32),
    "coins_reversed" BIGINT NOT NULL,
    "attribution" JSONB NOT NULL,
    "note" VARCHAR(500),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "closed_at" TIMESTAMPTZ(3),

    CONSTRAINT "topup_cases_pkey" PRIMARY KEY ("id")
);

-- Every Stripe event, once (the event id): a replayed or concurrent delivery changes nothing.
CREATE TABLE "stripe_events" (
    "id" VARCHAR(255) NOT NULL,
    "type" VARCHAR(100) NOT NULL,
    "order_id" UUID,
    "outcome" VARCHAR(32),
    "received_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "processed_at" TIMESTAMPTZ(3),

    CONSTRAINT "stripe_events_pkey" PRIMARY KEY ("id")
);

-- The buyer's Stripe customer (only for bank transfers: the customer's balance receives the transfer).
CREATE TABLE "stripe_customers" (
    "user_id" UUID NOT NULL,
    "customer_id" VARCHAR(255) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "stripe_customers_pkey" PRIMARY KEY ("user_id")
);

CREATE INDEX "topup_terms_acceptances_user_idx" ON "topup_terms_acceptances"("user_id", "accepted_at" DESC);
CREATE UNIQUE INDEX "topup_orders_terms_once" ON "topup_orders"("terms_acceptance_id");
CREATE UNIQUE INDEX "topup_orders_session_once" ON "topup_orders"("stripe_session_id");
CREATE UNIQUE INDEX "topup_orders_payment_intent_once" ON "topup_orders"("stripe_payment_intent_id");
CREATE INDEX "topup_orders_charge_idx" ON "topup_orders"("stripe_charge_id");
CREATE INDEX "topup_orders_user_created_idx" ON "topup_orders"("user_id", "created_at" DESC);
CREATE UNIQUE INDEX "topup_cases_object_once" ON "topup_cases"("kind", "stripe_object_id");
CREATE INDEX "topup_cases_status_idx" ON "topup_cases"("status", "created_at" DESC);
CREATE UNIQUE INDEX "stripe_customers_customer_once" ON "stripe_customers"("customer_id");

ALTER TABLE "topup_terms_acceptances" ADD CONSTRAINT "topup_terms_acceptances_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "topup_orders" ADD CONSTRAINT "topup_orders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "topup_orders" ADD CONSTRAINT "topup_orders_terms_acceptance_id_fkey" FOREIGN KEY ("terms_acceptance_id") REFERENCES "topup_terms_acceptances"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "topup_freezes" ADD CONSTRAINT "topup_freezes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "topup_freezes" ADD CONSTRAINT "topup_freezes_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "topup_orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "topup_cases" ADD CONSTRAINT "topup_cases_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "topup_orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "topup_cases" ADD CONSTRAINT "topup_cases_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "stripe_events" ADD CONSTRAINT "stripe_events_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "topup_orders"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "stripe_customers" ADD CONSTRAINT "stripe_customers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- A balance may go below 0 (a debt after a reversal); the ledger's sign rules gain the three reasons.
ALTER TABLE "wallets" DROP CONSTRAINT "wallets_coins_range";
ALTER TABLE "wallets" ADD CONSTRAINT "wallets_coins_range" CHECK (coins BETWEEN -9007199254740991 AND 9007199254740991);
ALTER TABLE "wallet_ledger" DROP CONSTRAINT "wallet_ledger_balance_range";
ALTER TABLE "wallet_ledger" ADD CONSTRAINT "wallet_ledger_balance_range"
  CHECK (balance_after BETWEEN -9007199254740991 AND 9007199254740991);
ALTER TABLE "wallet_ledger" DROP CONSTRAINT "wallet_ledger_reason_sign";
ALTER TABLE "wallet_ledger" ADD CONSTRAINT "wallet_ledger_reason_sign" CHECK (
  (reason IN ('ADMIN_GRANT', 'CP_REFUND', 'LUCKY_GIFT_WIN', 'LIVE_BOOST_REFUND', 'TASK_REWARD', 'CHECK_IN_REWARD',
              'EVENT_PRIZE', 'RECHARGE_PURCHASE', 'CARD_TOPUP', 'CARD_TOPUP_RESTORE') AND delta > 0)
  OR (reason IN ('ADMIN_REVOKE', 'BULLET_MESSAGE', 'FAMILY_CREATE', 'CP_REQUEST', 'CP_GIFT', 'LIVE_GIFT', 'LUCKY_GIFT',
                 'PREMIUM_USERNAME_RENT', 'PREMIUM_USERNAME_RENEW', 'LIVE_BOOST', 'DM_GIFT', 'CARD_TOPUP_REVERSAL')
      AND delta < 0));
