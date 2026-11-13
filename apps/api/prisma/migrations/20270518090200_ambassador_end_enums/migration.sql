-- v1.140-social (D390 follow-up, owner «نعم»: «إنهاء العضوية»), CONVENTIONS §10.179.11. The enum values in a migration of
-- their own (an added value cannot be used in the transaction that adds it):
--  - `ambassador_status` ENDED: the OWNER ended the membership (kept for the history; re-appointed by the OWNER only);
--  - `notification_type` AMBASSADOR_MEMBERSHIP_ENDED: the person is told (no target; the reason stays in the panel).
ALTER TYPE "ambassador_status" ADD VALUE 'ENDED';
ALTER TYPE "notification_type" ADD VALUE 'AMBASSADOR_MEMBERSHIP_ENDED';
