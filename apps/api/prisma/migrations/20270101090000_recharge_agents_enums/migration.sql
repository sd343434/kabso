-- v1.54-social (D185, owner 2026-10-30): recharge agents «وكلاء الشحن» (CONVENTIONS §10.48, CP-028). The values
-- added to existing types go in a migration of their own (a value added by ALTER TYPE … ADD VALUE cannot be
-- used in the same transaction): a coin purchase from an agent (credit), cherries sold to an agent (debit),
-- and the two notifications.
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'RECHARGE_PURCHASE';
ALTER TYPE "cherry_ledger_reason" ADD VALUE 'RECHARGE_SALE';
ALTER TYPE "notification_type" ADD VALUE 'RECHARGE_COINS_RECEIVED';
ALTER TYPE "notification_type" ADD VALUE 'RECHARGE_CHERRY_REQUEST';
