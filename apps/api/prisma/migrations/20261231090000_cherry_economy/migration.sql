-- v1.52-social (D179, owner 2026-10-30): Kabso economy phase 1 — the cherry ledger (the host currency,
-- D134, as a real balance), host agencies, their commissions and manual withdrawal requests
-- (CONVENTIONS §10.43, proposal CP-027). Additive: new types and tables; the cherry history of the gifts
-- received before this migration is backfilled once (below). No existing row changes. The runtime role
-- gets DML through the default privileges (20261016130000_per_database_runtime_group): no GRANT here.
-- New enum TYPES (not values added to an existing type) can be used in the same transaction.

-- Why a cherry balance changed. Credits: a gift received, an agency's commission, a parent agency's
-- commission, a withdrawal refused (its cherries back). Debits: the mirrors of the three credits when
-- an admin reverses a send, and the cherries held by a withdrawal request.
CREATE TYPE "cherry_ledger_reason" AS ENUM (
  'GIFT_RECEIVED', 'AGENCY_COMMISSION', 'PARENT_COMMISSION',
  'GIFT_REVERSAL', 'AGENCY_COMMISSION_REVERSAL', 'PARENT_COMMISSION_REVERSAL',
  'WITHDRAWAL_HOLD', 'WITHDRAWAL_REFUND');

-- An agency's rank for the month: NEW (created, not evaluated yet — its grace), AGENT (≥ 5 active
-- hosts or the monthly-cherries exception), ADMIN (an agent with ≥ 3 qualified sub-agencies), LAPSED
-- (did not qualify at the last month start: no commission on hosts who join while lapsed).
CREATE TYPE "agency_rank" AS ENUM ('NEW', 'AGENT', 'ADMIN', 'LAPSED');

-- A host's link to an agency: ACTIVE, LEFT (the host left within the leave window), RELEASED (an admin
-- ended it after a complaint), MOVED (an admin moved the host to another agency after a complaint).
CREATE TYPE "agency_host_status" AS ENUM ('ACTIVE', 'LEFT', 'RELEASED', 'MOVED');

CREATE TYPE "agency_complaint_status" AS ENUM ('OPEN', 'RESOLVED', 'REJECTED');

CREATE TYPE "cherry_withdrawal_status" AS ENUM ('PENDING', 'PAID', 'REJECTED');

-- ---- Cherries -------------------------------------------------------------------------------------

-- A person's cherry balance (no row = 0). Changed only together with a cherry_ledger row. It may go
-- below 0 only through an admin reversal of a send whose cherries were already withdrawn (a debt that
-- blocks withdrawals until gifts cover it).
CREATE TABLE "cherry_wallets" (
    "user_id" UUID NOT NULL,
    "cherries" BIGINT NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cherry_wallets_pkey" PRIMARY KEY ("user_id")
);

-- Every change of a cherry balance (append-only). (user, reason, reference) is unique: a send credits
-- a person once per reason (its id is the reference), a withdrawal holds and refunds once.
CREATE TABLE "cherry_ledger" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "delta" BIGINT NOT NULL,
    "balance_after" BIGINT NOT NULL,
    "reason" "cherry_ledger_reason" NOT NULL,
    "reference_id" VARCHAR(64) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cherry_ledger_pkey" PRIMARY KEY ("id")
);

-- ---- Agencies -------------------------------------------------------------------------------------

-- A host agency «وكالة المضيفين», created by an admin (economy-admin agency-create) for its owner (the
-- host agent). `parent_agency_id`: the agency admin (parent) that activated it. `rank_month`: the month
-- (first day, LIVE_RANKINGS_TIME_ZONE) of the last month-start evaluation; `evaluate_from`: the first
-- month start at which a NEW agency is evaluated (its grace before).
CREATE TABLE "agencies" (
    "id" UUID NOT NULL,
    "owner_user_id" UUID NOT NULL,
    "invite_code" VARCHAR(12) NOT NULL,
    "parent_agency_id" UUID,
    "rank" "agency_rank" NOT NULL DEFAULT 'NEW',
    "rank_month" DATE,
    "evaluate_from" DATE NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "agencies_pkey" PRIMARY KEY ("id")
);

-- A host's membership of an agency. One ACTIVE link per host. `commission_eligible`: the agency was
-- not LAPSED when the host joined (such a host earns the agency its commission even while it is
-- lapsed later; a host who joined during a lapse earns it only while the agency qualifies again).
CREATE TABLE "agency_hosts" (
    "id" UUID NOT NULL,
    "agency_id" UUID NOT NULL,
    "host_user_id" UUID NOT NULL,
    "status" "agency_host_status" NOT NULL DEFAULT 'ACTIVE',
    "commission_eligible" BOOLEAN NOT NULL,
    "activated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ended_at" TIMESTAMPTZ(3),

    CONSTRAINT "agency_hosts_pkey" PRIMARY KEY ("id")
);

-- One row per (send, recipient) for a recipient who was an agency's host at the send: the host's
-- cherries and the commissions paid on them (0 when not paid). The agency's monthly totals, the hosts
-- list and the reversal mirror read it.
CREATE TABLE "agency_earnings" (
    "id" UUID NOT NULL,
    "gift_id" UUID NOT NULL,
    "agency_id" UUID NOT NULL,
    "agency_host_id" UUID NOT NULL,
    "host_user_id" UUID NOT NULL,
    "host_cherries" BIGINT NOT NULL,
    "rate_bps" INTEGER NOT NULL,
    "commission" BIGINT NOT NULL,
    "parent_agency_id" UUID,
    "parent_rate_bps" INTEGER NOT NULL,
    "parent_commission" BIGINT NOT NULL,
    "month" DATE NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "reversed_at" TIMESTAMPTZ(3),

    CONSTRAINT "agency_earnings_pkey" PRIMARY KEY ("id")
);

-- An agency's month (first day, LIVE_RANKINGS_TIME_ZONE): its hosts' cherries (the 16 % tier of the
-- next month and the rank exception), the commission it earned on them, and what it earned as a
-- parent on its sub-agencies' hosts. Kept in the send's transaction; reversals subtract.
CREATE TABLE "agency_months" (
    "agency_id" UUID NOT NULL,
    "month" DATE NOT NULL,
    "host_cherries" BIGINT NOT NULL DEFAULT 0,
    "commission" BIGINT NOT NULL DEFAULT 0,
    "parent_commission" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "agency_months_pkey" PRIMARY KEY ("agency_id", "month")
);

-- A host's complaint to the admin after the leave window (the only way out then).
CREATE TABLE "agency_complaints" (
    "id" UUID NOT NULL,
    "agency_host_id" UUID NOT NULL,
    "host_user_id" UUID NOT NULL,
    "agency_id" UUID NOT NULL,
    "text" VARCHAR(1000) NOT NULL,
    "status" "agency_complaint_status" NOT NULL DEFAULT 'OPEN',
    "resolution" VARCHAR(10),
    "note" VARCHAR(500),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolved_at" TIMESTAMPTZ(3),

    CONSTRAINT "agency_complaints_pkey" PRIMARY KEY ("id")
);

-- ---- Withdrawals ----------------------------------------------------------------------------------

-- A withdrawal request (no payment provider yet: an admin pays by hand and marks it). The cherries are
-- held at request (WITHDRAWAL_HOLD) and given back on rejection (WITHDRAWAL_REFUND). The rate in force
-- is stored with the request. `client_id` is the request's Idempotency-Key.
CREATE TABLE "cherry_withdrawals" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "client_id" UUID NOT NULL,
    "cherries" BIGINT NOT NULL,
    "amount_minor" BIGINT NOT NULL,
    "currency" CHAR(3) NOT NULL,
    "rate_cherries" BIGINT NOT NULL,
    "rate_minor" INTEGER NOT NULL,
    "payout_details" VARCHAR(500) NOT NULL,
    "status" "cherry_withdrawal_status" NOT NULL DEFAULT 'PENDING',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "decided_at" TIMESTAMPTZ(3),
    "decision_note" VARCHAR(500),

    CONSTRAINT "cherry_withdrawals_pkey" PRIMARY KEY ("id")
);

-- ---- Indexes, keys, rules -------------------------------------------------------------------------

CREATE UNIQUE INDEX "cherry_ledger_reference_once" ON "cherry_ledger"("user_id", "reason", "reference_id");
CREATE INDEX "cherry_ledger_user_created_idx" ON "cherry_ledger"("user_id", "created_at" DESC, "id" DESC);
CREATE INDEX "cherry_ledger_reference_idx" ON "cherry_ledger"("reference_id");
CREATE UNIQUE INDEX "agencies_owner_once" ON "agencies"("owner_user_id");
CREATE UNIQUE INDEX "agencies_invite_code_key" ON "agencies"("invite_code");
CREATE INDEX "agencies_parent_idx" ON "agencies"("parent_agency_id");
CREATE UNIQUE INDEX "agency_hosts_one_active" ON "agency_hosts"("host_user_id") WHERE status = 'ACTIVE';
CREATE INDEX "agency_hosts_agency_idx" ON "agency_hosts"("agency_id", "status", "activated_at" DESC);
CREATE INDEX "agency_hosts_host_idx" ON "agency_hosts"("host_user_id", "activated_at" DESC);
CREATE UNIQUE INDEX "agency_earnings_once" ON "agency_earnings"("gift_id", "host_user_id");
CREATE INDEX "agency_earnings_agency_month_idx" ON "agency_earnings"("agency_id", "month", "host_user_id");
CREATE INDEX "agency_earnings_link_idx" ON "agency_earnings"("agency_host_id");
CREATE INDEX "agency_earnings_parent_idx" ON "agency_earnings"("parent_agency_id", "month");
CREATE UNIQUE INDEX "agency_complaints_one_open" ON "agency_complaints"("agency_host_id") WHERE status = 'OPEN';
CREATE INDEX "agency_complaints_status_idx" ON "agency_complaints"("status", "created_at");
CREATE INDEX "agency_complaints_agency_idx" ON "agency_complaints"("agency_id");
CREATE INDEX "agency_complaints_host_idx" ON "agency_complaints"("host_user_id");
CREATE UNIQUE INDEX "cherry_withdrawals_client_once" ON "cherry_withdrawals"("user_id", "client_id");
CREATE UNIQUE INDEX "cherry_withdrawals_one_pending" ON "cherry_withdrawals"("user_id") WHERE status = 'PENDING';
CREATE INDEX "cherry_withdrawals_user_created_idx" ON "cherry_withdrawals"("user_id", "created_at" DESC, "id" DESC);
CREATE INDEX "cherry_withdrawals_status_idx" ON "cherry_withdrawals"("status", "created_at");

ALTER TABLE "cherry_wallets" ADD CONSTRAINT "cherry_wallets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "cherry_ledger" ADD CONSTRAINT "cherry_ledger_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "agencies" ADD CONSTRAINT "agencies_owner_user_id_fkey" FOREIGN KEY ("owner_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "agencies" ADD CONSTRAINT "agencies_parent_agency_id_fkey" FOREIGN KEY ("parent_agency_id") REFERENCES "agencies"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "agency_hosts" ADD CONSTRAINT "agency_hosts_agency_id_fkey" FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "agency_hosts" ADD CONSTRAINT "agency_hosts_host_user_id_fkey" FOREIGN KEY ("host_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "agency_earnings" ADD CONSTRAINT "agency_earnings_agency_id_fkey" FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "agency_earnings" ADD CONSTRAINT "agency_earnings_agency_host_id_fkey" FOREIGN KEY ("agency_host_id") REFERENCES "agency_hosts"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "agency_months" ADD CONSTRAINT "agency_months_agency_id_fkey" FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "agency_complaints" ADD CONSTRAINT "agency_complaints_agency_host_id_fkey" FOREIGN KEY ("agency_host_id") REFERENCES "agency_hosts"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "cherry_withdrawals" ADD CONSTRAINT "cherry_withdrawals_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "cherry_wallets" ADD CONSTRAINT "cherry_wallets_range"
  CHECK (cherries BETWEEN -9007199254740991 AND 9007199254740991);
ALTER TABLE "cherry_ledger" ADD CONSTRAINT "cherry_ledger_reason_sign" CHECK (
  (reason IN ('GIFT_RECEIVED', 'AGENCY_COMMISSION', 'PARENT_COMMISSION', 'WITHDRAWAL_REFUND') AND delta > 0)
  OR (reason IN ('GIFT_REVERSAL', 'AGENCY_COMMISSION_REVERSAL', 'PARENT_COMMISSION_REVERSAL', 'WITHDRAWAL_HOLD')
      AND delta < 0));
ALTER TABLE "cherry_ledger" ADD CONSTRAINT "cherry_ledger_balance_range"
  CHECK (balance_after BETWEEN -9007199254740991 AND 9007199254740991);
ALTER TABLE "agencies" ADD CONSTRAINT "agencies_shape" CHECK (
  invite_code ~ '^[A-HJ-NP-Z2-9]{8}$' AND (parent_agency_id IS NULL OR parent_agency_id <> id));
ALTER TABLE "agency_hosts" ADD CONSTRAINT "agency_hosts_ended" CHECK ((status = 'ACTIVE') = (ended_at IS NULL));
ALTER TABLE "agency_earnings" ADD CONSTRAINT "agency_earnings_amounts" CHECK (
  host_cherries > 0 AND commission >= 0 AND parent_commission >= 0
  AND rate_bps BETWEEN 0 AND 10000 AND parent_rate_bps BETWEEN 0 AND 10000
  AND (parent_agency_id IS NOT NULL OR parent_commission = 0));
ALTER TABLE "agency_months" ADD CONSTRAINT "agency_months_amounts"
  CHECK (host_cherries >= 0 AND commission >= 0 AND parent_commission >= 0);
ALTER TABLE "agency_complaints" ADD CONSTRAINT "agency_complaints_shape" CHECK (
  char_length(text) BETWEEN 1 AND 1000
  AND ((status = 'OPEN') = (resolved_at IS NULL))
  AND (resolution IS NULL OR resolution IN ('RELEASED', 'MOVED', 'KEPT')));
ALTER TABLE "cherry_withdrawals" ADD CONSTRAINT "cherry_withdrawals_shape" CHECK (
  cherries > 0 AND amount_minor > 0 AND rate_cherries > 0 AND rate_minor > 0
  AND char_length(payout_details) BETWEEN 1 AND 500
  AND ((status = 'PENDING') = (decided_at IS NULL)));

-- ---- Backfill (once) ------------------------------------------------------------------------------
-- The gifts received before the cherry ledger existed (D164 showed them as computed earnings): one
-- GIFT_RECEIVED row per (send, recipient) with the same arithmetic as a new send — floor(recipient coins ×
-- stored host_share_bps × CHERRIES_PER_COIN (10) / 10 000) — at the send's time, and the balances. No
-- commission is backfilled (no agency existed). A migration runs once; ON CONFLICT keeps it idempotent.
INSERT INTO "cherry_ledger" ("id", "user_id", "delta", "balance_after", "reason", "reference_id", "created_at")
SELECT gen_random_uuid(), e.user_id, e.cherries,
       sum(e.cherries) OVER (PARTITION BY e.user_id ORDER BY e.created_at, e.gift_id
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),
       'GIFT_RECEIVED', e.gift_id::text, e.created_at
  FROM (SELECT gr.user_id, g.id AS gift_id, g.created_at,
               (gr.coins * g.host_share_bps * 10 / 10000)::bigint AS cherries
          FROM "live_gift_recipients" gr
          JOIN "live_gifts" g ON g.id = gr.gift_id) e
 WHERE e.cherries > 0
ON CONFLICT ("user_id", "reason", "reference_id") DO NOTHING;

INSERT INTO "cherry_wallets" ("user_id", "cherries", "updated_at")
SELECT "user_id", sum("delta"), now() FROM "cherry_ledger" GROUP BY "user_id"
ON CONFLICT ("user_id") DO NOTHING;
