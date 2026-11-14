-- v1.89-social (D290, owner, CONVENTIONS §10.103): level-raise requests «طلب رفع ليفيل». The new enum values go in a
-- migration of their own (a value added by ALTER TYPE … ADD VALUE cannot be used in the same transaction):
--  - `LEVEL_RAISE_APPROVED` / `LEVEL_RAISE_REJECTED`: the OWNER's decision, to the staff member who made the request;
--  - `LEVEL_RAISED`: to the supporter, on approval only (owner default; no notification on a rejection).
ALTER TYPE "notification_type" ADD VALUE 'LEVEL_RAISE_APPROVED';
ALTER TYPE "notification_type" ADD VALUE 'LEVEL_RAISE_REJECTED';
ALTER TYPE "notification_type" ADD VALUE 'LEVEL_RAISED';
