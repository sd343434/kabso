-- v1.112-social (int21, CONVENTIONS §10.143.3; owner «موافق على الاقتراحات», D345 #7 + D344): the app reports where it
-- was installed from (Android: the installer package — Google Play ⇒ PLAY, any other or none ⇒ SIDELOAD; iOS:
-- APP_STORE, TestFlight included) at sign-in and on each token refresh; the session keeps it, and the wallet's
-- «الشحن من الموقع» is offered only to the sources in TOPUP_APP_LINK_SOURCES (default SIDELOAD: the direct APK).
-- Nullable, no backfill: a session that never reported (an older app, the website) has NULL and is not offered the link.
-- A metadata-only change (no table rewrite); the runtime role already has DML on `sessions`.
ALTER TABLE "sessions" ADD COLUMN "install_source" VARCHAR(16);
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_install_source_check"
  CHECK ("install_source" IS NULL OR "install_source" IN ('PLAY', 'APP_STORE', 'SIDELOAD'));
