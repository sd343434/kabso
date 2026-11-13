-- D300 (owner 2026-11-07: «مدرسة المحتوى» / Content School, CONVENTIONS §10.111): the first medal whose level needs
-- SEVERAL numbers at once. Five `MedalMetric` values, in their own migration (20270401090100 and 20270401090200 use them) (a new enum value cannot be
-- used in the transaction that adds it):
--  - `ALL_REQUIREMENTS`: the metric of a multi-requirement medal — its value is the highest level whose every
--    `medal_level_requirements` row is met (so each level's `threshold` is the level number itself);
--  - `CREATOR_FOLLOWERS`, `CREATOR_LIKES`, `CREATOR_VIEWS`: the requirement metrics of a content creator (D285 / D295
--    `creator_members`): ACTIVE followers now, likes from other ACTIVE accounts on posts and reels that still stand, and
--    §11.4 views of those posts and reels (never the author's own);
--  - `PK_POINTS` («لاعب الأحكام» / Dares Player, 20270401090200): a host's PK points now (`pk_host_records.points`).
ALTER TYPE "MedalMetric" ADD VALUE 'ALL_REQUIREMENTS';
ALTER TYPE "MedalMetric" ADD VALUE 'CREATOR_FOLLOWERS';
ALTER TYPE "MedalMetric" ADD VALUE 'CREATOR_LIKES';
ALTER TYPE "MedalMetric" ADD VALUE 'CREATOR_VIEWS';
ALTER TYPE "MedalMetric" ADD VALUE 'PK_POINTS';
