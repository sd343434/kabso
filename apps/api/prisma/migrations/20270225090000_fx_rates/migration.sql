-- v1.81-social (D245, CONVENTIONS §10.87; owner 2026-11-02): automatic exchange rates for every country.
-- `fx_rates`: the latest automatic rate per currency (units per 1 USD × 1 000 000) with its source, when it was
-- fetched and the provider's own timestamp; a value that jumped too far from the last good one is HELD next to it for
-- the team's review (the last good value stays in force). `fx_settings`: one row — the OWNER's paid provider «مزوّد
-- أسعار الصرف» (API key sealed like D196 / D222 / D227, last 4 only) and the poller's state (the next fetch, a lease
-- so one instance fetches at a time, the last success / error and the failures in a row for the back-off).
-- `recharge_exchange_rates` (D204) is unchanged: a row there is the admin's MANUAL rate «يدوي», which wins over the
-- automatic one. The runtime role gets DML through the default privileges
-- (20261016130000_per_database_runtime_group): no GRANT.

-- CreateTable
CREATE TABLE "fx_rates" (
    "currency" CHAR(3) NOT NULL,
    "rate_micro" BIGINT NOT NULL,
    "source" VARCHAR(24) NOT NULL,
    "provider_updated_at" TIMESTAMPTZ(3),
    "fetched_at" TIMESTAMPTZ(3) NOT NULL,
    "held_rate_micro" BIGINT,
    "held_source" VARCHAR(24),
    "held_provider_updated_at" TIMESTAMPTZ(3),
    "held_at" TIMESTAMPTZ(3),
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "fx_rates_pkey" PRIMARY KEY ("currency"),
    CONSTRAINT "fx_rates_currency_check" CHECK ("currency" ~ '^[A-Z]{3}$'),
    CONSTRAINT "fx_rates_rate_check" CHECK ("rate_micro" > 0 AND "rate_micro" <= 1000000000000000000),
    CONSTRAINT "fx_rates_source_check" CHECK ("source" IN ('OPEN_ER_API', 'CURRENCYAPI', 'EXCHANGERATE_API')),
    CONSTRAINT "fx_rates_held_check" CHECK (
        ("held_rate_micro" IS NULL AND "held_source" IS NULL AND "held_at" IS NULL)
        OR ("held_rate_micro" > 0 AND "held_rate_micro" <= 1000000000000000000
            AND "held_source" IN ('OPEN_ER_API', 'CURRENCYAPI', 'EXCHANGERATE_API') AND "held_at" IS NOT NULL)
    )
);

-- CreateTable
CREATE TABLE "fx_settings" (
    "id" SMALLINT NOT NULL DEFAULT 1,
    "provider" VARCHAR(24) NOT NULL DEFAULT 'CURRENCYAPI',
    "enabled" BOOLEAN NOT NULL DEFAULT false,
    "api_key_enc" TEXT,
    "api_key_last4" VARCHAR(4),
    "api_key_set_by_id" UUID,
    "api_key_set_at" TIMESTAMPTZ(3),
    "last_test_at" TIMESTAMPTZ(3),
    "last_test_ok" BOOLEAN,
    "last_test_by_id" UUID,
    "last_test" JSONB,
    "next_fetch_at" TIMESTAMPTZ(3),
    "running_until" TIMESTAMPTZ(3),
    "last_attempt_at" TIMESTAMPTZ(3),
    "last_success_at" TIMESTAMPTZ(3),
    "last_source" VARCHAR(24),
    "last_provider_updated_at" TIMESTAMPTZ(3),
    "last_report" JSONB,
    "last_error_at" TIMESTAMPTZ(3),
    "last_error_issue" VARCHAR(32),
    "last_error_detail" VARCHAR(300),
    "failures" INTEGER NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_by_id" UUID,

    CONSTRAINT "fx_settings_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "fx_settings_single_row" CHECK ("id" = 1),
    CONSTRAINT "fx_settings_provider_check" CHECK ("provider" IN ('CURRENCYAPI', 'EXCHANGERATE_API')),
    CONSTRAINT "fx_settings_key_hint_check" CHECK (("api_key_enc" IS NULL) = ("api_key_last4" IS NULL)),
    CONSTRAINT "fx_settings_enabled_check" CHECK (NOT "enabled" OR "api_key_enc" IS NOT NULL),
    CONSTRAINT "fx_settings_failures_check" CHECK ("failures" >= 0),
    CONSTRAINT "fx_settings_last_source_check" CHECK (
        "last_source" IS NULL OR "last_source" IN ('OPEN_ER_API', 'CURRENCYAPI', 'EXCHANGERATE_API'))
);
