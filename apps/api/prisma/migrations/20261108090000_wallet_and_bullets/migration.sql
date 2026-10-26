-- CP-017 (D104, owner 2026-10-26): coins and bullet messages (CONVENTIONS §10.19). A user's coin
-- balance (`wallets`; no row = 0), the ledger of every change (`wallet_ledger`; one row per
-- (reason, reference): a bullet is charged once, an admin grant is one row) and the bullet
-- messages sent from a live to every live (`live_bullets`; the sender's idempotency key). Coins
-- are only granted by an admin on the server (`wallet-admin`); purchases wait for B5. The runtime
-- role gets DML through the default privileges (20261016130000_per_database_runtime_group), so
-- this migration contains no GRANT; the ledger is append-only for it (as `points_ledger`).

-- CreateEnum
CREATE TYPE "wallet_ledger_reason" AS ENUM ('ADMIN_GRANT', 'ADMIN_REVOKE', 'BULLET_MESSAGE');

-- CreateTable
CREATE TABLE "wallets" (
    "user_id" UUID NOT NULL,
    "coins" BIGINT NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "wallets_pkey" PRIMARY KEY ("user_id")
);

-- CreateTable
CREATE TABLE "wallet_ledger" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "delta" BIGINT NOT NULL,
    "balance_after" BIGINT NOT NULL,
    "reason" "wallet_ledger_reason" NOT NULL,
    "reference_id" VARCHAR(64) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "wallet_ledger_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "live_bullets" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "client_id" UUID NOT NULL,
    "room_id" UUID,
    "text" VARCHAR(60) NOT NULL,
    "cost" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "live_bullets_pkey" PRIMARY KEY ("id")
);

-- CreateIndex (a user's ledger, newest first; also the user_id FK index)
CREATE INDEX "wallet_ledger_user_created_idx" ON "wallet_ledger"("user_id", "created_at" DESC);

-- CreateIndex (one ledger row per reason and reference: a bullet is never charged twice)
CREATE UNIQUE INDEX "wallet_ledger_reference_once" ON "wallet_ledger"("reason", "reference_id");

-- CreateIndex
CREATE INDEX "live_bullets_room_idx" ON "live_bullets"("room_id");

-- CreateIndex (clientId is unique per sender: an idempotent retry; also the user_id FK index)
CREATE UNIQUE INDEX "live_bullets_client_once" ON "live_bullets"("user_id", "client_id");

-- AddForeignKey
ALTER TABLE "wallets" ADD CONSTRAINT "wallets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wallet_ledger" ADD CONSTRAINT "wallet_ledger_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_bullets" ADD CONSTRAINT "live_bullets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_bullets" ADD CONSTRAINT "live_bullets_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Balances are whole coins, never negative, and stay exact as JSON numbers (CONVENTIONS §3).
ALTER TABLE "wallets" ADD CONSTRAINT "wallets_coins_range" CHECK (coins BETWEEN 0 AND 9007199254740991);
ALTER TABLE "wallet_ledger" ADD CONSTRAINT "wallet_ledger_delta_nonzero" CHECK (delta <> 0);
ALTER TABLE "wallet_ledger" ADD CONSTRAINT "wallet_ledger_balance_range" CHECK (balance_after BETWEEN 0 AND 9007199254740991);
-- Grants and revokes add or remove coins; a bullet only removes them.
ALTER TABLE "wallet_ledger" ADD CONSTRAINT "wallet_ledger_reason_sign" CHECK (
  (reason = 'ADMIN_GRANT' AND delta > 0) OR (reason IN ('ADMIN_REVOKE', 'BULLET_MESSAGE') AND delta < 0));

-- 1–60 code points (CONVENTIONS §10.19; char_length counts code points); a bullet costs coins.
ALTER TABLE "live_bullets" ADD CONSTRAINT "live_bullets_text_length" CHECK (char_length(text) BETWEEN 1 AND 60);
ALTER TABLE "live_bullets" ADD CONSTRAINT "live_bullets_cost_positive" CHECK (cost > 0);

-- Append-only ledger for the runtime group of THIS database (as points_ledger, 20261020090000).
-- The shadow database of `prisma migrate dev` has no runtime group and is skipped.
DO $$
DECLARE
  grp text := 'kabso_runtime_' || current_database();
BEGIN
  IF to_regclass('public._prisma_migrations') IS NULL THEN
    RAISE NOTICE 'shadow database: runtime grants skipped';
    RETURN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = grp) THEN
    RAISE EXCEPTION 'role "%" does not exist. Run infra/postgres/bootstrap-roles.sql for this database first (docs/DEPLOYMENT.md §5.1).', grp;
  END IF;
  EXECUTE format('REVOKE UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.wallet_ledger FROM %I', grp);
END
$$;
