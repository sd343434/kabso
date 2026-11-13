-- v1.62-social (D193, owner 2026-10-31: retention answers; CONVENTIONS §10.56, CP-036 §4).
--
-- 1. Legal hold of reported content: content of a purged account that has an OPEN or ACTIONED report is copied into
--    `legal_holds` at the purge (a snapshot; the original rows are deleted as for any other content), hidden from
--    every user, linked only to its reports (`reports.legal_hold_id`) and to the tombstone id, and deleted with its
--    reports and files after REPORT_LEGAL_HOLD_DAYS (90). A held report of a post, comment, story, live-chat,
--    family-chat or CP-confession message keeps no target id (those rows are deleted, and their foreign keys cascade);
--    the hold carries it. DM and profile-link reports keep their id and snapshot (no foreign key).
-- 2. Audit IP addresses of a purged account are dropped at the purge and the person's identifiers removed from the
--    audit metadata; 7 years later (DELETED_LEDGER_RETENTION_DAYS) the tombstone's audit rows are deleted and the
--    admin reasons on its points ledger blanked. audit_logs, points_ledger and level_history are append-only for the
--    runtime role (20261016130000, 20261020090000), so the two narrow steps are SECURITY DEFINER functions that act
--    only on a DELETED account.

CREATE TABLE "legal_holds" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "target_type" "report_target_type" NOT NULL,
    "target_id" UUID NOT NULL,
    "snapshot" JSONB NOT NULL,
    "object_keys" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "held_at" TIMESTAMPTZ(3) NOT NULL,
    "delete_after" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "legal_holds_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "legal_holds_target_key" ON "legal_holds"("target_type", "target_id");
CREATE INDEX "legal_holds_delete_after_idx" ON "legal_holds"("delete_after");
CREATE INDEX "legal_holds_user_idx" ON "legal_holds"("user_id");

ALTER TABLE "legal_holds" ADD CONSTRAINT "legal_holds_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "legal_holds" ADD CONSTRAINT "legal_holds_shape" CHECK (
  delete_after > held_at
  AND target_type::text <> 'USER' AND target_type::text <> 'LIVE_ROOM'
  AND jsonb_typeof(snapshot) = 'object');

ALTER TABLE "reports" ADD COLUMN "legal_hold_id" UUID;
CREATE INDEX "reports_legal_hold_idx" ON "reports"("legal_hold_id");
ALTER TABLE "reports" ADD CONSTRAINT "reports_legal_hold_id_fkey"
  FOREIGN KEY ("legal_hold_id") REFERENCES "legal_holds"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Reports: exactly one target, the one the type names (20261215100000) — or, for content deleted at a purge and kept
-- under a legal hold, no target id and the hold.
ALTER TABLE "reports" DROP CONSTRAINT "reports_one_target";
ALTER TABLE "reports" ADD CONSTRAINT "reports_one_target" CHECK (
  (
    num_nonnulls(target_post_id, target_comment_id, target_user_id, target_story_id, target_live_room_id,
                 target_live_chat_message_id, target_cp_confession_id, target_family_chat_message_id,
                 target_dm_message_id, target_profile_link_id) = 1
    AND (
      (target_type::text = 'POST' AND target_post_id IS NOT NULL)
      OR (target_type::text = 'COMMENT' AND target_comment_id IS NOT NULL)
      OR (target_type::text = 'USER' AND target_user_id IS NOT NULL)
      OR (target_type::text = 'STORY' AND target_story_id IS NOT NULL)
      OR (target_type::text = 'LIVE_ROOM' AND target_live_room_id IS NOT NULL)
      OR (target_type::text = 'LIVE_CHAT_MESSAGE' AND target_live_chat_message_id IS NOT NULL)
      OR (target_type::text = 'CP_CONFESSION' AND target_cp_confession_id IS NOT NULL)
      OR (target_type::text = 'FAMILY_CHAT_MESSAGE' AND target_family_chat_message_id IS NOT NULL)
      OR (target_type::text = 'DM_MESSAGE' AND target_dm_message_id IS NOT NULL AND dm_snapshot IS NOT NULL)
      OR (target_type::text = 'PROFILE_LINK' AND target_profile_link_id IS NOT NULL AND link_snapshot IS NOT NULL)))
  OR (
    legal_hold_id IS NOT NULL
    AND target_type::text IN ('POST', 'COMMENT', 'STORY', 'LIVE_CHAT_MESSAGE', 'CP_CONFESSION',
                             'FAMILY_CHAT_MESSAGE')
    AND num_nonnulls(target_post_id, target_comment_id, target_user_id, target_story_id, target_live_room_id,
                     target_live_chat_message_id, target_cp_confession_id, target_family_chat_message_id,
                     target_dm_message_id, target_profile_link_id) = 0));

-- At the purge: the account's audit rows (as actor, or as the target user) lose their IP address and the person's
-- identifiers in the metadata. Only for a DELETED account (the purge sets the status first, in the same transaction).
CREATE FUNCTION account_deletion_scrub_audit(p_user uuid) RETURNS integer
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  n integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user AND status = 'DELETED'::user_status) THEN
    RAISE EXCEPTION 'account_deletion_scrub_audit: % is not a deleted account', p_user;
  END IF;
  UPDATE audit_logs
     SET ip = NULL,
         metadata = CASE WHEN jsonb_typeof(metadata) = 'object'
                         THEN metadata - ARRAY['username', 'email', 'identifier', 'from', 'to', 'baseUsername',
                                               'regularUsername', 'displayName', 'name', 'phone', 'fullName']
                         ELSE metadata END
   WHERE actor_user_id = p_user OR (target_type = 'user' AND target_id = p_user::text);
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END
$$;

-- DELETED_LEDGER_RETENTION_DAYS after the purge: the tombstone's audit rows are deleted and the free-text admin
-- reasons on its points ledger blanked (an ADMIN row must keep a reason: '—'). Only for an account DELETED on or
-- before p_cutoff.
CREATE FUNCTION account_deletion_end_retention(p_user uuid, p_cutoff timestamptz) RETURNS integer
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  n integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user AND status = 'DELETED'::user_status
                    AND deleted_at IS NOT NULL AND deleted_at <= p_cutoff) THEN
    RAISE EXCEPTION 'account_deletion_end_retention: % is not an account deleted before %', p_user, p_cutoff;
  END IF;
  DELETE FROM audit_logs WHERE actor_user_id = p_user OR (target_type = 'user' AND target_id = p_user::text);
  GET DIAGNOSTICS n = ROW_COUNT;
  UPDATE points_ledger SET reason = CASE WHEN source_type::text = 'ADMIN' THEN '—' ELSE NULL END
   WHERE user_id = p_user AND reason IS NOT NULL AND reason <> '—';
  RETURN n;
END
$$;

REVOKE ALL ON FUNCTION account_deletion_scrub_audit(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION account_deletion_end_retention(uuid, timestamptz) FROM PUBLIC;

-- The runtime group of THIS database may call both (KL7F-06: no routine is executable by PUBLIC). The shadow
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
  EXECUTE format('GRANT EXECUTE ON FUNCTION public.account_deletion_scrub_audit(uuid) TO %I', grp);
  EXECUTE format('GRANT EXECUTE ON FUNCTION public.account_deletion_end_retention(uuid, timestamptz) TO %I', grp);
END
$$;
