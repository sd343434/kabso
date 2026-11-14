-- D291 (owner: «سيد الحظ» / Lucky Master, «يتم احتساب من مجموع هدايا الحظ التي قام بإرسالها»): the metric of the second
-- real levelled medal — the coin value of the lucky gifts a person sent (the mirror of GIFTS_SENT_COINS, which leaves
-- them out). Its own migration: a new enum value cannot be used in the transaction that adds it.
ALTER TYPE "MedalMetric" ADD VALUE 'LUCKY_GIFTS_SENT_COINS';
