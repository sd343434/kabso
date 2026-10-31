-- v1.46-live / v1.71-social (D207, owner 2026-10-31, CONVENTIONS §10.66): gift categories managed in the admin
-- panel, and a gift's hosted effect as SVGA or MP4 (plain, or side-by-side alpha) plus an optional MP3 sound.
--
-- 1. `gift_categories` replaces the fixed `gift_category` enum. It is seeded with the five tabs that existed, under
--    the names the app showed (شائعة / Popular, مناسبات / Events, مرح / Fun, الحظ / Lucky, إفيهات / Quips) and in the
--    same order. `gifts.category` becomes a VARCHAR foreign key to it with the same values, so every existing gift
--    keeps its category and every rule that tests `category = 'LUCKY' | 'QUIPS'` keeps its meaning: a special
--    category's code equals its kind (CHECK) and there is at most one of each special kind (unique index).
-- 2. `animation_format` (SVGA | MP4, set exactly with `animation_object_key`; existing hosted effects are SVGA),
--    `animation_alpha` (NONE | SIDE_BY_SIDE, set exactly for MP4) and `audio_object_key` / `audio_bytes` / `audio_ms`.

-- CreateEnum
CREATE TYPE "gift_category_kind" AS ENUM ('NORMAL', 'LUCKY', 'QUIPS');
CREATE TYPE "gift_animation_format" AS ENUM ('SVGA', 'MP4');
CREATE TYPE "gift_video_alpha" AS ENUM ('NONE', 'SIDE_BY_SIDE');

-- CreateTable
CREATE TABLE "gift_categories" (
    "code" VARCHAR(40) NOT NULL,
    "kind" "gift_category_kind" NOT NULL DEFAULT 'NORMAL',
    "name_ar" VARCHAR(30) NOT NULL,
    "name_en" VARCHAR(30) NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "icon_object_key" VARCHAR(200),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "gift_categories_pkey" PRIMARY KEY ("code")
);

ALTER TABLE "gift_categories" ADD CONSTRAINT "gift_categories_code_format" CHECK (code ~ '^[A-Z][A-Z0-9_]{0,39}$');
ALTER TABLE "gift_categories" ADD CONSTRAINT "gift_categories_kind_code" CHECK (kind = 'NORMAL' OR code = kind::text);
ALTER TABLE "gift_categories" ADD CONSTRAINT "gift_categories_names" CHECK (
    length(btrim(name_ar)) BETWEEN 1 AND 30 AND length(btrim(name_en)) BETWEEN 1 AND 30);
ALTER TABLE "gift_categories" ADD CONSTRAINT "gift_categories_sort_range" CHECK (sort_order BETWEEN 0 AND 1000000);
ALTER TABLE "gift_categories" ADD CONSTRAINT "gift_categories_icon_key_format" CHECK (
    icon_object_key ~ '^media/gift-categories/[A-Z][A-Z0-9_]{0,39}/[0-9a-f]{32}\.(png|webp)$');
-- At most one LUCKY and one QUIPS category.
CREATE UNIQUE INDEX "gift_categories_special_kind_key" ON "gift_categories" ("kind") WHERE "kind" <> 'NORMAL';
CREATE INDEX "gift_categories_sort_idx" ON "gift_categories" ("sort_order", "code");

-- The five tabs of the enum, in its order (the app's names before D207).
INSERT INTO "gift_categories" ("code", "kind", "name_ar", "name_en", "sort_order") VALUES
    ('POPULAR', 'NORMAL', 'شائعة', 'Popular', 10),
    ('EVENT', 'NORMAL', 'مناسبات', 'Events', 20),
    ('FUN', 'NORMAL', 'مرح', 'Fun', 30),
    ('LUCKY', 'LUCKY', 'الحظ', 'Lucky', 40),
    ('QUIPS', 'QUIPS', 'إفيهات', 'Quips', 50);

-- gifts.category: enum -> VARCHAR(40) FK. The CHECKs that compare it with enum literals are dropped first and
-- re-added unchanged in meaning (an ALTER TYPE would re-parse them against the old enum type).
ALTER TABLE "gifts" DROP CONSTRAINT "gifts_quip_fields";
ALTER TABLE "gifts" DROP CONSTRAINT "gifts_price_range";
ALTER TABLE "gifts" DROP CONSTRAINT "gifts_pk_booster_kind";
DROP INDEX "gifts_category_sort_idx";
ALTER TABLE "gifts" ALTER COLUMN "category" TYPE VARCHAR(40) USING "category"::text;
DROP TYPE "gift_category";
CREATE INDEX "gifts_category_sort_idx" ON "gifts" ("category", "sort_order");
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_category_fkey" FOREIGN KEY ("category")
    REFERENCES "gift_categories" ("code") ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE "gifts" ADD CONSTRAINT "gifts_quip_fields" CHECK (
    ((category = 'QUIPS') = (sound_key IS NOT NULL AND sound_ms IS NOT NULL))
    AND (quip_text IS NULL OR category = 'QUIPS')
    AND (sound_ms IS NULL OR sound_ms BETWEEN 200 AND 15000)
    AND (sound_key IS NULL OR sound_key ~ '^[A-Za-z0-9][A-Za-z0-9_./-]{0,79}$')
    AND (quip_text IS NULL OR length(btrim(quip_text)) > 0));
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_price_range" CHECK (
    price_coins BETWEEN 1 AND 1000000 OR (price_coins = 0 AND category = 'QUIPS'));
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_pk_booster_kind"
    CHECK ("pk_booster" IS NULL OR ("category" NOT IN ('LUCKY', 'QUIPS') AND "price_coins" > 0));

-- The hosted effect: SVGA (as before) or MP4.
ALTER TABLE "gifts" ADD COLUMN "animation_format" "gift_animation_format",
ADD COLUMN "animation_alpha" "gift_video_alpha",
ADD COLUMN "audio_object_key" VARCHAR(200),
ADD COLUMN "audio_bytes" INTEGER,
ADD COLUMN "audio_ms" INTEGER;
UPDATE "gifts" SET "animation_format" = 'SVGA' WHERE "animation_object_key" IS NOT NULL;

ALTER TABLE "gifts" DROP CONSTRAINT "gifts_animation_object_key_format";
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_animation_object_key_format" CHECK (
    animation_object_key ~ '^media/gifts/[a-z0-9][a-z0-9_]{0,39}/[0-9a-f]{32}\.(svga|mp4)$');
-- The format goes with the key (and its extension); the transparency exactly with an MP4.
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_animation_format_set" CHECK (
    (animation_object_key IS NULL AND animation_format IS NULL AND animation_alpha IS NULL)
    OR (animation_format = 'SVGA' AND animation_alpha IS NULL AND animation_object_key LIKE '%.svga')
    OR (animation_format = 'MP4' AND animation_alpha IS NOT NULL AND animation_object_key LIKE '%.mp4'));
-- The MP3 sound: the three set together (≤ 1 MiB, 1 ms … 15 s), never on a QUIPS gift (it has its own sound).
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_audio_set" CHECK (
    (audio_object_key IS NULL AND audio_bytes IS NULL AND audio_ms IS NULL)
    OR (audio_object_key ~ '^media/gifts/[a-z0-9][a-z0-9_]{0,39}/[0-9a-f]{32}\.mp3$'
        AND audio_bytes BETWEEN 1 AND 1048576 AND audio_ms BETWEEN 1 AND 15000 AND category <> 'QUIPS'));
