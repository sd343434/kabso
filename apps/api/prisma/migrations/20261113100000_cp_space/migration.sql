-- v1.24-live (CP-021, owner D112, 2026-10-26): the CP space, CONVENTIONS §10.24. Owned by the
-- `cp-space` module. The runtime role gets DML through the default privileges
-- (20261016130000_per_database_runtime_group), so this migration contains no GRANT; the CP points
-- ledger is append-only for it (as `wallet_ledger` and `family_points_ledger`).
--
-- * `cp_points_ledger`: every CP points gain of a couple (CP gifts and claimed daily tasks), the
--   source of the weekly couples ranking. Back-filled below from the existing CP gifts, so for every
--   couple SUM(points) = cp_couples.points.
-- * `cp_check_ins`, `cp_task_claims`: the daily CP tasks (one claim per couple, CP day and task).
-- * `cp_confessions`: partner-to-partner confessions on the couple's page; reports may target them.
-- * `live_chat_messages.cp_bubble`: the author's couple had the Exclusive Chat Bubble when sent.

-- CreateEnum
CREATE TYPE "cp_points_source" AS ENUM ('GIFT', 'TASK');

-- AlterTable
ALTER TABLE "live_chat_messages" ADD COLUMN     "cp_bubble" BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE "reports" ADD COLUMN     "target_cp_confession_id" UUID;

-- CreateTable
CREATE TABLE "cp_points_ledger" (
    "id" UUID NOT NULL,
    "couple_id" UUID NOT NULL,
    "source" "cp_points_source" NOT NULL,
    "reference_id" UUID NOT NULL,
    "points" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cp_points_ledger_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cp_check_ins" (
    "couple_id" UUID NOT NULL,
    "day" DATE NOT NULL,
    "user_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cp_check_ins_pkey" PRIMARY KEY ("couple_id","day","user_id")
);

-- CreateTable
CREATE TABLE "cp_task_claims" (
    "id" UUID NOT NULL,
    "couple_id" UUID NOT NULL,
    "day" DATE NOT NULL,
    "task_code" VARCHAR(40) NOT NULL,
    "points" INTEGER NOT NULL,
    "claimed_by_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cp_task_claims_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cp_confessions" (
    "id" UUID NOT NULL,
    "couple_id" UUID NOT NULL,
    "author_id" UUID NOT NULL,
    "recipient_id" UUID NOT NULL,
    "text" VARCHAR(200) NOT NULL,
    "client_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMPTZ(3),
    "deleted_by_id" UUID,

    CONSTRAINT "cp_confessions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "cp_points_ledger_created_idx" ON "cp_points_ledger"("created_at", "couple_id");

-- CreateIndex
CREATE INDEX "cp_points_ledger_couple_idx" ON "cp_points_ledger"("couple_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "cp_points_ledger_reference_once" ON "cp_points_ledger"("source", "reference_id");

-- CreateIndex
CREATE INDEX "cp_check_ins_user_idx" ON "cp_check_ins"("user_id");

-- CreateIndex
CREATE INDEX "cp_task_claims_claimed_by_idx" ON "cp_task_claims"("claimed_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "cp_task_claims_once" ON "cp_task_claims"("couple_id", "day", "task_code");

-- CreateIndex
CREATE INDEX "cp_confessions_couple_idx" ON "cp_confessions"("couple_id", "created_at");

-- CreateIndex
CREATE INDEX "cp_confessions_recipient_idx" ON "cp_confessions"("recipient_id");

-- CreateIndex
CREATE INDEX "cp_confessions_deleted_by_idx" ON "cp_confessions"("deleted_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "cp_confessions_client_once" ON "cp_confessions"("author_id", "client_id");

-- CreateIndex
CREATE INDEX "reports_target_cp_confession_idx" ON "reports"("target_cp_confession_id");

-- CreateIndex
CREATE UNIQUE INDEX "reports_open_cp_confession_once" ON "reports"("reporter_id", "target_cp_confession_id") WHERE (status = 'OPEN'::report_status AND target_cp_confession_id IS NOT NULL);

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_target_cp_confession_id_fkey" FOREIGN KEY ("target_cp_confession_id") REFERENCES "cp_confessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cp_points_ledger" ADD CONSTRAINT "cp_points_ledger_couple_id_fkey" FOREIGN KEY ("couple_id") REFERENCES "cp_couples"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cp_check_ins" ADD CONSTRAINT "cp_check_ins_couple_id_fkey" FOREIGN KEY ("couple_id") REFERENCES "cp_couples"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cp_check_ins" ADD CONSTRAINT "cp_check_ins_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cp_task_claims" ADD CONSTRAINT "cp_task_claims_couple_id_fkey" FOREIGN KEY ("couple_id") REFERENCES "cp_couples"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cp_task_claims" ADD CONSTRAINT "cp_task_claims_claimed_by_id_fkey" FOREIGN KEY ("claimed_by_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cp_confessions" ADD CONSTRAINT "cp_confessions_couple_id_fkey" FOREIGN KEY ("couple_id") REFERENCES "cp_couples"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cp_confessions" ADD CONSTRAINT "cp_confessions_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cp_confessions" ADD CONSTRAINT "cp_confessions_recipient_id_fkey" FOREIGN KEY ("recipient_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cp_confessions" ADD CONSTRAINT "cp_confessions_deleted_by_id_fkey" FOREIGN KEY ("deleted_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;


-- ---- Checks -------------------------------------------------------------------------------------
ALTER TABLE "cp_points_ledger" ADD CONSTRAINT "cp_points_ledger_points_positive" CHECK (points > 0);
ALTER TABLE "cp_task_claims" ADD CONSTRAINT "cp_task_claims_points_positive" CHECK (points > 0);
ALTER TABLE "cp_task_claims" ADD CONSTRAINT "cp_task_claims_code_format" CHECK (task_code ~ '^[A-Z][A-Z0-9_]{0,39}$');
ALTER TABLE "cp_confessions" ADD CONSTRAINT "cp_confessions_text_length" CHECK (char_length(text) BETWEEN 1 AND 200);
ALTER TABLE "cp_confessions" ADD CONSTRAINT "cp_confessions_not_self" CHECK (author_id <> recipient_id);

-- Reports: exactly one target, the one the type names (replaces the rule of
-- 20261029090000_live_chat; CP_CONFESSION compared as text, the value comes from the previous
-- migration).
ALTER TABLE "reports" DROP CONSTRAINT "reports_one_target";
ALTER TABLE "reports" ADD CONSTRAINT "reports_one_target" CHECK (
  num_nonnulls(target_post_id, target_comment_id, target_user_id, target_story_id, target_live_room_id,
               target_live_chat_message_id, target_cp_confession_id) = 1
  AND (
    (target_type::text = 'POST' AND target_post_id IS NOT NULL)
    OR (target_type::text = 'COMMENT' AND target_comment_id IS NOT NULL)
    OR (target_type::text = 'USER' AND target_user_id IS NOT NULL)
    OR (target_type::text = 'STORY' AND target_story_id IS NOT NULL)
    OR (target_type::text = 'LIVE_ROOM' AND target_live_room_id IS NOT NULL)
    OR (target_type::text = 'LIVE_CHAT_MESSAGE' AND target_live_chat_message_id IS NOT NULL)
    OR (target_type::text = 'CP_CONFESSION' AND target_cp_confession_id IS NOT NULL)));

-- ---- Back-fill: the CP gifts so far (one GIFT row each, at the gift's time) --------------------
INSERT INTO "cp_points_ledger" ("id", "couple_id", "source", "reference_id", "points", "created_at")
SELECT gen_random_uuid(), g.couple_id, 'GIFT'::cp_points_source, g.id, g.amount, g.created_at
  FROM "cp_gifts" g
ON CONFLICT ("source", "reference_id") DO NOTHING;

-- Append-only CP points ledger for the runtime group of THIS database (as family_points_ledger).
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
  EXECUTE format('REVOKE UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.cp_points_ledger FROM %I', grp);
END
$$;
