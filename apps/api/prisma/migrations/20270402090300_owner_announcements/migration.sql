-- v1.95-social (D301 follow-up, owner 2026-11-07: «اعلان التي يقوم المؤسس نشرها تكون دائماً في اول منشور ويتم نشرها
-- بلغتين … ويصل اشعار لكل المستخدمين لها حتى المشرفين»; CONVENTIONS §10.112.7).
--
-- 1. Bilingual: `posts.text_en` — the English caption of an official announcement (`text` holds the Arabic one).
-- 2. The posts feed's first item is the latest official announcement: `posts_official_latest_idx`.
-- 3. The notification to every ACTIVE account, staff too, once per announcement: written after the request by a batched,
--    resumable fan-out (`owner_announcement_fanouts`, a cursor over `users.id`), idempotent thanks to the partial unique
--    index `notifications_owner_announcement_once`; the existing push outbox sends each row in the recipient's language.
-- Runtime grants come from the default privileges (20261016120000_runtime_role_grants).

ALTER TABLE "posts" ADD COLUMN "text_en" VARCHAR(2200);
CREATE INDEX "posts_official_latest_idx" ON "posts"("official_at" DESC) WHERE (official_at IS NOT NULL);

CREATE UNIQUE INDEX "notifications_owner_announcement_once" ON "notifications"("recipient_id", "post_id") WHERE (type = 'OWNER_ANNOUNCEMENT'::notification_type);

CREATE TABLE "owner_announcement_fanouts" (
    "post_id" UUID NOT NULL,
    "cursor_user_id" UUID,
    "recipients" INTEGER NOT NULL DEFAULT 0,
    "started_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "done_at" TIMESTAMPTZ(3),

    CONSTRAINT "owner_announcement_fanouts_pkey" PRIMARY KEY ("post_id"),
    CONSTRAINT "owner_announcement_fanouts_recipients" CHECK (recipients >= 0)
);
CREATE INDEX "owner_announcement_fanouts_pending_idx" ON "owner_announcement_fanouts"("started_at") WHERE (done_at IS NULL);
ALTER TABLE "owner_announcement_fanouts" ADD CONSTRAINT "owner_announcement_fanouts_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;
