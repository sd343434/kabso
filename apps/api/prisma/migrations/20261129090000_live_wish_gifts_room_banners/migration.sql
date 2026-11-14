-- v1.27.3-live (D136, owner 2026-10-27): the host's wish list (CONVENTIONS §10.29), and
-- v1.27.4-live (D137): in-room promo banners (§10.26). Additive: a column with a default on each
-- table. No GRANT (default privileges, 20261016130000_per_database_runtime_group).

-- AlterTable: up to 4 gift codes, in display order.
ALTER TABLE "live_rooms" ADD COLUMN "wish_gifts" VARCHAR(40)[] NOT NULL DEFAULT ARRAY[]::VARCHAR(40)[];
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_wish_gifts_max" CHECK (cardinality(wish_gifts) <= 4);

-- AlterTable: where a banner is shown (the live hub or the in-room promo box).
ALTER TABLE "home_banners" ADD COLUMN "placement" VARCHAR(8) NOT NULL DEFAULT 'HOME';
ALTER TABLE "home_banners" ADD CONSTRAINT "home_banners_placement_values" CHECK (placement IN ('HOME', 'ROOM'));

-- CreateIndex
CREATE INDEX "home_banners_placement_idx" ON "home_banners"("placement", "sort_order", "starts_at") WHERE enabled;
