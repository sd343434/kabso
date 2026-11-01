-- v1.69-social (D204, owner 2026-10-31): recharge orders with escrow «طلبات الشحن» (CONVENTIONS §10.64). The values
-- added to existing types go in a migration of their own (a value added by ALTER TYPE … ADD VALUE cannot be used in
-- the same transaction): the stock frozen for an order and given back, the buyer's credit, and the notification.
ALTER TYPE "recharge_stock_reason" ADD VALUE 'ORDER_HOLD';
ALTER TYPE "recharge_stock_reason" ADD VALUE 'ORDER_RELEASE';
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'RECHARGE_ORDER';
ALTER TYPE "notification_type" ADD VALUE 'RECHARGE_ORDER_UPDATE';
