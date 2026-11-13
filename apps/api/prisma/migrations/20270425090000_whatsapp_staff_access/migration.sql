-- v1.120-social (D360, CONVENTIONS §10.155): a WhatsApp level per staff member «مستوى واتساب لكل موظف».
--
-- Owner: each staff member gets NONE / VIEW / REPLY / MANAGE instead of the D355 role rule. NO ROW = the default of the
-- person's roles, which is exactly D355 (OWNER and MODERATION → MANAGE, SUPPORT → REPLY, everyone else → NONE), so
-- nothing changes on deploy: the table starts empty and no existing row is touched. Written only by the panel's
-- `team.manage` route (audited `admin.team.whatsapp`). It cannot make anyone staff (a level applies only while the
-- person holds a panel role, checked on every request) and an OWNER is always MANAGE, so — unlike `admin_permissions`
-- — it needs no SECURITY DEFINER function. A new table: the schema's default privileges give the runtime role access.

CREATE TYPE "wa_access_level" AS ENUM ('NONE', 'VIEW', 'REPLY', 'MANAGE');

CREATE TABLE "wa_staff_access" (
    "user_id" UUID NOT NULL,
    "level" "wa_access_level" NOT NULL,
    "set_by_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wa_staff_access_pkey" PRIMARY KEY ("user_id")
);
