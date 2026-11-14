-- D72 / CP-005 (contract v1.4-levels, DRAFT): four independent level systems — ATTRACTIVENESS,
-- SUPPORT, WIZARD, GAMING. Forward-only and additive: new types and tables, no change to an
-- existing table. Seeds the four categories DISABLED with no version: no multiplier or threshold
-- is seeded (business decisions, CP-005 §9).
--
-- Runs as the migration role (KL-013). The runtime group gets SELECT, INSERT, UPDATE and DELETE
-- on the new tables through the default privileges (20261016120000_runtime_role_grants); the
-- block at the end makes points_ledger and level_history append-only for it, like audit_logs.
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

-- CreateEnum
CREATE TYPE "level_category_code" AS ENUM ('ATTRACTIVENESS', 'SUPPORT', 'WIZARD', 'GAMING');

-- CreateEnum
CREATE TYPE "level_version_status" AS ENUM ('DRAFT', 'PUBLISHED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "level_value_unit" AS ENUM ('COIN');

-- CreateEnum
CREATE TYPE "level_reversal_policy" AS ENUM ('REVERSE_POINTS', 'KEEP_LEVEL');

-- CreateEnum
CREATE TYPE "points_entry_type" AS ENUM ('EARN', 'REVERSAL', 'ADJUSTMENT');

-- CreateEnum
CREATE TYPE "points_source_type" AS ENUM ('GIFT_RECEIVED', 'GIFT_SENT', 'LUCKY_GIFT_SENT', 'GAME_SPEND', 'ADMIN', 'CONFIG');

-- CreateEnum
CREATE TYPE "level_transition_reason" AS ENUM ('EARNED', 'REVERSED', 'ADJUSTED', 'CONFIG_PUBLISHED', 'RECALCULATED');

-- CreateEnum
CREATE TYPE "level_source_event_type" AS ENUM ('GIFT_COMMITTED', 'GAME_SPEND_COMMITTED', 'GIFT_REVERSED', 'GAME_SPEND_REVERSED');

-- CreateEnum
CREATE TYPE "level_event_status" AS ENUM ('PENDING', 'PROCESSED', 'SKIPPED', 'FAILED');

-- CreateEnum
CREATE TYPE "level_reconciliation_mode" AS ENUM ('DRY_RUN', 'REPAIR');

-- CreateEnum
CREATE TYPE "level_reconciliation_status" AS ENUM ('RUNNING', 'COMPLETED', 'FAILED');

-- CreateTable
CREATE TABLE "level_categories" (
    "id" UUID NOT NULL,
    "code" "level_category_code" NOT NULL,
    "name_ar" VARCHAR(40) NOT NULL,
    "name_en" VARCHAR(40) NOT NULL,
    "description_ar" VARCHAR(200) NOT NULL,
    "description_en" VARCHAR(200) NOT NULL,
    "is_enabled" BOOLEAN NOT NULL DEFAULT false,
    "published_version_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "level_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "level_category_versions" (
    "id" UUID NOT NULL,
    "category_id" UUID NOT NULL,
    "version_number" INTEGER NOT NULL,
    "status" "level_version_status" NOT NULL DEFAULT 'DRAFT',
    "multiplier" DECIMAL(18,6),
    "value_unit" "level_value_unit",
    "reversal_policy" "level_reversal_policy" NOT NULL DEFAULT 'REVERSE_POINTS',
    "lucky_gifts_count_as_support" BOOLEAN NOT NULL DEFAULT false,
    "created_by_id" UUID,
    "published_by_id" UUID,
    "published_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "level_category_versions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "level_definitions" (
    "id" UUID NOT NULL,
    "version_id" UUID NOT NULL,
    "level_number" INTEGER NOT NULL,
    "name_ar" VARCHAR(40) NOT NULL,
    "name_en" VARCHAR(40) NOT NULL,
    "required_points" BIGINT NOT NULL,
    "icon_key" VARCHAR(64),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "level_definitions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_level_states" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "category_id" UUID NOT NULL,
    "total_points" BIGINT NOT NULL DEFAULT 0,
    "lifetime_earned_points" BIGINT NOT NULL DEFAULT 0,
    "current_level" INTEGER,
    "version_id" UUID,
    "last_qualified_activity_at" TIMESTAMPTZ(3),
    "calculated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "user_level_states_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "points_ledger" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "category_id" UUID NOT NULL,
    "entry_type" "points_entry_type" NOT NULL,
    "source_type" "points_source_type" NOT NULL,
    "source_transaction_id" VARCHAR(128),
    "source_value" BIGINT,
    "points_delta" BIGINT NOT NULL,
    "multiplier_used" DECIMAL(18,6),
    "version_id" UUID,
    "idempotency_key" VARCHAR(128),
    "reversal_of_entry_id" UUID,
    "reason" VARCHAR(500),
    "created_by_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "points_ledger_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "level_history" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "category_id" UUID NOT NULL,
    "previous_level" INTEGER,
    "new_level" INTEGER,
    "points" BIGINT NOT NULL,
    "reason" "level_transition_reason" NOT NULL,
    "ledger_entry_id" UUID,
    "version_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "level_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "level_source_events" (
    "id" UUID NOT NULL,
    "type" "level_source_event_type" NOT NULL,
    "source_transaction_id" VARCHAR(128) NOT NULL,
    "payload" JSONB NOT NULL,
    "status" "level_event_status" NOT NULL DEFAULT 'PENDING',
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "last_error" VARCHAR(300),
    "received_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "processed_at" TIMESTAMPTZ(3),

    CONSTRAINT "level_source_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "level_reconciliation_runs" (
    "id" UUID NOT NULL,
    "category" "level_category_code",
    "mode" "level_reconciliation_mode" NOT NULL,
    "status" "level_reconciliation_status" NOT NULL DEFAULT 'RUNNING',
    "started_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" TIMESTAMPTZ(3),
    "events_inspected" INTEGER NOT NULL DEFAULT 0,
    "states_inspected" INTEGER NOT NULL DEFAULT 0,
    "failed_events" INTEGER NOT NULL DEFAULT 0,
    "unprocessed_events" INTEGER NOT NULL DEFAULT 0,
    "state_mismatches" INTEGER NOT NULL DEFAULT 0,
    "corrected" INTEGER NOT NULL DEFAULT 0,
    "errors" JSONB NOT NULL DEFAULT '[]',
    "initiated_by_id" UUID,

    CONSTRAINT "level_reconciliation_runs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "level_categories_code_key" ON "level_categories"("code");

-- CreateIndex
CREATE UNIQUE INDEX "level_categories_published_version_id_key" ON "level_categories"("published_version_id");

-- CreateIndex
CREATE UNIQUE INDEX "level_category_versions_category_number_key" ON "level_category_versions"("category_id", "version_number");

-- CreateIndex
CREATE UNIQUE INDEX "level_category_versions_one_published" ON "level_category_versions"("category_id") WHERE (status = 'PUBLISHED'::level_version_status);

-- CreateIndex
CREATE UNIQUE INDEX "level_definitions_version_level_key" ON "level_definitions"("version_id", "level_number");

-- CreateIndex
CREATE INDEX "user_level_states_category_level_idx" ON "user_level_states"("category_id", "current_level");

-- CreateIndex
CREATE UNIQUE INDEX "user_level_states_user_category_key" ON "user_level_states"("user_id", "category_id");

-- CreateIndex
CREATE UNIQUE INDEX "points_ledger_reversal_of_key" ON "points_ledger"("reversal_of_entry_id");

-- CreateIndex
CREATE INDEX "points_ledger_user_category_created_idx" ON "points_ledger"("user_id", "category_id", "created_at" DESC, "id" DESC);

-- CreateIndex
CREATE INDEX "points_ledger_user_created_idx" ON "points_ledger"("user_id", "created_at" DESC, "id" DESC);

-- CreateIndex
CREATE INDEX "points_ledger_source_transaction_idx" ON "points_ledger"("source_transaction_id");

-- CreateIndex
CREATE INDEX "points_ledger_category_id_idx" ON "points_ledger"("category_id");

-- CreateIndex
CREATE UNIQUE INDEX "points_ledger_source_once" ON "points_ledger"("category_id", "source_type", "source_transaction_id", "entry_type") WHERE (entry_type = ANY (ARRAY['EARN'::points_entry_type, 'REVERSAL'::points_entry_type]));

-- CreateIndex
CREATE UNIQUE INDEX "points_ledger_idempotency_key" ON "points_ledger"("idempotency_key") WHERE (idempotency_key IS NOT NULL);

-- CreateIndex
CREATE INDEX "level_history_user_created_idx" ON "level_history"("user_id", "created_at" DESC, "id" DESC);

-- CreateIndex
CREATE INDEX "level_history_category_created_idx" ON "level_history"("category_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "level_source_events_status_received_idx" ON "level_source_events"("status", "received_at" DESC);

-- CreateIndex
CREATE INDEX "level_source_events_received_idx" ON "level_source_events"("received_at" DESC, "id" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "level_source_events_type_source_key" ON "level_source_events"("type", "source_transaction_id");

-- CreateIndex
CREATE INDEX "level_reconciliation_runs_started_idx" ON "level_reconciliation_runs"("started_at" DESC, "id" DESC);

-- AddForeignKey
ALTER TABLE "level_categories" ADD CONSTRAINT "level_categories_published_version_id_fkey" FOREIGN KEY ("published_version_id") REFERENCES "level_category_versions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "level_category_versions" ADD CONSTRAINT "level_category_versions_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "level_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "level_definitions" ADD CONSTRAINT "level_definitions_version_id_fkey" FOREIGN KEY ("version_id") REFERENCES "level_category_versions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_level_states" ADD CONSTRAINT "user_level_states_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_level_states" ADD CONSTRAINT "user_level_states_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "level_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "points_ledger" ADD CONSTRAINT "points_ledger_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "points_ledger" ADD CONSTRAINT "points_ledger_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "level_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "points_ledger" ADD CONSTRAINT "points_ledger_reversal_of_entry_id_fkey" FOREIGN KEY ("reversal_of_entry_id") REFERENCES "points_ledger"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "level_history" ADD CONSTRAINT "level_history_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "level_history" ADD CONSTRAINT "level_history_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "level_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Hand-written CHECK constraints (second line of defence behind the application, CP-005 §3–§4).

ALTER TABLE "level_category_versions" ADD CONSTRAINT "level_category_versions_number_positive"
  CHECK ("version_number" >= 1);
ALTER TABLE "level_category_versions" ADD CONSTRAINT "level_category_versions_multiplier_range"
  CHECK ("multiplier" IS NULL OR ("multiplier" > 0 AND "multiplier" <= 1000000));
ALTER TABLE "level_category_versions" ADD CONSTRAINT "level_category_versions_published_complete"
  CHECK ("status" = 'DRAFT' OR ("multiplier" IS NOT NULL AND "value_unit" IS NOT NULL AND "published_at" IS NOT NULL));

ALTER TABLE "level_definitions" ADD CONSTRAINT "level_definitions_level_range"
  CHECK ("level_number" BETWEEN 1 AND 200);
ALTER TABLE "level_definitions" ADD CONSTRAINT "level_definitions_points_nonnegative"
  CHECK ("required_points" >= 0);
ALTER TABLE "level_definitions" ADD CONSTRAINT "level_definitions_icon_key_format"
  CHECK ("icon_key" IS NULL OR "icon_key" ~ '^[a-z0-9_]{1,64}$');

ALTER TABLE "user_level_states" ADD CONSTRAINT "user_level_states_points_nonnegative"
  CHECK ("total_points" >= 0 AND "lifetime_earned_points" >= 0);
ALTER TABLE "user_level_states" ADD CONSTRAINT "user_level_states_level_range"
  CHECK ("current_level" IS NULL OR "current_level" BETWEEN 1 AND 200);

ALTER TABLE "points_ledger" ADD CONSTRAINT "points_ledger_delta_nonzero"
  CHECK ("points_delta" <> 0);
ALTER TABLE "points_ledger" ADD CONSTRAINT "points_ledger_source_value_nonnegative"
  CHECK ("source_value" IS NULL OR "source_value" >= 0);
-- Activity entries carry their source; ADMIN/CONFIG entries do not.
ALTER TABLE "points_ledger" ADD CONSTRAINT "points_ledger_source_shape"
  CHECK (
    ("source_type" IN ('ADMIN', 'CONFIG') AND "source_transaction_id" IS NULL AND "entry_type" = 'ADJUSTMENT')
    OR ("source_type" NOT IN ('ADMIN', 'CONFIG') AND "source_transaction_id" IS NOT NULL AND "entry_type" IN ('EARN', 'REVERSAL'))
  );
ALTER TABLE "points_ledger" ADD CONSTRAINT "points_ledger_reversal_shape"
  CHECK (("entry_type" = 'REVERSAL') = ("reversal_of_entry_id" IS NOT NULL));
ALTER TABLE "points_ledger" ADD CONSTRAINT "points_ledger_sign"
  CHECK (("entry_type" = 'EARN' AND "points_delta" > 0) OR ("entry_type" = 'REVERSAL' AND "points_delta" < 0) OR "entry_type" = 'ADJUSTMENT');
ALTER TABLE "points_ledger" ADD CONSTRAINT "points_ledger_admin_reason"
  CHECK ("source_type" <> 'ADMIN' OR ("reason" IS NOT NULL AND "idempotency_key" IS NOT NULL AND "created_by_id" IS NOT NULL));

ALTER TABLE "level_history" ADD CONSTRAINT "level_history_levels_range"
  CHECK (("previous_level" IS NULL OR "previous_level" BETWEEN 1 AND 200) AND ("new_level" IS NULL OR "new_level" BETWEEN 1 AND 200));

ALTER TABLE "level_source_events" ADD CONSTRAINT "level_source_events_attempts_nonnegative"
  CHECK ("attempts" >= 0);

-- The four categories, disabled, with no version (CP-005 §8). Names and descriptions are the
-- user-facing defaults; admins may edit them.
INSERT INTO "level_categories" ("id", "code", "name_ar", "name_en", "description_ar", "description_en", "is_enabled", "updated_at") VALUES
  (gen_random_uuid(), 'ATTRACTIVENESS', 'مستوى الجاذبية', 'Attractiveness', 'يرتفع بقيمة الهدايا التي تستلمها.', 'Grows with the value of the gifts you receive.', false, CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'SUPPORT', 'مستوى الدعم', 'Support', 'يرتفع بقيمة الهدايا التي ترسلها.', 'Grows with the value of the gifts you send.', false, CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'WIZARD', 'مستوى الساحر', 'Wizard', 'يرتفع بقيمة هدايا الحظ التي ترسلها، لا بما تربحه منها.', 'Grows with the value of the lucky gifts you send, not what they win.', false, CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'GAMING', 'مستوى اللعب', 'Gaming', 'يرتفع بما تنفقه داخل الألعاب، لا بما تربحه.', 'Grows with what you spend in games, not what you win.', false, CURRENT_TIMESTAMP)
ON CONFLICT ("code") DO NOTHING;

-- Append-only for the runtime group of THIS database (as audit_logs, 20261016130000). The shadow
-- database of `prisma migrate dev` has no runtime group and is skipped.
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
  EXECUTE format('REVOKE UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.points_ledger FROM %I', grp);
  EXECUTE format('REVOKE UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.level_history FROM %I', grp);
END
$$;
