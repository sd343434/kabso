-- D264 (CONVENTIONS §10.97): a VIP member's tier items show in the bag, derived from the membership (never copied
-- rows: their time is the membership's). What the member took off from the bag is kept here (perk codes).
ALTER TABLE "vip_memberships" ADD COLUMN "off_perks" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];
ALTER TABLE "vip_memberships" ADD CONSTRAINT "vip_memberships_off_perks_check"
  CHECK ("off_perks" <@ ARRAY['AVATAR_FRAME', 'PROFILE_CARD', 'CHAT_BUBBLE', 'ENTRY_BANNER', 'ENTRY_EFFECT', 'MIC_WAVE']::TEXT[]);

-- One worn item per kind (owner): a VIP's frame and card are worn by default and replace the bag's worn ones. Members
-- active now wore both (the VIP art drawn with the bag's item); the bag's frame / card give way where the member's
-- tier (or a lower one) holds that perk, enabled.
UPDATE "user_bag_items" b
   SET "equipped" = false
  FROM "vip_memberships" m
  JOIN "vip_tiers" t ON t."id" = m."tier_id"
 WHERE b."user_id" = m."user_id"
   AND b."equipped"
   AND m."expires_at" > now()
   AND b."category"::text IN ('AVATAR_FRAME', 'PROFILE_CARD')
   AND EXISTS (
     SELECT 1 FROM "vip_tier_perks" p JOIN "vip_tiers" pt ON pt."id" = p."tier_id"
      WHERE p."enabled" AND p."code" = b."category"::text AND pt."sort_order" <= t."sort_order");
