-- v1.68-live (D273, CONVENTIONS §10.96.6; owner 2026-11-04): «فريق كابسو» from the app — the staff tools' step-up grant
-- (the panel authenticator code, bound to one app session), a warning on a live (WARN), the staff alert of a report on a
-- live (LIVE_STAFF_REPORT, one unread row per live and staff member) and the live a USER report was made in (its
-- context). The runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group): no
-- GRANT here. The new enum values are not used in this migration.

ALTER TYPE "live_moderation_kind" ADD VALUE IF NOT EXISTS 'WARN';
ALTER TYPE "notification_type" ADD VALUE IF NOT EXISTS 'LIVE_STAFF_REPORT';

CREATE TABLE "admin_app_grants" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "session_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "revoked_at" TIMESTAMPTZ(3),
    "revoked_reason" VARCHAR(16),
    "ip" VARCHAR(64),

    CONSTRAINT "admin_app_grants_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "admin_app_grants_expiry" CHECK (expires_at > created_at),
    CONSTRAINT "admin_app_grants_revoked_reason" CHECK (
      (revoked_at IS NULL AND revoked_reason IS NULL)
      OR (revoked_at IS NOT NULL
          AND revoked_reason IN ('ENDED', 'ROLE_REVOKED', 'LOCKED', 'TOTP_RESET', 'REPLACED')))
);
CREATE INDEX "admin_app_grants_session_idx" ON "admin_app_grants"("session_id") WHERE revoked_at IS NULL;
CREATE INDEX "admin_app_grants_user_idx" ON "admin_app_grants"("user_id");
ALTER TABLE "admin_app_grants" ADD CONSTRAINT "admin_app_grants_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "admin_app_grants" ADD CONSTRAINT "admin_app_grants_session_id_fkey"
  FOREIGN KEY ("session_id") REFERENCES "sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "notifications" ADD COLUMN "live_room_id" UUID;
CREATE INDEX "notifications_live_room_idx" ON "notifications"("live_room_id") WHERE live_room_id IS NOT NULL;
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_live_room_id_fkey"
  FOREIGN KEY ("live_room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "reports" ADD COLUMN "context_live_room_id" UUID;
CREATE INDEX "reports_context_live_room_idx" ON "reports"("context_live_room_id") WHERE context_live_room_id IS NOT NULL;
ALTER TABLE "reports" ADD CONSTRAINT "reports_context_live_room_id_fkey"
  FOREIGN KEY ("context_live_room_id") REFERENCES "live_rooms"("id") ON DELETE SET NULL ON UPDATE CASCADE;
-- Only a USER report has a context live.
ALTER TABLE "reports" ADD CONSTRAINT "reports_context_live_room_user_only"
  CHECK (context_live_room_id IS NULL OR target_type = 'USER'::report_target_type);
