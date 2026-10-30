-- v1.43-levels (D169, 2026-10-30): the support tier avatar frames. The new enum values go first, in
-- a migration of their own (PostgreSQL does not allow a value added by ALTER TYPE … ADD VALUE to be
-- used in the same transaction; the same split as 20261210090000_direct_messages_enums).

-- Bag (CONVENTIONS §10.22): a second category, the frame drawn around the user's photo.
ALTER TYPE "bag_category" ADD VALUE 'AVATAR_FRAME';

-- Bag: an item the server gives when a level is reached (the support tier frames).
ALTER TYPE "bag_item_source" ADD VALUE 'LEVEL_REWARD';
