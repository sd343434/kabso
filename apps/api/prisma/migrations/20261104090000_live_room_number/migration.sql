-- CP-016 part G (D99): the host's public room number (CONVENTIONS §10.17). Nine digits, random and
-- unique, kept on `live_hosts` so every live of a host shows the same "ID: …". Existing hosts get
-- one each (re-drawn on a clash) before the column becomes NOT NULL. New hosts get one from the
-- column default; the grant retries in the rare case the drawn number is taken.

ALTER TABLE "live_hosts" ADD COLUMN "room_number" INTEGER;

DO $$
DECLARE
  h RECORD;
  n INTEGER;
BEGIN
  FOR h IN SELECT user_id FROM live_hosts LOOP
    LOOP
      n := (100000000 + floor((random() * (900000000)::double precision)))::integer;
      EXIT WHEN NOT EXISTS (SELECT 1 FROM live_hosts WHERE room_number = n);
    END LOOP;
    UPDATE live_hosts SET room_number = n WHERE user_id = h.user_id;
  END LOOP;
END $$;

ALTER TABLE "live_hosts" ALTER COLUMN "room_number" SET NOT NULL,
  ALTER COLUMN "room_number" SET DEFAULT (100000000 + floor((random() * (900000000)::double precision)))::integer;

-- CreateIndex
CREATE UNIQUE INDEX "live_hosts_room_number_key" ON "live_hosts"("room_number");

-- Check (CONVENTIONS §10.17): nine digits.
ALTER TABLE "live_hosts" ADD CONSTRAINT "live_hosts_room_number_range" CHECK (room_number BETWEEN 100000000 AND 999999999);
