-- v1.48-social (D171, owner 2026-10-29): the bag v2 (CONVENTIONS §10.45). Owned by the `bag` module.
-- The runtime role gets DML through the default privileges
-- (20261016130000_per_database_runtime_group), so this migration contains no GRANT.
--
-- * `user_bag_items.expires_at`: when the item leaves the bag (NULL = permanent; every item given
--   before this migration stays permanent). Reads never return a past one; the bag sweeper deletes
--   them (`user_bag_items_expires_idx`).
-- * `user_bag_items.gifted_by_user_id`: who sent it (source GIFT only; SET NULL when the account
--   row goes).
-- * `notifications.bag_item_code`: the item of a BAG_ITEM_RECEIVED notification.
-- * `bag_transfers`: the ledger of items sent between users (kept when an account goes).

-- AlterTable
ALTER TABLE "notifications" ADD COLUMN     "bag_item_code" VARCHAR(40);

-- AlterTable
ALTER TABLE "user_bag_items" ADD COLUMN     "expires_at" TIMESTAMPTZ(3),
ADD COLUMN     "gifted_by_user_id" UUID;

-- A giver only on a gift.
ALTER TABLE "user_bag_items" ADD CONSTRAINT "user_bag_items_gifted_by_source_check"
    CHECK ("gifted_by_user_id" IS NULL OR "source" = 'GIFT');

-- CreateTable
CREATE TABLE "bag_transfers" (
    "id" UUID NOT NULL,
    "sender_id" UUID,
    "recipient_id" UUID,
    "item_code" VARCHAR(40) NOT NULL,
    "category" "bag_category" NOT NULL,
    "whole" BOOLEAN NOT NULL,
    "duration_ms" BIGINT,
    "sender_expires_at" TIMESTAMPTZ(3),
    "recipient_expires_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "bag_transfers_pkey" PRIMARY KEY ("id"),
    -- Some time is sent; NULL only for a permanent item, which is sent whole.
    CONSTRAINT "bag_transfers_duration_check" CHECK (("duration_ms" IS NULL AND "whole") OR "duration_ms" > 0),
    -- A partial send leaves the sender an expiry; a whole send leaves nothing.
    CONSTRAINT "bag_transfers_sender_expiry_check" CHECK ("whole" = ("sender_expires_at" IS NULL))
);

-- CreateIndex
CREATE INDEX "bag_transfers_sender_idx" ON "bag_transfers"("sender_id", "created_at");

-- CreateIndex
CREATE INDEX "bag_transfers_recipient_idx" ON "bag_transfers"("recipient_id", "created_at");

-- CreateIndex
CREATE INDEX "user_bag_items_expires_idx" ON "user_bag_items"("expires_at") WHERE (expires_at IS NOT NULL);

-- CreateIndex
CREATE INDEX "user_bag_items_gifted_by_idx" ON "user_bag_items"("gifted_by_user_id");

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_bag_item_code_fkey" FOREIGN KEY ("bag_item_code") REFERENCES "bag_items"("code") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_bag_items" ADD CONSTRAINT "user_bag_items_gifted_by_user_id_fkey" FOREIGN KEY ("gifted_by_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bag_transfers" ADD CONSTRAINT "bag_transfers_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bag_transfers" ADD CONSTRAINT "bag_transfers_recipient_id_fkey" FOREIGN KEY ("recipient_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
