-- v1.75-live (D285, owner, CONVENTIONS §10.96.13): recruitment by staff «الاستقطاب».
--
-- 1. The four application forms (agency «افتح وكالة», recharge agent «كن وكيل شحن», host «كن مضيفاً مع الإدارة», and
--    the new creator programme «انضم كصانع محتوى») may name the Kabso Team member who referred the applicant
--    (`recruiter_user_id`; an ACTIVE MODERATION or BD staff member, checked by the API at the submission and again at
--    the activation).
-- 2. `creator_applications` / `creator_members`: the creator programme (there was no creator application before).
-- 3. `staff_recruitments`: the recruit permanently attributed to the recruiter when the application is ACTIVATED
--    (approved; an agency at its opening). One per (type, recruit); HOST and CREATOR exclusive per person. The OWNER
--    alone changes the recruiter (panel, reason, audited).
-- 4. `staff_recruit_settings`: the OWNER's shares per type (bps of the platform profit; defaults 2 % host / creator,
--    1 % agency / recharge agent; at most 20 %).
-- 5. `staff_recruit_commissions`: one row per recruitment and day, written once by the daily job (primary key =
--    idempotency) with the profit counted and the share; CHECK `staff_recruit_commissions_guard`: the cherries are never
--    more than the share of the ACTUAL profit counted (cherry value = rate_minor / rate_cherries). Append-only for the
--    runtime group.
-- 6. The cherry ledger's sign rule: STAFF_RECRUIT_COMMISSION is a credit.
-- 7. `kabso_admin_panel_role(...)` accepts BD (a panel role; it gets its staff ID like the others).
--
-- New tables get their runtime grants from the default privileges (KL-013, migration 20261016130000).
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

CREATE TYPE "staff_recruit_type" AS ENUM ('HOST', 'AGENCY', 'RECHARGE_AGENT', 'CREATOR');
CREATE TYPE "creator_application_status" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED');

-- 1. The recruiter named on an application.
ALTER TABLE "agency_applications" ADD COLUMN "recruiter_user_id" UUID;
ALTER TABLE "recharge_agent_applications" ADD COLUMN "recruiter_user_id" UUID;
ALTER TABLE "host_applications" ADD COLUMN "recruiter_user_id" UUID;
ALTER TABLE "agency_applications" ADD CONSTRAINT "agency_applications_recruiter_user_id_fkey" FOREIGN KEY ("recruiter_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "recharge_agent_applications" ADD CONSTRAINT "recharge_agent_applications_recruiter_user_id_fkey" FOREIGN KEY ("recruiter_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "host_applications" ADD CONSTRAINT "host_applications_recruiter_user_id_fkey" FOREIGN KEY ("recruiter_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "agency_applications" ADD CONSTRAINT "agency_applications_recruiter_not_self" CHECK ("recruiter_user_id" IS DISTINCT FROM "user_id");
ALTER TABLE "recharge_agent_applications" ADD CONSTRAINT "recharge_agent_applications_recruiter_not_self" CHECK ("recruiter_user_id" IS DISTINCT FROM "user_id");
ALTER TABLE "host_applications" ADD CONSTRAINT "host_applications_recruiter_not_self" CHECK ("recruiter_user_id" IS DISTINCT FROM "user_id");

-- 2. The creator programme.
CREATE TABLE "creator_applications" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "status" "creator_application_status" NOT NULL DEFAULT 'PENDING',
    "country" CHAR(2) NOT NULL,
    "category" VARCHAR(24) NOT NULL,
    "links" VARCHAR(200)[],
    "bio" VARCHAR(300),
    "recruiter_user_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "decided_at" TIMESTAMPTZ(3),
    "decided_by_id" UUID,
    "reject_reason" VARCHAR(500),

    CONSTRAINT "creator_applications_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "creator_applications_shape" CHECK (
        "country" ~ '^[A-Z]{2}$'
        AND "category" IN ('VIDEO', 'PHOTO', 'MUSIC', 'GAMING', 'COMEDY', 'EDUCATION', 'LIFESTYLE', 'OTHER')
        AND "links" IS NOT NULL AND cardinality("links") BETWEEN 1 AND 5
        AND "recruiter_user_id" IS DISTINCT FROM "user_id"
        AND ("status" = 'PENDING') = ("decided_at" IS NULL)
        AND ("status" = 'REJECTED') = ("reject_reason" IS NOT NULL))
);
CREATE INDEX "creator_applications_user_idx" ON "creator_applications"("user_id", "created_at" DESC);
CREATE INDEX "creator_applications_status_idx" ON "creator_applications"("status", "created_at" DESC);
CREATE UNIQUE INDEX "creator_applications_one_pending" ON "creator_applications"("user_id") WHERE (status = 'PENDING'::creator_application_status);
ALTER TABLE "creator_applications" ADD CONSTRAINT "creator_applications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "creator_applications" ADD CONSTRAINT "creator_applications_decided_by_id_fkey" FOREIGN KEY ("decided_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "creator_applications" ADD CONSTRAINT "creator_applications_recruiter_user_id_fkey" FOREIGN KEY ("recruiter_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "creator_members" (
    "user_id" UUID NOT NULL,
    "application_id" UUID NOT NULL,
    "activated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "creator_members_pkey" PRIMARY KEY ("user_id")
);
CREATE UNIQUE INDEX "creator_members_application_key" ON "creator_members"("application_id");
ALTER TABLE "creator_members" ADD CONSTRAINT "creator_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "creator_members" ADD CONSTRAINT "creator_members_application_id_fkey" FOREIGN KEY ("application_id") REFERENCES "creator_applications"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- 3. The recruitments.
CREATE TABLE "staff_recruitments" (
    "id" UUID NOT NULL,
    "type" "staff_recruit_type" NOT NULL,
    "recruiter_user_id" UUID NOT NULL,
    "recruit_user_id" UUID NOT NULL,
    "application_id" UUID NOT NULL,
    "agency_id" UUID,
    "activated_at" TIMESTAMPTZ(3) NOT NULL,
    "reassigned_at" TIMESTAMPTZ(3),
    "reassigned_by_id" UUID,
    "reassign_reason" VARCHAR(500),

    CONSTRAINT "staff_recruitments_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "staff_recruitments_shape" CHECK (
        "recruiter_user_id" <> "recruit_user_id"
        AND ("agency_id" IS NOT NULL) = ("type" = 'AGENCY')
        AND ("reassigned_at" IS NULL) = ("reassign_reason" IS NULL)
        AND ("reassign_reason" IS NULL OR char_length(btrim("reassign_reason")) >= 1))
);
CREATE INDEX "staff_recruitments_recruiter_idx" ON "staff_recruitments"("recruiter_user_id", "type", "activated_at" DESC);
CREATE UNIQUE INDEX "staff_recruitments_type_recruit_key" ON "staff_recruitments"("type", "recruit_user_id");
CREATE UNIQUE INDEX "staff_recruitments_one_gift_recruit" ON "staff_recruitments"("recruit_user_id") WHERE (type IN ('HOST'::staff_recruit_type, 'CREATOR'::staff_recruit_type));
ALTER TABLE "staff_recruitments" ADD CONSTRAINT "staff_recruitments_recruiter_user_id_fkey" FOREIGN KEY ("recruiter_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "staff_recruitments" ADD CONSTRAINT "staff_recruitments_recruit_user_id_fkey" FOREIGN KEY ("recruit_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- 4. The OWNER's shares (one row).
CREATE TABLE "staff_recruit_settings" (
    "id" SMALLINT NOT NULL DEFAULT 1,
    "host_bps" INTEGER NOT NULL DEFAULT 200,
    "creator_bps" INTEGER NOT NULL DEFAULT 200,
    "agency_bps" INTEGER NOT NULL DEFAULT 100,
    "recharge_bps" INTEGER NOT NULL DEFAULT 100,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_by_id" UUID,

    CONSTRAINT "staff_recruit_settings_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "staff_recruit_settings_one" CHECK ("id" = 1),
    CONSTRAINT "staff_recruit_settings_shape" CHECK (
        "host_bps" BETWEEN 0 AND 2000 AND "creator_bps" BETWEEN 0 AND 2000
        AND "agency_bps" BETWEEN 0 AND 2000 AND "recharge_bps" BETWEEN 0 AND 2000)
);
INSERT INTO "staff_recruit_settings" ("id") VALUES (1) ON CONFLICT DO NOTHING;

-- 5. The daily commissions.
CREATE TABLE "staff_recruit_commissions" (
    "recruitment_id" UUID NOT NULL,
    "day" DATE NOT NULL,
    "type" "staff_recruit_type" NOT NULL,
    "recruiter_user_id" UUID NOT NULL,
    "recruit_user_id" UUID NOT NULL,
    "profit_units" DECIMAL(40,0) NOT NULL,
    "rate_cherries" BIGINT NOT NULL,
    "rate_minor" INTEGER NOT NULL,
    "bps" INTEGER NOT NULL,
    "cherries" BIGINT NOT NULL,
    "skipped" VARCHAR(24),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "staff_recruit_commissions_pkey" PRIMARY KEY ("recruitment_id","day"),
    CONSTRAINT "staff_recruit_commissions_shape" CHECK (
        "rate_cherries" > 0 AND "rate_minor" > 0 AND "bps" BETWEEN 0 AND 2000 AND "cherries" >= 0
        AND ("skipped" IS NULL OR ("skipped" IN ('RECRUITER_INACTIVE') AND "cherries" = 0))),
    -- The owner's guard: cherries × (rate_minor × 10^6 money units per cherry) × 10 000 ≤ max(profit, 0) × bps.
    CONSTRAINT "staff_recruit_commissions_guard" CHECK (
        "cherries"::numeric * "rate_minor"::numeric * 1000000 * 10000
          <= GREATEST("profit_units", 0) * "bps"::numeric)
);
CREATE INDEX "staff_recruit_commissions_recruiter_idx" ON "staff_recruit_commissions"("recruiter_user_id", "day" DESC);
CREATE INDEX "staff_recruit_commissions_day_idx" ON "staff_recruit_commissions"("day");
ALTER TABLE "staff_recruit_commissions" ADD CONSTRAINT "staff_recruit_commissions_recruitment_id_fkey" FOREIGN KEY ("recruitment_id") REFERENCES "staff_recruitments"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "staff_recruit_commissions" ADD CONSTRAINT "staff_recruit_commissions_recruiter_user_id_fkey" FOREIGN KEY ("recruiter_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Append-only for the runtime group of THIS database (the shadow database has none): a day is written once.
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
  EXECUTE format('REVOKE UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.staff_recruit_commissions FROM %I', grp);
END
$$;

-- 6. The cherry ledger's sign rule: STAFF_RECRUIT_COMMISSION is a credit (extended in place, as 20270315090100).
DO $$
DECLARE
  def text;
BEGIN
  SELECT pg_get_constraintdef(c.oid) INTO STRICT def
    FROM pg_constraint c
   WHERE c.conrelid = 'cherry_ledger'::regclass AND c.conname = 'cherry_ledger_reason_sign';
  ALTER TABLE "cherry_ledger" DROP CONSTRAINT "cherry_ledger_reason_sign";
  EXECUTE format('ALTER TABLE cherry_ledger ADD CONSTRAINT cherry_ledger_reason_sign CHECK ((%s) OR (reason::text = %L AND delta > 0))',
                 substring(def FROM '^CHECK \((.*)\)$'), 'STAFF_RECRUIT_COMMISSION');
END
$$;

-- 7. BD is a panel role.
CREATE OR REPLACE FUNCTION public.kabso_admin_panel_role(p_user uuid, p_role text, p_grant boolean, p_by uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  changed integer;
BEGIN
  -- v1.75-live (D285): BD «تطوير الأعمال».
  IF p_role NOT IN ('OWNER', 'MODERATION', 'SUPPORT', 'FINANCE', 'BD') THEN
    RAISE EXCEPTION 'kabso_admin_panel_role: % is not a panel role', p_role USING ERRCODE = '22023';
  END IF;
  IF p_grant THEN
    INSERT INTO user_admin_permissions (user_id, permission, granted_by_id)
    VALUES (p_user, p_role::admin_permission, p_by)
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS changed = ROW_COUNT;
    -- v1.73-live (D283c) / v1.74-live (D283d): the staff ID in this transaction («Kabso» for the primary OWNER).
    PERFORM kabso_assign_staff_id(p_user, p_role = 'OWNER');
  ELSE
    DELETE FROM user_admin_permissions WHERE user_id = p_user AND permission = p_role::admin_permission;
    GET DIAGNOSTICS changed = ROW_COUNT;
  END IF;
  RETURN changed > 0;
END
$fn$;
