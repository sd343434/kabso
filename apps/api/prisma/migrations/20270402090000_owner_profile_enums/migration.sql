-- v1.95-social (D301, owner: «صفحة صاحب البرنامج», CONVENTIONS §10.112.5): the notification of a new item in the app
-- owner's inbox «صندوق المؤسس». Its own migration: a new enum value cannot be used in the transaction that adds it.
ALTER TYPE "notification_type" ADD VALUE IF NOT EXISTS 'OWNER_FEEDBACK_NEW';
