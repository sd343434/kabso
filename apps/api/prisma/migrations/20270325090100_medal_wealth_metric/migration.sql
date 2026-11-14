-- D291 (owner: «ملوك الثروة»): the metric of the first real levelled medal — the coin value of every gift a person sent
-- to anyone (owner: «اي هدية مرسلة لاي مستخدم الا هدايا فئة الحظ»), lucky gifts excluded. Its own migration: a new enum value cannot be used in the
-- transaction that adds it (20270325090200 uses it).
ALTER TYPE "MedalMetric" ADD VALUE 'GIFTS_SENT_COINS';
