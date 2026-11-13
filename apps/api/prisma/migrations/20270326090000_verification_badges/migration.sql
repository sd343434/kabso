-- v1.90-social (D293, owner 2026-11-06, CONVENTIONS §10.105): automatic verification badges «شارة التوثيق».
--
-- 1. `verification_badge`: OWNER (black and gold), STAFF (red, the Kabso Team), RECHARGE_AGENT (gold), HOST_AGENT
--    (green), CREATOR (purple), VERIFIED_HOST (blue) — in priority order (the first that applies is shown).
-- 2. `user_verification_badges`: a person's current badge (no row = none), written only by the API's
--    `verification-badges.ts` (the sweeper, the CLI `verification-admin recompute`, and the immediate recomputes on a
--    panel role, a creator activation and an identity-check decision). Audited `verification.badge.change`.
-- 3. `verification_badge_settings`: the OWNER's thresholds (one row; defaults are the owner's: 300 000 000 coins sold
--    and 300 000 000 cherries bought by a recharge agent, more than 30 active hosts and 300 000 000 cherries for a host
--    agent's agency, all in the last 30 days, "more than"). BIGINT end to end.
--
-- The table starts empty: run `verification-admin recompute` once after this migration (DEPLOYMENT §5.73), or wait
-- for the first sweep. The runtime role gets DML through the default privileges (20261016120000_runtime_role_grants),
-- so this migration contains no GRANT.
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

CREATE TYPE "verification_badge" AS ENUM ('OWNER', 'STAFF', 'RECHARGE_AGENT', 'HOST_AGENT', 'CREATOR', 'VERIFIED_HOST');

CREATE TABLE "user_verification_badges" (
    "user_id" UUID NOT NULL,
    "badge" "verification_badge" NOT NULL,
    "since" TIMESTAMPTZ(3) NOT NULL,
    "computed_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "user_verification_badges_pkey" PRIMARY KEY ("user_id")
);
CREATE INDEX "user_verification_badges_badge_idx" ON "user_verification_badges"("badge");
ALTER TABLE "user_verification_badges" ADD CONSTRAINT "user_verification_badges_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "verification_badge_settings" (
    "id" SMALLINT NOT NULL DEFAULT 1,
    "recharge_min_sales_coins" BIGINT NOT NULL DEFAULT 300000000,
    "recharge_min_cherries" BIGINT NOT NULL DEFAULT 300000000,
    "host_agent_min_hosts" INTEGER NOT NULL DEFAULT 30,
    "host_agent_min_cherries" BIGINT NOT NULL DEFAULT 300000000,
    "last_run_at" TIMESTAMPTZ(3),
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_by_id" UUID,

    CONSTRAINT "verification_badge_settings_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "verification_badge_settings_one_row" CHECK ("id" = 1),
    CONSTRAINT "verification_badge_settings_shape" CHECK (
        "recharge_min_sales_coins" BETWEEN 0 AND 1000000000000000
        AND "recharge_min_cherries" BETWEEN 0 AND 1000000000000000
        AND "host_agent_min_hosts" BETWEEN 0 AND 100000
        AND "host_agent_min_cherries" BETWEEN 0 AND 1000000000000000)
);
INSERT INTO "verification_badge_settings" ("id") VALUES (1);
