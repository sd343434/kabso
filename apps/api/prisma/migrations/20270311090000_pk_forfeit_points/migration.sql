-- D276 (owner: «pk الاحكام: تعادل = نقطة، فوز = ٣ نقاط، خسارة = ٠، انسحاب = −٣»، «الاحكام فقط» — CONVENTIONS
-- §10.80.1): in a DARES match only, a host who withdrew from the battle (FORFEIT «إنهاء التحدي» during it, DISCONNECT, AWAY) gets `forfeit_points` (−3 by default)
-- instead of `loss_points`; still a loss in the record. Edited in «أحكام PK» (OWNER, D274) like the other values.
-- The shape CHECK keeps its name (the KL-013 constraint list is unchanged) and gains the new column's range.
ALTER TABLE "pk_dare_settings" ADD COLUMN "forfeit_points" INTEGER NOT NULL DEFAULT -3;
ALTER TABLE "pk_dare_settings" DROP CONSTRAINT "pk_dare_settings_shape";
ALTER TABLE "pk_dare_settings" ADD CONSTRAINT "pk_dare_settings_shape" CHECK (
  id = 1 AND win_points BETWEEN -100 AND 100 AND draw_points BETWEEN -100 AND 100 AND loss_points BETWEEN -100 AND 100
  AND refuse_points BETWEEN -100 AND 100 AND forfeit_points BETWEEN -100 AND 100 AND decide_seconds BETWEEN 5 AND 300
  AND reports_to_disable BETWEEN 1 AND 1000);
