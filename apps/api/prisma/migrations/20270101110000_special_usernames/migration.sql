-- v1.54-social (D185, owner 2026-10-30): the special-username layer «يوزر مميز» (CONVENTIONS §10.48.1, CP-028).
-- `user_profiles.username` keeps meaning "the username shown now"; while a special username is ACTIVE it is the
-- special one and the person's own (base) username is kept here and stays reserved for them. When it ends (expiry,
-- revocation, an agent's suspension) the profile goes back to the base username and the special one stays
-- reserved for the person (GRACE) for SPECIAL_USERNAME_GRACE_DAYS, then is released — except `coin` + digits (the
-- recharge agents' codes), which are never released. Additive: existing usernames are not touched.

CREATE TYPE "special_username_source" AS ENUM ('RECHARGE_AGENT', 'ADMIN_GIFT', 'PURCHASE');
CREATE TYPE "special_username_status" AS ENUM ('ACTIVE', 'GRACE', 'ENDED');

CREATE TABLE "special_usernames" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "username" VARCHAR(30) NOT NULL,
    "base_username" VARCHAR(30) NOT NULL,
    "source" "special_username_source" NOT NULL,
    "status" "special_username_status" NOT NULL DEFAULT 'ACTIVE',
    "locked" BOOLEAN NOT NULL DEFAULT true,
    "granted_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ(3),
    "grace_until" TIMESTAMPTZ(3),
    "ended_at" TIMESTAMPTZ(3),
    "end_reason" VARCHAR(20),
    "reason" VARCHAR(500),

    CONSTRAINT "special_usernames_pkey" PRIMARY KEY ("id")
);

-- One ACTIVE special username per person; a name is held by one row while ACTIVE or in GRACE; a base username
-- is held by one ACTIVE row; a `coin` name is never given to another row.
CREATE UNIQUE INDEX "special_usernames_one_active" ON "special_usernames"("user_id") WHERE status = 'ACTIVE';
CREATE UNIQUE INDEX "special_usernames_name_held" ON "special_usernames"("username") WHERE status IN ('ACTIVE', 'GRACE');
CREATE UNIQUE INDEX "special_usernames_base_held" ON "special_usernames"("base_username") WHERE status = 'ACTIVE';
CREATE UNIQUE INDEX "special_usernames_coin_once" ON "special_usernames"("username") WHERE username ~ '^coin[0-9]+$';
CREATE INDEX "special_usernames_user_idx" ON "special_usernames"("user_id", "granted_at" DESC);
CREATE INDEX "special_usernames_due_idx" ON "special_usernames"("status", "expires_at", "grace_until");

ALTER TABLE "special_usernames" ADD CONSTRAINT "special_usernames_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "special_usernames" ADD CONSTRAINT "special_usernames_shape" CHECK (
  username <> base_username
  AND ((status = 'ACTIVE') = (ended_at IS NULL))
  AND (status <> 'ACTIVE' OR grace_until IS NULL));
