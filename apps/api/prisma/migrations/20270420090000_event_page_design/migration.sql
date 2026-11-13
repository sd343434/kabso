-- v1.115-social (D354, owner «اجعل كل الخيارات متاحة», 2026-11-10; CONVENTIONS §10.150): the event page designer.
--
-- 1. `events.design` (JSONB, nullable): the page design `EventPageDesign` chosen per event in the panel (layout,
--    leaderboard style, countdown, card preset, rules button, sections, rewards tiers, motion). Null = today's page:
--    every event that exists now keeps its look (nothing is written here). The shape is checked by the API
--    (`event-design.ts`); the database only requires an object of version 1.
-- 2. Media kind `EVENT_BOARD_BG`: an event's leaderboard background (a still WebP, 1 080 × 1 440, from the panel's event
--    media upload kind `board_background`). CHECK from 20270411090100_dm_archive_groups plus EVENT_BOARD_BG; it has no
--    duration and no poster, which `media_assets_duration_shape` / `media_assets_poster_shape` already require of
--    unlisted kinds.

ALTER TABLE "events" ADD COLUMN "design" JSONB;
ALTER TABLE "events" ADD CONSTRAINT "events_design_shape" CHECK (
  design IS NULL OR (jsonb_typeof(design) = 'object' AND design -> 'v' = '1'::jsonb)
);

ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_kind_known";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_kind_known" CHECK (kind IN ('POST_IMAGE', 'STORY_IMAGE', 'LIVE_COVER', 'LIVE_CHAT_IMAGE', 'LIVE_CHAT_VOICE', 'FAMILY_EMBLEM', 'FAMILY_COVER', 'HOME_BANNER', 'DM_IMAGE', 'DM_VOICE', 'POST_VIDEO', 'REEL_VIDEO', 'VIDEO_POSTER', 'AVATAR', 'PROFILE_COVER', 'LEVEL_RAISE_VIDEO', 'PROFILE_COVER_VIDEO', 'BANNER_VIDEO', 'DM_GROUP_PHOTO', 'EVENT_BOARD_BG'));
