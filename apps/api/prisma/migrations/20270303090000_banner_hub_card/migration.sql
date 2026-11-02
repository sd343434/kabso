-- D248 (v1.59-live, CONVENTIONS §10.90): the live hub's card-size banner. A fifth banner placement, HUB_CARD (its
-- picture has the live card's aspect, 720 × 805); only the CHECK changes (placement is VARCHAR(8): 'HUB_CARD' fits).
ALTER TABLE "home_banners" DROP CONSTRAINT "home_banners_placement_values";
ALTER TABLE "home_banners" ADD CONSTRAINT "home_banners_placement_values" CHECK (placement IN ('HOME', 'ROOM', 'TASKS', 'WALLET', 'HUB_CARD'));
