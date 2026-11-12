-- v1.128-social (D373, owner 2026-11-11: «سيارات الدخول ستكون اما بشاشة كاملة او نصف الشاشة … من لوحة الادمن انت تحدد
-- كيف ستكون الدخلة اما بشاشة كاملة او نصف شاشة»), CONVENTIONS §10.165: how an entry car plays — FULL_SCREEN «شاشة
-- كاملة» (the whole live screen, D331) or HALF_SCREEN «نصف الشاشة» (a band about half the screen high, above the chat).
--
-- 1. The enum `entry_display`.
-- 2. `store_items.entry_display` and `vip_tier_perks.entry_display`, NOT NULL DEFAULT 'FULL_SCREEN': every existing
--    row keeps today's look (D331: the car covers the whole live screen). The value is read only for an entry car
--    (a store item of kind ENTRY_EFFECT, a VIP perk ENTRY_EFFECT); the API never returns it for any other kind.
--
-- No new table (no grant to give: the new columns follow their tables' grants; an enum type is usable by PUBLIC).
-- Adding a NOT NULL column with a constant default is a catalogue-only change in PostgreSQL 11+ (no rewrite, short lock).
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

CREATE TYPE "entry_display" AS ENUM ('FULL_SCREEN', 'HALF_SCREEN');

ALTER TABLE "store_items" ADD COLUMN "entry_display" "entry_display" NOT NULL DEFAULT 'FULL_SCREEN';
ALTER TABLE "vip_tier_perks" ADD COLUMN "entry_display" "entry_display" NOT NULL DEFAULT 'FULL_SCREEN';
