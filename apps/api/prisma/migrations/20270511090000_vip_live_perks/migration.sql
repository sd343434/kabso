-- v1.132-social (D379, owner 2026-11-11: the VIP perks inside live rooms), CONVENTIONS §10.169.
--
-- 1. `live_rooms.vip_min_tier_id` — VIP_ROOM «غرفة VIP خاصة»: an AUDIO live only members of this tier or a higher one
--    enter (null = open to all). RESTRICT: a tier a live points at cannot be deleted under it (the panel switches tiers
--    off, it never deletes one).
-- 2. `live_chat_pins` — PINNED_MESSAGE «تثبيت رسالتك أعلى الدردشة لثوانٍ»: one row per pin (the day's count, the room's
--    one pin at a time), deleted with its message.
-- 3. `live_seat_reservations` — SEAT_RESERVE «قفل المقعد لصديق»: a seat the host keeps for one person until `until`.
--
-- Nothing existing changes: the new column is nullable and the new tables start empty.
-- New tables get their runtime grants from the default privileges (KL-013, migration 20261016130000).
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

-- 1. The VIP room.
ALTER TABLE "live_rooms" ADD COLUMN "vip_min_tier_id" UUID;
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_vip_min_tier_id_fkey" FOREIGN KEY ("vip_min_tier_id") REFERENCES "vip_tiers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_vip_audio" CHECK ("vip_min_tier_id" IS NULL OR "mode" = 'AUDIO'::live_room_mode);
CREATE INDEX "live_rooms_vip_min_tier_idx" ON "live_rooms"("vip_min_tier_id") WHERE "vip_min_tier_id" IS NOT NULL;

-- 2. The pins.
CREATE TABLE "live_chat_pins" (
    "id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "message_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "text" VARCHAR(200) NOT NULL,
    "pinned_at" TIMESTAMPTZ(3) NOT NULL,
    "until" TIMESTAMPTZ(3) NOT NULL,
    "removed_at" TIMESTAMPTZ(3),
    "removed_by_id" UUID,

    CONSTRAINT "live_chat_pins_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "live_chat_pins_window" CHECK ("until" > "pinned_at" AND "until" <= "pinned_at" + INTERVAL '600 seconds')
);
CREATE INDEX "live_chat_pins_room_until_idx" ON "live_chat_pins"("room_id", "until" DESC);
CREATE INDEX "live_chat_pins_user_day_idx" ON "live_chat_pins"("user_id", "pinned_at");
CREATE INDEX "live_chat_pins_message_idx" ON "live_chat_pins"("message_id");
CREATE INDEX "live_chat_pins_removed_by_idx" ON "live_chat_pins"("removed_by_id");
ALTER TABLE "live_chat_pins" ADD CONSTRAINT "live_chat_pins_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "live_chat_pins" ADD CONSTRAINT "live_chat_pins_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "live_chat_messages"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "live_chat_pins" ADD CONSTRAINT "live_chat_pins_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "live_chat_pins" ADD CONSTRAINT "live_chat_pins_removed_by_id_fkey" FOREIGN KEY ("removed_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- 3. The reserved seats (seat 0 is the host's tile: never reserved).
CREATE TABLE "live_seat_reservations" (
    "room_id" UUID NOT NULL,
    "seat_index" SMALLINT NOT NULL,
    "user_id" UUID NOT NULL,
    "reserved_by_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL,
    "until" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "live_seat_reservations_pkey" PRIMARY KEY ("room_id", "seat_index"),
    CONSTRAINT "live_seat_reservations_shape" CHECK (
      "seat_index" >= 1 AND "until" > "created_at" AND "until" <= "created_at" + INTERVAL '60 minutes'
      AND "user_id" <> "reserved_by_id")
);
CREATE UNIQUE INDEX "live_seat_reservations_one_per_user" ON "live_seat_reservations"("room_id", "user_id");
CREATE INDEX "live_seat_reservations_user_idx" ON "live_seat_reservations"("user_id");
CREATE INDEX "live_seat_reservations_by_idx" ON "live_seat_reservations"("reserved_by_id");
ALTER TABLE "live_seat_reservations" ADD CONSTRAINT "live_seat_reservations_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "live_seat_reservations" ADD CONSTRAINT "live_seat_reservations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "live_seat_reservations" ADD CONSTRAINT "live_seat_reservations_reserved_by_id_fkey" FOREIGN KEY ("reserved_by_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
