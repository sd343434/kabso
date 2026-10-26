-- v1.21-live (CP-018, owner D106, 2026-10-26): families, CP couples and medals. The new enum
-- values go first, in a migration of their own: PostgreSQL does not allow a value added by
-- ALTER TYPE … ADD VALUE to be used in the same transaction, and the next migration's CHECKs use
-- them (20261110100000_families_cp_medals).

-- Wallet ledger reasons (CONVENTIONS §10.21): creating a family, a CP request and its refund, a CP gift.
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'FAMILY_CREATE';
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'CP_REQUEST';
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'CP_REFUND';
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'CP_GIFT';

-- In-app notifications (CONVENTIONS §11.10, §10.21).
ALTER TYPE "notification_type" ADD VALUE 'CP_REQUEST';
ALTER TYPE "notification_type" ADD VALUE 'CP_ACCEPTED';
ALTER TYPE "notification_type" ADD VALUE 'FAMILY_JOIN_ACCEPTED';
ALTER TYPE "notification_type" ADD VALUE 'FAMILY_JOIN_DECLINED';
ALTER TYPE "notification_type" ADD VALUE 'MEDAL_AWARDED';
