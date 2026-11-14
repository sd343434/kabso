-- v1.139-social (D387, owner 2026-11-12, CONVENTIONS §10.176): the operations staff roles. The new enum values go in a
-- migration of their own (a value added by ALTER TYPE … ADD VALUE cannot be used in the same transaction):
--  - `LIVE_OPS` «مدير عمليات البث», `TALENT` «مدير الوكالات والمواهب», `VIP_CARE` «دعم كبار الداعمين», `COMMUNITY`
--    «المجتمع والفعاليات»: new panel roles. TRUST_SAFETY «مراقبة المحتوى والأمان» is the existing `MODERATION` (no
--    value is added or renamed for it, so every holder keeps exactly their access);
--  - `STAFF_COMPENSATION`: a compensation in coins from the VIP care staff (a credit; reference: the compensation).
ALTER TYPE "admin_permission" ADD VALUE 'LIVE_OPS';
ALTER TYPE "admin_permission" ADD VALUE 'TALENT';
ALTER TYPE "admin_permission" ADD VALUE 'VIP_CARE';
ALTER TYPE "admin_permission" ADD VALUE 'COMMUNITY';
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'STAFF_COMPENSATION';
