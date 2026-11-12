-- v1.136-social (D384, owner 2026-11-12: the VIP «صورة متحركة»), CONVENTIONS §10.173. The new enum value goes first, in
-- a migration of its own (PostgreSQL does not allow a value added by ALTER TYPE … ADD VALUE to be used in the same
-- transaction; the split of 20270209090000_profile_cover_enums).

-- Notifications (§10.173.5, §11.10): (system) a moderator removed the VIP animated picture.
ALTER TYPE "notification_type" ADD VALUE 'ANIMATED_AVATAR_REMOVED';
