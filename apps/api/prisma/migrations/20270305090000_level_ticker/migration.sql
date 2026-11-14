-- v1.62-live (D254, CONVENTIONS §10.92): the OWNER's threshold of the level-up banner shown in every live is one more
-- row of `site_settings` (key `levelTickerMinLevel`, an integer 1–100; absent = 30). No row is inserted: the default
-- needs none.
ALTER TABLE "site_settings" DROP CONSTRAINT "site_settings_key_check";
ALTER TABLE "site_settings" ADD CONSTRAINT "site_settings_key_check"
    CHECK ("key" IN ('socials', 'topupEnabled', 'cameraFxEngine', 'levelTickerMinLevel'));
