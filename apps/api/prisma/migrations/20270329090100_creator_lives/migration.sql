-- v1.82-live (D295, owner, CONVENTIONS §10.108): content creators go live «صانع محتوى».
--
-- 1. `creator_applications.source` / `agency_id`: an application is the person's own («انضم كصانع محتوى», APPLICATION)
--    or an agency owner's activation of one of the agency's members as a creator (AGENCY: written APPROVED at once,
--    `decided_by_id` = the agency owner, `agency_id` = the activating agency — «فعّله وكيل: …» in the panel).
-- 2. `creator_applications.revoked_*`: the team ended the membership the application made (status REVOKED).
-- 3. Host and creator are mutually exclusive (owner): a `creator_members` row and a `live_hosts` row of another source
--    never exist together for one person. Enforced by a trigger on both tables (every path: API, CLI, SQL), on top of
--    the API's own refusals. Rows that already exist are NOT changed (see DEPLOYMENT §5.76 for the data check).
-- 4. Backfill: every existing member without a hosting permission gets `live_hosts` CREATOR (the membership grants it).
--    A member who already holds the permission from another source keeps that row untouched (a both-roles case for
--    the team: DEPLOYMENT §5.76).
-- 5. `agency_bans`: one row per banned agency (the agency id is the key: a second ban changes nothing) with the
--    reason, the commission counted, the cherries forfeited (AGENCY_FORFEIT) and the creator activations concerned.
--    Append-only for the runtime group.
-- 6. The cherry ledger's sign rule: AGENCY_FORFEIT is a debit.
--
-- New tables get their runtime grants from the default privileges (KL-013, migration 20261016130000).
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

CREATE TYPE "creator_application_source" AS ENUM ('APPLICATION', 'AGENCY');

-- 1. and 2.
ALTER TABLE "creator_applications"
  ADD COLUMN "source" "creator_application_source" NOT NULL DEFAULT 'APPLICATION',
  ADD COLUMN "agency_id" UUID,
  ADD COLUMN "revoked_at" TIMESTAMPTZ(3),
  ADD COLUMN "revoked_by_id" UUID,
  ADD COLUMN "revoke_reason" VARCHAR(500);
ALTER TABLE "creator_applications" ADD CONSTRAINT "creator_applications_agency_id_fkey" FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "creator_applications" ADD CONSTRAINT "creator_applications_revoked_by_id_fkey" FOREIGN KEY ("revoked_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "creator_applications" ADD CONSTRAINT "creator_applications_activation_shape" CHECK (
  ("source" = 'APPLICATION' OR "status" IN ('APPROVED', 'REVOKED'))
  AND ("status" = 'REVOKED') = ("revoked_at" IS NOT NULL)
  AND ("revoked_at" IS NULL) = ("revoke_reason" IS NULL));
CREATE INDEX "creator_applications_agency_idx" ON "creator_applications"("agency_id", "created_at" DESC) WHERE "agency_id" IS NOT NULL;

-- 3. Host and creator are mutually exclusive.
CREATE OR REPLACE FUNCTION public.kabso_creator_host_exclusive() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_TABLE_NAME = 'live_hosts' THEN
    IF NEW.source <> 'CREATOR'::live_host_source
       AND EXISTS (SELECT 1 FROM creator_members m WHERE m.user_id = NEW.user_id) THEN
      RAISE EXCEPTION 'D295: % is a content creator and cannot also be a host', NEW.user_id
        USING ERRCODE = '23514', CONSTRAINT = 'creator_host_exclusive';
    END IF;
  ELSE
    IF EXISTS (SELECT 1 FROM live_hosts h WHERE h.user_id = NEW.user_id AND h.source <> 'CREATOR'::live_host_source) THEN
      RAISE EXCEPTION 'D295: % is a host and cannot also be a content creator', NEW.user_id
        USING ERRCODE = '23514', CONSTRAINT = 'creator_host_exclusive';
    END IF;
  END IF;
  RETURN NEW;
END
$$;
CREATE TRIGGER "live_hosts_creator_exclusive" BEFORE INSERT OR UPDATE OF "source", "user_id" ON "live_hosts"
  FOR EACH ROW EXECUTE FUNCTION public.kabso_creator_host_exclusive();
CREATE TRIGGER "creator_members_host_exclusive" BEFORE INSERT OR UPDATE OF "user_id" ON "creator_members"
  FOR EACH ROW EXECUTE FUNCTION public.kabso_creator_host_exclusive();

-- 4. Backfill (one statement; a rare room-number clash would skip that member — DEPLOYMENT §5.76 lists it).
INSERT INTO "live_hosts" ("user_id", "source", "granted_at")
SELECT m."user_id", 'CREATOR'::live_host_source, m."activated_at"
  FROM "creator_members" m
 WHERE NOT EXISTS (SELECT 1 FROM "live_hosts" h WHERE h."user_id" = m."user_id")
ON CONFLICT DO NOTHING;

-- 5. Agency bans.
CREATE TABLE "agency_bans" (
    "agency_id" UUID NOT NULL,
    "owner_user_id" UUID NOT NULL,
    "banned_by_id" UUID,
    "reason" VARCHAR(500) NOT NULL,
    "commission_cherries" BIGINT NOT NULL,
    "forfeited_cherries" BIGINT NOT NULL,
    "creator_user_ids" UUID[] NOT NULL DEFAULT ARRAY[]::UUID[],
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "agency_bans_pkey" PRIMARY KEY ("agency_id"),
    CONSTRAINT "agency_bans_shape" CHECK (
        char_length(btrim("reason")) >= 1
        AND "commission_cherries" >= 0
        AND "forfeited_cherries" >= 0
        AND "forfeited_cherries" <= "commission_cherries")
);
CREATE INDEX "agency_bans_owner_idx" ON "agency_bans"("owner_user_id");
ALTER TABLE "agency_bans" ADD CONSTRAINT "agency_bans_agency_id_fkey" FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "agency_bans" ADD CONSTRAINT "agency_bans_owner_user_id_fkey" FOREIGN KEY ("owner_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "agency_bans" ADD CONSTRAINT "agency_bans_banned_by_id_fkey" FOREIGN KEY ("banned_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

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
  EXECUTE format('REVOKE UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.agency_bans FROM %I', grp);
END
$$;

-- 6. The cherry ledger's sign rule: AGENCY_FORFEIT is a debit (extended in place, as 20270319090100).
DO $$
DECLARE
  def text;
BEGIN
  SELECT pg_get_constraintdef(c.oid) INTO STRICT def
    FROM pg_constraint c
   WHERE c.conrelid = 'cherry_ledger'::regclass AND c.conname = 'cherry_ledger_reason_sign';
  ALTER TABLE "cherry_ledger" DROP CONSTRAINT "cherry_ledger_reason_sign";
  EXECUTE format('ALTER TABLE cherry_ledger ADD CONSTRAINT cherry_ledger_reason_sign CHECK ((%s) OR (reason::text = %L AND delta < 0))',
                 substring(def FROM '^CHECK \((.*)\)$'), 'AGENCY_FORFEIT');
END
$$;
