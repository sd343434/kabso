-- v1.28-live (D146, 2026-10-27): premium usernames. The new enum values go first, in a migration of
-- their own (PostgreSQL does not allow a value added by ALTER TYPE … ADD VALUE to be used in the same
-- transaction; the same split as 20261127090000_lucky_gifts_enums).

-- Wallet ledger reasons: renting a premium username, and renewing it (CONVENTIONS §10.32).
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'PREMIUM_USERNAME_RENT';
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'PREMIUM_USERNAME_RENEW';

-- In-app notifications (system, always on): the period ends soon, and it ended.
ALTER TYPE "notification_type" ADD VALUE 'PREMIUM_USERNAME_EXPIRING';
ALTER TYPE "notification_type" ADD VALUE 'PREMIUM_USERNAME_EXPIRED';
