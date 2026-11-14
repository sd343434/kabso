-- v1.118-social (D357, CONVENTIONS §10.47 / §10.153): room for the founder's social row.
--
-- Owner (2026-11-10): «تحت البايو ضع اشارة السوشل ميديا مثل انستقرام وفيسبوك وواتساب وسناب شات لنضيف صفحاتنا عليها».
-- The row is drawn from the existing profile links (§10.47, no second store): the app owner may keep up to 7 links
-- (his 3 plus one per platform of the row: Instagram, Facebook, WhatsApp, Snapchat); everyone else keeps 3, which
-- the API enforces (`links` / `too_many`). The position CHECK widens from 0–2 to 0–6. An existing table and
-- constraint: no GRANT, no data change (every stored row is within 0–2).

ALTER TABLE "user_profile_links" DROP CONSTRAINT "user_profile_links_position";
ALTER TABLE "user_profile_links" ADD CONSTRAINT "user_profile_links_position" CHECK (position BETWEEN 0 AND 6);
