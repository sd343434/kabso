-- v1.62-social (D193, owner: «زر حذف الحساب داخل التطبيق» as Apple and Google require, 30 days to change one's mind):
-- account deletion (CONVENTIONS §10.56, CP-036). The value added to an existing type goes in a migration of its own
-- (a value added by ALTER TYPE … ADD VALUE cannot be used in the same transaction): an account in its grace period.
ALTER TYPE "user_status" ADD VALUE 'PENDING_DELETION';
