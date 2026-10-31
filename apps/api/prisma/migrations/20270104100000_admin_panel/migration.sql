-- v1.60-social (D191, owner 2026-10-31, CONVENTIONS §10.54, CP-034): the admin panel «لوحة الإدارة». Its second
-- factor (TOTP secret encrypted with ADMIN_TOTP_KEY, hashed single-use recovery codes, lockout), its cookie sessions
-- (only the SHA-256 of the cookie; the CSRF token is an HMAC of it) and the public website's settings (D192 reads them; the OWNER
-- edits them from the panel). The runtime role gets DML through the default privileges: no GRANT here.

CREATE TABLE "admin_credentials" (
    "user_id" UUID NOT NULL,
    "totp_secret_enc" VARCHAR(255),
    "totp_enrolled_at" TIMESTAMPTZ(3),
    "last_totp_step" BIGINT,
    "failed_attempts" INTEGER NOT NULL DEFAULT 0,
    "locked_until" TIMESTAMPTZ(3),
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "admin_credentials_pkey" PRIMARY KEY ("user_id"),
    CONSTRAINT "admin_credentials_failed_attempts_check" CHECK ("failed_attempts" >= 0),
    CONSTRAINT "admin_credentials_enrolled_has_secret" CHECK ("totp_enrolled_at" IS NULL OR "totp_secret_enc" IS NOT NULL)
);

CREATE TABLE "admin_recovery_codes" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "code_hash" CHAR(64) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "used_at" TIMESTAMPTZ(3),

    CONSTRAINT "admin_recovery_codes_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "admin_sessions" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "token_hash" CHAR(64) NOT NULL,
    "stage" VARCHAR(16) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_seen_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "absolute_expires_at" TIMESTAMPTZ(3) NOT NULL,
    "revoked_at" TIMESTAMPTZ(3),
    "ip" VARCHAR(64),

    CONSTRAINT "admin_sessions_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "admin_sessions_stage_check" CHECK ("stage" IN ('PASSWORD', 'ACTIVE'))
);

CREATE TABLE "site_settings" (
    "key" VARCHAR(40) NOT NULL,
    "value" JSONB NOT NULL,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_by_id" UUID,

    CONSTRAINT "site_settings_pkey" PRIMARY KEY ("key"),
    CONSTRAINT "site_settings_key_check" CHECK ("key" IN ('socials', 'topupEnabled'))
);

CREATE UNIQUE INDEX "admin_recovery_codes_code_hash_key" ON "admin_recovery_codes"("code_hash");
CREATE INDEX "admin_recovery_codes_user_idx" ON "admin_recovery_codes"("user_id");
CREATE UNIQUE INDEX "admin_sessions_token_hash_key" ON "admin_sessions"("token_hash");
CREATE INDEX "admin_sessions_user_idx" ON "admin_sessions"("user_id", "created_at" DESC);
CREATE INDEX "admin_sessions_expires_idx" ON "admin_sessions"("expires_at");

ALTER TABLE "admin_credentials" ADD CONSTRAINT "admin_credentials_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "admin_recovery_codes" ADD CONSTRAINT "admin_recovery_codes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "admin_sessions" ADD CONSTRAINT "admin_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
