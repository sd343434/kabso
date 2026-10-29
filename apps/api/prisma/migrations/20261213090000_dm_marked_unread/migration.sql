-- v1.43-social (D165, owner: «الوكيل الثاني يعمل على زر الرسائل»): a user can mark a conversation
-- unread for themself (CONVENTIONS §11.13). Additive: one column with a default (existing rows false);
-- no index (read with the participant row), no GRANT (the runtime role already has the table).
ALTER TABLE "dm_participants" ADD COLUMN "marked_unread" BOOLEAN NOT NULL DEFAULT false;
