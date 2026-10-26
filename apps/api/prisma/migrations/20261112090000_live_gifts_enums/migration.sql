-- v1.23-live (CP-020, D108, 2026-10-26): live gifts. The new wallet ledger reason goes first, in a
-- migration of its own (PostgreSQL does not allow a value added by ALTER TYPE … ADD VALUE to be used
-- in the same transaction; the same split as 20261110090000_families_cp_medals_enums).

-- Wallet ledger reason (CONVENTIONS §10.23): a gift sent in a live and paid with coins.
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'LIVE_GIFT';
