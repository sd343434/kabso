-- v1.129-social (D374, owner 2026-11-11: every VIP tier gets the perks the admin picks in the panel, with art where a
-- perk needs it), CONVENTIONS §10.166: the perk catalogue's typed value per tier perk and an MP4 art file.
--
-- 1. `vip_tier_perks.value` (JSONB, null = not set): the perk's value, validated by the API against the catalogue
--    (`vip-catalogue.ts`): a number, a string, a list of strings or an object of numbers / strings.
-- 2. `vip_tier_perks.video`: the perk's MP4 art (https, uploaded from the panel), beside `animation` (SVGA) and `still`.
-- 3. D258's `amount` stays (the server's DAILY_BULLET / LEVEL_SPEEDUP reads and older apps use it); the existing
--    amounts are copied into `value`, and a CHECK keeps both equal from now on.
-- 4. The owner removed DAILY_COINS (2026-11-11, «ازلها»): its tier rows are KEPT (configuration, not money) and
--    ignored by the API — never listed to the app, never granted; the panel drops them on a tier's next save. The
--    `VIP_DAILY_COINS` ledger reason and `vip_daily_coin_claims` stay (history).
--
-- Every existing tier and perk row is kept as it is (codes, titles, art, order, on / off). Nothing is deleted.
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

ALTER TABLE "vip_tier_perks" ADD COLUMN "value" JSONB;
ALTER TABLE "vip_tier_perks" ADD COLUMN "video" VARCHAR(2048);

UPDATE "vip_tier_perks" SET "value" = to_jsonb("amount") WHERE "amount" IS NOT NULL;

ALTER TABLE "vip_tier_perks" ADD CONSTRAINT "vip_tier_perks_value_shape" CHECK (
    "value" IS NULL OR jsonb_typeof("value") IN ('number', 'string', 'array', 'object'));
ALTER TABLE "vip_tier_perks" ADD CONSTRAINT "vip_tier_perks_amount_value" CHECK (
    "amount" IS NULL OR ("value" IS NOT NULL AND "value" = to_jsonb("amount")));
ALTER TABLE "vip_tier_perks" ADD CONSTRAINT "vip_tier_perks_video_https" CHECK (
    "video" IS NULL OR "video" ~ '^https://');
