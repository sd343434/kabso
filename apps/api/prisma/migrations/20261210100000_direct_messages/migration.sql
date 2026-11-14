-- v1.40-social (D155, owner 2026-10-28): direct messages, CONVENTIONS §11.13. Owned by the
-- `messages` module. The runtime role gets DML through the default privileges
-- (20261016130000_per_database_runtime_group), so this migration contains no GRANT.
--
-- * `dm_conversations` (one per pair), `dm_participants` (each side: status, mute, read and
--   "deleted for me" pointers, the request counter), `dm_messages` (hard-deleted by the sweeper at
--   `expires_at`, 24 h after sending), `dm_message_hides` ("delete for me").
-- * `privacy_settings.who_can_message` («من يستطيع مراسلتك», default EVERYONE).
-- * `live_gifts.dm_conversation_id`: a gift sent in a conversation (room_id NULL); the send, its
--   ledger rows and draws are permanent, the message expires.
-- * `reports.target_dm_message_id` (no foreign key: the message is deleted after 24 h) and
--   `reports.dm_snapshot` (what the message was; cleared 30 days after the report is resolved).
-- CreateEnum
CREATE TYPE "who_can_message" AS ENUM ('EVERYONE', 'FOLLOWING', 'NOBODY');

-- CreateEnum
CREATE TYPE "dm_participant_status" AS ENUM ('ACCEPTED', 'REQUEST');

-- CreateEnum
CREATE TYPE "dm_message_kind" AS ENUM ('TEXT', 'IMAGE', 'VOICE', 'EMOJI', 'GIFT');


-- AlterTable
ALTER TABLE "reports" ADD COLUMN     "dm_snapshot" JSONB,
ADD COLUMN     "target_dm_message_id" UUID;

-- AlterTable
ALTER TABLE "privacy_settings" ADD COLUMN     "who_can_message" "who_can_message" NOT NULL DEFAULT 'EVERYONE';

-- AlterTable
ALTER TABLE "live_gifts" ADD COLUMN     "dm_conversation_id" UUID;

-- CreateTable
CREATE TABLE "dm_conversations" (
    "id" UUID NOT NULL,
    "user_low_id" UUID NOT NULL,
    "user_high_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_message_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "dm_conversations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "dm_participants" (
    "conversation_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "peer_id" UUID NOT NULL,
    "status" "dm_participant_status" NOT NULL,
    "muted" BOOLEAN NOT NULL DEFAULT false,
    "has_sent" BOOLEAN NOT NULL DEFAULT false,
    "request_sent" INTEGER NOT NULL DEFAULT 0,
    "read_at" TIMESTAMPTZ(3),
    "cleared_at" TIMESTAMPTZ(3),
    "last_message_at" TIMESTAMPTZ(3) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "dm_participants_pkey" PRIMARY KEY ("conversation_id","user_id")
);

-- CreateTable
CREATE TABLE "dm_messages" (
    "id" UUID NOT NULL,
    "conversation_id" UUID NOT NULL,
    "sender_id" UUID NOT NULL,
    "recipient_id" UUID NOT NULL,
    "client_id" UUID NOT NULL,
    "kind" "dm_message_kind" NOT NULL,
    "text" VARCHAR(1000),
    "token" VARCHAR(64),
    "media_id" UUID,
    "gift_id" UUID,
    "as_request" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "dm_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "dm_message_hides" (
    "message_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "dm_message_hides_pkey" PRIMARY KEY ("message_id","user_id")
);

-- CreateIndex
CREATE INDEX "dm_conversations_user_high_idx" ON "dm_conversations"("user_high_id");

-- CreateIndex
CREATE UNIQUE INDEX "dm_conversations_pair_key" ON "dm_conversations"("user_low_id", "user_high_id");

-- CreateIndex
CREATE INDEX "dm_participants_list_idx" ON "dm_participants"("user_id", "status", "last_message_at" DESC, "conversation_id");

-- CreateIndex
CREATE INDEX "dm_participants_peer_idx" ON "dm_participants"("peer_id");

-- CreateIndex
CREATE UNIQUE INDEX "dm_participants_user_peer_key" ON "dm_participants"("user_id", "peer_id");

-- CreateIndex
CREATE UNIQUE INDEX "dm_messages_media_id_key" ON "dm_messages"("media_id");

-- CreateIndex
CREATE UNIQUE INDEX "dm_messages_gift_id_key" ON "dm_messages"("gift_id");

-- CreateIndex
CREATE INDEX "dm_messages_conversation_idx" ON "dm_messages"("conversation_id", "created_at", "id");

-- CreateIndex
CREATE INDEX "dm_messages_recipient_idx" ON "dm_messages"("recipient_id", "created_at");

-- CreateIndex
CREATE INDEX "dm_messages_expires_idx" ON "dm_messages"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "dm_messages_client_once" ON "dm_messages"("sender_id", "client_id");

-- CreateIndex
CREATE INDEX "dm_message_hides_user_idx" ON "dm_message_hides"("user_id");

-- CreateIndex
CREATE INDEX "reports_target_dm_message_idx" ON "reports"("target_dm_message_id");

-- CreateIndex
CREATE UNIQUE INDEX "reports_open_dm_message_once" ON "reports"("reporter_id", "target_dm_message_id") WHERE (status = 'OPEN'::report_status AND target_dm_message_id IS NOT NULL);

-- CreateIndex
CREATE INDEX "live_gifts_dm_conversation_idx" ON "live_gifts"("dm_conversation_id");

-- AddForeignKey
ALTER TABLE "live_gifts" ADD CONSTRAINT "live_gifts_dm_conversation_id_fkey" FOREIGN KEY ("dm_conversation_id") REFERENCES "dm_conversations"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dm_conversations" ADD CONSTRAINT "dm_conversations_user_low_id_fkey" FOREIGN KEY ("user_low_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dm_conversations" ADD CONSTRAINT "dm_conversations_user_high_id_fkey" FOREIGN KEY ("user_high_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dm_participants" ADD CONSTRAINT "dm_participants_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "dm_conversations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dm_participants" ADD CONSTRAINT "dm_participants_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dm_participants" ADD CONSTRAINT "dm_participants_peer_id_fkey" FOREIGN KEY ("peer_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dm_messages" ADD CONSTRAINT "dm_messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "dm_conversations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dm_messages" ADD CONSTRAINT "dm_messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dm_messages" ADD CONSTRAINT "dm_messages_recipient_id_fkey" FOREIGN KEY ("recipient_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dm_messages" ADD CONSTRAINT "dm_messages_media_id_fkey" FOREIGN KEY ("media_id") REFERENCES "media_assets"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dm_messages" ADD CONSTRAINT "dm_messages_gift_id_fkey" FOREIGN KEY ("gift_id") REFERENCES "live_gifts"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dm_message_hides" ADD CONSTRAINT "dm_message_hides_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "dm_messages"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dm_message_hides" ADD CONSTRAINT "dm_message_hides_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;


-- Pairs are stored once, low id first.
ALTER TABLE "dm_conversations" ADD CONSTRAINT "dm_conversations_ordered" CHECK (user_low_id < user_high_id);
ALTER TABLE "dm_participants" ADD CONSTRAINT "dm_participants_not_self" CHECK (user_id <> peer_id);
ALTER TABLE "dm_participants" ADD CONSTRAINT "dm_participants_request_sent_range" CHECK (request_sent >= 0);
ALTER TABLE "dm_messages" ADD CONSTRAINT "dm_messages_not_self" CHECK (sender_id <> recipient_id);
ALTER TABLE "dm_messages" ADD CONSTRAINT "dm_messages_expiry" CHECK (expires_at >= created_at);
-- The column of its kind (media and gift may later become NULL: the asset was purged or the send
-- row's conversation was removed; the message itself is deleted with them by the sweeper).
ALTER TABLE "dm_messages" ADD CONSTRAINT "dm_messages_content" CHECK (
  (kind = 'TEXT' AND text IS NOT NULL AND char_length(text) BETWEEN 1 AND 1000 AND token IS NULL AND gift_id IS NULL AND media_id IS NULL)
  OR (kind = 'EMOJI' AND token IS NOT NULL AND text IS NULL AND gift_id IS NULL AND media_id IS NULL)
  OR (kind IN ('IMAGE', 'VOICE') AND text IS NULL AND token IS NULL AND gift_id IS NULL)
  OR (kind = 'GIFT' AND text IS NULL AND token IS NULL AND media_id IS NULL));

-- A gift is sent either in a live or in a conversation, never both.
ALTER TABLE "live_gifts" ADD CONSTRAINT "live_gifts_one_context" CHECK (room_id IS NULL OR dm_conversation_id IS NULL);

-- Reports: exactly one target, the one the type names (replaces the rule of
-- 20261115100000_families_v2; DM_MESSAGE compared as text, the value comes from the previous
-- migration). A DM_MESSAGE report always carries its snapshot.
ALTER TABLE "reports" DROP CONSTRAINT "reports_one_target";
ALTER TABLE "reports" ADD CONSTRAINT "reports_one_target" CHECK (
  num_nonnulls(target_post_id, target_comment_id, target_user_id, target_story_id, target_live_room_id,
               target_live_chat_message_id, target_cp_confession_id, target_family_chat_message_id,
               target_dm_message_id) = 1
  AND (
    (target_type::text = 'POST' AND target_post_id IS NOT NULL)
    OR (target_type::text = 'COMMENT' AND target_comment_id IS NOT NULL)
    OR (target_type::text = 'USER' AND target_user_id IS NOT NULL)
    OR (target_type::text = 'STORY' AND target_story_id IS NOT NULL)
    OR (target_type::text = 'LIVE_ROOM' AND target_live_room_id IS NOT NULL)
    OR (target_type::text = 'LIVE_CHAT_MESSAGE' AND target_live_chat_message_id IS NOT NULL)
    OR (target_type::text = 'CP_CONFESSION' AND target_cp_confession_id IS NOT NULL)
    OR (target_type::text = 'FAMILY_CHAT_MESSAGE' AND target_family_chat_message_id IS NOT NULL)
    OR (target_type::text = 'DM_MESSAGE' AND target_dm_message_id IS NOT NULL AND dm_snapshot IS NOT NULL)));

-- Media: the direct message kinds (§11.1); a DM voice note has a duration like a live chat clip.
ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_duration_shape";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_duration_shape" CHECK (
  (kind IN ('LIVE_CHAT_VOICE', 'DM_VOICE') AND duration_ms BETWEEN 1 AND 30000)
  OR (kind NOT IN ('LIVE_CHAT_VOICE', 'DM_VOICE') AND duration_ms IS NULL));
ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_kind_known";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_kind_known" CHECK (kind IN ('POST_IMAGE', 'STORY_IMAGE', 'LIVE_COVER', 'LIVE_CHAT_IMAGE', 'LIVE_CHAT_VOICE', 'FAMILY_EMBLEM', 'FAMILY_COVER', 'HOME_BANNER', 'DM_IMAGE', 'DM_VOICE'));

-- Wallet ledger: a gift in a conversation takes coins (the sign CHECK of
-- 20261205100000_live_boosts, extended: it keeps LIVE_BOOST and LIVE_BOOST_REFUND of D154b).
ALTER TABLE "wallet_ledger" DROP CONSTRAINT "wallet_ledger_reason_sign";
ALTER TABLE "wallet_ledger" ADD CONSTRAINT "wallet_ledger_reason_sign" CHECK (
  (reason IN ('ADMIN_GRANT', 'CP_REFUND', 'LUCKY_GIFT_WIN', 'LIVE_BOOST_REFUND') AND delta > 0)
  OR (reason IN ('ADMIN_REVOKE', 'BULLET_MESSAGE', 'FAMILY_CREATE', 'CP_REQUEST', 'CP_GIFT', 'LIVE_GIFT', 'LUCKY_GIFT',
                 'PREMIUM_USERNAME_RENT', 'PREMIUM_USERNAME_RENEW', 'LIVE_BOOST', 'DM_GIFT') AND delta < 0));
