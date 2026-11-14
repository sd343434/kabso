-- v1.95-social (D301 follow-up, owner: «اعلان التي يقوم المؤسس نشرها … ويصل اشعار لكل المستخدمين لها حتى المشرفين»,
-- CONVENTIONS §10.112.7): the notification of the app owner's official announcement. Its own migration: a new enum value
-- cannot be used in the transaction that adds it (20270402090300 indexes on it).
ALTER TYPE "notification_type" ADD VALUE IF NOT EXISTS 'OWNER_ANNOUNCEMENT';
