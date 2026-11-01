-- v1.69-social (D204, owner 2026-10-31): recharge orders with escrow «طلبات الشحن» (CONVENTIONS §10.64). Additive:
-- three types, three tables, two nullable columns on notifications, and the ledger sign rules extended. The runtime
-- role gets DML through the default privileges (20261016130000_per_database_runtime_group): no GRANT here.

CREATE TYPE "recharge_order_status" AS ENUM ('REQUESTED', 'AWAITING_PAYMENT', 'PAID', 'DISPUTED', 'COMPLETED',
  'COMPLETED_BY_ADMIN', 'REFUNDED_TO_AGENT', 'CANCELLED', 'EXPIRED');
CREATE TYPE "recharge_order_message_kind" AS ENUM ('TEXT', 'IMAGE', 'PAYMENT_DETAILS', 'TRANSFER_PROOF', 'SYSTEM');
CREATE TYPE "recharge_order_role" AS ENUM ('BUYER', 'AGENT', 'EMPLOYEE', 'ADMIN', 'SYSTEM');

-- The exchange rate of a country's currency set by OWNER / FINANCE (panel or `recharge-admin set-rate`, audited):
-- units of `currency` per 1 USD × 1 000 000, `digits` decimal places. No row: the country is priced in USD only.
CREATE TABLE "recharge_exchange_rates" (
    "country" CHAR(2) NOT NULL,
    "currency" CHAR(3) NOT NULL,
    "rate_micro" BIGINT NOT NULL,
    "digits" SMALLINT NOT NULL,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_by" UUID,

    CONSTRAINT "recharge_exchange_rates_pkey" PRIMARY KEY ("country")
);

-- A buyer's order to an agent. Prices are fixed at creation. `held_coins`: the coins frozen from the agent's stock
-- now (an ORDER_HOLD ledger row when the details are sent; given to the buyer, or back with ORDER_RELEASE).
-- `client_id`: the buyer's Idempotency-Key. `expires_at`: when REQUESTED / AWAITING_PAYMENT ends by itself.
CREATE TABLE "recharge_orders" (
    "id" UUID NOT NULL,
    "buyer_user_id" UUID NOT NULL,
    "agent_user_id" UUID NOT NULL,
    "client_id" UUID NOT NULL,
    "country" CHAR(2) NOT NULL,
    "coins" BIGINT NOT NULL,
    "usd_minor" BIGINT NOT NULL,
    "local_currency" CHAR(3),
    "local_rate_micro" BIGINT,
    "local_minor" BIGINT,
    "local_digits" SMALLINT,
    "payment_type" VARCHAR(16) NOT NULL,
    "status" "recharge_order_status" NOT NULL DEFAULT 'REQUESTED',
    "held_coins" BIGINT NOT NULL DEFAULT 0,
    "details_at" TIMESTAMPTZ(3),
    "notice_ack_at" TIMESTAMPTZ(3),
    "paid_at" TIMESTAMPTZ(3),
    "disputed_at" TIMESTAMPTZ(3),
    "disputed_by" "recharge_order_role",
    "closed_at" TIMESTAMPTZ(3),
    "closed_by" UUID,
    "close_reason" VARCHAR(500),
    "expires_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "recharge_orders_pkey" PRIMARY KEY ("id")
);

-- The order's chat (evidence: participants never edit or delete). `image_key`: a private object under
-- `private/recharge-orders/<order id>/`. `seq`: the chat's order (lines written in one transaction share the time).
CREATE TABLE "recharge_order_messages" (
    "id" UUID NOT NULL,
    "seq" BIGSERIAL NOT NULL,
    "order_id" UUID NOT NULL,
    "author_user_id" UUID,
    "role" "recharge_order_role" NOT NULL,
    "kind" "recharge_order_message_kind" NOT NULL,
    "text" VARCHAR(1000),
    "method" VARCHAR(16),
    "image_key" VARCHAR(256),
    "event" VARCHAR(24),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "recharge_order_messages_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "notifications" ADD COLUMN "recharge_order_id" UUID;
ALTER TABLE "notifications" ADD COLUMN "recharge_order_event" VARCHAR(24);

CREATE UNIQUE INDEX "recharge_orders_client_once" ON "recharge_orders"("buyer_user_id", "client_id");
CREATE UNIQUE INDEX "recharge_orders_one_open" ON "recharge_orders"("buyer_user_id", "agent_user_id")
  WHERE status IN ('REQUESTED', 'AWAITING_PAYMENT', 'PAID', 'DISPUTED');
CREATE INDEX "recharge_orders_buyer_idx" ON "recharge_orders"("buyer_user_id", "created_at" DESC, "id" DESC);
CREATE INDEX "recharge_orders_agent_idx" ON "recharge_orders"("agent_user_id", "created_at" DESC, "id" DESC);
CREATE INDEX "recharge_orders_status_idx" ON "recharge_orders"("status", "updated_at");
CREATE INDEX "recharge_orders_expiry_idx" ON "recharge_orders"("expires_at") WHERE expires_at IS NOT NULL;
CREATE UNIQUE INDEX "recharge_order_messages_seq_key" ON "recharge_order_messages"("seq");
CREATE INDEX "recharge_order_messages_order_idx" ON "recharge_order_messages"("order_id", "seq");
CREATE INDEX "notifications_recharge_order_idx" ON "notifications"("recipient_id", "recharge_order_id")
  WHERE recharge_order_id IS NOT NULL;

ALTER TABLE "recharge_orders" ADD CONSTRAINT "recharge_orders_buyer_user_id_fkey" FOREIGN KEY ("buyer_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "recharge_orders" ADD CONSTRAINT "recharge_orders_agent_user_id_fkey" FOREIGN KEY ("agent_user_id") REFERENCES "recharge_agents"("user_id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "recharge_order_messages" ADD CONSTRAINT "recharge_order_messages_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "recharge_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_recharge_order_id_fkey" FOREIGN KEY ("recharge_order_id") REFERENCES "recharge_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "recharge_exchange_rates" ADD CONSTRAINT "recharge_exchange_rates_shape" CHECK (
  country ~ '^[A-Z]{2}$' AND currency ~ '^[A-Z]{3}$' AND rate_micro > 0 AND digits BETWEEN 0 AND 3);
-- The money rules: the frozen coins are 0 or the order's coins, and only while the order holds them.
ALTER TABLE "recharge_orders" ADD CONSTRAINT "recharge_orders_shape" CHECK (
  coins > 0 AND coins <= 9007199254740991 AND usd_minor >= 0 AND buyer_user_id <> agent_user_id
  AND country ~ '^[A-Z]{2}$'
  AND ((local_currency IS NULL) = (local_minor IS NULL)) AND ((local_currency IS NULL) = (local_rate_micro IS NULL))
  AND ((local_currency IS NULL) = (local_digits IS NULL))
  AND (held_coins = 0 OR held_coins = coins)
  AND ((held_coins > 0) = (status IN ('AWAITING_PAYMENT', 'PAID', 'DISPUTED')))
  AND (status = 'REQUESTED' OR status IN ('CANCELLED', 'EXPIRED') OR details_at IS NOT NULL)
  AND (status NOT IN ('PAID', 'DISPUTED', 'COMPLETED', 'COMPLETED_BY_ADMIN', 'REFUNDED_TO_AGENT') OR paid_at IS NOT NULL)
  AND (status <> 'DISPUTED' OR disputed_at IS NOT NULL)
  AND (status NOT IN ('COMPLETED_BY_ADMIN', 'REFUNDED_TO_AGENT') OR disputed_at IS NOT NULL)
  AND ((closed_at IS NOT NULL) = (status IN ('COMPLETED', 'COMPLETED_BY_ADMIN', 'REFUNDED_TO_AGENT', 'CANCELLED',
                                              'EXPIRED')))
  AND (expires_at IS NULL OR status IN ('REQUESTED', 'AWAITING_PAYMENT')));
ALTER TABLE "recharge_order_messages" ADD CONSTRAINT "recharge_order_messages_shape" CHECK (
  (kind = 'TEXT' AND text IS NOT NULL AND image_key IS NULL)
  OR (kind IN ('IMAGE', 'TRANSFER_PROOF') AND image_key IS NOT NULL)
  OR (kind = 'PAYMENT_DETAILS' AND text IS NOT NULL AND method IS NOT NULL)
  OR (kind = 'SYSTEM' AND event IS NOT NULL AND role = 'SYSTEM'));

-- ORDER_HOLD is a debit of the stock, ORDER_RELEASE a credit back; RECHARGE_ORDER a credit of the buyer's wallet
-- (the rules of 20270101100000_recharge_agents and 20270104100000_card_topups, extended).
ALTER TABLE "recharge_stock_ledger" DROP CONSTRAINT "recharge_stock_ledger_sign";
ALTER TABLE "recharge_stock_ledger" ADD CONSTRAINT "recharge_stock_ledger_sign" CHECK (
  ((reason IN ('TOPUP', 'CHERRY_PURCHASE', 'ORDER_RELEASE') AND delta > 0)
   OR (reason IN ('SALE', 'ORDER_HOLD') AND delta < 0))
  AND balance_after BETWEEN 0 AND 9007199254740991);
ALTER TABLE "wallet_ledger" DROP CONSTRAINT "wallet_ledger_reason_sign";
ALTER TABLE "wallet_ledger" ADD CONSTRAINT "wallet_ledger_reason_sign" CHECK (
  (reason IN ('ADMIN_GRANT', 'CP_REFUND', 'LUCKY_GIFT_WIN', 'LIVE_BOOST_REFUND', 'TASK_REWARD', 'CHECK_IN_REWARD',
              'EVENT_PRIZE', 'RECHARGE_PURCHASE', 'CARD_TOPUP', 'CARD_TOPUP_RESTORE', 'RECHARGE_ORDER') AND delta > 0)
  OR (reason IN ('ADMIN_REVOKE', 'BULLET_MESSAGE', 'FAMILY_CREATE', 'CP_REQUEST', 'CP_GIFT', 'LIVE_GIFT', 'LUCKY_GIFT',
                 'PREMIUM_USERNAME_RENT', 'PREMIUM_USERNAME_RENEW', 'LIVE_BOOST', 'DM_GIFT', 'CARD_TOPUP_REVERSAL')
      AND delta < 0));
