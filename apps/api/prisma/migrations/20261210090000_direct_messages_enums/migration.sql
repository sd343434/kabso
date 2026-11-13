-- v1.40-social (D155, 2026-10-28): direct messages. The new enum values go first, in a migration of
-- their own (PostgreSQL does not allow a value added by ALTER TYPE … ADD VALUE to be used in the same
-- transaction; the same split as 20261127090000_lucky_gifts_enums).

-- Wallet ledger: a (non-lucky) gift sent in a direct conversation (CONVENTIONS §11.13).
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'DM_GIFT';

-- Reports (CONVENTIONS §11.7, §11.13): a direct message, kept as a snapshot.
ALTER TYPE "report_target_type" ADD VALUE 'DM_MESSAGE';
