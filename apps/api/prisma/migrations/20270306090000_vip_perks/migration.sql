-- D258 (owner's VIP 1 perks, CONVENTIONS §10.94): a perk's number per tier and VIP 1's perks as the owner chose them
-- (a tier holds every lower tier's perks).

ALTER TABLE "vip_tier_perks" ADD COLUMN "amount" INTEGER;
ALTER TABLE "vip_tier_perks" ADD CONSTRAINT "vip_tier_perks_amount_check" CHECK ("amount" IS NULL OR "amount" >= 1);

-- VIP 1 (seeded by 20270305090100_vip): the owner's list — badge, animated avatar frame, profile card, entry banner,
-- chat bubble, entry effect (the car) were seeded; add the name colour, the mic wave, 3 free public messages a day,
-- the profile visitors, the daily coins (amount set in the panel) and the level speed-up (1 %).
INSERT INTO "vip_tier_perks" ("id", "tier_id", "code", "title_ar", "title_en", "sort_order", "enabled", "amount")
VALUES
  ('01a25200-0000-7000-8000-0000000000a7', '01a25200-0000-7000-8000-000000000001', 'CHAT_NAME_COLOR', 'لون الاسم', 'Name colour', 6, true, NULL),
  ('01a25200-0000-7000-8000-0000000000a8', '01a25200-0000-7000-8000-000000000001', 'MIC_WAVE', 'موجة المايك', 'Mic wave', 7, true, NULL),
  ('01a25200-0000-7000-8000-0000000000a9', '01a25200-0000-7000-8000-000000000001', 'DAILY_BULLET', 'رسائل عامة مجانية', 'Free public messages', 8, true, 3),
  ('01a25200-0000-7000-8000-0000000000aa', '01a25200-0000-7000-8000-000000000001', 'PROFILE_VISITORS', 'من زار ملفي', 'Profile visitors', 9, true, NULL),
  ('01a25200-0000-7000-8000-0000000000ab', '01a25200-0000-7000-8000-000000000001', 'DAILY_COINS', 'عملات يومية', 'Daily coins', 10, true, NULL),
  ('01a25200-0000-7000-8000-0000000000ac', '01a25200-0000-7000-8000-000000000001', 'LEVEL_SPEEDUP', 'تسريع المستوى', 'Level speed-up', 11, true, 1)
ON CONFLICT DO NOTHING;
