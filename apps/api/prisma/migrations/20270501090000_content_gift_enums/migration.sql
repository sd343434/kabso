-- v1.127-social (D372, CONVENTIONS §10.164; owner 2026-11-11: «هدية الدعم» on reels and posts): the wallet ledger reason
-- of a gift sent on a post or reel and the author's notification. Their own migration: a new enum value cannot be used
-- in the transaction that adds it.
ALTER TYPE "wallet_ledger_reason" ADD VALUE IF NOT EXISTS 'CONTENT_GIFT';
ALTER TYPE "notification_type" ADD VALUE IF NOT EXISTS 'CONTENT_GIFT_RECEIVED';
