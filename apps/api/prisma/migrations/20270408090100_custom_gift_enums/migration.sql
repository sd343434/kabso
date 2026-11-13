-- v1.100-social (D312, CONVENTIONS §10.118; owner: «هدايا من فئة مُخصَّص تستند الى مستخدم»): the special gift category kind
-- CUSTOM and the wallet ledger reasons of the gift owner's coin share. Their own migration: a new enum value cannot be
-- used in the transaction that adds it.
ALTER TYPE "gift_category_kind" ADD VALUE IF NOT EXISTS 'CUSTOM';
ALTER TYPE "wallet_ledger_reason" ADD VALUE IF NOT EXISTS 'GIFT_OWNER_ROYALTY';
ALTER TYPE "wallet_ledger_reason" ADD VALUE IF NOT EXISTS 'GIFT_OWNER_ROYALTY_REVERSAL';
