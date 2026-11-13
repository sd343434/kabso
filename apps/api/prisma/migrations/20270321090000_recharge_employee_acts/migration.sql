-- D287 (v1.87-social, CONVENTIONS §10.100): a recharge agent's employees act FOR the agent within their shift — they
-- buy hosts' cherries into the agent's stock and receive the agent's coin orders. Two permissions per employee (ON
-- for every existing employee: they were all added to sell), who acted on a cherry request, and who owns an order
-- (the first person of the agent's side to act on it). Additive: no existing row or rule changes.
ALTER TABLE "recharge_employees"
  ADD COLUMN "can_buy_cherries" BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN "receives_orders" BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE "recharge_cherry_requests"
  ADD COLUMN "acted_by" UUID,
  ADD COLUMN "decided_by" UUID;

-- An employee creates a request for the agent: the creator is then the employee who acted (the idempotency key stays
-- per caller, `recharge_cherry_requests_client_once`); every other row keeps the D185 shape.
ALTER TABLE "recharge_cherry_requests" DROP CONSTRAINT "recharge_cherry_requests_shape";
ALTER TABLE "recharge_cherry_requests" ADD CONSTRAINT "recharge_cherry_requests_shape" CHECK (
  cherries > 0 AND coins >= 0 AND payout_minor >= 0 AND host_user_id <> agent_user_id
  AND (created_by IN (host_user_id, agent_user_id) OR created_by = acted_by)
  AND ((status = 'PENDING') = (decided_at IS NULL)));

CREATE INDEX "recharge_cherry_requests_acted_by_idx" ON "recharge_cherry_requests"("acted_by", "decided_at")
  WHERE acted_by IS NOT NULL;

ALTER TABLE "recharge_orders"
  ADD COLUMN "claimed_by" UUID,
  ADD COLUMN "claimed_at" TIMESTAMPTZ(3);

CREATE INDEX "recharge_orders_claimed_by_idx" ON "recharge_orders"("claimed_by", "closed_at")
  WHERE claimed_by IS NOT NULL;
