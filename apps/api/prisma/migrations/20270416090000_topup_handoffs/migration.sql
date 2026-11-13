-- v1.109-social (D344, CONVENTIONS §10.143; owner 2026-11-09: «اريد جعل الشحن من الموقع يفتح من نفس التطبيق ويدخل
-- اليوزر والباسورد تلقائي»): the app mints a one-time code (`POST /wallet/topup-session`) that the website top-up
-- page exchanges once (`POST /topup/handoff`) for its own short web session — never a password. Only the SHA-256 of the
-- code is stored; it lives 60 seconds and is redeemed once.
-- The runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group): no GRANT here.
CREATE TABLE "topup_handoffs" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "session_id" UUID NOT NULL,
    "code_hash" CHAR(64) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "consumed_at" TIMESTAMPTZ(3),
    "web_session_id" UUID,

    CONSTRAINT "topup_handoffs_pkey" PRIMARY KEY ("id"),
    -- At most 60 seconds (the contract's upper bound), never already expired when written.
    CONSTRAINT "topup_handoffs_ttl_check"
      CHECK ("expires_at" > "created_at" AND "expires_at" <= "created_at" + INTERVAL '60 seconds'),
    CONSTRAINT "topup_handoffs_code_hash_check" CHECK ("code_hash" ~ '^[0-9a-f]{64}$'),
    -- A web session is recorded only on a redeemed code.
    CONSTRAINT "topup_handoffs_web_session_check" CHECK ("web_session_id" IS NULL OR "consumed_at" IS NOT NULL)
);

CREATE UNIQUE INDEX "topup_handoffs_code_hash_key" ON "topup_handoffs"("code_hash");
CREATE INDEX "topup_handoffs_user_idx" ON "topup_handoffs"("user_id");
CREATE INDEX "topup_handoffs_session_idx" ON "topup_handoffs"("session_id");

ALTER TABLE "topup_handoffs" ADD CONSTRAINT "topup_handoffs_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "topup_handoffs" ADD CONSTRAINT "topup_handoffs_session_id_fkey"
  FOREIGN KEY ("session_id") REFERENCES "sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
