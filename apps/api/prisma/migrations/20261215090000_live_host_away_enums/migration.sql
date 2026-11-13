-- v1.42-live (D170, 2026-10-29): a video live whose host stayed away too long ends with
-- HOST_AWAY_TIMEOUT. The enum value goes first, in a migration of its own (PostgreSQL does not allow
-- a value added by ALTER TYPE … ADD VALUE to be used in the same transaction; the same split as
-- 20261210090000_direct_messages_enums).
ALTER TYPE "live_room_end_reason" ADD VALUE 'HOST_AWAY_TIMEOUT';
