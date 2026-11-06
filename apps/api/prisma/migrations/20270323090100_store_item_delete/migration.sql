-- v1.79-live (D289b, CONVENTIONS §10.102.5). Owner: «عند اضافة عنصر الى متجر من لوحة الادمن لا يمكن حذفه، فاريد منك اضافة زر
-- الحذف». A store item nobody bought or holds is deleted for real (no column needed); one that was bought or is held is
-- hidden instead: `hidden_at` set, `enabled` false — gone from the store and the listings, never sold, still working for
-- its owners until their items end. «إرجاع للمتجر» clears it.
-- The runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group): no GRANT here.
ALTER TABLE "store_items" ADD COLUMN "hidden_at" TIMESTAMPTZ(3);
ALTER TABLE "store_items"
  ADD CONSTRAINT "store_items_hidden_off" CHECK ("hidden_at" IS NULL OR NOT "enabled");
