-- v1.103-social (D338, CONVENTIONS §10.131). Owner: «أريد زر لإزالتهم وليس فقط إيقافهم» — «حذف» of a gift in the panel
-- (and `gift-admin delete`). A gift nothing ever used is deleted for real (no column needed); one that was used — sent,
-- held in a bag, in an event, a PK boost, a wish list, a task, a prize — is archived instead: `archived_at` set and
-- `enabled` false, so it leaves the catalogue, the bag's send choices, the panel's normal list and the pickers, while
-- history (sends, ledgers, bags, events, draws) keeps pointing at the row. «استعادة» clears it.
-- The runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group): no GRANT here.
ALTER TABLE "gifts" ADD COLUMN "archived_at" TIMESTAMPTZ(3);
ALTER TABLE "gifts"
  ADD CONSTRAINT "gifts_archived_off" CHECK ("archived_at" IS NULL OR NOT "enabled");
