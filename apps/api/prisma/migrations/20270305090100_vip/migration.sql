-- v1.82-social (D252, CONVENTIONS §10.92): «شراء VIP». The tiers and their perks are rows the OWNER manages in the admin
-- panel (VIP 1 is seeded enabled with its perks; all tier / perk art is hosted and uploaded from the admin panel — nothing is bundled, so the app binary stays light); a person holds at most one membership; every
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
    -- The tier BADGE (central crest «بدج / ميدالية»): a hosted SVGA animation and a still (https, uploaded from
    -- the admin panel; the gifts `animationUrl` pattern, D126). Null = a token placeholder. Nothing is bundled.
    "badge_animation" VARCHAR(2048),
    "badge_still" VARCHAR(2048),
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
    -- The perk's own hosted art (avatar frame, entry bar, …): an SVGA animation and a still (https), plus the art's
    -- intrinsic size so the client fits it (the card is 720×1280, the entrance 660×150 — not all square). Uploaded from admin.
    "animation" VARCHAR(2048),
    "still" VARCHAR(2048),
    "art_width" INTEGER,
    "art_height" INTEGER,

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
    AND (badge_animation IS NULL OR badge_animation ~ '^https://')
    AND (badge_still IS NULL OR badge_still ~ '^https://')
    AND price_coins BETWEEN 1 AND 1000000000000
    AND duration_days BETWEEN 1 AND 365);
ALTER TABLE "vip_tier_perks" ADD CONSTRAINT "vip_tier_perks_shape" CHECK (
    code ~ '^[A-Z][A-Z0-9_]{0,39}$'
    AND length(btrim(title_ar)) > 0 AND length(btrim(title_en)) > 0
    AND sort_order >= 0
    AND (animation IS NULL OR animation ~ '^https://')
    AND (still IS NULL OR still ~ '^https://')
    AND (art_width IS NULL OR art_width BETWEEN 1 AND 8192)
    AND (art_height IS NULL OR art_height BETWEEN 1 AND 8192));
ALTER TABLE "vip_memberships" ADD CONSTRAINT "vip_memberships_period" CHECK (expires_at > started_at);
ALTER TABLE "vip_purchases" ADD CONSTRAINT "vip_purchases_shape" CHECK (
    price_coins > 0 AND duration_days BETWEEN 1 AND 365 AND coins_after >= 0
    AND (kind = 'NEW' OR previous_tier_id IS NOT NULL));

-- VIP is bought with coins: `VIP_PURCHASE` is a debit. The `wallet_ledger_reason_sign` CHECK lists every reason with
-- its sign, so it is dropped and re-added with the new reason (ADMIN_ADJUSTMENT stays either sign). Done here (not in
-- the enums migration) because the enum value `VIP_PURCHASE` is added in that earlier transaction.
ALTER TABLE "wallet_ledger" DROP CONSTRAINT "wallet_ledger_reason_sign";
ALTER TABLE "wallet_ledger" ADD CONSTRAINT "wallet_ledger_reason_sign" CHECK (
  (reason IN ('ADMIN_GRANT', 'CP_REFUND', 'LUCKY_GIFT_WIN', 'LIVE_BOOST_REFUND', 'TASK_REWARD', 'CHECK_IN_REWARD',
              'EVENT_PRIZE', 'RECHARGE_PURCHASE', 'CARD_TOPUP', 'CARD_TOPUP_RESTORE', 'RECHARGE_ORDER') AND delta > 0)
  OR (reason IN ('ADMIN_REVOKE', 'BULLET_MESSAGE', 'FAMILY_CREATE', 'CP_REQUEST', 'CP_GIFT', 'LIVE_GIFT', 'LUCKY_GIFT',
                 'PREMIUM_USERNAME_RENT', 'PREMIUM_USERNAME_RENEW', 'LIVE_BOOST', 'DM_GIFT', 'CARD_TOPUP_REVERSAL',
                 'VIP_PURCHASE')
      AND delta < 0)
  OR (reason = 'ADMIN_ADJUSTMENT' AND delta <> 0));

-- Seed VIP 1 (D252): the tier and its six perks, enabled, so the screen has a tier out of the box. All art is
-- hosted and uploaded from the admin panel after merge (the gifts `animationUrl` pattern, D126) — nothing is
-- bundled (the entry effect alone is 13 MB), so the badge / perk art URLs are NULL until the owner uploads them.
INSERT INTO "vip_tiers" ("id", "code", "name_ar", "name_en", "sort_order", "color", "price_coins", "duration_days", "enabled")
VALUES ('01a25200-0000-7000-8000-000000000001', 'VIP_1', 'في آي بي 1', 'VIP 1', 1, '#2E8B3D', 1000000, 30, true);

INSERT INTO "vip_tier_perks" ("id", "tier_id", "code", "title_ar", "title_en", "sort_order", "enabled")
VALUES
  ('01a25200-0000-7000-8000-0000000000a1', '01a25200-0000-7000-8000-000000000001', 'BADGE', 'الشارة', 'Badge', 0, true),
  ('01a25200-0000-7000-8000-0000000000a2', '01a25200-0000-7000-8000-000000000001', 'AVATAR_FRAME', 'إطار الصورة', 'Avatar frame', 1, true),
  ('01a25200-0000-7000-8000-0000000000a3', '01a25200-0000-7000-8000-000000000001', 'PROFILE_CARD', 'إطار البطاقة', 'Profile card', 2, true),
  ('01a25200-0000-7000-8000-0000000000a4', '01a25200-0000-7000-8000-000000000001', 'ENTRY_BANNER', 'لافتة الدخول', 'Entry banner', 3, true),
  ('01a25200-0000-7000-8000-0000000000a5', '01a25200-0000-7000-8000-000000000001', 'CHAT_BUBBLE', 'إطار الرسائل', 'Message frame', 4, true),
  ('01a25200-0000-7000-8000-0000000000a6', '01a25200-0000-7000-8000-000000000001', 'ENTRY_EFFECT', 'مؤثر الدخول', 'Entry effect', 5, true);
