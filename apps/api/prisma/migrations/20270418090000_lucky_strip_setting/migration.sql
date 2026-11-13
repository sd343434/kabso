-- v1.111-live (D347, CONVENTIONS §10.146): the viewer's switch «إخفاء أشرطة الفوز» / "Hide win banners".
--
-- Owner («نعم موافق», 2026-11-09): a per-user option to hide the global lucky banner (a ×250 / ×500 / ×1000 win in
-- another live). Kept with the other global strips' switches (D305 `gift_strip` / `game_strip`) so it follows the
-- account to every phone. Default true = shown (no row = shown, as before). The server keeps sending the banner to
-- every live; the app hides it. An existing table: the app role's grants already cover the new column; no GRANT.
-- Metadata-only on PostgreSQL 11+ (a constant default): no table rewrite.

ALTER TABLE "notification_settings"
    ADD COLUMN "lucky_strip" BOOLEAN NOT NULL DEFAULT true;
