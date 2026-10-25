-- CP-011 amendment (owner D100, 2026-10-25): an AUDIO room has 6, 9, 15, 20 or 25 tiles, the host
-- included (was 5, 9, 13). Seats 1 … 24. No new table; no GRANT needed.

-- Existing AUDIO rooms move to the next allowed size (more seats; every taken seat keeps its
-- index, which stays inside the new range).
UPDATE "live_rooms" SET "seat_count" = 6 WHERE mode::text = 'AUDIO' AND seat_count = 5;
UPDATE "live_rooms" SET "seat_count" = 15 WHERE mode::text = 'AUDIO' AND seat_count = 13;

ALTER TABLE "live_rooms" DROP CONSTRAINT "live_rooms_seat_count_mode";
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_seat_count_mode" CHECK (
  (mode::text IN ('SOLO', 'PK') AND seat_count IS NULL)
  OR (mode::text = 'MULTI' AND seat_count IN (4, 6, 9, 12))
  OR (mode::text = 'AUDIO' AND seat_count IN (6, 9, 15, 20, 25)));

ALTER TABLE "live_room_seats" DROP CONSTRAINT "live_room_seats_index";
ALTER TABLE "live_room_seats" ADD CONSTRAINT "live_room_seats_index" CHECK (seat_index BETWEEN 1 AND 24);
ALTER TABLE "live_seat_requests" DROP CONSTRAINT "live_seat_requests_index";
ALTER TABLE "live_seat_requests" ADD CONSTRAINT "live_seat_requests_index" CHECK (seat_index IS NULL OR seat_index BETWEEN 1 AND 24);
ALTER TABLE "live_seat_invites" DROP CONSTRAINT "live_seat_invites_index";
ALTER TABLE "live_seat_invites" ADD CONSTRAINT "live_seat_invites_index" CHECK (seat_index IS NULL OR seat_index BETWEEN 1 AND 24);
