-- v1.51-live (D233, owner 2026-11-01): «بطاقة الزيارات» becomes a 4-stage rocket «صاروخ 1 · 2 · 3 · 4», priced
-- in coins (200 000 / 550 000 / 1 500 000 / 3 500 000 by default, server config `LIVE_BOOST_PRICES`) and editable
-- in the admin panel. CONVENTIONS §10.81. Additive: a new column (backfilled) and a new table. The runtime role
-- gets DML through the default privileges (20261016130000_per_database_runtime_group): no GRANT here.

-- Every card remembers the stage it was bought as (its rocket on the hub). Older cards were bought as a length
-- of the four default ones; any other length (a custom env) reads as stage 1.
ALTER TABLE "live_boosts" ADD COLUMN "stage" SMALLINT;
UPDATE "live_boosts"
   SET "stage" = CASE "minutes" WHEN 20 THEN 2 WHEN 30 THEN 3 WHEN 60 THEN 4 ELSE 1 END;
ALTER TABLE "live_boosts" ALTER COLUMN "stage" SET NOT NULL;
ALTER TABLE "live_boosts" ADD CONSTRAINT "live_boosts_stage" CHECK (stage BETWEEN 1 AND 4);

-- CreateTable: the price of a stage set in the panel (no row: the server config's price).
CREATE TABLE "live_boost_prices" (
    "stage" SMALLINT NOT NULL,
    "coins" BIGINT NOT NULL,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_by_id" UUID,

    CONSTRAINT "live_boost_prices_pkey" PRIMARY KEY ("stage")
);

-- ---- CHECKs (not expressible in schema.prisma) -------------------------------------------------
ALTER TABLE "live_boost_prices" ADD CONSTRAINT "live_boost_prices_shape" CHECK (
    stage BETWEEN 1 AND 4 AND coins BETWEEN 1 AND 1000000000);
