-- v1.126-social (D370, owner 2026-11-11: «نقاط الشحن» — every recharged coin is one point, the points never expire
-- («النقاط لا تصفر كل شهر بل تبقى مجموع») and buy VIP «استبدل بالنقاط»), CONVENTIONS §10.163.
--
-- 1. `recharge_points_balances`: one row per person (created on the first point); may go below 0 after a reversal.
-- 2. `recharge_points_ledger`: append-only for the runtime group; `(reason, reference_id)` unique — a recharge earns
--    once, a redemption spends once, a reversal step reverses once.
-- 3. `vip_tiers.points_price` (null = not redeemable with points) and the owner's price table set by tier code.
-- 4. `vip_purchases.pay_with` / `price_points` / `list_price_points` / `points_after`.
--
-- No back-fill: points start with the recharges after this migration (CTO choice, D370; the owner may ask otherwise).
-- New tables get their runtime grants from the default privileges (KL-013, migration 20261016130000).
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

CREATE TYPE "recharge_points_reason" AS ENUM ('RECHARGE_WEB', 'RECHARGE_STORE', 'RECHARGE_AGENT', 'VIP_REDEEM', 'REVERSAL', 'ADMIN_ADJUST');
CREATE TYPE "vip_pay_with" AS ENUM ('COINS', 'POINTS');

-- 1. The balance.
CREATE TABLE "recharge_points_balances" (
    "user_id" UUID NOT NULL,
    "points" BIGINT NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "recharge_points_balances_pkey" PRIMARY KEY ("user_id"),
    CONSTRAINT "recharge_points_balances_range" CHECK ("points" BETWEEN -9007199254740991 AND 9007199254740991)
);
ALTER TABLE "recharge_points_balances" ADD CONSTRAINT "recharge_points_balances_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- 2. The ledger. Earning reasons are credits, VIP_REDEEM a debit; REVERSAL and ADMIN_ADJUST either way (never 0).
CREATE TABLE "recharge_points_ledger" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "delta" BIGINT NOT NULL,
    "balance_after" BIGINT NOT NULL,
    "reason" "recharge_points_reason" NOT NULL,
    "reference_id" VARCHAR(64) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "recharge_points_ledger_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "recharge_points_ledger_sign" CHECK (
      "delta" <> 0
      AND ("reason" NOT IN ('RECHARGE_WEB', 'RECHARGE_STORE', 'RECHARGE_AGENT') OR "delta" > 0)
      AND ("reason" <> 'VIP_REDEEM' OR "delta" < 0))
);
CREATE UNIQUE INDEX "recharge_points_ledger_reference_once" ON "recharge_points_ledger"("reason", "reference_id");
CREATE INDEX "recharge_points_ledger_user_idx" ON "recharge_points_ledger"("user_id", "created_at" DESC, "id" DESC);
ALTER TABLE "recharge_points_ledger" ADD CONSTRAINT "recharge_points_ledger_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- 3. The tiers' points price (owner-approved table, 2026-11-11). Tiers are created in the panel; only the ones that
--    exist now (by code) get their price — the panel sets the rest when the owner adds them.
ALTER TABLE "vip_tiers" ADD COLUMN "points_price" BIGINT;
ALTER TABLE "vip_tiers" ADD CONSTRAINT "vip_tiers_points_price_range" CHECK ("points_price" IS NULL OR "points_price" BETWEEN 1 AND 1000000000000);
UPDATE "vip_tiers" AS t SET "points_price" = p.price
  FROM (VALUES
    ('VIP_1', 2000000), ('VIP_2', 3500000), ('VIP_3', 6000000), ('VIP_4', 10000000),
    ('VIP_5', 16000000), ('VIP_6', 25000000), ('VIP_7', 40000000), ('VIP_8', 65000000),
    ('VIP_9', 100000000), ('VIP_10', 160000000), ('VIP_11', 250000000), ('VIP_12', 400000000)
  ) AS p(code, price)
 WHERE t."code" = p.code;

-- 4. What paid for a purchase.
ALTER TABLE "vip_purchases" ADD COLUMN "pay_with" "vip_pay_with" NOT NULL DEFAULT 'COINS';
ALTER TABLE "vip_purchases" ADD COLUMN "price_points" BIGINT;
ALTER TABLE "vip_purchases" ADD COLUMN "list_price_points" BIGINT;
ALTER TABLE "vip_purchases" ADD COLUMN "points_after" BIGINT;
-- The D252 shape (price_coins > 0, coins_after >= 0) holds for a coin purchase only: a points purchase charges no coins
-- and records the coin balance as it is (it may be below 0 after a reversed top-up).
ALTER TABLE "vip_purchases" DROP CONSTRAINT "vip_purchases_shape";
ALTER TABLE "vip_purchases" ADD CONSTRAINT "vip_purchases_shape" CHECK (
    duration_days BETWEEN 1 AND 365
    AND (kind = 'NEW' OR previous_tier_id IS NOT NULL)
    AND (pay_with = 'POINTS' OR (price_coins > 0 AND coins_after >= 0)));
ALTER TABLE "vip_purchases" ADD CONSTRAINT "vip_purchases_pay_with_shape" CHECK (
  ("pay_with" = 'COINS' AND "price_points" IS NULL AND "list_price_points" IS NULL AND "points_after" IS NULL)
  OR ("pay_with" = 'POINTS' AND "price_coins" = 0 AND "price_points" > 0 AND "list_price_points" > 0
      AND "points_after" IS NOT NULL));

-- Append-only for the runtime group of THIS database (the shadow database has none).
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
  EXECUTE format('REVOKE UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.recharge_points_ledger FROM %I', grp);
END
$$;
