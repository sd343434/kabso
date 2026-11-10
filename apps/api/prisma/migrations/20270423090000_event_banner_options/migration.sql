-- v1.119-social (D359, CONVENTIONS §10.154): «بانر صفحة البث» in the event wizard.
--
-- Owner: events reach the Live hub only through the existing home banner carousel — the admin uploads the event's
-- banner in the event itself and turns it on or off. `banner_enabled` (default true = as before: a published event
-- with a banner picture has its banner) takes the banner down while keeping the picture; `banner_before_start`
-- (default false = as before: shown from the event's start) shows it from the publish time so an upcoming event is
-- announced. An existing table: the app role's grants already cover the new columns; no GRANT. Metadata-only on
-- PostgreSQL 11+ (constant defaults): no table rewrite.

ALTER TABLE "events"
    ADD COLUMN "banner_enabled" BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN "banner_before_start" BOOLEAN NOT NULL DEFAULT false;
