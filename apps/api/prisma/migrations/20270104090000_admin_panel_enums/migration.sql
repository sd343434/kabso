-- v1.60-social (D191, owner 2026-10-31): the admin panel «لوحة الإدارة» (CONVENTIONS §10.54, CP-034). Values added to
-- existing types go in a migration of their own (a value added by ALTER TYPE … ADD VALUE cannot be used in the same
-- transaction): the panel roles OWNER, SUPPORT and FINANCE (MODERATION is the moderator) and the moderator's warning
-- notification.
ALTER TYPE "admin_permission" ADD VALUE 'OWNER';
ALTER TYPE "admin_permission" ADD VALUE 'SUPPORT';
ALTER TYPE "admin_permission" ADD VALUE 'FINANCE';
ALTER TYPE "notification_type" ADD VALUE 'MODERATION_WARNING';
