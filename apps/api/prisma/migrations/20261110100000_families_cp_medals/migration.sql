-- v1.21-live (CP-018, owner D106, 2026-10-26): families (العائلة), CP couples (العلاقة) and medals
-- (الميداليات), CONVENTIONS §10.21. Owned by the `families`, `couples` and `medals` modules. The
-- runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group),
-- so this migration contains no GRANT; the family points ledger is append-only for it (as
-- `wallet_ledger`). The medal catalogue is seeded at the end; the family ladder and the CP tiers
-- are named constants in the API (families.constants.ts, couples.constants.ts).

-- CreateEnum
CREATE TYPE "family_role" AS ENUM ('LEADER', 'DEPUTY', 'MEMBER');

-- CreateEnum
CREATE TYPE "bond_request_status" AS ENUM ('PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED', 'EXPIRED');

-- AlterTable
ALTER TABLE "notifications" ADD COLUMN     "family_id" UUID,
ADD COLUMN     "medal_code" VARCHAR(40);

-- CreateTable
CREATE TABLE "families" (
    "id" UUID NOT NULL,
    "number" INTEGER NOT NULL DEFAULT (10000000 + floor((random() * (90000000)::double precision)))::integer,
    "name" VARCHAR(40) NOT NULL,
    "name_key" VARCHAR(80) NOT NULL,
    "emblem_media_id" UUID,
    "emblem_url" VARCHAR(512),
    "points" BIGINT NOT NULL DEFAULT 0,
    "level" INTEGER NOT NULL DEFAULT 1,
    "member_count" INTEGER NOT NULL DEFAULT 0,
    "created_by_id" UUID,
    "create_client_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "disbanded_at" TIMESTAMPTZ(3),

    CONSTRAINT "families_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "family_members" (
    "user_id" UUID NOT NULL,
    "family_id" UUID NOT NULL,
    "role" "family_role" NOT NULL DEFAULT 'MEMBER',
    "points" BIGINT NOT NULL DEFAULT 0,
    "joined_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "family_members_pkey" PRIMARY KEY ("user_id")
);

-- CreateTable
CREATE TABLE "family_join_requests" (
    "id" UUID NOT NULL,
    "family_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "status" "bond_request_status" NOT NULL DEFAULT 'PENDING',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "handled_at" TIMESTAMPTZ(3),
    "handled_by_id" UUID,

    CONSTRAINT "family_join_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "family_points_ledger" (
    "id" UUID NOT NULL,
    "family_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "wallet_ledger_id" UUID NOT NULL,
    "points" BIGINT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "family_points_ledger_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cp_requests" (
    "id" UUID NOT NULL,
    "sender_id" UUID NOT NULL,
    "receiver_id" UUID NOT NULL,
    "client_id" UUID NOT NULL,
    "cost" INTEGER NOT NULL,
    "status" "bond_request_status" NOT NULL DEFAULT 'PENDING',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "handled_at" TIMESTAMPTZ(3),

    CONSTRAINT "cp_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cp_couples" (
    "id" UUID NOT NULL,
    "user_a_id" UUID NOT NULL,
    "user_b_id" UUID NOT NULL,
    "request_id" UUID,
    "since" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "points" BIGINT NOT NULL DEFAULT 0,
    "level" INTEGER NOT NULL DEFAULT 1,
    "ended_at" TIMESTAMPTZ(3),
    "ended_by_id" UUID,

    CONSTRAINT "cp_couples_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cp_partners" (
    "user_id" UUID NOT NULL,
    "couple_id" UUID NOT NULL,
    "partner_id" UUID NOT NULL,

    CONSTRAINT "cp_partners_pkey" PRIMARY KEY ("user_id")
);

-- CreateTable
CREATE TABLE "cp_gifts" (
    "id" UUID NOT NULL,
    "couple_id" UUID NOT NULL,
    "sender_id" UUID NOT NULL,
    "receiver_id" UUID NOT NULL,
    "amount" INTEGER NOT NULL,
    "client_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cp_gifts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "medals" (
    "code" VARCHAR(40) NOT NULL,
    "name_ar" VARCHAR(60) NOT NULL,
    "name_en" VARCHAR(60) NOT NULL,
    "description_ar" VARCHAR(200) NOT NULL,
    "description_en" VARCHAR(200) NOT NULL,
    "icon_key" VARCHAR(60) NOT NULL,
    "sort_order" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "medals_pkey" PRIMARY KEY ("code")
);

-- CreateTable
CREATE TABLE "user_medals" (
    "user_id" UUID NOT NULL,
    "medal_code" VARCHAR(40) NOT NULL,
    "awarded_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_medals_pkey" PRIMARY KEY ("user_id","medal_code")
);

-- CreateIndex
CREATE UNIQUE INDEX "families_emblem_media_id_key" ON "families"("emblem_media_id");

-- CreateIndex
CREATE INDEX "families_points_idx" ON "families"("points" DESC, "id" DESC) WHERE (disbanded_at IS NULL);

-- CreateIndex
CREATE UNIQUE INDEX "families_number_key" ON "families"("number");

-- CreateIndex
CREATE UNIQUE INDEX "families_create_once" ON "families"("created_by_id", "create_client_id");

-- CreateIndex
CREATE UNIQUE INDEX "families_name_key_active" ON "families"("name_key") WHERE (disbanded_at IS NULL);

-- CreateIndex
CREATE INDEX "family_members_family_idx" ON "family_members"("family_id", "joined_at");

-- CreateIndex
CREATE UNIQUE INDEX "family_members_one_leader" ON "family_members"("family_id") WHERE (role = 'LEADER'::family_role);

-- CreateIndex
CREATE INDEX "family_join_requests_family_idx" ON "family_join_requests"("family_id", "created_at");

-- CreateIndex
CREATE INDEX "family_join_requests_user_idx" ON "family_join_requests"("user_id");

-- CreateIndex
CREATE INDEX "family_join_requests_expiry_idx" ON "family_join_requests"("expires_at") WHERE (status = 'PENDING'::bond_request_status);

-- CreateIndex
CREATE INDEX "family_join_requests_handled_by_idx" ON "family_join_requests"("handled_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "family_join_requests_one_pending" ON "family_join_requests"("user_id") WHERE (status = 'PENDING'::bond_request_status);

-- CreateIndex
CREATE UNIQUE INDEX "family_points_ledger_wallet_ledger_id_key" ON "family_points_ledger"("wallet_ledger_id");

-- CreateIndex
CREATE INDEX "family_points_ledger_family_idx" ON "family_points_ledger"("family_id", "created_at");

-- CreateIndex
CREATE INDEX "family_points_ledger_user_idx" ON "family_points_ledger"("user_id");

-- CreateIndex
CREATE INDEX "cp_requests_receiver_idx" ON "cp_requests"("receiver_id", "created_at");

-- CreateIndex
CREATE INDEX "cp_requests_expiry_idx" ON "cp_requests"("expires_at") WHERE (status = 'PENDING'::bond_request_status);

-- CreateIndex
CREATE UNIQUE INDEX "cp_requests_client_once" ON "cp_requests"("sender_id", "client_id");

-- CreateIndex
CREATE UNIQUE INDEX "cp_requests_one_outgoing" ON "cp_requests"("sender_id") WHERE (status = 'PENDING'::bond_request_status);

-- CreateIndex
CREATE UNIQUE INDEX "cp_couples_request_id_key" ON "cp_couples"("request_id");

-- CreateIndex
CREATE INDEX "cp_couples_user_a_idx" ON "cp_couples"("user_a_id");

-- CreateIndex
CREATE INDEX "cp_couples_user_b_idx" ON "cp_couples"("user_b_id");

-- CreateIndex
CREATE INDEX "cp_couples_ended_by_idx" ON "cp_couples"("ended_by_id");

-- CreateIndex
CREATE INDEX "cp_partners_couple_idx" ON "cp_partners"("couple_id");

-- CreateIndex
CREATE INDEX "cp_partners_partner_idx" ON "cp_partners"("partner_id");

-- CreateIndex
CREATE INDEX "cp_gifts_couple_idx" ON "cp_gifts"("couple_id", "created_at");

-- CreateIndex
CREATE INDEX "cp_gifts_receiver_idx" ON "cp_gifts"("receiver_id");

-- CreateIndex
CREATE UNIQUE INDEX "cp_gifts_client_once" ON "cp_gifts"("sender_id", "client_id");

-- CreateIndex
CREATE INDEX "user_medals_user_awarded_idx" ON "user_medals"("user_id", "awarded_at" DESC);

-- CreateIndex
CREATE INDEX "user_medals_medal_idx" ON "user_medals"("medal_code");

-- CreateIndex
CREATE INDEX "notifications_family_id_idx" ON "notifications"("family_id");

-- CreateIndex
CREATE INDEX "notifications_medal_code_idx" ON "notifications"("medal_code");

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "families"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_medal_code_fkey" FOREIGN KEY ("medal_code") REFERENCES "medals"("code") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "families" ADD CONSTRAINT "families_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "families" ADD CONSTRAINT "families_emblem_media_id_fkey" FOREIGN KEY ("emblem_media_id") REFERENCES "media_assets"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_members" ADD CONSTRAINT "family_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_members" ADD CONSTRAINT "family_members_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "families"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_join_requests" ADD CONSTRAINT "family_join_requests_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "families"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_join_requests" ADD CONSTRAINT "family_join_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_join_requests" ADD CONSTRAINT "family_join_requests_handled_by_id_fkey" FOREIGN KEY ("handled_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_points_ledger" ADD CONSTRAINT "family_points_ledger_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "families"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_points_ledger" ADD CONSTRAINT "family_points_ledger_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_points_ledger" ADD CONSTRAINT "family_points_ledger_wallet_ledger_id_fkey" FOREIGN KEY ("wallet_ledger_id") REFERENCES "wallet_ledger"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cp_requests" ADD CONSTRAINT "cp_requests_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cp_requests" ADD CONSTRAINT "cp_requests_receiver_id_fkey" FOREIGN KEY ("receiver_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cp_couples" ADD CONSTRAINT "cp_couples_user_a_id_fkey" FOREIGN KEY ("user_a_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cp_couples" ADD CONSTRAINT "cp_couples_user_b_id_fkey" FOREIGN KEY ("user_b_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cp_couples" ADD CONSTRAINT "cp_couples_ended_by_id_fkey" FOREIGN KEY ("ended_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cp_couples" ADD CONSTRAINT "cp_couples_request_id_fkey" FOREIGN KEY ("request_id") REFERENCES "cp_requests"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cp_partners" ADD CONSTRAINT "cp_partners_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cp_partners" ADD CONSTRAINT "cp_partners_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cp_partners" ADD CONSTRAINT "cp_partners_couple_id_fkey" FOREIGN KEY ("couple_id") REFERENCES "cp_couples"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cp_gifts" ADD CONSTRAINT "cp_gifts_couple_id_fkey" FOREIGN KEY ("couple_id") REFERENCES "cp_couples"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cp_gifts" ADD CONSTRAINT "cp_gifts_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cp_gifts" ADD CONSTRAINT "cp_gifts_receiver_id_fkey" FOREIGN KEY ("receiver_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_medals" ADD CONSTRAINT "user_medals_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_medals" ADD CONSTRAINT "user_medals_medal_code_fkey" FOREIGN KEY ("medal_code") REFERENCES "medals"("code") ON DELETE CASCADE ON UPDATE CASCADE;

-- ---- Checks (CONVENTIONS §10.21) ---------------------------------------------------------------

-- Family: an 8-digit public number, a 1–40 code point name (the API allows 2–20 graphemes), points
-- and level in range, 0–500 members (500 = the capacity, owner D106).
ALTER TABLE "families" ADD CONSTRAINT "families_number_range" CHECK (number BETWEEN 10000000 AND 99999999);
ALTER TABLE "families" ADD CONSTRAINT "families_name_length" CHECK (char_length(name) BETWEEN 1 AND 40);
ALTER TABLE "families" ADD CONSTRAINT "families_points_range" CHECK (points BETWEEN 0 AND 9007199254740991);
ALTER TABLE "families" ADD CONSTRAINT "families_level_range" CHECK (level BETWEEN 1 AND 10);
ALTER TABLE "families" ADD CONSTRAINT "families_member_count_range" CHECK (member_count BETWEEN 0 AND 500);
ALTER TABLE "families" ADD CONSTRAINT "families_emblem_shape" CHECK (emblem_media_id IS NULL OR emblem_url IS NOT NULL);
ALTER TABLE "family_members" ADD CONSTRAINT "family_members_points_range" CHECK (points >= 0);
ALTER TABLE "family_points_ledger" ADD CONSTRAINT "family_points_ledger_points_positive" CHECK (points > 0);
ALTER TABLE "family_join_requests" ADD CONSTRAINT "family_join_requests_handled" CHECK ((status = 'PENDING') = (handled_at IS NULL));

-- CP: never with oneself; a couple's users in a fixed order; a request costs coins; a gift is a
-- positive number of coins; points and the tier in range.
ALTER TABLE "cp_requests" ADD CONSTRAINT "cp_requests_not_self" CHECK (sender_id <> receiver_id);
ALTER TABLE "cp_requests" ADD CONSTRAINT "cp_requests_cost_positive" CHECK (cost > 0);
ALTER TABLE "cp_requests" ADD CONSTRAINT "cp_requests_handled" CHECK ((status = 'PENDING') = (handled_at IS NULL));
ALTER TABLE "cp_couples" ADD CONSTRAINT "cp_couples_ordered" CHECK (user_a_id < user_b_id);
ALTER TABLE "cp_couples" ADD CONSTRAINT "cp_couples_points_range" CHECK (points BETWEEN 0 AND 9007199254740991);
ALTER TABLE "cp_couples" ADD CONSTRAINT "cp_couples_level_range" CHECK (level BETWEEN 1 AND 5);
ALTER TABLE "cp_partners" ADD CONSTRAINT "cp_partners_not_self" CHECK (user_id <> partner_id);
ALTER TABLE "cp_gifts" ADD CONSTRAINT "cp_gifts_amount_positive" CHECK (amount > 0);
ALTER TABLE "cp_gifts" ADD CONSTRAINT "cp_gifts_not_self" CHECK (sender_id <> receiver_id);

-- Wallet ledger: grants and CP refunds add coins; every other reason takes them (replaces the
-- CP-017 rule of 20261108090000_wallet_and_bullets).
ALTER TABLE "wallet_ledger" DROP CONSTRAINT "wallet_ledger_reason_sign";
ALTER TABLE "wallet_ledger" ADD CONSTRAINT "wallet_ledger_reason_sign" CHECK (
  (reason IN ('ADMIN_GRANT', 'CP_REFUND') AND delta > 0)
  OR (reason IN ('ADMIN_REVOKE', 'BULLET_MESSAGE', 'FAMILY_CREATE', 'CP_REQUEST', 'CP_GIFT') AND delta < 0));

-- Media: the family emblem kind (a centre-cropped square like the live cover, §11.1).
ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_kind_known";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_kind_known" CHECK (kind IN ('POST_IMAGE', 'STORY_IMAGE', 'LIVE_COVER', 'LIVE_CHAT_IMAGE', 'LIVE_CHAT_VOICE', 'FAMILY_EMBLEM'));

-- ---- The medal catalogue (owner D106; CONVENTIONS §10.21) -------------------------------------
-- The API keeps the same list (medals.catalogue.ts) so a test database can be re-seeded.
INSERT INTO "medals" ("code", "name_ar", "name_en", "description_ar", "description_en", "icon_key", "sort_order") VALUES
  ('FIRST_LIVE', 'أول لايف', 'First live', 'استضفت أول بث مباشر لك.', 'Hosted your first live.', 'medal_first_live', 10),
  ('LIVE_HOURS_10', '10 ساعات بث', '10 live hours', 'استضفت 10 ساعات من البث المباشر.', 'Hosted 10 hours of lives.', 'medal_live_hours_10', 20),
  ('LIVE_HOURS_100', '100 ساعة بث', '100 live hours', 'استضفت 100 ساعة من البث المباشر.', 'Hosted 100 hours of lives.', 'medal_live_hours_100', 30),
  ('CHARM_10', 'جاذبية 10', 'Charm 10', 'بلغت مستوى الجاذبية 10.', 'Reached charm level 10.', 'medal_charm_10', 40),
  ('CHARM_50', 'جاذبية 50', 'Charm 50', 'بلغت مستوى الجاذبية 50.', 'Reached charm level 50.', 'medal_charm_50', 50),
  ('CHARM_100', 'جاذبية 100', 'Charm 100', 'بلغت مستوى الجاذبية 100.', 'Reached charm level 100.', 'medal_charm_100', 60),
  ('FIRST_FAMILY', 'أول عائلة', 'First family', 'انضممت إلى عائلة أو أنشأت واحدة.', 'Joined or created a family.', 'medal_first_family', 70),
  ('FIRST_CP', 'أول ثنائي', 'First couple', 'كوّنت أول ثنائي (CP).', 'Formed your first CP couple.', 'medal_first_cp', 80),
  ('BULLET_FIRST', 'أول رسالة عامة', 'First bullet message', 'أرسلت أول رسالة عامة.', 'Sent your first bullet message.', 'medal_bullet_first', 90);

-- Append-only family points ledger for the runtime group of THIS database (as wallet_ledger).
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
  EXECUTE format('REVOKE UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.family_points_ledger FROM %I', grp);
END
$$;
