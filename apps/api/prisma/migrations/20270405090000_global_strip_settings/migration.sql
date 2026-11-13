-- v1.85-live (D305, CONVENTIONS §10.115): the global strips «شريط الهدايا» and «شريط الألعاب».
--
-- 1. Owner: «يمكن للمستخدم الغاء شريط الهدايا من اعدادات اي غرفة وايضاً الغاء شريط الألعاب» — two per-account
--    switches, kept with the notification settings so they follow the account to every phone. Default on (no row =
--    all on, as before). The server keeps sending the strips to every live; the app hides the switched-off kind.
--    An existing table: the app role's grants already cover the new columns; no GRANT.
-- 2. Owner: both thresholds editable in the panel — one more row of `site_settings` (key `globalStrips`,
--    `{"giftMinCoins": int, "gameMinTickets": int}`; absent = the server's configuration, 500 000 coins for one gift
--    and 1 000 000 tickets). No row is inserted: the default needs none.

ALTER TABLE "notification_settings"
    ADD COLUMN "gift_strip" BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN "game_strip" BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE "site_settings" DROP CONSTRAINT "site_settings_key_check";
ALTER TABLE "site_settings" ADD CONSTRAINT "site_settings_key_check"
    CHECK ("key" IN ('socials', 'topupEnabled', 'cameraFxEngine', 'levelTickerMinLevel', 'globalStrips'));
