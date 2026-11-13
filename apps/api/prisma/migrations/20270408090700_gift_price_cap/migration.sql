-- v1.91-live (D323, CONVENTIONS §10.23; owner: a 3 000 000-coin gift «تاج الافتتاح» was refused by the
-- 1 000 000 cap): a gift costs 1 … 100 000 000 coins (was 1 … 1 000 000); a free quip (0, QUIPS) as before. Only the
-- upper bound changes; the other branch of the CHECK (20270127090000_gift_categories) is unchanged. price_coins stays
-- INTEGER (100 000 000 < 2^31); every amount of a send (× quantity × recipients) is already BIGINT.
ALTER TABLE "gifts" DROP CONSTRAINT "gifts_price_range";
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_price_range" CHECK (
    price_coins BETWEEN 1 AND 100000000 OR (price_coins = 0 AND category = 'QUIPS'));
