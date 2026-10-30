-- v1.47-social (D175, owner 2026-10-30): profile fields, private accounts and follow requests. The new
-- enum values go first, in a migration of their own (PostgreSQL does not allow a value added by
-- ALTER TYPE … ADD VALUE to be used in the same transaction; the same split as
-- 20261210090000_direct_messages_enums).

-- Notifications (CONVENTIONS §10.43, §11.10): a follow request to the private account; the request
-- was accepted; (system) a moderator removed the profile photo.
ALTER TYPE "notification_type" ADD VALUE 'FOLLOW_REQUEST';
ALTER TYPE "notification_type" ADD VALUE 'FOLLOW_REQUEST_ACCEPTED';
ALTER TYPE "notification_type" ADD VALUE 'AVATAR_REMOVED';

-- Reports (CONVENTIONS §11.7, §10.43): a link on someone's profile, kept as a snapshot.
ALTER TYPE "report_target_type" ADD VALUE 'PROFILE_LINK';
