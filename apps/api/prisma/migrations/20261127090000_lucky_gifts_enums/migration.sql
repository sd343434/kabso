-- v1.27-live (D132, 2026-10-27): lucky gifts. The new enum values go first, in a migration of their
-- own (PostgreSQL does not allow a value added by ALTER TYPE … ADD VALUE to be used in the same
-- transaction; the same split as 20261112090000_live_gifts_enums).

-- The gift panel's lucky tab (CONVENTIONS §10.27); listed only while LUCKY_GIFTS_ENABLED.
ALTER TYPE "gift_category" ADD VALUE 'LUCKY';

-- Wallet ledger reasons: the charge of a lucky gift, and the coins its draws won.
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'LUCKY_GIFT';
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'LUCKY_GIFT_WIN';
