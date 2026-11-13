-- v1.140-social (D390 follow-up, owner «نعم»: «إنهاء العضوية»), CONVENTIONS §10.179.11.
--
-- 1. `ambassadors.ended_at` / `ended_reason` / `ended_by_id`: who ended the membership, when and why (status ENDED;
--    CHECK `ambassadors_shape` re-made with the rule). A re-appointment clears them.
-- 2. `ambassador_months.reward_status` may be VOID: a reward held when the membership ended is not granted (the reward
--    itself is kept for the history).
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

ALTER TABLE "ambassadors" ADD COLUMN "ended_at" TIMESTAMPTZ(3),
ADD COLUMN "ended_reason" VARCHAR(500),
ADD COLUMN "ended_by_id" UUID;
ALTER TABLE "ambassadors" ADD CONSTRAINT "ambassadors_ended_by_id_fkey" FOREIGN KEY ("ended_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "ambassadors" DROP CONSTRAINT "ambassadors_shape";
ALTER TABLE "ambassadors" ADD CONSTRAINT "ambassadors_shape" CHECK (
    "source" IN ('APPLICATION', 'APPOINTED')
    AND ("source" = 'APPLICATION') = ("application_id" IS NOT NULL)
    AND ("status" = 'FROZEN') = ("frozen_at" IS NOT NULL)
    AND ("frozen_at" IS NULL OR "frozen_reason" IS NOT NULL)
    AND ("status" = 'ENDED') = ("ended_at" IS NOT NULL AND "ended_reason" IS NOT NULL)
    AND "under_review" = ("review_reason" IS NOT NULL)
    AND ("country" IS NULL OR "country" ~ '^[A-Z]{2}$'));

ALTER TABLE "ambassador_months" DROP CONSTRAINT "ambassador_months_shape";
ALTER TABLE "ambassador_months" ADD CONSTRAINT "ambassador_months_shape" CHECK (
    "month" ~ '^[0-9]{4}-[0-9]{2}$'
    AND "active_referrals" >= 0 AND "topup_coins" >= 0 AND "commission_cherries" >= 0
    AND "reward_status" IN ('NONE', 'GRANTED', 'HELD', 'VOID')
    AND ("reward_status" = 'GRANTED') = ("granted_at" IS NOT NULL)
    AND ("reward_status" = 'NONE') = ("reward" IS NULL));
