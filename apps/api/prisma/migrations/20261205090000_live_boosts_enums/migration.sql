-- v1.33-live (D154b, 2026-10-28): traffic cards «بطاقة الزيارات». The new enum values go first, in a
-- migration of their own (PostgreSQL does not allow a value added by ALTER TYPE … ADD VALUE to be used
-- in the same transaction; the same split as 20261204090000_quips_enums).

-- How a traffic card was paid.
CREATE TYPE "live_boost_source" AS ENUM ('COINS', 'CARD');

-- Wallet ledger reasons: a traffic card bought with coins, and its refund when it never ran.
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'LIVE_BOOST';
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'LIVE_BOOST_REFUND';
