-- v1.61-social (D192, owner 2026-10-31): the public website kabsolive.com (CONVENTIONS §10.55, CP-035).
-- Additive: two new tables. The runtime role gets DML through the default privileges
-- (20261016130000_per_database_runtime_group): no GRANT here.

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

-- The website's settings, key → JSON value (social links, the top-up switch); a missing key is its default.
CREATE TABLE "site_settings" (
    "key" VARCHAR(64) NOT NULL,
    "value" JSONB NOT NULL,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_by_id" UUID,

    CONSTRAINT "site_settings_pkey" PRIMARY KEY ("key"),
    CONSTRAINT "site_settings_key_check" CHECK ("key" IN ('socials.instagram', 'socials.tiktok', 'socials.whatsapp', 'topup.enabled'))
);
