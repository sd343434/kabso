-- v1.140-social (D388, CONVENTIONS §10.177): «سؤال اللغة» — the WhatsApp language question and language routing.
--
-- Owner (2026-11-13: «اريد عندما يرسل الشخص يقوم تلقائي بسؤاله عن لغة التي يتحدثها عربي او انجليزي»; first time only,
-- a confirmation in the chosen language, the language shown to the staff, the conversation routed to staff who speak
-- it). Each conversation carries the customer's language (NULL until they choose; every existing conversation starts
-- NULL and is asked once, on its next message) and when the question was sent (NULL: never asked; set once, so the
-- customer is asked only the first time). A staff member at REPLY or above may be marked with the languages they
-- speak (`wa_staff_languages`, one row per language; NO ROW = both, so nothing changes on deploy: the table starts
-- empty). Written only by the panel's `team.manage` route (audited `admin.team.whatsapp_languages`). No foreign key,
-- like every staff id of the module (accounts are tombstoned). Constant-free nullable columns: metadata-only, no table
-- rewrite. New table: the schema's default privileges give the runtime role access.

CREATE TYPE "wa_language" AS ENUM ('AR', 'EN');

ALTER TABLE "wa_conversations"
    ADD COLUMN "language" "wa_language",
    ADD COLUMN "language_asked_at" TIMESTAMPTZ(3);

CREATE TABLE "wa_staff_languages" (
    "user_id" UUID NOT NULL,
    "language" "wa_language" NOT NULL,
    "set_by_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wa_staff_languages_pkey" PRIMARY KEY ("user_id", "language")
);
