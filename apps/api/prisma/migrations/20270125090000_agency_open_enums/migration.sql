-- v1.70-social (D206, CONVENTIONS §10.65; owner 2026-10-31: «افتح وكالة»): the notification types of a self-opened
-- agency. New enum values in a migration of their own (a value added by ALTER TYPE cannot be used in the same
-- transaction), as 20270118090000 did.

-- AlterEnum
ALTER TYPE "notification_type" ADD VALUE 'AGENCY_OPENED';
ALTER TYPE "notification_type" ADD VALUE 'AGENCY_PROBATION_REMINDER';
ALTER TYPE "notification_type" ADD VALUE 'AGENCY_PROBATION_PASSED';
ALTER TYPE "notification_type" ADD VALUE 'AGENCY_CLOSED';
ALTER TYPE "notification_type" ADD VALUE 'AGENCY_HOST_RELEASED';
