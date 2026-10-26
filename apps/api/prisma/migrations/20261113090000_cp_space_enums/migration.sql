-- v1.24-live (CP-021, D112, 2026-10-26): the CP space. The new report target goes first, in a
-- migration of its own (PostgreSQL does not allow a value added by ALTER TYPE … ADD VALUE to be used
-- in the same transaction; the same split as 20261110090000_families_cp_medals_enums).

-- Reports (CONVENTIONS §11.7, §10.24): a confession on a CP couple's page.
ALTER TYPE "report_target_type" ADD VALUE 'CP_CONFESSION';
