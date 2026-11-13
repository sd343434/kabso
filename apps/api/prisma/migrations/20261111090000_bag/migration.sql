-- v1.22-live (CP-019, owner D107, 2026-10-26): the bag (الحقيبة), CONVENTIONS §10.22. Owned by the
-- `bag` module. First category PROFILE_CARD (the decoration on the profile card's header); more
-- categories come later as new `bag_category` values. The runtime role gets DML through the default
-- privileges (20261016130000_per_database_runtime_group), so this migration contains no GRANT.
-- Admin grants and revokes are audited (`bag.grant` / `bag.revoke` in audit_logs).

-- CreateEnum
CREATE TYPE "bag_category" AS ENUM ('PROFILE_CARD');

-- CreateEnum
CREATE TYPE "bag_item_source" AS ENUM ('FREE_SIGNUP', 'BACKFILL', 'ADMIN');

-- CreateTable
CREATE TABLE "bag_items" (
    "code" VARCHAR(40) NOT NULL,
    "category" "bag_category" NOT NULL,
    "name_ar" VARCHAR(60) NOT NULL,
    "name_en" VARCHAR(60) NOT NULL,
    "asset_key" VARCHAR(60) NOT NULL,
    "sort_order" INTEGER NOT NULL,
    "free" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "bag_items_pkey" PRIMARY KEY ("code")
);

-- CreateTable
CREATE TABLE "user_bag_items" (
    "user_id" UUID NOT NULL,
    "item_code" VARCHAR(40) NOT NULL,
    "category" "bag_category" NOT NULL,
    "source" "bag_item_source" NOT NULL,
    "acquired_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "equipped" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "user_bag_items_pkey" PRIMARY KEY ("user_id","item_code")
);

-- CreateIndex
CREATE INDEX "bag_items_category_sort_idx" ON "bag_items"("category", "sort_order");

-- CreateIndex
CREATE UNIQUE INDEX "bag_items_code_category_key" ON "bag_items"("code", "category");

-- CreateIndex
CREATE INDEX "user_bag_items_item_idx" ON "user_bag_items"("item_code", "category");

-- CreateIndex: at most one equipped item per user and category.
CREATE UNIQUE INDEX "user_bag_items_equipped_key" ON "user_bag_items"("user_id", "category") WHERE (equipped);

-- AddForeignKey
ALTER TABLE "user_bag_items" ADD CONSTRAINT "user_bag_items_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey: the category is the catalogue's (an item cannot be owned under another category).
ALTER TABLE "user_bag_items" ADD CONSTRAINT "user_bag_items_item_code_category_fkey" FOREIGN KEY ("item_code", "category") REFERENCES "bag_items"("code", "category") ON DELETE CASCADE ON UPDATE CASCADE;

-- ---- The catalogue (owner D107; CONVENTIONS §10.22) -------------------------------------------
-- The API keeps the same list (bag.catalogue.ts) so a test database can be re-seeded; a unit test
-- compares the two. `bunny_royal` is free: every new account receives it and wears it.
INSERT INTO "bag_items" ("code", "category", "name_ar", "name_en", "asset_key", "sort_order", "free") VALUES
  ('bunny_royal', 'PROFILE_CARD', 'الأرنب الملكي', 'Royal Bunny', 'header_bunny_royal', 10, true),
  ('kabi_royal', 'PROFILE_CARD', 'كابي الملكي', 'Royal Kabi', 'header_kabi_royal', 20, false),
  ('golden_stags', 'PROFILE_CARD', 'الغزلان الذهبية', 'Golden Stags', 'header_golden_stags', 30, false),
  ('emerald_wings', 'PROFILE_CARD', 'الأجنحة الزمردية', 'Emerald Wings', 'header_emerald_wings', 40, false);

-- ---- Backfill (owner D107): accounts that existed before the bag ------------------------------
-- They never chose to take the free item off, so each one that is not deleted receives every free
-- item it does not own (source BACKFILL) and wears the first of each category where it wears
-- nothing, once. The statement between the markers is run as-is by e2e KL-080.
-- BEGIN bag-backfill
INSERT INTO "user_bag_items" ("user_id", "item_code", "category", "source", "equipped")
SELECT u."id", i."code", i."category", 'BACKFILL',
       ROW_NUMBER() OVER (PARTITION BY u."id", i."category" ORDER BY i."sort_order", i."code") = 1
       AND NOT EXISTS (
         SELECT 1 FROM "user_bag_items" e
          WHERE e."user_id" = u."id" AND e."category" = i."category" AND e."equipped")
  FROM "users" u
 CROSS JOIN "bag_items" i
 WHERE i."free"
   AND u."deleted_at" IS NULL
   AND NOT EXISTS (
     SELECT 1 FROM "user_bag_items" o WHERE o."user_id" = u."id" AND o."item_code" = i."code");
-- END bag-backfill
