-- v1.59-social (D190, owner answer CP-033 Q2, 2026-10-31): a refund the team makes itself (`payments-admin refund`,
-- e.g. a goodwill refund) reverses its coins but never freezes the buyer. The order records what the team refunded
-- (cents, written BEFORE the Stripe call so a webhook that arrives first knows it) and why.
ALTER TABLE "topup_orders" ADD COLUMN "team_refunded_minor" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "topup_orders" ADD COLUMN "team_refund_reason" VARCHAR(500);
ALTER TABLE "topup_orders" ADD CONSTRAINT "topup_orders_team_refunded_check"
  CHECK ("team_refunded_minor" BETWEEN 0 AND "amount_minor");
