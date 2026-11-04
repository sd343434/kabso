-- v1.63-live (D259, CONVENTIONS §10.95): the live's real host cherries — what the host's balance was
-- credited for gifts received in this live (Σ per send floor(coins × host share × CHERRIES_PER_COIN)),
-- next to the score parts. The app shows it in the host pill (the score is points, not cherries).
ALTER TABLE live_room_scores
  ADD COLUMN host_cherries BIGINT NOT NULL DEFAULT 0,
  ADD CONSTRAINT live_room_scores_host_cherries CHECK (host_cherries >= 0);

-- Backfill from the stored sends at the default CHERRIES_PER_COIN (10): the host's own recipient rows of
-- every live's gifts, each send floored as the cherry ledger credits it (D179).
UPDATE live_room_scores s
   SET host_cherries = x.cherries
  FROM (
    SELECT g.room_id, SUM((gr.coins * g.host_share_bps * 10) / 10000)::bigint AS cherries
      FROM live_gift_recipients gr
      JOIN live_gifts g ON g.id = gr.gift_id
      JOIN live_rooms r ON r.id = g.room_id
     WHERE gr.user_id = r.host_user_id AND g.host_share_bps > 0 AND gr.coins > 0
     GROUP BY g.room_id
  ) x
 WHERE s.room_id = x.room_id;
