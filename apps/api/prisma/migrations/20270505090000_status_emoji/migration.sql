-- v1.130-social (D376, owner 2026-11-12: the «الحالة» status emoji pack — animated emoji that rise over the picture
-- like bubbles; free packs and «المميزة» sold for 100 000 coins for 30 days), CONVENTIONS §10.167.
--
-- 1. `users.status_emoji_id`: the status worn (`<pack>.<emoji>`; the allow-list is the API's
--    `status-emoji-catalogue.ts`, not the database, so a new emoji needs no migration). NULL = none.
-- 2. `status_pack_offers`: the price of a status pack per duration (coins), seeded with the owner's «المميزة».
-- 3. `user_status_packs`: the packs a person holds and until when (a renewal adds days: max(now, end) + days).
-- 4. `status_pack_purchases`: append-only for the runtime group (KL-013); `(user_id, idempotency_key)` unique.
-- 5. `wallet_ledger_reason` + `STATUS_PACK_PURCHASE` (added in its own statement: the new value is not used here), a
--    debit in the ledger's sign rule `wallet_ledger_reason_sign`.
--
-- New tables get their runtime grants from the default privileges (KL-013, migration 20261016130000).
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

ALTER TYPE "wallet_ledger_reason" ADD VALUE IF NOT EXISTS 'STATUS_PACK_PURCHASE';

-- The ledger's sign rule: STATUS_PACK_PURCHASE is a debit. Extended in place (read from the catalogue, not restated),
-- as 20270417090100_store_iap did; the new enum value is compared as text, so it is not used in this transaction.
DO $$
DECLARE
  def text;
BEGIN
  SELECT pg_get_constraintdef(c.oid) INTO STRICT def
    FROM pg_constraint c
   WHERE c.conrelid = 'wallet_ledger'::regclass AND c.conname = 'wallet_ledger_reason_sign';
  ALTER TABLE "wallet_ledger" DROP CONSTRAINT "wallet_ledger_reason_sign";
  EXECUTE format('ALTER TABLE wallet_ledger ADD CONSTRAINT wallet_ledger_reason_sign CHECK ((%s) OR (reason::text = %L AND delta < 0))',
                 substring(def FROM '^CHECK \((.*)\)$'), 'STATUS_PACK_PURCHASE');
END
$$;

-- 1. The status worn.
ALTER TABLE "users" ADD COLUMN "status_emoji_id" VARCHAR(64);
ALTER TABLE "users" ADD CONSTRAINT "users_status_emoji_id_shape"
  CHECK ("status_emoji_id" IS NULL OR "status_emoji_id" ~ '^[a-z][a-z0-9]{0,23}\.[a-z0-9_]{1,39}$');

-- 2. Prices.
CREATE TABLE "status_pack_offers" (
    "pack_id" VARCHAR(24) NOT NULL,
    "days" INTEGER NOT NULL,
    "coins" BIGINT NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "status_pack_offers_pkey" PRIMARY KEY ("pack_id", "days"),
    CONSTRAINT "status_pack_offers_shape" CHECK (
      "pack_id" ~ '^[a-z][a-z0-9]{0,23}$' AND "days" BETWEEN 1 AND 365 AND "coins" BETWEEN 1 AND 1000000000000)
);
-- The owner's price (2026-11-12): the whole «المميزة» pack, 100 000 coins for 30 days, one duration.
INSERT INTO "status_pack_offers" ("pack_id", "days", "coins") VALUES ('premium', 30, 100000);

-- 3. Packs held.
CREATE TABLE "user_status_packs" (
    "user_id" UUID NOT NULL,
    "pack_id" VARCHAR(24) NOT NULL,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_status_packs_pkey" PRIMARY KEY ("user_id", "pack_id")
);
ALTER TABLE "user_status_packs" ADD CONSTRAINT "user_status_packs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- 4. Purchases.
CREATE TABLE "status_pack_purchases" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "pack_id" VARCHAR(24) NOT NULL,
    "days" INTEGER NOT NULL,
    "price" BIGINT NOT NULL,
    "balance_after" BIGINT NOT NULL,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "extended" BOOLEAN NOT NULL,
    "idempotency_key" UUID NOT NULL,
    "request_hash" CHAR(64) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "status_pack_purchases_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "status_pack_purchases_shape" CHECK ("days" BETWEEN 1 AND 365 AND "price" > 0 AND "balance_after" >= 0)
);
CREATE UNIQUE INDEX "status_pack_purchases_idempotency" ON "status_pack_purchases"("user_id", "idempotency_key");
CREATE INDEX "status_pack_purchases_user_idx" ON "status_pack_purchases"("user_id", "created_at" DESC);
ALTER TABLE "status_pack_purchases" ADD CONSTRAINT "status_pack_purchases_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Append-only for the runtime group of THIS database (the shadow database has none). An account's rows still go
-- with the account (ON DELETE CASCADE runs as the table owner).
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
  EXECUTE format('REVOKE UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.status_pack_purchases FROM %I', grp);
END
$$;
