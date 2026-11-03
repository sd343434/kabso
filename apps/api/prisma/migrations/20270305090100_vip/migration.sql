-- v1.82-social (D252, CONVENTIONS §10.92): «شراء VIP». The tiers and their perks are rows the OWNER manages in the admin
-- panel (no seed: nothing is on sale until a tier is added and switched on); a person holds at most one membership; every
-- purchase is a row with the coins it took (wallet ledger `VIP_PURCHASE`, reference = the purchase). Additive. The
-- runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group): no GRANT here.

-- The tiers, in the panel's order (`sort_order` 1 … n: the higher, the higher the tier).
CREATE TABLE "vip_tiers" (
    "id" UUID NOT NULL,
    "code" VARCHAR(40) NOT NULL,
    "name_ar" VARCHAR(30) NOT NULL,
    "name_en" VARCHAR(30) NOT NULL,
    "sort_order" INTEGER NOT NULL,
    "color" CHAR(7) NOT NULL,
    "emblem_url" VARCHAR(2048),
    "price_coins" BIGINT NOT NULL,
    "duration_days" INTEGER NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_by_id" UUID,

    CONSTRAINT "vip_tiers_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "vip_tiers_code_key" ON "vip_tiers"("code");
CREATE INDEX "vip_tiers_sort_idx" ON "vip_tiers"("sort_order", "id");

-- A tier's perks, in order. `available` is not stored: the server knows which perks the app really does.
CREATE TABLE "vip_tier_perks" (
    "id" UUID NOT NULL,
    "tier_id" UUID NOT NULL,
    "code" VARCHAR(40) NOT NULL,
    "title_ar" VARCHAR(40) NOT NULL,
    "title_en" VARCHAR(40) NOT NULL,
    "description_ar" VARCHAR(200),
    "description_en" VARCHAR(200),
    "sort_order" INTEGER NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "vip_tier_perks_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "vip_tier_perks_tier_code_key" ON "vip_tier_perks"("tier_id", "code");
ALTER TABLE "vip_tier_perks" ADD CONSTRAINT "vip_tier_perks_tier_id_fkey"
  FOREIGN KEY ("tier_id") REFERENCES "vip_tiers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- A person's membership (one row per person; active while `expires_at` is in the future).
CREATE TABLE "vip_memberships" (
    "user_id" UUID NOT NULL,
    "tier_id" UUID NOT NULL,
    "started_at" TIMESTAMPTZ(3) NOT NULL,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "vip_memberships_pkey" PRIMARY KEY ("user_id")
);
CREATE INDEX "vip_memberships_tier_idx" ON "vip_memberships"("tier_id", "expires_at");
ALTER TABLE "vip_memberships" ADD CONSTRAINT "vip_memberships_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "vip_memberships" ADD CONSTRAINT "vip_memberships_tier_id_fkey"
  FOREIGN KEY ("tier_id") REFERENCES "vip_tiers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Every purchase (the replay answer of an Idempotency-Key, and the ledger reference).
CREATE TABLE "vip_purchases" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "tier_id" UUID NOT NULL,
    "kind" "vip_purchase_kind" NOT NULL,
    "price_coins" BIGINT NOT NULL,
    "duration_days" INTEGER NOT NULL,
    "previous_tier_id" UUID,
    "previous_expires_at" TIMESTAMPTZ(3),
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "coins_after" BIGINT NOT NULL,
    "idempotency_key" UUID,
    "request_hash" CHAR(64),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "vip_purchases_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "vip_purchases_idempotency" ON "vip_purchases"("user_id", "idempotency_key");
CREATE INDEX "vip_purchases_user_idx" ON "vip_purchases"("user_id", "created_at" DESC);
ALTER TABLE "vip_purchases" ADD CONSTRAINT "vip_purchases_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "vip_purchases" ADD CONSTRAINT "vip_purchases_tier_id_fkey"
  FOREIGN KEY ("tier_id") REFERENCES "vip_tiers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- ---- CHECKs (not expressible in schema.prisma) -------------------------------------------------
ALTER TABLE "vip_tiers" ADD CONSTRAINT "vip_tiers_shape" CHECK (
    code ~ '^[A-Z][A-Z0-9_]{0,39}$'
    AND length(btrim(name_ar)) > 0 AND length(btrim(name_en)) > 0
    AND sort_order >= 1
    AND color ~ '^#[0-9A-F]{6}$'
    AND (emblem_url IS NULL OR emblem_url LIKE 'https://%')
    AND price_coins BETWEEN 1 AND 1000000000000
    AND duration_days BETWEEN 1 AND 365);
ALTER TABLE "vip_tier_perks" ADD CONSTRAINT "vip_tier_perks_shape" CHECK (
    code ~ '^[A-Z][A-Z0-9_]{0,39}$'
    AND length(btrim(title_ar)) > 0 AND length(btrim(title_en)) > 0
    AND sort_order >= 0);
ALTER TABLE "vip_memberships" ADD CONSTRAINT "vip_memberships_period" CHECK (expires_at > started_at);
ALTER TABLE "vip_purchases" ADD CONSTRAINT "vip_purchases_shape" CHECK (
    price_coins > 0 AND duration_days BETWEEN 1 AND 365 AND coins_after >= 0
    AND (kind = 'NEW' OR previous_tier_id IS NOT NULL));
