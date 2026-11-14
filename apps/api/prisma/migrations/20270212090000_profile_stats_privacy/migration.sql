-- v1.77-social (D220, CONVENTIONS §10.74): two privacy switches for the person card's lifetime totals.
-- New columns only (no new table, so no GRANT: the runtime role's privileges on privacy_settings cover
-- them). Constant defaults, so existing rows are not rewritten; a user without a row reads both as false
-- (shown), like the other privacy settings.
ALTER TABLE "privacy_settings"
  ADD COLUMN "hide_cherries_received" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "hide_coins_sent" BOOLEAN NOT NULL DEFAULT false;
