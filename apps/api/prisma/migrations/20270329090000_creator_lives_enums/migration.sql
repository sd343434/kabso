-- v1.82-live (D295, owner, CONVENTIONS §10.108): content creators go live «صانع محتوى». The new enum values go in a
-- migration of their own (a value added by ALTER TYPE … ADD VALUE cannot be used in the same transaction):
--  - `live_host_source` CREATOR: the hosting permission a creator-programme membership gives (granted with the
--    membership, removed when it ends);
--  - `creator_application_status` REVOKED: the team ended a membership (the application that made it is kept);
--  - `agency_close_reason` BANNED: «حظر الوكالة — تفعيل صانع محتوى وهمي» (OWNER only; the agency cannot be reopened);
--  - `cherry_ledger_reason` AGENCY_FORFEIT: the ban's forfeit of the owner's unwithdrawn agency commission (a debit,
--    reference: the agency).
ALTER TYPE "live_host_source" ADD VALUE 'CREATOR';
ALTER TYPE "creator_application_status" ADD VALUE 'REVOKED';
ALTER TYPE "agency_close_reason" ADD VALUE 'BANNED';
ALTER TYPE "cherry_ledger_reason" ADD VALUE 'AGENCY_FORFEIT';
