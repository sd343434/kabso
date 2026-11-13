-- v1.73-social (D209, CONVENTIONS §10.68; owner 2026-10-31: «يمكن للشخص تفعيل حسابه مضيف مع الإدارة»): the
-- notification types of an application to host directly with the Kabso team. New enum values in a migration of
-- their own (a value added by ALTER TYPE cannot be used in the same transaction), as 20270125090000 did.

-- AlterEnum
ALTER TYPE "notification_type" ADD VALUE 'HOST_APPLICATION_APPROVED';
ALTER TYPE "notification_type" ADD VALUE 'HOST_APPLICATION_REJECTED';
