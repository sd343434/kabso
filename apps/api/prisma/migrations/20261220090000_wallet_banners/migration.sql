-- v1.51-social (D177, owner 2026-10-30): promo banners on the wallet page (CONVENTIONS §10.26).
-- A third banner placement, WALLET (3:1 like HOME). Only the CHECK changes; no data moves.
ALTER TABLE "home_banners" DROP CONSTRAINT "home_banners_placement_values";
ALTER TABLE "home_banners" ADD CONSTRAINT "home_banners_placement_values" CHECK (placement IN ('HOME', 'ROOM', 'WALLET'));
