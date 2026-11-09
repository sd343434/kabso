-- v1.86-live (D310, CONVENTIONS §10.116; owner: «ترتيب الغرف اجعله بالكرز»): a room ranks by its cherries — what the
-- cherry ledger credited the host AND the seated guests for gifts received in this live (each send's stored share:
-- 65 % normal → 6.5 cherries a coin, a creator's live 70 % → 7, lucky 10 % → 1, quips their share). Taps never count.
-- The score (points) stays for PK, the popularity boards and the charm level. The runtime role gets DML through the
-- default privileges (20261016120000_runtime_role_grants), so this migration contains no GRANT.

ALTER TABLE "live_rooms" ADD COLUMN "cherries" BIGINT NOT NULL DEFAULT 0;
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_cherries_nonneg" CHECK (cherries >= 0);

-- Backfill the rooms that are LIVE now (only they are listed; an ENDED room keeps 0 — its history shows the host's
-- cherries, D259) from the cherry ledger itself, so a deployment with another CHERRIES_PER_COIN is exact: the
-- recipients' GIFT_RECEIVED rows of each send of that live, less their GIFT_REVERSAL rows. Never below 0.
UPDATE "live_rooms" r
   SET cherries = x.cherries
  FROM (
    SELECT g.room_id, GREATEST(SUM(l.delta), 0)::bigint AS cherries
      FROM live_rooms lr
      JOIN live_gifts g ON g.room_id = lr.id
      JOIN live_gift_recipients gr ON gr.gift_id = g.id
      JOIN cherry_ledger l ON l.reference_id = g.id::text AND l.user_id = gr.user_id
     WHERE lr.status = 'LIVE'::live_room_status AND l.reason IN ('GIFT_RECEIVED', 'GIFT_REVERSAL')
     GROUP BY g.room_id
  ) x
 WHERE r.id = x.room_id;

-- The popular keyset moves from the score to the cherries (CONVENTIONS §10.4, v1.86-live).
DROP INDEX "live_rooms_live_popular_idx";
DROP INDEX "live_rooms_live_cat_popular_idx";
CREATE INDEX "live_rooms_live_popular_cherries_idx" ON "live_rooms"("cherries" DESC, "started_at" DESC, "id" DESC) WHERE (status = 'LIVE'::live_room_status);
CREATE INDEX "live_rooms_live_cat_popular_cherries_idx" ON "live_rooms"("category_id", "cherries" DESC, "started_at" DESC, "id" DESC) WHERE (status = 'LIVE'::live_room_status);
