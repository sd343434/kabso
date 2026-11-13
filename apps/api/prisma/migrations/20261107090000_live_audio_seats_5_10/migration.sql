-- CP-011 amendment (owner D103, 2026-10-26): an AUDIO room has 5, 10, 15, 20 or 25 tiles, the host
-- included (was 6, 9, 15, 20, 25, D100). Seats stay 1 … 24. No new table; no GRANT needed.

-- The old CHECK (AUDIO 6, 9, 15, 20, 25) goes first: it would refuse the new size below.
ALTER TABLE "live_rooms" DROP CONSTRAINT "live_rooms_seat_count_mode";

-- Existing AUDIO rooms of 6 or 9 move to the next allowed size, 10 (more seats; every taken seat
-- keeps its index, which stays inside the new range; empty seats have no row).
UPDATE "live_rooms" SET "seat_count" = 10 WHERE mode::text = 'AUDIO' AND seat_count IN (6, 9);

ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_seat_count_mode" CHECK (
  (mode::text IN ('SOLO', 'PK') AND seat_count IS NULL)
  OR (mode::text = 'MULTI' AND seat_count IN (4, 6, 9, 12))
  OR (mode::text = 'AUDIO' AND seat_count IN (5, 10, 15, 20, 25)));
