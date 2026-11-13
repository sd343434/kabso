-- v1.75-social (D222, owner 2026-11-01): the OWNER enters and turns on the media storage (Cloudflare R2, or any
-- S3-compatible service) in the admin panel «التخزين (R2 / S3)» instead of the server environment
-- (CONVENTIONS §10.72). Additive: one new table, one row at most. The runtime role gets DML through the default
-- privileges (20261016130000_per_database_runtime_group): no GRANT here. No backfill: without a row, or with the
-- switch off, the env settings (S3_*, MEDIA_PUBLIC_BASE_URL, MEDIA_UPLOADS_ENABLED) apply as before.

CREATE TABLE "storage_settings" (
    "id" SMALLINT NOT NULL DEFAULT 1,
    -- «تفعيل»: on → uploads use these settings (over the env); off → the env settings (or 503 as before).
    "enabled" BOOLEAN NOT NULL DEFAULT false,
    -- R2: the endpoint is https://<account_id>.r2.cloudflarestorage.com, region `auto`. S3: `endpoint` + `region`.
    "provider" VARCHAR(8) NOT NULL DEFAULT 'R2',
    "account_id" VARCHAR(32),
    "endpoint" VARCHAR(300),
    "region" VARCHAR(64),
    "force_path_style" BOOLEAN NOT NULL DEFAULT false,
    -- AES-256-GCM sealed (`v1.<iv>.<tag>.<ciphertext>`, key HKDF `storage-settings/v1` from ADMIN_TOTP_KEY); only
    -- the last 4 characters in clear.
    "access_key_id_enc" TEXT,
    "access_key_id_last4" VARCHAR(4),
    "access_key_id_set_by_id" UUID,
    "access_key_id_set_at" TIMESTAMPTZ(3),
    "secret_access_key_enc" TEXT,
    "secret_access_key_last4" VARCHAR(4),
    "secret_access_key_set_by_id" UUID,
    "secret_access_key_set_at" TIMESTAMPTZ(3),
    -- `media/` (public through `public_base_url`); `uploads/` and `private/` (never public) in the private bucket.
    "public_bucket" VARCHAR(63),
    "public_base_url" VARCHAR(300),
    "private_bucket" VARCHAR(63),
    -- The last «اختبار الاتصال» (the steps and the target as JSON; never a secret).
    "last_test_at" TIMESTAMPTZ(3),
    "last_test_ok" BOOLEAN,
    "last_test_by_id" UUID,
    "last_test" JSONB,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_by_id" UUID,

    CONSTRAINT "storage_settings_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "storage_settings_single_row" CHECK ("id" = 1),
    CONSTRAINT "storage_settings_provider" CHECK ("provider" IN ('R2', 'S3')),
    CONSTRAINT "storage_settings_account_id" CHECK ("account_id" IS NULL OR "account_id" ~ '^[a-f0-9]{32}$'),
    CONSTRAINT "storage_settings_buckets" CHECK (
        ("public_bucket" IS NULL OR "public_bucket" ~ '^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$')
        AND ("private_bucket" IS NULL OR "private_bucket" ~ '^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$')
        AND ("public_bucket" IS NULL OR "private_bucket" IS NULL OR "public_bucket" <> "private_bucket")),
    CONSTRAINT "storage_settings_key_hints" CHECK (
        ("access_key_id_enc" IS NULL) = ("access_key_id_last4" IS NULL)
        AND ("secret_access_key_enc" IS NULL) = ("secret_access_key_last4" IS NULL)),
    -- On only when complete (the private bucket is required: ID photos and payment proofs never go public).
    CONSTRAINT "storage_settings_enabled_complete" CHECK (
        NOT "enabled" OR (
            "access_key_id_enc" IS NOT NULL AND "secret_access_key_enc" IS NOT NULL
            AND "public_bucket" IS NOT NULL AND "public_base_url" IS NOT NULL AND "private_bucket" IS NOT NULL
            AND ("provider" <> 'R2' OR "account_id" IS NOT NULL)))
);
