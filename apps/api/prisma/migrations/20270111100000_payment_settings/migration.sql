-- v1.64-social (D196, owner 2026-10-31): the OWNER enters the Stripe keys in the admin panel «الدفع (Stripe)»
-- instead of the server environment (CONVENTIONS §10.53.1). Additive: one new table, one row at most. The runtime
-- role gets DML through the default privileges (20261016130000_per_database_runtime_group): no GRANT here.
-- No backfill: without a row the env keys (STRIPE_SECRET_KEY / STRIPE_WEBHOOK_SECRET) apply as before.

CREATE TABLE "payment_settings" (
    "id" SMALLINT NOT NULL DEFAULT 1,
    -- AES-256-GCM sealed (`v1.<iv>.<tag>.<ciphertext>`, key HKDF `payment-settings/v1` from ADMIN_TOTP_KEY).
    "secret_key_enc" TEXT,
    "secret_key_prefix" VARCHAR(7),
    "secret_key_last4" VARCHAR(4),
    "secret_key_set_by_id" UUID,
    "secret_key_set_at" TIMESTAMPTZ(3),
    "webhook_secret_enc" TEXT,
    "webhook_secret_last4" VARCHAR(4),
    "webhook_secret_set_by_id" UUID,
    "webhook_secret_set_at" TIMESTAMPTZ(3),
    -- The webhook secret in use before the last rotation, accepted until `previous_webhook_secret_until` (10 min).
    "previous_webhook_secret_enc" TEXT,
    "previous_webhook_secret_until" TIMESTAMPTZ(3),
    "publishable_key" VARCHAR(260),
    -- Null: the server's value (STRIPE_BANK_TRANSFER_ENABLED, STRIPE_STATEMENT_DESCRIPTOR_SUFFIX,
    -- STRIPE_DISPUTE_AUTO_SUBMIT, TOPUP_APP_LINK_ENABLED). An empty suffix = explicitly none.
    "bank_transfer_enabled" BOOLEAN,
    "statement_descriptor_suffix" VARCHAR(10),
    "dispute_auto_submit" BOOLEAN,
    "app_link_enabled" BOOLEAN,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_by_id" UUID,

    CONSTRAINT "payment_settings_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "payment_settings_single_row" CHECK ("id" = 1),
    -- The two secrets are a pair: both stored or neither (a key without its webhook secret is never live).
    CONSTRAINT "payment_settings_keys_pair" CHECK (("secret_key_enc" IS NULL) = ("webhook_secret_enc" IS NULL)),
    CONSTRAINT "payment_settings_secret_key_hint" CHECK (
        ("secret_key_enc" IS NULL AND "secret_key_prefix" IS NULL AND "secret_key_last4" IS NULL)
        OR ("secret_key_enc" IS NOT NULL AND "secret_key_prefix" IN ('sk_live', 'sk_test', 'rk_live', 'rk_test')
            AND char_length("secret_key_last4") = 4)),
    CONSTRAINT "payment_settings_webhook_hint" CHECK (
        ("webhook_secret_enc" IS NULL) = ("webhook_secret_last4" IS NULL)),
    CONSTRAINT "payment_settings_publishable_key" CHECK (
        "publishable_key" IS NULL OR "publishable_key" ~ '^pk_(test|live)_[A-Za-z0-9_]{8,250}$'),
    CONSTRAINT "payment_settings_descriptor_suffix" CHECK (
        "statement_descriptor_suffix" IS NULL OR "statement_descriptor_suffix" ~ '^[A-Za-z0-9 ]{0,10}$')
);
