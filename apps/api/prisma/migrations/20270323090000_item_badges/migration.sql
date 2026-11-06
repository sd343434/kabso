-- v1.79-live (D289, CONVENTIONS §10.102): the badges of gifts and store items, a set instead of one value.
-- Owner: «بمؤثرات صوتية / بدون مؤثرات صوتية / جديد / الأكثر طلباً / مميز / لفترة محدودة» plus «شاشة كاملة / حصري / موسمي»;
-- the two sound badges exclude each other; «جديد» ends 14 days after it is set (or on the owner's date), «لفترة محدودة»
-- and «موسمي» on the owner's date — after the end only the badge stops showing (read time, no sweeper).
-- Expand only (DEPLOYMENT §5): `gifts.badge` and `store_items.is_new` stay, written by the API from the set, for an
-- older app and a rollback; a later release drops them.
-- The runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group): no GRANT here.
CREATE TYPE "item_badge" AS ENUM (
  'SOUND', 'NO_SOUND', 'NEW', 'MOST_WANTED', 'FEATURED', 'LIMITED', 'FULLSCREEN', 'EXCLUSIVE', 'SEASONAL');

ALTER TABLE "gifts"
  ADD COLUMN "badges" "item_badge"[] NOT NULL DEFAULT '{}',
  ADD COLUMN "badge_new_until" TIMESTAMPTZ(3),
  ADD COLUMN "badge_limited_until" TIMESTAMPTZ(3),
  ADD COLUMN "badge_seasonal_until" TIMESTAMPTZ(3);
ALTER TABLE "store_items"
  ADD COLUMN "badges" "item_badge"[] NOT NULL DEFAULT '{}',
  ADD COLUMN "badge_new_until" TIMESTAMPTZ(3),
  ADD COLUMN "badge_limited_until" TIMESTAMPTZ(3),
  ADD COLUMN "badge_seasonal_until" TIMESTAMPTZ(3);

-- Backfill (both tables are small: the panel's catalogue). Decided (owner question D289-Q1): an existing «جديد» gets the
-- 14-day rule from this release; an existing EVENT becomes «موسمي» without an end until the owner sets a date.
UPDATE "gifts" SET "badges" = ARRAY['NEW']::"item_badge"[], "badge_new_until" = now() + interval '14 days'
 WHERE "badge" = 'NEW';
UPDATE "gifts" SET "badges" = ARRAY['SEASONAL']::"item_badge"[] WHERE "badge" = 'EVENT';
UPDATE "store_items" SET "badges" = ARRAY['NEW']::"item_badge"[], "badge_new_until" = now() + interval '14 days'
 WHERE "is_new";

ALTER TABLE "gifts"
  ADD CONSTRAINT "gifts_badges_sound" CHECK (NOT ("badges" @> ARRAY['SOUND', 'NO_SOUND']::"item_badge"[])),
  ADD CONSTRAINT "gifts_badge_new_until" CHECK (("badge_new_until" IS NOT NULL) = ('NEW' = ANY ("badges"))),
  ADD CONSTRAINT "gifts_badge_limited_until" CHECK (("badge_limited_until" IS NOT NULL) = ('LIMITED' = ANY ("badges"))),
  ADD CONSTRAINT "gifts_badge_seasonal_until" CHECK ("badge_seasonal_until" IS NULL OR 'SEASONAL' = ANY ("badges"));
ALTER TABLE "store_items"
  ADD CONSTRAINT "store_items_badges_sound" CHECK (NOT ("badges" @> ARRAY['SOUND', 'NO_SOUND']::"item_badge"[])),
  ADD CONSTRAINT "store_items_badge_new_until" CHECK (("badge_new_until" IS NOT NULL) = ('NEW' = ANY ("badges"))),
  ADD CONSTRAINT "store_items_badge_limited_until"
    CHECK (("badge_limited_until" IS NOT NULL) = ('LIMITED' = ANY ("badges"))),
  ADD CONSTRAINT "store_items_badge_seasonal_until"
    CHECK ("badge_seasonal_until" IS NULL OR 'SEASONAL' = ANY ("badges"));
