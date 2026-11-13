-- v1.74-social (D217, CONVENTIONS §10.71; owner 2026-11-01: «زر اربح المال يجب ان يفتح على هذه الصفحة الخاصة بالدعوة»):
-- the cherry ledger reasons of a referral reward and of its claw-back when the team voids the referral (owner
-- 2026-11-01), and the notification of that claw-back. A new enum value in a migration of its own (a value added by ALTER
-- TYPE cannot be used in the same transaction), as 20270202090000 did.

-- AlterEnum
ALTER TYPE "cherry_ledger_reason" ADD VALUE 'REFERRAL_REWARD';
ALTER TYPE "cherry_ledger_reason" ADD VALUE 'REFERRAL_REVERSAL';
ALTER TYPE "notification_type" ADD VALUE 'REFERRAL_REWARD_REVERSED';
