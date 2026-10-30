-- v1.48-social (D171, owner 2026-10-29): the bag v2 — expiry, gifts between users and sending items
-- (CONVENTIONS §10.45). The new enum values go first, in a migration of their own (PostgreSQL does
-- not allow a value added by ALTER TYPE … ADD VALUE to be used in the same transaction; the same
-- split as 20261201090000_premium_usernames_enums).

-- A bag item sent by another user (`user_bag_items.gifted_by_user_id`).
ALTER TYPE "bag_item_source" ADD VALUE 'GIFT';

-- In-app notification (actor the sender, always on): someone sent you a bag item.
ALTER TYPE "notification_type" ADD VALUE 'BAG_ITEM_RECEIVED';
