-- v1.76-social (D218, owner 2026-11-01), CONVENTIONS §10.73. The new enum value goes first, in a migration of
-- its own (PostgreSQL does not allow a value added by ALTER TYPE … ADD VALUE to be used in the same
-- transaction; the same split as 20261215090000_profile_fields_enums).

-- Notifications (§10.73.3, §11.10): (system) a moderator removed the profile cover.
ALTER TYPE "notification_type" ADD VALUE 'COVER_REMOVED';
