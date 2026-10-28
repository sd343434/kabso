-- v1.32-live (D154, 2026-10-28): «إفيهات» quips. The new enum value goes first, in a migration of its
-- own (PostgreSQL does not allow a value added by ALTER TYPE … ADD VALUE to be used in the same
-- transaction; the same split as 20261127090000_lucky_gifts_enums).

-- The gift panel's quips tab (CONVENTIONS §10.33).
ALTER TYPE "gift_category" ADD VALUE 'QUIPS';
