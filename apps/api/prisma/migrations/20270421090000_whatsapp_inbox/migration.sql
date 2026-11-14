-- v1.116-social (D355, CONVENTIONS §10.151): «واتساب» — the official Kabso WhatsApp number answered by the staff (WhatsApp
-- Business Platform, Cloud API). Conversations (one per customer phone, E.164), messages (Meta's `wamid` unique: a
-- webhook delivered twice stores one row), internal notes, the assignment history, quick replies and each staff member's
-- push mute. The staff columns carry no foreign key (accounts are tombstoned, never deleted; the history keeps who
-- acted). No GRANT: the runtime role gets DML through the default privileges (20261016120000_runtime_role_grants).

CREATE TYPE "wa_conversation_status" AS ENUM ('OPEN', 'CLOSED');
CREATE TYPE "wa_direction" AS ENUM ('INBOUND', 'OUTBOUND');
CREATE TYPE "wa_message_type" AS ENUM ('TEXT', 'IMAGE', 'AUDIO', 'VIDEO', 'DOCUMENT', 'STICKER', 'LOCATION', 'REACTION', 'CONTACTS', 'INTERACTIVE', 'TEMPLATE', 'UNSUPPORTED');
CREATE TYPE "wa_message_status" AS ENUM ('RECEIVED', 'SENT', 'DELIVERED', 'READ', 'FAILED');
CREATE TYPE "wa_media_state" AS ENUM ('NONE', 'STORED', 'TOO_LARGE', 'TYPE_REFUSED', 'FAILED');
CREATE TYPE "wa_assignment_action" AS ENUM ('CLAIM', 'RELEASE', 'TRANSFER', 'CLOSE', 'REOPEN');

CREATE TABLE "wa_conversations" (
    "id" UUID NOT NULL,
    "phone_e164" VARCHAR(16) NOT NULL,
    "wa_id" VARCHAR(32) NOT NULL,
    "profile_name" VARCHAR(200),
    "status" "wa_conversation_status" NOT NULL DEFAULT 'OPEN',
    "assigned_to_id" UUID,
    "assigned_at" TIMESTAMPTZ(3),
    "unread_count" INTEGER NOT NULL DEFAULT 0,
    "last_inbound_at" TIMESTAMPTZ(3),
    "last_message_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_preview" VARCHAR(120),
    "last_direction" "wa_direction",
    "linked_user_id" UUID,
    "linked_by_id" UUID,
    "linked_at" TIMESTAMPTZ(3),
    "closed_at" TIMESTAMPTZ(3),
    "closed_by_id" UUID,
    "purge_after" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wa_conversations_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "wa_conversations_shape" CHECK (
        "phone_e164" ~ '^\+[1-9][0-9]{6,14}$'
        AND "unread_count" >= 0
        AND (("assigned_to_id" IS NULL) = ("assigned_at" IS NULL)))
);
CREATE UNIQUE INDEX "wa_conversations_phone_key" ON "wa_conversations" ("phone_e164");
CREATE INDEX "wa_conversations_status_last_idx" ON "wa_conversations" ("status", "last_message_at" DESC, "id" DESC);
CREATE INDEX "wa_conversations_assigned_idx" ON "wa_conversations" ("assigned_to_id", "last_message_at" DESC);
CREATE INDEX "wa_conversations_linked_idx" ON "wa_conversations" ("linked_user_id") WHERE linked_user_id IS NOT NULL;

CREATE TABLE "wa_messages" (
    "id" UUID NOT NULL,
    "conversation_id" UUID NOT NULL,
    "wa_message_id" VARCHAR(160),
    "direction" "wa_direction" NOT NULL,
    "type" "wa_message_type" NOT NULL,
    "body" TEXT,
    "media_key" VARCHAR(256),
    "media_state" "wa_media_state" NOT NULL DEFAULT 'NONE',
    "media_mime" VARCHAR(100),
    "media_size" INTEGER,
    "media_filename" VARCHAR(240),
    "media_voice" BOOLEAN NOT NULL DEFAULT false,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "location_name" VARCHAR(240),
    "reaction_emoji" VARCHAR(16),
    "reaction_to_wa_id" VARCHAR(160),
    "template_name" VARCHAR(512),
    "template_lang" VARCHAR(16),
    "status" "wa_message_status" NOT NULL,
    "error_code" INTEGER,
    "error_title" VARCHAR(300),
    "sent_by_id" UUID,
    "wa_timestamp" TIMESTAMPTZ(3),
    "status_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wa_messages_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "wa_messages_shape" CHECK (
        ("body" IS NULL OR length("body") <= 4096)
        AND ("media_size" IS NULL OR "media_size" >= 0)
        AND ("media_key" IS NULL OR "media_key" LIKE 'private/whatsapp/%')
        AND (("direction" = 'INBOUND') = ("status" = 'RECEIVED')))
);
CREATE UNIQUE INDEX "wa_messages_wamid_key" ON "wa_messages" ("wa_message_id");
CREATE INDEX "wa_messages_conversation_idx" ON "wa_messages" ("conversation_id", "created_at" DESC, "id" DESC);
ALTER TABLE "wa_messages" ADD CONSTRAINT "wa_messages_conversation_id_fkey"
    FOREIGN KEY ("conversation_id") REFERENCES "wa_conversations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "wa_notes" (
    "id" UUID NOT NULL,
    "conversation_id" UUID NOT NULL,
    "author_id" UUID NOT NULL,
    "body" VARCHAR(2000) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wa_notes_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "wa_notes_conversation_idx" ON "wa_notes" ("conversation_id", "created_at");
ALTER TABLE "wa_notes" ADD CONSTRAINT "wa_notes_conversation_id_fkey"
    FOREIGN KEY ("conversation_id") REFERENCES "wa_conversations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "wa_assignments" (
    "id" UUID NOT NULL,
    "conversation_id" UUID NOT NULL,
    "action" "wa_assignment_action" NOT NULL,
    "from_user_id" UUID,
    "to_user_id" UUID,
    "actor_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wa_assignments_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "wa_assignments_conversation_idx" ON "wa_assignments" ("conversation_id", "created_at");
ALTER TABLE "wa_assignments" ADD CONSTRAINT "wa_assignments_conversation_id_fkey"
    FOREIGN KEY ("conversation_id") REFERENCES "wa_conversations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "wa_quick_replies" (
    "id" UUID NOT NULL,
    "title" VARCHAR(60) NOT NULL,
    "body" VARCHAR(1024) NOT NULL,
    "created_by_id" UUID,
    "updated_by_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wa_quick_replies_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "wa_quick_replies_title_key" ON "wa_quick_replies" ("title");

CREATE TABLE "wa_agent_settings" (
    "user_id" UUID NOT NULL,
    "push_muted" BOOLEAN NOT NULL DEFAULT false,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wa_agent_settings_pkey" PRIMARY KEY ("user_id")
);
