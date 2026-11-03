-- v1.82-social (D252, owner 2026-11-03: «اصنع صفحة شراء vip … واضافة الفي اي بي وترتيبه يكون من لوحة كل في اي بي له
-- ميزات وامتيازات مختلفة»): VIP tiers bought with coins, managed in the admin panel (CONVENTIONS §10.92). The new enum
-- value and type go first, in a migration of their own (PostgreSQL does not allow a value added by ALTER TYPE … ADD
-- VALUE to be used in the same transaction; the same split as 20261214090000_me_programs_enums).

-- Wallet ledger reason (a debit): a VIP tier bought, renewed or upgraded (reference: the `vip_purchases` row).
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'VIP_PURCHASE';

-- What a purchase did: a new membership, the same tier extended, or a higher tier from now.
CREATE TYPE "vip_purchase_kind" AS ENUM ('NEW', 'RENEW', 'UPGRADE');
