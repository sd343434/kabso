-- D258 (CONVENTIONS §10.94.5): the ledger reason of a VIP's daily coins (its own migration: a new enum value is usable
-- only after its transaction commits).
ALTER TYPE "wallet_ledger_reason" ADD VALUE IF NOT EXISTS 'VIP_DAILY_COINS';
