-- D268 (CONVENTIONS §10.94.10, owner: «لون خط vip1=#FFC928»): VIP 1's special text colour is now #FFC928. The colour
-- is per tier (set in the panel); only a tier still on the old default #FFD12E moves, a colour the owner set stays.
UPDATE "vip_tiers" SET "name_color" = '#FFC928' WHERE "code" = 'VIP_1' AND "name_color" = '#FFD12E';
