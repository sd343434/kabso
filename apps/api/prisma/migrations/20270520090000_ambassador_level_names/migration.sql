-- v1.141-social (D390 follow-up, owner 2026-11-14: «سفراء النجوم»), CONVENTIONS §10.179.6.
--
-- The four default level codes BRONZE / SILVER / GOLD / DIAMOND become SPARK / STAR / CONSTELLATION / GALAXY
-- («شرارة / نجم / كوكبة / مجرّة»). Level codes are free-form (the OWNER edits the list); the apps name the four
-- default codes through their translations and show any other code as it is.
--
-- 1. `ambassador_settings.levels`: the column default, and the stored list — each level still holding an old
--    default code gets its new one (its numbers and reward unchanged), only when the list holds an old default code
--    and none of the new ones (an OWNER who already used a new code keeps the list as is).
-- 2. `ambassadors.level`, `ambassador_commissions.level`, `ambassador_months.level_before` / `level_after` /
--    `met_level`: an old default code becomes its new one, only when the settings now hold the new code and no
--    longer the old one (so a level never points at a code the list does not have).
--
-- Idempotent: a second run finds no old code to rename. No CHECK constraint names the codes. The audit log keeps the
-- codes it recorded (history); the API's `levelIndex` and the apps read an old code as its new one.
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

-- 1. The settings.
ALTER TABLE "ambassador_settings" ALTER COLUMN "levels" SET DEFAULT '[{"code":"SPARK","minActiveReferrals":0,"minTopupCoins":0,"commissionBps":200,"reward":{"kind":"NONE"}},{"code":"STAR","minActiveReferrals":5,"minTopupCoins":3000000,"commissionBps":300,"reward":{"kind":"COINS","amount":100000}},{"code":"CONSTELLATION","minActiveReferrals":15,"minTopupCoins":15000000,"commissionBps":400,"reward":{"kind":"VIP_DAYS","amount":7,"vipTier":"VIP_1"}},{"code":"GALAXY","minActiveReferrals":40,"minTopupCoins":60000000,"commissionBps":500,"reward":{"kind":"COINS","amount":1000000}}]';

-- One function for the mapping (dropped at the end), so every statement below uses the same four pairs.
CREATE FUNCTION "_amb_level_new_code"(old_code TEXT) RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE old_code WHEN 'BRONZE' THEN 'SPARK' WHEN 'SILVER' THEN 'STAR'
                       WHEN 'GOLD' THEN 'CONSTELLATION' WHEN 'DIAMOND' THEN 'GALAXY' END
$$;

UPDATE "ambassador_settings" s
   SET "levels" = (
         SELECT jsonb_agg(
                  CASE WHEN "_amb_level_new_code"(e.lvl ->> 'code') IS NULL THEN e.lvl
                       ELSE jsonb_set(e.lvl, '{code}', to_jsonb("_amb_level_new_code"(e.lvl ->> 'code'))) END
                  ORDER BY e.ord)
           FROM jsonb_array_elements(s."levels") WITH ORDINALITY AS e(lvl, ord))
 WHERE jsonb_typeof(s."levels") = 'array'
   AND EXISTS (SELECT 1 FROM jsonb_array_elements(s."levels") e(lvl)
                WHERE e.lvl ->> 'code' IN ('BRONZE', 'SILVER', 'GOLD', 'DIAMOND'))
   AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(s."levels") e(lvl)
                    WHERE e.lvl ->> 'code' IN ('SPARK', 'STAR', 'CONSTELLATION', 'GALAXY'));

-- 2. The rows that name a level: only an old code the settings renamed (the new code there, the old one gone).
CREATE FUNCTION "_amb_level_renamed"(old_code TEXT) RETURNS TEXT LANGUAGE sql STABLE AS $$
  SELECT n.code
    FROM (SELECT "_amb_level_new_code"(old_code) AS code) n
   WHERE n.code IS NOT NULL
     AND EXISTS (SELECT 1 FROM "ambassador_settings" s, jsonb_array_elements(s."levels") e(lvl)
                  WHERE jsonb_typeof(s."levels") = 'array' AND e.lvl ->> 'code' = n.code)
     AND NOT EXISTS (SELECT 1 FROM "ambassador_settings" s, jsonb_array_elements(s."levels") e(lvl)
                      WHERE jsonb_typeof(s."levels") = 'array' AND e.lvl ->> 'code' = old_code)
$$;

UPDATE "ambassadors" SET "level" = "_amb_level_renamed"("level")
 WHERE "level" IN ('BRONZE', 'SILVER', 'GOLD', 'DIAMOND') AND "_amb_level_renamed"("level") IS NOT NULL;
UPDATE "ambassador_commissions" SET "level" = "_amb_level_renamed"("level")
 WHERE "level" IN ('BRONZE', 'SILVER', 'GOLD', 'DIAMOND') AND "_amb_level_renamed"("level") IS NOT NULL;
UPDATE "ambassador_months"
   SET "level_before" = COALESCE("_amb_level_renamed"("level_before"), "level_before"),
       "level_after" = COALESCE("_amb_level_renamed"("level_after"), "level_after"),
       "met_level" = COALESCE("_amb_level_renamed"("met_level"), "met_level")
 WHERE "level_before" IN ('BRONZE', 'SILVER', 'GOLD', 'DIAMOND')
    OR "level_after" IN ('BRONZE', 'SILVER', 'GOLD', 'DIAMOND')
    OR "met_level" IN ('BRONZE', 'SILVER', 'GOLD', 'DIAMOND');

DROP FUNCTION "_amb_level_renamed"(TEXT);
DROP FUNCTION "_amb_level_new_code"(TEXT);
