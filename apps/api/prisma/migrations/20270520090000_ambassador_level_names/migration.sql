-- v1.141-social (D390 follow-up, owner 2026-11-14: «سفراء النجوم»), CONVENTIONS §10.179.6.
--
-- The four default level codes BRONZE / SILVER / GOLD / DIAMOND become SPARK / STAR / CONSTELLATION / GALAXY
-- («شرارة / نجم / كوكبة / مجرّة»). Level codes are free-form (the OWNER edits the list); the apps name the four
-- default codes through their translations and show any other code as it is.
--
-- 1. `ambassador_settings.levels`: the column default (the new codes and numbers, 3.), and the stored list — each level still holding an old
--    default code gets its new one (its numbers and reward unchanged), only when the list holds an old default code
--    and none of the new ones (an OWNER who already used a new code keeps the list as is).
-- 2. `ambassadors.level`, `ambassador_commissions.level`, `ambassador_months.level_before` / `level_after` /
--    `met_level`: an old default code becomes its new one, only when the settings now hold the new code and no
--    longer the old one (so a level never points at a code the list does not have).
--
-- 3. The numbers (owner 2026-11-14: «عمولة شرارة ١.٥٪ ويلي بعدها ٢.٥٪ ويلي بعدها ٣ ٪ ثم ٤٪ — الهدف: شرارة من صفر، نجم ٢٠
--    مليون – ٤٩.٩٩ مليون، كوكبة ٥٠ مليون – ٢٤٩،٩٩ مليون، مجرة ٢٥٠ مليون»): SPARK 1.5 % from 0, STAR 2.5 % from
--    20 000 000 coins of qualifying top-ups a month, CONSTELLATION 3 % from 50 000 000, GALAXY 4 % from 250 000 000; the
--    monthly active-referral requirement 0 at every level (the volume alone decides); the monthly rewards in
--    withdrawable cherries (owner: «يجب ان تكون ارباح السفير بالكرز ليتمكن من سحبهم من وكيل شحن», «نعم» for the rewards;
--    the amounts proposed by the coordinator): STAR 5 000 000, CONSTELLATION 15 000 000, GALAXY 50 000 000. Both the
--    column default and the stored list: a stored level is replaced only while it still equals the shipped default
--    level exactly (code, numbers and reward) — a level the OWNER edited stays — and only when the resulting list
--    still passes the level rules (§10.179.6: the first 0 / 0, each next asking at least as much of both and more of
--    one, the commission never lower), so a mixed list is never left invalid.
--
-- 4. The monthly commission cap (owner 2026-11-14: «ب) إلغاء الحد تماماً»): the column default 0 (= no cap), and the
--    stored cap 50 000 000 → 0 only while it is still the shipped default (an OWNER's cap stays).
-- 5. `cherry_ledger_reason_sign`: AMBASSADOR_REWARD_CHERRIES (added by `20270520085000_ambassador_reward_cherries_enums`)
--    is a credit; the CHECK is re-made from the catalogue, as `20270519090100` did.
--
-- Idempotent: a second run finds no old code to rename, no shipped default to replace, and the sign rule already
-- naming the reason. No CHECK constraint names the codes. The audit log keeps the
-- codes it recorded (history); the API's `levelIndex` and the apps read an old code as its new one.
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

-- 1. The settings.
ALTER TABLE "ambassador_settings" ALTER COLUMN "levels" SET DEFAULT '[{"code":"SPARK","minActiveReferrals":0,"minTopupCoins":0,"commissionBps":150,"reward":{"kind":"NONE"}},{"code":"STAR","minActiveReferrals":0,"minTopupCoins":20000000,"commissionBps":250,"reward":{"kind":"CHERRIES","amount":5000000}},{"code":"CONSTELLATION","minActiveReferrals":0,"minTopupCoins":50000000,"commissionBps":300,"reward":{"kind":"CHERRIES","amount":15000000}},{"code":"GALAXY","minActiveReferrals":0,"minTopupCoins":250000000,"commissionBps":400,"reward":{"kind":"CHERRIES","amount":50000000}}]';
ALTER TABLE "ambassador_settings" ALTER COLUMN "monthly_cap_cherries" SET DEFAULT 0;

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

-- 3. The owner's numbers, level by level, only over the shipped defaults (after the renaming above).
CREATE FUNCTION "_amb_level_new_numbers"(lvl JSONB) RETURNS JSONB LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE lvl
    WHEN '{"code":"SPARK","minActiveReferrals":0,"minTopupCoins":0,"commissionBps":200,"reward":{"kind":"NONE"}}'::jsonb
      THEN '{"code":"SPARK","minActiveReferrals":0,"minTopupCoins":0,"commissionBps":150,"reward":{"kind":"NONE"}}'::jsonb
    WHEN '{"code":"STAR","minActiveReferrals":5,"minTopupCoins":3000000,"commissionBps":300,"reward":{"kind":"COINS","amount":100000}}'::jsonb
      THEN '{"code":"STAR","minActiveReferrals":0,"minTopupCoins":20000000,"commissionBps":250,"reward":{"kind":"CHERRIES","amount":5000000}}'::jsonb
    WHEN '{"code":"CONSTELLATION","minActiveReferrals":15,"minTopupCoins":15000000,"commissionBps":400,"reward":{"kind":"VIP_DAYS","amount":7,"vipTier":"VIP_1"}}'::jsonb
      THEN '{"code":"CONSTELLATION","minActiveReferrals":0,"minTopupCoins":50000000,"commissionBps":300,"reward":{"kind":"CHERRIES","amount":15000000}}'::jsonb
    WHEN '{"code":"GALAXY","minActiveReferrals":40,"minTopupCoins":60000000,"commissionBps":500,"reward":{"kind":"COINS","amount":1000000}}'::jsonb
      THEN '{"code":"GALAXY","minActiveReferrals":0,"minTopupCoins":250000000,"commissionBps":400,"reward":{"kind":"CHERRIES","amount":50000000}}'::jsonb
    ELSE lvl END
$$;

WITH proposed AS (
  SELECT s."id", jsonb_agg("_amb_level_new_numbers"(e.lvl) ORDER BY e.ord) AS levels
    FROM "ambassador_settings" s, jsonb_array_elements(s."levels") WITH ORDINALITY AS e(lvl, ord)
   WHERE jsonb_typeof(s."levels") = 'array'
   GROUP BY s."id"
), valid AS (
  SELECT p."id", p.levels
    FROM proposed p
   WHERE NOT EXISTS (
     SELECT 1
       FROM (SELECT x.ord,
                    (x.lvl ->> 'minActiveReferrals')::numeric AS a,
                    (x.lvl ->> 'minTopupCoins')::numeric AS c,
                    (x.lvl ->> 'commissionBps')::numeric AS b,
                    lag((x.lvl ->> 'minActiveReferrals')::numeric) OVER w AS pa,
                    lag((x.lvl ->> 'minTopupCoins')::numeric) OVER w AS pc,
                    lag((x.lvl ->> 'commissionBps')::numeric) OVER w AS pb
               FROM jsonb_array_elements(p.levels) WITH ORDINALITY AS x(lvl, ord)
             WINDOW w AS (ORDER BY x.ord)) r
      WHERE (r.ord = 1 AND (r.a <> 0 OR r.c <> 0))
         OR (r.ord > 1 AND (r.a < r.pa OR r.c < r.pc OR (r.a = r.pa AND r.c = r.pc) OR r.b < r.pb)))
)
UPDATE "ambassador_settings" s
   SET "levels" = v.levels
  FROM valid v
 WHERE s."id" = v."id" AND s."levels" <> v.levels;

DROP FUNCTION "_amb_level_new_numbers"(JSONB);

-- 4. The monthly cap: off by default (0 = none); an OWNER's cap stays.
UPDATE "ambassador_settings" SET "monthly_cap_cherries" = 0 WHERE "monthly_cap_cherries" = 50000000;

-- 5. The cherry ledger's sign rule: AMBASSADOR_REWARD_CHERRIES is a credit (re-made once; a second run skips it).
DO $$
DECLARE
  def text;
BEGIN
  SELECT pg_get_constraintdef(c.oid) INTO STRICT def
    FROM pg_constraint c
   WHERE c.conrelid = 'cherry_ledger'::regclass AND c.conname = 'cherry_ledger_reason_sign';
  IF position('AMBASSADOR_REWARD_CHERRIES' IN def) = 0 THEN
    ALTER TABLE "cherry_ledger" DROP CONSTRAINT "cherry_ledger_reason_sign";
    EXECUTE format('ALTER TABLE cherry_ledger ADD CONSTRAINT cherry_ledger_reason_sign CHECK ((%s) OR (reason::text = %L AND delta > 0))',
                   substring(def FROM '^CHECK \((.*)\)$'), 'AMBASSADOR_REWARD_CHERRIES');
  END IF;
END
$$;
DROP FUNCTION "_amb_level_renamed"(TEXT);
DROP FUNCTION "_amb_level_new_code"(TEXT);
