-- D281b (owner, CONVENTIONS §10.62.2): «هذه كلها اهداف هدايا ولا يوجد اهداف لهدايا الحظ» — two tracks of three targets
-- a day: «الهدايا» (GIFTS: gifts outside the lucky category) and «هدايا الحظ» (LUCKY: lucky gifts), each easy /
-- medium / hard from the host's own history on that track. Owner (same day: today's gift prices are placeholders): the
-- new-host defaults become OWNER-editable (`host_target_settings.new_host_defaults`, NULL = the code's values).
--
-- Rows written by D281 are the gifts track (`track` defaults to GIFTS); their ledger references stay `HT:<level>@<day>`,
-- the lucky track's are `HT:LUCKY:<level>@<day>`.

ALTER TABLE "host_target_assignments" ADD COLUMN "track" VARCHAR(6) NOT NULL DEFAULT 'GIFTS';
ALTER TABLE "host_target_assignments" DROP CONSTRAINT "host_target_assignments_pkey";
ALTER TABLE "host_target_assignments"
    ADD CONSTRAINT "host_target_assignments_pkey" PRIMARY KEY ("user_id", "day", "track", "level");

ALTER TABLE "host_target_assignments" DROP CONSTRAINT "host_target_assignments_shape";
ALTER TABLE "host_target_assignments" ADD CONSTRAINT "host_target_assignments_shape" CHECK (
    "level" IN ('EASY', 'MEDIUM', 'HARD')
    AND "track" IN ('GIFTS', 'LUCKY')
    AND "kind" IN ('GIFT_CHERRIES', 'LUCKY_CHERRIES', 'GIFT_COUNT', 'CATEGORY_COUNT', 'SUPPORTERS', 'GIFT_SENDS',
                   'COMBO', 'GIFT_COMBO', 'LUCKY_GIFT_COUNT', 'LUCKY_SENDS', 'LUCKY_SUPPORTERS', 'LUCKY_COMBO')
    AND ("track" = 'LUCKY') = ("kind" IN ('LUCKY_CHERRIES', 'LUCKY_GIFT_COUNT', 'LUCKY_SENDS', 'LUCKY_SUPPORTERS',
                                          'LUCKY_COMBO'))
    AND ("subject" IS NOT NULL) = ("kind" IN ('GIFT_COUNT', 'CATEGORY_COUNT', 'GIFT_COMBO', 'LUCKY_GIFT_COUNT'))
    AND "code" LIKE 'T.%'
    AND "amount" BETWEEN 1 AND 1000000000
    AND "window_from" >= 0 AND "window_from" < "window_to" AND "window_to" <= 1440
    AND "expected_coins" >= 0 AND "reward_bps" BETWEEN 0 AND 10000 AND "reward_cherries" >= 0
    AND ("paid_at" IS NULL) = ("paid_cherries" IS NULL)
    AND ("paid_cherries" IS NULL OR ("paid_cherries" >= 0 AND "paid_cherries" <= "reward_cherries"))
    AND ("paid_at" IS NULL OR "completed_at" IS NOT NULL));

-- The OWNER's new-host defaults: {kind: [[easy, medium, hard] × 4 bands]} (validated by the API), NULL = the code's.
ALTER TABLE "host_target_settings" ADD COLUMN "new_host_defaults" JSONB;
ALTER TABLE "host_target_settings" ADD CONSTRAINT "host_target_settings_defaults_shape" CHECK (
    "new_host_defaults" IS NULL OR jsonb_typeof("new_host_defaults") = 'object');
