-- v1.61-social (D192, owner 2026-10-31): the public website kabsolive.com (CONVENTIONS §10.55, CP-035).
-- Additive: one new table. The runtime role gets DML through the default privileges
-- (20261016130000_per_database_runtime_group): no GRANT here.
--
-- Integration note (KL-069, before any deploy): the website's settings table `site_settings` is created once, by
-- D191's 20270104100000_admin_panel (one module and table for the panel and the website, CONVENTIONS §10.54.6).
-- This migration (which also created it) and the removed 20270106090000_website_enums (the `SITE_SETTINGS` admin
-- permission, no longer used) had never run on any database when they were adjusted.

-- «أبلغني عند الإطلاق»: one row per normalized email (trimmed + lowercase); a repeated sign-up changes nothing.
CREATE TABLE "waitlist_signups" (
    "id" UUID NOT NULL,
    "email" VARCHAR(254) NOT NULL,
    "locale" VARCHAR(8) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "waitlist_signups_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "waitlist_signups_email_check" CHECK ("email" = lower(btrim("email")) AND "email" LIKE '%_@_%'),
    CONSTRAINT "waitlist_signups_locale_check" CHECK ("locale" IN ('ar', 'en'))
);

CREATE UNIQUE INDEX "waitlist_signups_email_key" ON "waitlist_signups"("email");
CREATE INDEX "waitlist_signups_created_at_idx" ON "waitlist_signups"("created_at");
