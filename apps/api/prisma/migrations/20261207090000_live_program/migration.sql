-- v1.36-live (D154e, owner 2026-10-28): a live's program «قائمة البرامج», CONVENTIONS §10.37.
-- Additive: one new table; no existing row changes. The runtime role gets DML through the default
-- privileges (20261016130000_per_database_runtime_group): no GRANT here.

-- CreateTable: the segments of one live (≤ 10), replaced whole by the host.
CREATE TABLE "live_program_items" (
    "room_id" UUID NOT NULL,
    "position" SMALLINT NOT NULL,
    "starts_at" TIMESTAMPTZ(3) NOT NULL,
    "title" VARCHAR(240) NOT NULL,
    "announced_at" TIMESTAMPTZ(3),

    CONSTRAINT "live_program_items_pkey" PRIMARY KEY ("room_id","position")
);

-- CreateIndex
CREATE INDEX "live_program_items_due_idx" ON "live_program_items"("starts_at") WHERE (announced_at IS NULL);

-- AddForeignKey
ALTER TABLE "live_program_items" ADD CONSTRAINT "live_program_items_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "live_program_items" ADD CONSTRAINT "live_program_items_shape" CHECK (
    position BETWEEN 0 AND 9 AND length(btrim(title)) > 0);
