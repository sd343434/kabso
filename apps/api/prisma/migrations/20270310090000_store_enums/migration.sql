-- D270 (owner: «المتجر» — CONVENTIONS §10.98): the store sells timed bag items for coins or cherries. The new enum
-- values go first, in a migration of their own (a value added by ALTER TYPE … ADD VALUE cannot be used in the same
-- transaction; the same split as 20270305090000_vip_enums).

-- The kinds the store sells that were VIP-only categories (D264): a chat bubble, an entry banner, an entry car /
-- effect are now real bag items too (MIC_WAVE stays VIP-only).
ALTER TYPE "bag_category" ADD VALUE IF NOT EXISTS 'CHAT_BUBBLE';
ALTER TYPE "bag_category" ADD VALUE IF NOT EXISTS 'ENTRY_BANNER';
ALTER TYPE "bag_category" ADD VALUE IF NOT EXISTS 'ENTRY_EFFECT';

-- How the item came: bought in the store for oneself (a store gift is a GIFT with its giver).
ALTER TYPE "bag_item_source" ADD VALUE IF NOT EXISTS 'STORE';

-- The ledgers' debit of a store purchase (reference: the `store_purchases` row).
ALTER TYPE "wallet_ledger_reason" ADD VALUE IF NOT EXISTS 'STORE_PURCHASE';
ALTER TYPE "cherry_ledger_reason" ADD VALUE IF NOT EXISTS 'STORE_PURCHASE';

-- What a price is in.
CREATE TYPE "store_currency" AS ENUM ('COINS', 'CHERRIES');
