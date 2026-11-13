-- v1.140-social (D390, CONVENTIONS §10.179): «برنامج سفراء Kabso» — the ambassadors programme. The new enum values go in
-- a migration of their own (a value added by ALTER TYPE … ADD VALUE cannot be used in the same transaction):
--  - `AMBASSADOR_COMMISSION` (credit): an ambassador's commission on a referred person's qualifying top-up, credited
--    after its hold (withdrawable cherries; reference = the `ambassador_commissions` row);
--  - `AMBASSADOR_COMMISSION_REVERSAL` (debit): that commission taken back after a refund or a chargeback (reference =
--    the same row, so never twice);
--  - `AMBASSADOR_REWARD` (coins, credit): a monthly target reward in coins (reference `AMB:<user>@<YYYY-MM>`);
--  - four system notifications: the application approved / rejected, a level up, a monthly reward granted.
ALTER TYPE "cherry_ledger_reason" ADD VALUE 'AMBASSADOR_COMMISSION';
ALTER TYPE "cherry_ledger_reason" ADD VALUE 'AMBASSADOR_COMMISSION_REVERSAL';
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'AMBASSADOR_REWARD';
ALTER TYPE "notification_type" ADD VALUE 'AMBASSADOR_APPLICATION_APPROVED';
ALTER TYPE "notification_type" ADD VALUE 'AMBASSADOR_APPLICATION_REJECTED';
ALTER TYPE "notification_type" ADD VALUE 'AMBASSADOR_LEVEL_UP';
ALTER TYPE "notification_type" ADD VALUE 'AMBASSADOR_REWARD_GRANTED';
