-- v1.78-live (D288, CONVENTIONS §10.101; owner: «ان البلاغ يصل كل المشرفين والدعم والذي يقوم بحله يضغط تم حله»): the
-- shared report queue. Every new report notifies the moderators and the support (STAFF_REPORT_NEW, one unread row per
-- staff member that moves to the newest report). «تم حله» reuses the existing `reports.resolved_at`,
-- `resolved_by_id` and `resolution_note` (no new report column).
-- The runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group): no GRANT here.
-- The new enum value is not used in this migration.

ALTER TYPE "notification_type" ADD VALUE IF NOT EXISTS 'STAFF_REPORT_NEW';

ALTER TABLE "notifications" ADD COLUMN "report_id" UUID;
CREATE INDEX "notifications_report_idx" ON "notifications"("report_id") WHERE report_id IS NOT NULL;
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_report_id_fkey"
  FOREIGN KEY ("report_id") REFERENCES "reports"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- The resolved tab lists the closed reports, newest resolution first.
CREATE INDEX "reports_resolved_idx" ON "reports"("resolved_at" DESC, "id" DESC) WHERE status <> 'OPEN'::report_status;
