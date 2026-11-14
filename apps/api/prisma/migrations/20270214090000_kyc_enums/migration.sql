-- v1.80-kyc (D227, CONVENTIONS §10.77; owner 2026-11-01): identity verification with Didit «تأكيد الهوية». The
-- notification types of a check's result, in a migration of their own (a value added by ALTER TYPE cannot be used in
-- the same transaction), as 20270202090000 did.

-- AlterEnum
ALTER TYPE "notification_type" ADD VALUE 'KYC_APPROVED';
ALTER TYPE "notification_type" ADD VALUE 'KYC_DECLINED';
ALTER TYPE "notification_type" ADD VALUE 'KYC_IN_REVIEW';
