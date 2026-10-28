-- v1.30-live (D152): push notifications on Android (Firebase Cloud Messaging), CONVENTIONS §11.12.
-- `device_tokens`: one token per session (deleted with it); `notifications.pushed_at`: the push
-- outbox (NULL or older than updated_at = waiting); `notification_settings.messages`: family chat
-- pushes. No GRANT (default privileges, 20261016130000_per_database_runtime_group).

-- CreateEnum
CREATE TYPE "push_platform" AS ENUM ('ANDROID', 'IOS');

-- CreateTable
CREATE TABLE "device_tokens" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "session_id" UUID NOT NULL,
    "token" VARCHAR(1024) NOT NULL,
    "platform" "push_platform" NOT NULL,
    "app_version" VARCHAR(32) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_seen_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "device_tokens_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "device_tokens_token_format" CHECK ("token" ~ '^[A-Za-z0-9_:.-]+$' AND char_length("token") <= 1024),
    CONSTRAINT "device_tokens_app_version_format" CHECK ("app_version" ~ '^[0-9A-Za-z.+_-]+$' AND char_length("app_version") <= 32)
);

-- AlterTable
ALTER TABLE "notifications" ADD COLUMN "pushed_at" TIMESTAMPTZ(3);
-- Everything that exists before this migration counts as handled: nothing old is ever pushed.
UPDATE "notifications" SET "pushed_at" = "updated_at";

ALTER TABLE "notification_settings" ADD COLUMN "messages" BOOLEAN NOT NULL DEFAULT true;

-- CreateIndex
CREATE UNIQUE INDEX "device_tokens_token_key" ON "device_tokens"("token");
CREATE UNIQUE INDEX "device_tokens_session_id_key" ON "device_tokens"("session_id");
CREATE INDEX "device_tokens_user_id_idx" ON "device_tokens"("user_id");
CREATE INDEX "device_tokens_last_seen_at_idx" ON "device_tokens"("last_seen_at");
CREATE INDEX "notifications_push_pending_idx" ON "notifications"("updated_at") WHERE (pushed_at IS NULL OR pushed_at < updated_at);

-- AddForeignKey
ALTER TABLE "device_tokens" ADD CONSTRAINT "device_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "device_tokens" ADD CONSTRAINT "device_tokens_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
