-- v1.139-social (D387, §10.176.4; owner: «نعم ينقص تقرير الربح قيمة هذه العملات»): «الربح» reads the coin compensations
-- of a period (its STAFF_COMPENSATIONS line), like the free coins (`wallet_ledger_free_coins_idx`). A small partial index:
-- only the compensation rows (none before this release).
CREATE INDEX "wallet_ledger_staff_compensation_idx" ON "wallet_ledger" ("created_at")
  WHERE reason = 'STAFF_COMPENSATION'::wallet_ledger_reason;
