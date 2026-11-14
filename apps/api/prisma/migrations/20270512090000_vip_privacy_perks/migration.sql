-- v1.133-social (D380, owner 2026-11-11), CONVENTIONS §10.170: the VIP privacy perks.
--
-- 1. `privacy_settings`: the holder's switch of three perks (kept when the membership ends; read only while the perk
--    is held): «زيارة خفية» HIDDEN_VISIT (default on), «اسم مخفي في التصنيفات» RANKING_ANONYMOUS (default off),
--    «حماية من طرد وكتم المشرف العادي» KICK_MUTE_SHIELD (default on). A person without a row gets the defaults.
-- 2. `live_gifts.anonymous`: an ANONYMOUS_GIFT send «إهداء مجهول» — the room, the recipients and the other lives see
--    «مجهول»; `sender_id` stays the real sender (the ledger, the audit and the panel are unchanged).
-- 3. `reports.context_live_gift_id`: a report filed by a recipient from a gift (an anonymous one names no one): a USER
--    report on the real sender, with the send it came from, for the team.
-- 4. `anonymous_gift_blocks`: a recipient refuses any further ANONYMOUS gift from the sender of a send (without
--    learning who it is); the sender's named gifts are unaffected (an ordinary block still covers everything).
--
-- Every existing row is kept as it is; the new columns take their defaults. Nothing is deleted.
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

ALTER TABLE "privacy_settings" ADD COLUMN "vip_hidden_visit" BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "privacy_settings" ADD COLUMN "vip_ranking_anonymous" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "privacy_settings" ADD COLUMN "vip_kick_mute_shield" BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE "live_gifts" ADD COLUMN "anonymous" BOOLEAN NOT NULL DEFAULT false;
-- An anonymous send is a live send (a direct-conversation gift names its sender to the one person it is for).
ALTER TABLE "live_gifts" ADD CONSTRAINT "live_gifts_anonymous_live" CHECK (NOT "anonymous" OR "dm_conversation_id" IS NULL);

ALTER TABLE "reports" ADD COLUMN "context_live_gift_id" UUID;
ALTER TABLE "reports" ADD CONSTRAINT "reports_context_live_gift_id_fkey" FOREIGN KEY ("context_live_gift_id") REFERENCES "live_gifts"("id") ON DELETE SET NULL ON UPDATE CASCADE;
CREATE INDEX "reports_context_live_gift_idx" ON "reports"("context_live_gift_id") WHERE "context_live_gift_id" IS NOT NULL;

CREATE TABLE "anonymous_gift_blocks" (
    "recipient_id" UUID NOT NULL,
    "sender_id" UUID NOT NULL,
    "gift_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "anonymous_gift_blocks_pkey" PRIMARY KEY ("recipient_id", "sender_id"),
    CONSTRAINT "anonymous_gift_blocks_not_self" CHECK ("recipient_id" <> "sender_id")
);
CREATE INDEX "anonymous_gift_blocks_sender_idx" ON "anonymous_gift_blocks"("sender_id");
ALTER TABLE "anonymous_gift_blocks" ADD CONSTRAINT "anonymous_gift_blocks_recipient_id_fkey" FOREIGN KEY ("recipient_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "anonymous_gift_blocks" ADD CONSTRAINT "anonymous_gift_blocks_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "anonymous_gift_blocks" ADD CONSTRAINT "anonymous_gift_blocks_gift_id_fkey" FOREIGN KEY ("gift_id") REFERENCES "live_gifts"("id") ON DELETE SET NULL ON UPDATE CASCADE;
