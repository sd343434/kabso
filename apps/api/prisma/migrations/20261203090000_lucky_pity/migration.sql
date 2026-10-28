-- v1.30-live (D148, owner 2026-10-28): the lucky-gift guarantee ("pity", option B), CONVENTIONS
-- §10.27. Additive: one new table and three nullable audit columns; no existing row changes. The
-- runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group):
-- no GRANT here.

-- CreateTable: one row per sender who ever made a lucky draw — their losing draws in a row (any
-- room, any session). Read and written only inside a lucky send's transaction, under the sender's
-- advisory lock (`live-gift:<userId>`), so concurrent sends of one sender never lose an update.
-- Reset to 0 by any paid draw (the guarantee's own included).
CREATE TABLE "lucky_gift_pity" (
    "user_id" UUID NOT NULL,
    "losses" INTEGER NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "lucky_gift_pity_pkey" PRIMARY KEY ("user_id")
);

-- AddForeignKey
ALTER TABLE "lucky_gift_pity" ADD CONSTRAINT "lucky_gift_pity_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "lucky_gift_pity" ADD CONSTRAINT "lucky_gift_pity_losses" CHECK (losses >= 0);

-- AlterTable: the audit row of a lucky send also keeps the sender's streak before and after it and
-- how many of its draws the guarantee paid (null on rows written before D148).
ALTER TABLE "lucky_gift_draws" ADD COLUMN "losses_before" INTEGER,
ADD COLUMN "losses_after" INTEGER,
ADD COLUMN "guaranteed" INTEGER;

ALTER TABLE "lucky_gift_draws" ADD CONSTRAINT "lucky_gift_draws_pity" CHECK (
    (losses_before IS NULL OR losses_before >= 0) AND (losses_after IS NULL OR losses_after >= 0)
    AND (guaranteed IS NULL OR (guaranteed >= 0 AND guaranteed <= draws)));
