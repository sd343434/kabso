-- v1.93-social (D296, CONVENTIONS §10.109; owner: a report opens its content for the staff, with actions, and an action
-- resolves the report automatically): which action resolved a report. NULL for a manual «تم حله» (D288) and while the
-- report is OPEN; cleared again by a reopen.
-- The runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group): no GRANT here.

ALTER TABLE "reports" ADD COLUMN "resolution_action" VARCHAR(20);
ALTER TABLE "reports" ADD CONSTRAINT "reports_resolution_action_check" CHECK (
  resolution_action IS NULL
  OR (status <> 'OPEN'::report_status
      AND resolution_action IN ('WARN', 'RESTRICT', 'SUSPEND', 'BAN', 'REMOVE_CONTENT', 'DELETE_CONTENT',
                            'DELETE_ACCOUNT', 'DISMISS'))
);
