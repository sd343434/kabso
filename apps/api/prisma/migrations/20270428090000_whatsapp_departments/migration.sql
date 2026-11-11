-- v1.123-social (D366, CONVENTIONS §10.159): WhatsApp departments and the transfer with a department «الأقسام والتحويل».
--
-- Owner (approved «نعم موافق»): five fixed departments. A staff member at REPLY or above belongs to one or more of them
-- (`wa_staff_departments`, one row per membership; NO ROW = GENERAL «عام», so nothing changes on deploy: the table starts
-- empty). Written only by the panel's `team.manage` route (audited `admin.team.whatsapp_departments`). A separate table,
-- not a column of `wa_staff_access`, because a row there means «a level is SET» (no row = the roles' default) — a
-- membership must not create a level. No foreign key, like every staff id of the module (accounts are tombstoned).
--
-- Every conversation carries its department (default GENERAL: every existing conversation is «عام»; a constant default
-- is metadata-only on PostgreSQL 11+, no table rewrite) and changes it only through a transfer. Each history row of a
-- transfer keeps the department it went to, the one it came from and the internal note written with it (a `wa_notes`
-- row, never sent to the customer). New table: the schema's default privileges give the runtime role access.

CREATE TYPE "wa_department" AS ENUM ('PAYMENTS', 'AGENCIES', 'TECHNICAL', 'REPORTS', 'GENERAL');

CREATE TABLE "wa_staff_departments" (
    "user_id" UUID NOT NULL,
    "department" "wa_department" NOT NULL,
    "set_by_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wa_staff_departments_pkey" PRIMARY KEY ("user_id", "department")
);

ALTER TABLE "wa_conversations" ADD COLUMN "department" "wa_department" NOT NULL DEFAULT 'GENERAL';

CREATE INDEX "wa_conversations_department_idx" ON "wa_conversations"("department", "status", "last_message_at" DESC, "id" DESC);

ALTER TABLE "wa_assignments"
    ADD COLUMN "department" "wa_department",
    ADD COLUMN "from_department" "wa_department",
    ADD COLUMN "note_id" UUID;
