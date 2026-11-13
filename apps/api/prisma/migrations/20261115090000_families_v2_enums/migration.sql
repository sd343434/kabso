-- v1.25-live (CP-022, D116, 2026-10-26): families v2. The new report target goes first, in a
-- migration of its own (PostgreSQL does not allow a value added by ALTER TYPE … ADD VALUE to be used
-- in the same transaction; the same split as 20261113090000_cp_space_enums).

-- Reports (CONVENTIONS §11.7, §10.25): a message in a family's chat.
ALTER TYPE "report_target_type" ADD VALUE 'FAMILY_CHAT_MESSAGE';
