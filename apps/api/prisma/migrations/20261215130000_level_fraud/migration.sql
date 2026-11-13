-- v1.46-levels (owner D169, 2026-10-30): an admin adjustment may be marked as fraud — the only entry
-- that lowers a level (CONVENTIONS §10.43). Recorded on the ledger row so a replay of the same
-- Idempotency-Key is compared with it. Only a negative ADJUSTMENT may be fraud.
ALTER TABLE "points_ledger" ADD COLUMN "fraud" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "points_ledger" ADD CONSTRAINT "points_ledger_fraud_check"
  CHECK (NOT "fraud" OR ("entry_type" = 'ADJUSTMENT' AND "points_delta" < 0));
