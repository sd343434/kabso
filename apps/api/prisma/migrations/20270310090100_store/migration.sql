-- D270 (owner: «المتجر», CONVENTIONS §10.98): the store's items — each one is a bag catalogue row (`bag_items`, code
-- `store_<12 hex>`) plus its store row: hosted art (a PNG / WebP still and an SVGA or MP4 animation, uploaded from the
-- panel), names, the order, the «جديد» badge, on / off, and a price per duration (7 / 14 / 30 days) per currency (coins,
-- cherries). Every purchase is a row (the Idempotency-Key replay and the ledger reference). Additive. The runtime role
-- gets DML through the default privileges (20261016130000_per_database_runtime_group): no GRANT here.

CREATE TABLE "store_items" (
    "id" UUID NOT NULL,
    "bag_code" VARCHAR(40) NOT NULL,
    "kind" "bag_category" NOT NULL,
    "name_ar" VARCHAR(40) NOT NULL,
    "name_en" VARCHAR(40) NOT NULL,
    "still" VARCHAR(2048),
    "animation" VARCHAR(2048),
    "animation_format" "gift_animation_format",
    "animation_alpha" "gift_video_alpha",
    "art_width" INTEGER,
    "art_height" INTEGER,
    "sort_order" INTEGER NOT NULL,
    "is_new" BOOLEAN NOT NULL DEFAULT false,
    "enabled" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "store_items_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "store_items_bag_code_key" ON "store_items"("bag_code");
CREATE UNIQUE INDEX "store_items_bag_code_kind_key" ON "store_items"("bag_code", "kind");
CREATE INDEX "store_items_kind_sort_idx" ON "store_items"("kind", "sort_order", "id");
-- The bag row and its kind: one item, one category (a composite FK, as user_bag_items).
ALTER TABLE "store_items" ADD CONSTRAINT "store_items_bag_code_kind_fkey"
  FOREIGN KEY ("bag_code", "kind") REFERENCES "bag_items"("code", "category") ON DELETE RESTRICT ON UPDATE CASCADE;

-- A price: one per item, currency and duration; a duration without a price in a currency is not offered in it.
CREATE TABLE "store_item_prices" (
    "item_id" UUID NOT NULL,
    "currency" "store_currency" NOT NULL,
    "days" INTEGER NOT NULL,
    "amount" BIGINT NOT NULL,

    CONSTRAINT "store_item_prices_pkey" PRIMARY KEY ("item_id", "currency", "days")
);
ALTER TABLE "store_item_prices" ADD CONSTRAINT "store_item_prices_item_id_fkey"
  FOREIGN KEY ("item_id") REFERENCES "store_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "store_purchases" (
    "id" UUID NOT NULL,
    "buyer_id" UUID NOT NULL,
    "recipient_id" UUID NOT NULL,
    "item_id" UUID NOT NULL,
    "currency" "store_currency" NOT NULL,
    "days" INTEGER NOT NULL,
    "price" BIGINT NOT NULL,
    -- The buyer's balance in that currency right after the purchase.
    "balance_after" BIGINT NOT NULL,
    -- The recipient's item end after the purchase (extended when they owned it).
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "extended" BOOLEAN NOT NULL,
    "idempotency_key" UUID,
    "request_hash" CHAR(64),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "store_purchases_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "store_purchases_idempotency" ON "store_purchases"("buyer_id", "idempotency_key");
CREATE INDEX "store_purchases_buyer_idx" ON "store_purchases"("buyer_id", "created_at" DESC);
CREATE INDEX "store_purchases_created_idx" ON "store_purchases"("created_at" DESC, "id");
CREATE INDEX "store_purchases_item_idx" ON "store_purchases"("item_id", "created_at" DESC);
ALTER TABLE "store_purchases" ADD CONSTRAINT "store_purchases_buyer_id_fkey"
  FOREIGN KEY ("buyer_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "store_purchases" ADD CONSTRAINT "store_purchases_recipient_id_fkey"
  FOREIGN KEY ("recipient_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "store_purchases" ADD CONSTRAINT "store_purchases_item_id_fkey"
  FOREIGN KEY ("item_id") REFERENCES "store_items"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- ---- CHECKs (not expressible in schema.prisma) -------------------------------------------------
ALTER TABLE "store_items" ADD CONSTRAINT "store_items_shape" CHECK (
    bag_code ~ '^store_[0-9a-f]{12}$'
    AND kind::text IN ('AVATAR_FRAME', 'PROFILE_CARD', 'CHAT_BUBBLE', 'ENTRY_BANNER', 'ENTRY_EFFECT')
    AND length(btrim(name_ar)) > 0 AND length(btrim(name_en)) > 0
    AND sort_order >= 0
    AND (still IS NULL OR still ~ '^https://')
    AND (animation IS NULL OR animation ~ '^https://')
    AND ((animation IS NULL) = (animation_format IS NULL))
    AND ((animation_format IS NOT NULL AND animation_format = 'MP4') = (animation_alpha IS NOT NULL))
    AND (art_width IS NULL OR art_width BETWEEN 1 AND 8192)
    AND (art_height IS NULL OR art_height BETWEEN 1 AND 8192));
ALTER TABLE "store_item_prices" ADD CONSTRAINT "store_item_prices_shape" CHECK (
    days IN (7, 14, 30) AND amount BETWEEN 1 AND 1000000000000);
ALTER TABLE "store_purchases" ADD CONSTRAINT "store_purchases_shape" CHECK (
    days IN (7, 14, 30) AND price > 0 AND balance_after >= 0);

-- The ledgers' sign rule: STORE_PURCHASE is a debit in both. Extended in place (read from the catalogue, not
-- restated), as 20270206090100_referrals did, so a branch that changed the list before keeps its change.
DO $$
DECLARE
  def text;
BEGIN
  SELECT pg_get_constraintdef(c.oid) INTO STRICT def
    FROM pg_constraint c
   WHERE c.conrelid = 'wallet_ledger'::regclass AND c.conname = 'wallet_ledger_reason_sign';
  ALTER TABLE "wallet_ledger" DROP CONSTRAINT "wallet_ledger_reason_sign";
  EXECUTE format('ALTER TABLE wallet_ledger ADD CONSTRAINT wallet_ledger_reason_sign CHECK ((%s) OR (reason::text = %L AND delta < 0))',
                 substring(def FROM '^CHECK \((.*)\)$'), 'STORE_PURCHASE');
  SELECT pg_get_constraintdef(c.oid) INTO STRICT def
    FROM pg_constraint c
   WHERE c.conrelid = 'cherry_ledger'::regclass AND c.conname = 'cherry_ledger_reason_sign';
  ALTER TABLE "cherry_ledger" DROP CONSTRAINT "cherry_ledger_reason_sign";
  EXECUTE format('ALTER TABLE cherry_ledger ADD CONSTRAINT cherry_ledger_reason_sign CHECK ((%s) OR (reason::text = %L AND delta < 0))',
                 substring(def FROM '^CHECK \((.*)\)$'), 'STORE_PURCHASE');
END
$$;
