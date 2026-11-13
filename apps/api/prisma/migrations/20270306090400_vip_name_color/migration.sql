-- D258 (CONVENTIONS §10.94.10): a tier's special text colour (CHAT_NAME_COLOR), set in the panel; VIP 1's is the
-- owner's gold #FFD12E (a solid text colour in the app).
ALTER TABLE "vip_tiers" ADD COLUMN "name_color" CHAR(7);
ALTER TABLE "vip_tiers" ADD CONSTRAINT "vip_tiers_name_color_check" CHECK ("name_color" IS NULL OR "name_color" ~ '^#[0-9A-F]{6}$');
UPDATE "vip_tiers" SET "name_color" = '#FFD12E' WHERE "code" = 'VIP_1' AND "name_color" IS NULL;
