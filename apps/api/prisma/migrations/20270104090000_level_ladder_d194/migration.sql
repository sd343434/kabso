-- D194 (owner, 2026-10-31): the level ladder repriced for cheap coins (retail 1 000 000 coins =
-- $12.50). Level 100 = 2 000 840 500 points = 20 008 405 000 coins ≈ $250 105 (CONVENTIONS §10.57,
-- `level-preset.ts`, whose spec checks the VALUES below row for row).
--
-- Publishing is an admin action (CP-005 §4); the owner ordered this ladder, so this migration
-- publishes it ONCE as an audited system change (audit_logs, actor NULL, via 'migration'), in every
-- category (all four are coin-valued). A category's on/off switch is not touched. Open DRAFTS stay
-- drafts (a draft cannot be archived, CHECK level_category_versions_published_complete); their
-- version numbers are listed in the audit row (`openDrafts`) — re-check before publishing one.
--
-- Nobody's level drops (owner D169): `current_level` is kept, and each user gets
-- `carried_points` — the level points credited at a ladder change so that
-- `total_points + carried_points` sits at the kept level's NEW threshold plus the points they had
-- already made inside that level (capped below the next level). Progress then follows the new
-- ladder from there. `total_points` (Σ ledger) is unchanged.

ALTER TABLE "user_level_states" ADD COLUMN "carried_points" BIGINT NOT NULL DEFAULT 0;
ALTER TABLE "user_level_states" ADD CONSTRAINT "user_level_states_carried_points_check"
  CHECK ("carried_points" >= 0);

CREATE TEMP TABLE "d194_ladder" (
  "level_number" INTEGER PRIMARY KEY,
  "name_ar" VARCHAR(40) NOT NULL,
  "name_en" VARCHAR(40) NOT NULL,
  "required_points" BIGINT NOT NULL,
  "icon_key" VARCHAR(64) NOT NULL
);

INSERT INTO "d194_ladder" ("level_number", "name_ar", "name_en", "required_points", "icon_key") VALUES
  (1, 'حديدي', 'Iron', 0, 'tier_01'),
  (2, 'حديدي', 'Iron', 4500, 'tier_01'),
  (3, 'حديدي', 'Iron', 9000, 'tier_01'),
  (4, 'حديدي', 'Iron', 13500, 'tier_01'),
  (5, 'حديدي', 'Iron', 18000, 'tier_01'),
  (6, 'حديدي', 'Iron', 22500, 'tier_01'),
  (7, 'حديدي', 'Iron', 27000, 'tier_01'),
  (8, 'حديدي', 'Iron', 31500, 'tier_01'),
  (9, 'حديدي', 'Iron', 36000, 'tier_01'),
  (10, 'برونزي', 'Bronze', 40500, 'tier_02'),
  (11, 'برونزي', 'Bronze', 60500, 'tier_02'),
  (12, 'برونزي', 'Bronze', 80500, 'tier_02'),
  (13, 'برونزي', 'Bronze', 100500, 'tier_02'),
  (14, 'برونزي', 'Bronze', 120500, 'tier_02'),
  (15, 'برونزي', 'Bronze', 140500, 'tier_02'),
  (16, 'برونزي', 'Bronze', 160500, 'tier_02'),
  (17, 'برونزي', 'Bronze', 180500, 'tier_02'),
  (18, 'برونزي', 'Bronze', 200500, 'tier_02'),
  (19, 'برونزي', 'Bronze', 220500, 'tier_02'),
  (20, 'فضي', 'Silver', 240500, 'tier_03'),
  (21, 'فضي', 'Silver', 340500, 'tier_03'),
  (22, 'فضي', 'Silver', 440500, 'tier_03'),
  (23, 'فضي', 'Silver', 540500, 'tier_03'),
  (24, 'فضي', 'Silver', 640500, 'tier_03'),
  (25, 'فضي', 'Silver', 740500, 'tier_03'),
  (26, 'فضي', 'Silver', 840500, 'tier_03'),
  (27, 'فضي', 'Silver', 940500, 'tier_03'),
  (28, 'فضي', 'Silver', 1040500, 'tier_03'),
  (29, 'فضي', 'Silver', 1140500, 'tier_03'),
  (30, 'ذهبي', 'Gold', 1240500, 'tier_04'),
  (31, 'ذهبي', 'Gold', 1600500, 'tier_04'),
  (32, 'ذهبي', 'Gold', 1960500, 'tier_04'),
  (33, 'ذهبي', 'Gold', 2320500, 'tier_04'),
  (34, 'ذهبي', 'Gold', 2680500, 'tier_04'),
  (35, 'ذهبي', 'Gold', 3040500, 'tier_04'),
  (36, 'ذهبي', 'Gold', 3400500, 'tier_04'),
  (37, 'ذهبي', 'Gold', 3760500, 'tier_04'),
  (38, 'ذهبي', 'Gold', 4120500, 'tier_04'),
  (39, 'ذهبي', 'Gold', 4480500, 'tier_04'),
  (40, 'زمردي', 'Emerald', 4840500, 'tier_05'),
  (41, 'زمردي', 'Emerald', 5940500, 'tier_05'),
  (42, 'زمردي', 'Emerald', 7040500, 'tier_05'),
  (43, 'زمردي', 'Emerald', 8140500, 'tier_05'),
  (44, 'زمردي', 'Emerald', 9240500, 'tier_05'),
  (45, 'زمردي', 'Emerald', 10340500, 'tier_05'),
  (46, 'زمردي', 'Emerald', 11440500, 'tier_05'),
  (47, 'زمردي', 'Emerald', 12540500, 'tier_05'),
  (48, 'زمردي', 'Emerald', 13640500, 'tier_05'),
  (49, 'زمردي', 'Emerald', 14740500, 'tier_05'),
  (50, 'ياقوتي', 'Sapphire', 15840500, 'tier_06'),
  (51, 'ياقوتي', 'Sapphire', 19040500, 'tier_06'),
  (52, 'ياقوتي', 'Sapphire', 22240500, 'tier_06'),
  (53, 'ياقوتي', 'Sapphire', 25440500, 'tier_06'),
  (54, 'ياقوتي', 'Sapphire', 28640500, 'tier_06'),
  (55, 'ياقوتي', 'Sapphire', 31840500, 'tier_06'),
  (56, 'ياقوتي', 'Sapphire', 35040500, 'tier_06'),
  (57, 'ياقوتي', 'Sapphire', 38240500, 'tier_06'),
  (58, 'ياقوتي', 'Sapphire', 41440500, 'tier_06'),
  (59, 'ياقوتي', 'Sapphire', 44640500, 'tier_06'),
  (60, 'وردي', 'Rose', 47840500, 'tier_07'),
  (61, 'وردي', 'Rose', 61440500, 'tier_07'),
  (62, 'وردي', 'Rose', 75040500, 'tier_07'),
  (63, 'وردي', 'Rose', 88640500, 'tier_07'),
  (64, 'وردي', 'Rose', 102240500, 'tier_07'),
  (65, 'وردي', 'Rose', 115840500, 'tier_07'),
  (66, 'وردي', 'Rose', 129440500, 'tier_07'),
  (67, 'وردي', 'Rose', 143040500, 'tier_07'),
  (68, 'وردي', 'Rose', 156640500, 'tier_07'),
  (69, 'وردي', 'Rose', 170240500, 'tier_07'),
  (70, 'فيروزي', 'Turquoise', 183840500, 'tier_08'),
  (71, 'فيروزي', 'Turquoise', 197440500, 'tier_08'),
  (72, 'فيروزي', 'Turquoise', 211040500, 'tier_08'),
  (73, 'فيروزي', 'Turquoise', 224640500, 'tier_08'),
  (74, 'فيروزي', 'Turquoise', 238240500, 'tier_08'),
  (75, 'فيروزي', 'Turquoise', 251840500, 'tier_08'),
  (76, 'فيروزي', 'Turquoise', 265440500, 'tier_08'),
  (77, 'فيروزي', 'Turquoise', 279040500, 'tier_08'),
  (78, 'فيروزي', 'Turquoise', 292640500, 'tier_08'),
  (79, 'فيروزي', 'Turquoise', 306240500, 'tier_08'),
  (80, 'ياقوت أحمر', 'Ruby', 319840500, 'tier_09'),
  (81, 'ياقوت أحمر', 'Ruby', 378840500, 'tier_09'),
  (82, 'ياقوت أحمر', 'Ruby', 437840500, 'tier_09'),
  (83, 'ياقوت أحمر', 'Ruby', 496840500, 'tier_09'),
  (84, 'ياقوت أحمر', 'Ruby', 555840500, 'tier_09'),
  (85, 'ياقوت أحمر', 'Ruby', 614840500, 'tier_09'),
  (86, 'ياقوت أحمر', 'Ruby', 673840500, 'tier_09'),
  (87, 'ياقوت أحمر', 'Ruby', 732840500, 'tier_09'),
  (88, 'ياقوت أحمر', 'Ruby', 791840500, 'tier_09'),
  (89, 'ياقوت أحمر', 'Ruby', 850840500, 'tier_09'),
  (90, 'ماسي', 'Diamond', 909840500, 'tier_10'),
  (91, 'ماسي', 'Diamond', 968840500, 'tier_10'),
  (92, 'ماسي', 'Diamond', 1027840500, 'tier_10'),
  (93, 'ماسي', 'Diamond', 1086840500, 'tier_10'),
  (94, 'ماسي', 'Diamond', 1145840500, 'tier_10'),
  (95, 'ماسي', 'Diamond', 1204840500, 'tier_10'),
  (96, 'ماسي', 'Diamond', 1263840500, 'tier_10'),
  (97, 'ماسي', 'Diamond', 1322840500, 'tier_10'),
  (98, 'ماسي', 'Diamond', 1381840500, 'tier_10'),
  (99, 'ماسي', 'Diamond', 1440840500, 'tier_10'),
  (100, 'أسطوري', 'Legend', 2000840500, 'tier_11');

DO $$
DECLARE
  c RECORD;
  old_version RECORD;
  new_id UUID;
  next_number INTEGER;
  drafts INTEGER[];
  users INTEGER;
  carried INTEGER;
BEGIN
  FOR c IN SELECT "id", "code", "published_version_id" FROM "level_categories" ORDER BY "code" FOR UPDATE LOOP
    SELECT "id", "version_number", "reversal_policy", "lucky_gifts_count_as_support"
      INTO old_version FROM "level_category_versions" WHERE "id" = c."published_version_id";

    SELECT COALESCE(array_agg("version_number" ORDER BY "version_number"), '{}') INTO drafts
      FROM "level_category_versions" WHERE "category_id" = c."id" AND "status" = 'DRAFT';
    UPDATE "level_category_versions" SET "status" = 'ARCHIVED', "updated_at" = CURRENT_TIMESTAMP
     WHERE "id" = old_version."id";

    SELECT COALESCE(max("version_number"), 0) + 1 INTO next_number
      FROM "level_category_versions" WHERE "category_id" = c."id";
    new_id := gen_random_uuid();
    INSERT INTO "level_category_versions" ("id", "category_id", "version_number", "status", "multiplier",
        "value_unit", "reversal_policy", "lucky_gifts_count_as_support", "published_at", "updated_at")
      VALUES (new_id, c."id", next_number, 'PUBLISHED', 0.1, 'COIN',
        COALESCE(old_version."reversal_policy", 'REVERSE_POINTS'),
        COALESCE(old_version."lucky_gifts_count_as_support", false),
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
    INSERT INTO "level_definitions" ("id", "version_id", "level_number", "name_ar", "name_en", "required_points", "icon_key")
      SELECT gen_random_uuid(), new_id, "level_number", "name_ar", "name_en", "required_points", "icon_key"
        FROM "d194_ladder";
    UPDATE "level_categories" SET "published_version_id" = new_id, "updated_at" = CURRENT_TIMESTAMP
     WHERE "id" = c."id";

    -- The kept level n: the stored level (every new threshold is above the old one, so the points
    -- never reach higher on the new ladder). x = points already made inside level n on the old
    -- ladder, at most one below the new step.
    WITH s AS (
      SELECT st."id", st."total_points" AS total, st."carried_points" AS old_carry,
             GREATEST(st."current_level",
               (SELECT max(l."level_number") FROM "d194_ladder" l WHERE l."required_points" <= st."total_points")) AS n
        FROM "user_level_states" st
       WHERE st."category_id" = c."id" AND st."current_level" IS NOT NULL
    ), k AS (
      SELECT s."id", s.total, s.n, nl."required_points" AS thr_new,
             CASE WHEN ol."required_points" IS NULL OR nn."required_points" IS NULL THEN 0
                  ELSE LEAST(GREATEST(s.total + s.old_carry - ol."required_points", 0),
                             nn."required_points" - nl."required_points" - 1) END AS x
        FROM s
        LEFT JOIN "d194_ladder" nl ON nl."level_number" = s.n
        LEFT JOIN "d194_ladder" nn ON nn."level_number" = s.n + 1
        LEFT JOIN "level_definitions" ol ON ol."version_id" = old_version."id" AND ol."level_number" = s.n
    )
    UPDATE "user_level_states" u
       SET "carried_points" = CASE WHEN k.thr_new IS NULL OR k.total >= k.thr_new THEN 0
                                   ELSE GREATEST(k.thr_new + k.x - k.total, 0) END,
           "current_level" = k.n
      FROM k WHERE u."id" = k."id";

    UPDATE "user_level_states" SET "version_id" = new_id, "calculated_at" = CURRENT_TIMESTAMP
     WHERE "category_id" = c."id";
    SELECT count(*), count(*) FILTER (WHERE "carried_points" > 0) INTO users, carried
      FROM "user_level_states" WHERE "category_id" = c."id";

    INSERT INTO "audit_logs" ("id", "actor_user_id", "action", "target_type", "target_id", "metadata") VALUES
      (gen_random_uuid(), NULL, 'levels.version.create', 'level_version', new_id::text,
       jsonb_build_object('category', c."code", 'versionNumber', next_number,
         'preset', 'owner-d194-2026-10-31', 'decision', 'D194', 'via', 'migration')),
      (gen_random_uuid(), NULL, 'levels.version.publish', 'level_version', new_id::text,
       jsonb_build_object('category', c."code", 'versionNumber', next_number,
         'previousVersionNumber', old_version."version_number", 'recalculation', 'PRESERVE_POINTS',
         'users', users, 'adjusted', 0, 'levelChanges', 0, 'carriedUsers', carried,
         'openDrafts', to_jsonb(drafts), 'preset', 'owner-d194-2026-10-31',
         'decision', 'D194', 'via', 'migration'));
  END LOOP;
END $$;

DROP TABLE "d194_ladder";
