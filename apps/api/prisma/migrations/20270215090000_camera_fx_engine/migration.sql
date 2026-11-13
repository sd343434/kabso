-- v1.49-live (D228, CONVENTIONS §10.79): the OWNER's switch of the app's camera effects engine (DeepAR or the free
-- ML Kit + MediaPipe engine) is one more row of `site_settings` (key `cameraFxEngine`, value "DEEPAR" / "FREE";
-- absent = DEEPAR). No row is inserted: the default needs none.
ALTER TABLE "site_settings" DROP CONSTRAINT "site_settings_key_check";
ALTER TABLE "site_settings" ADD CONSTRAINT "site_settings_key_check"
    CHECK ("key" IN ('socials', 'topupEnabled', 'cameraFxEngine'));
