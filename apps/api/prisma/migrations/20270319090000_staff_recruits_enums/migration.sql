-- v1.75-live (D285, owner, CONVENTIONS §10.96.13): recruitment by staff «الاستقطاب». The new enum values go in a
-- migration of their own (a value added by ALTER TYPE … ADD VALUE cannot be used in the same transaction):
--  - `BD` «تطوير الأعمال»: a new panel role for recruitment only (a limited staff account like D283, no moderation);
--  - `STAFF_RECRUIT_COMMISSION`: the recruiter's daily share of the platform profit of each recruit (withdrawable
--    cherries; reference `SR:<recruitment>@<day>`).
ALTER TYPE "admin_permission" ADD VALUE 'BD';
ALTER TYPE "cherry_ledger_reason" ADD VALUE 'STAFF_RECRUIT_COMMISSION';
