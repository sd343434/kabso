-- CP-017 (D104, owner 2026-10-26): voice clips and images in the live chat (CONVENTIONS §10.11,
-- §10.19). A chat message has a kind: TEXT (as before), VOICE (an audio clip of at most 30 s) or
-- IMAGE. A VOICE or IMAGE message has no text, holds its `LIVE_CHAT_VOICE` / `LIVE_CHAT_IMAGE`
-- asset in `media_id` and vanishes 60 s after sending (`expires_at`): reads stop returning it and
-- the live chat sweeper deletes the asset and its objects (the FK then sets `media_id` to NULL).
-- Existing messages become TEXT. The runtime role gets DML through the default privileges, so
-- this migration contains no GRANT.

-- CreateEnum
CREATE TYPE "live_chat_message_kind" AS ENUM ('TEXT', 'VOICE', 'IMAGE');

-- AlterTable
ALTER TABLE "live_chat_messages" ADD COLUMN     "expires_at" TIMESTAMPTZ(3),
ADD COLUMN     "kind" "live_chat_message_kind" NOT NULL DEFAULT 'TEXT',
ADD COLUMN     "media_id" UUID,
ALTER COLUMN "text" SET DEFAULT '';

-- AlterTable
ALTER TABLE "media_assets" ADD COLUMN     "duration_ms" INTEGER;

-- CreateIndex (one message per asset)
CREATE UNIQUE INDEX "live_chat_messages_media_once" ON "live_chat_messages"("media_id");

-- CreateIndex (the expired-media sweep)
CREATE INDEX "live_chat_messages_media_expiry_idx" ON "live_chat_messages"("expires_at") WHERE (media_id IS NOT NULL);

-- AddForeignKey
ALTER TABLE "live_chat_messages" ADD CONSTRAINT "live_chat_messages_media_id_fkey" FOREIGN KEY ("media_id") REFERENCES "media_assets"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- TEXT: 1–200 code points; VOICE and IMAGE: no text. Only VOICE and IMAGE expire and hold an
-- asset (until the sweeper deleted it).
ALTER TABLE "live_chat_messages" DROP CONSTRAINT "live_chat_messages_text_length";
ALTER TABLE "live_chat_messages" ADD CONSTRAINT "live_chat_messages_text_length" CHECK (
  (kind = 'TEXT' AND char_length(text) BETWEEN 1 AND 200) OR (kind <> 'TEXT' AND text = ''));
ALTER TABLE "live_chat_messages" ADD CONSTRAINT "live_chat_messages_kind_shape" CHECK (
  (kind = 'TEXT' AND media_id IS NULL AND expires_at IS NULL) OR (kind <> 'TEXT' AND expires_at IS NOT NULL));

-- The new asset kinds (§11.1); only a voice clip has a duration, at most 30 s.
ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_kind_known";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_kind_known" CHECK (kind IN ('POST_IMAGE', 'STORY_IMAGE', 'LIVE_COVER', 'LIVE_CHAT_IMAGE', 'LIVE_CHAT_VOICE'));
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_duration_shape" CHECK (
  (kind = 'LIVE_CHAT_VOICE' AND duration_ms BETWEEN 1 AND 30000) OR (kind <> 'LIVE_CHAT_VOICE' AND duration_ms IS NULL));
