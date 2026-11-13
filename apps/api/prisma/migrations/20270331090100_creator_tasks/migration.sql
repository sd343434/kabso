-- v1.94-social (D297, owner 2026-11-06: «مهام خاصة بصناع المحتوى، وقيمتها كمهام المضيف» — tasks only for content
-- creators, valued like the host tasks; CONVENTIONS §10.110).
--
-- 1. Who: only creator-programme members (`creator_members`, D285) get CREATORS tasks, as HOSTS tasks are only for
--    hosting-permission holders. A member never gets HOSTS tasks, even with a hosting permission (D295 gives members the
--    permission `live_hosts.source = CREATOR`): the membership decides, in the API.
-- 2. The daily pool: the group CREATOR (audience CREATORS) and `task_pool_bands.creator_count` — how many of a band's
--    daily tasks a creator gets from it first — mirroring `host_count` (2 · 2 · 2 · 3).
-- 3. Five new measurable actions, counted from stored data, never the creator's own actions, ACTIVE counterparts only:
--    REEL_VIEWS_RECEIVED (§11.4 views of the creator's reels), LIKES_RECEIVED (likes on the creator's posts and reels),
--    COMMENT_REPLIES (different comments by other people on the creator's posts the creator replied to),
--    NEW_FOLLOWERS (follows of the creator made in the period that still stand), SHARES_RECEIVED (outside shares and
--    reposts of the creator's posts and reels by other people).
-- 4. The defaults, rewards in cherries mirroring the host tasks band by band (owner: «قيمتها كمهام المضيف»):
--      daily (pool, CREATOR)       targets band 1 · 2 · 3 · 4      rewards                         mirrors
--      P_CR_REEL    REELS                1 · 1 · 2 · 2         4 000 · 6 000 · 8 000 · 10 000   P_HOST_LIVE_30
--      P_CR_POST    POSTS                1 · 1 · 2 · 3         2 000 · 3 000 · 4 000 · 6 000    P_HOST_GUEST
--      P_CR_STORY   STORIES              1 · 2 · 3 · 5         2 000 · 3 000 · 4 000 · 6 000    P_PK_BATTLES
--      P_CR_VIEWS   REEL_VIEWS_RECEIVED  100 · 250 · 500 · 1000  3 000 · 4 000 · 6 000 · 8 000  P_PK_WINS
--      P_CR_LIKES   LIKES_RECEIVED       20 · 50 · 100 · 200   3 000 · 4 000 · 6 000 · 8 000    P_PK_WINS
--      P_CR_REPLIES COMMENT_REPLIES      3 · 5 · 10 · 20       2 000 · 3 000 · 4 000 · 6 000    P_HOST_GUEST
--      weekly (fixed, per band; the owner's figure is band 1, scaled ×1 · ×1.2 · ×1.6 · ×2 like the weekly live minutes)
--      CREATOR_WEEKLY_REELS     REELS                5 · 6 · 8 · 10                 180 000 · 190 000 · 220 000 · 250 000  HOST_LIVE_MINUTES
--      CREATOR_WEEKLY_VIEWS     REEL_VIEWS_RECEIVED  5 000 · 6 000 · 8 000 · 10 000 180 000 · 190 000 · 220 000 · 250 000  HOST_LIVE_MINUTES
--      CREATOR_WEEKLY_FOLLOWERS NEW_FOLLOWERS        50 · 60 · 80 · 100             220 000 · 270 000 · 290 000 · 430 000  HOST_GIFT_COINS
--      CREATOR_WEEKLY_SHARES    SHARES_RECEIVED      20 · 24 · 32 · 40              220 000 · 270 000 · 290 000 · 430 000  HOST_GIFT_COINS
--    The caps are the host tasks' own and SHARED: daily tasks under TASK_DAILY_CAP_CHERRIES, daily and weekly under
--    TASK_MONTHLY_CAP_MINOR (the claim code does not look at the audience). Every value: `task-admin set` / `band`.
--    Existing rows of the same codes are left as the team set them (ON CONFLICT DO NOTHING).
--
-- No new table: no GRANT (the runtime role already has DML on these tables).

-- 2. The creator count of each band (≤ the daily count, like host_count).
ALTER TABLE "task_pool_bands" ADD COLUMN "creator_count" SMALLINT NOT NULL DEFAULT 0;
UPDATE "task_pool_bands" SET "creator_count" = "host_count";
ALTER TABLE "task_pool_bands" DROP CONSTRAINT "task_pool_bands_shape";
ALTER TABLE "task_pool_bands" ADD CONSTRAINT "task_pool_bands_shape" CHECK (
    band BETWEEN 1 AND 4 AND min_level BETWEEN 0 AND 200 AND daily_count BETWEEN 1 AND 12
    AND host_count BETWEEN 0 AND daily_count AND creator_count BETWEEN 0 AND daily_count
    AND char_length(name_ar) BETWEEN 1 AND 40 AND char_length(name_en) BETWEEN 1 AND 40);

-- 3. The new metrics.
ALTER TABLE "task_definitions" DROP CONSTRAINT "task_definitions_shape";
ALTER TABLE "task_definitions" ADD CONSTRAINT "task_definitions_shape" CHECK (
    code ~ '^[A-Z][A-Z0-9_]{1,39}$'
    AND metric IN ('WATCH_LIVES', 'FOLLOWS', 'LIVE_CHAT_MESSAGES', 'GIFT_SENDS', 'HOST_LIVE_MINUTES', 'HOST_GIFT_COINS',
                   'WATCH_MINUTES', 'AUDIO_ROOMS', 'LIVE_TAPS', 'NEW_HOST_GIFTS', 'POSTS', 'REELS', 'STORIES',
                   'POST_COMMENTS', 'DM_FRIENDS', 'DM_VOICE_MESSAGES', 'HOST_GIFTS_RECEIVED', 'HOST_GUESTS',
                   'GIFT_COINS_SENT', 'HOST_LUCKY_COINS', 'HOST_GIFT_CHERRIES', 'HOST_LUCKY_CHERRIES',
                   'GIFT_COUNT_SENT', 'CATEGORY_GIFTS_SENT', 'GIFTED_HOSTS', 'FAMILY_JOIN', 'FAMILY_CHAT_MESSAGES',
                   'PK_BATTLES', 'PK_WINS',
                   'REEL_VIEWS_RECEIVED', 'LIKES_RECEIVED', 'COMMENT_REPLIES', 'NEW_FOLLOWERS', 'SHARES_RECEIVED')
    AND target BETWEEN 1 AND 1000000000 AND reward_cherries BETWEEN 1 AND 1000000000
    AND char_length(name_ar) BETWEEN 1 AND 80 AND char_length(name_en) BETWEEN 1 AND 80);

-- 2. The pool group CREATOR (the rest as 20270115090200_host_lucky_task).
ALTER TABLE "task_definitions" DROP CONSTRAINT "task_definitions_pool_shape";
ALTER TABLE "task_definitions" ADD CONSTRAINT "task_definitions_pool_shape" CHECK (
    (NOT pool AND pool_group IS NULL
        AND ((cardinality(band_targets) = 0 AND cardinality(band_rewards) = 0)
             OR (period IN ('DAILY', 'WEEKLY') AND cardinality(band_targets) = 4 AND cardinality(band_rewards) = 4
                 AND 0 <= ALL (band_targets) AND 1000000000 >= ALL (band_targets)
                 AND 0 <= ALL (band_rewards) AND 1000000000 >= ALL (band_rewards))))
    OR (pool AND period = 'DAILY'
        AND pool_group IN ('WATCH', 'LIVE', 'SOCIAL', 'GIFT', 'CONTENT', 'MESSAGE', 'HOST', 'CREATOR')
        AND cardinality(band_targets) = 4 AND cardinality(band_rewards) = 4
        AND 0 <= ALL (band_targets) AND 1000000000 >= ALL (band_targets)
        AND 0 <= ALL (band_rewards) AND 1000000000 >= ALL (band_rewards)));

-- 4. The defaults (`target` / `reward_cherries` mirror band 4, as every banded row).
INSERT INTO "task_definitions" ("code", "period", "metric", "target", "reward_cherries", "audience", "name_ar", "name_en", "sort_order", "pool", "pool_group", "band_targets", "band_rewards") VALUES
    ('P_CR_REEL', 'DAILY', 'REELS', 2, 10000, 'CREATORS', 'انشر مقاطع ريلز', 'Publish reels', 800, true, 'CREATOR', ARRAY[1, 1, 2, 2], ARRAY[4000, 6000, 8000, 10000]),
    ('P_CR_POST', 'DAILY', 'POSTS', 3, 6000, 'CREATORS', 'انشر منشورات', 'Publish posts', 810, true, 'CREATOR', ARRAY[1, 1, 2, 3], ARRAY[2000, 3000, 4000, 6000]),
    ('P_CR_STORY', 'DAILY', 'STORIES', 5, 6000, 'CREATORS', 'انشر قصصاً', 'Publish stories', 820, true, 'CREATOR', ARRAY[1, 2, 3, 5], ARRAY[2000, 3000, 4000, 6000]),
    ('P_CR_VIEWS', 'DAILY', 'REEL_VIEWS_RECEIVED', 1000, 8000, 'CREATORS', 'مشاهدات ريلزك اليوم', 'Views on your reels today', 830, true, 'CREATOR', ARRAY[100, 250, 500, 1000], ARRAY[3000, 4000, 6000, 8000]),
    ('P_CR_LIKES', 'DAILY', 'LIKES_RECEIVED', 200, 8000, 'CREATORS', 'إعجابات على محتواك', 'Likes on your content', 840, true, 'CREATOR', ARRAY[20, 50, 100, 200], ARRAY[3000, 4000, 6000, 8000]),
    ('P_CR_REPLIES', 'DAILY', 'COMMENT_REPLIES', 20, 6000, 'CREATORS', 'ردّ على تعليقات منشوراتك', 'Reply to comments on your posts', 850, true, 'CREATOR', ARRAY[3, 5, 10, 20], ARRAY[2000, 3000, 4000, 6000]),
    ('CREATOR_WEEKLY_REELS', 'WEEKLY', 'REELS', 10, 250000, 'CREATORS', 'انشر ريلز هذا الأسبوع', 'Publish reels this week', 900, false, NULL, ARRAY[5, 6, 8, 10], ARRAY[180000, 190000, 220000, 250000]),
    ('CREATOR_WEEKLY_VIEWS', 'WEEKLY', 'REEL_VIEWS_RECEIVED', 10000, 250000, 'CREATORS', 'مشاهدات ريلزك هذا الأسبوع', 'Views on your reels this week', 910, false, NULL, ARRAY[5000, 6000, 8000, 10000], ARRAY[180000, 190000, 220000, 250000]),
    ('CREATOR_WEEKLY_FOLLOWERS', 'WEEKLY', 'NEW_FOLLOWERS', 100, 430000, 'CREATORS', 'متابعون جدد هذا الأسبوع', 'New followers this week', 920, false, NULL, ARRAY[50, 60, 80, 100], ARRAY[220000, 270000, 290000, 430000]),
    ('CREATOR_WEEKLY_SHARES', 'WEEKLY', 'SHARES_RECEIVED', 40, 430000, 'CREATORS', 'مشاركات محتواك هذا الأسبوع', 'Shares of your content this week', 930, false, NULL, ARRAY[20, 24, 32, 40], ARRAY[220000, 270000, 290000, 430000])
ON CONFLICT ("code") DO NOTHING;

-- The audience type is shared with the Event Center: events stay EVERYONE or HOSTS (`event-admin` and the panel only
-- offer those; an event board for creators is not built).
ALTER TABLE "events" ADD CONSTRAINT "events_audience_not_creators" CHECK ("audience"::text <> 'CREATORS');
