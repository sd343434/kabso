-- v1.137-social (D385, owner 2026-11-12: «دعم كابسو» in «الرسائل» and the pinned chats), CONVENTIONS §10.174.
--
-- 1. `wa_channel` and `wa_conversations.channel`: a support conversation is on WhatsApp or in the app «دعم كابسو»
--    (one IN_APP thread per account, `linked_user_id` its owner; no phone, no WhatsApp id — CHECK
--    `wa_conversations_channel_shape`). `user_read_at` / `staff_read_at`: who read the thread up to when.
-- 2. `wa_messages.media_asset_id` (an IN_APP picture or voice clip, the person's DM_IMAGE / DM_VOICE upload) and
--    `client_id` (the person's idempotency key, one per thread).
-- 3. `dm_pins`: the chats pinned at the top of «الرسائل» (a direct conversation or a group, CHECK `dm_pins_target`);
--    at most 5 per person, checked by the API under a per-person lock.
--
-- New tables get their runtime grants from the default privileges (KL-013, migration 20261016130000).
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

-- 1. The channel.
CREATE TYPE "wa_channel" AS ENUM ('WHATSAPP', 'IN_APP');

ALTER TABLE "wa_conversations" ADD COLUMN "channel" "wa_channel" NOT NULL DEFAULT 'WHATSAPP',
ADD COLUMN "user_read_at" TIMESTAMPTZ(3),
ADD COLUMN "staff_read_at" TIMESTAMPTZ(3),
ALTER COLUMN "phone_e164" DROP NOT NULL,
ALTER COLUMN "wa_id" DROP NOT NULL;

ALTER TABLE "wa_conversations" ADD CONSTRAINT "wa_conversations_channel_shape" CHECK (
  (channel = 'WHATSAPP' AND phone_e164 IS NOT NULL AND wa_id IS NOT NULL)
  OR (channel = 'IN_APP' AND phone_e164 IS NULL AND wa_id IS NULL AND linked_user_id IS NOT NULL));

CREATE UNIQUE INDEX "wa_conversations_in_app_user_key" ON "wa_conversations"("linked_user_id") WHERE (channel = 'IN_APP'::wa_channel);
CREATE INDEX "wa_conversations_channel_idx" ON "wa_conversations"("channel", "status", "last_message_at" DESC, "id" DESC);

-- 2. The in-app messages' media and idempotency key.
ALTER TABLE "wa_messages" ADD COLUMN "media_asset_id" UUID,
ADD COLUMN "client_id" UUID;

CREATE UNIQUE INDEX "wa_messages_media_asset_key" ON "wa_messages"("media_asset_id");
CREATE UNIQUE INDEX "wa_messages_client_once" ON "wa_messages"("conversation_id", "client_id");

ALTER TABLE "wa_messages" ADD CONSTRAINT "wa_messages_media_asset_id_fkey" FOREIGN KEY ("media_asset_id") REFERENCES "media_assets"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- 3. The pins.
CREATE TABLE "dm_pins" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "conversation_id" UUID,
    "group_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "dm_pins_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "dm_pins_target" CHECK (num_nonnulls("conversation_id", "group_id") = 1)
);

CREATE INDEX "dm_pins_user_idx" ON "dm_pins"("user_id", "created_at", "id");
CREATE INDEX "dm_pins_conversation_idx" ON "dm_pins"("conversation_id");
CREATE INDEX "dm_pins_group_idx" ON "dm_pins"("group_id");
CREATE UNIQUE INDEX "dm_pins_user_conversation_key" ON "dm_pins"("user_id", "conversation_id");
CREATE UNIQUE INDEX "dm_pins_user_group_key" ON "dm_pins"("user_id", "group_id");

ALTER TABLE "dm_pins" ADD CONSTRAINT "dm_pins_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "dm_pins" ADD CONSTRAINT "dm_pins_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "dm_conversations"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "dm_pins" ADD CONSTRAINT "dm_pins_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "dm_groups"("id") ON DELETE CASCADE ON UPDATE CASCADE;
