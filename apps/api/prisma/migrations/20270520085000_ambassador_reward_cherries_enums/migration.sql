-- v1.141-social (D390 follow-up, owner 2026-11-14: «يجب ان تكون ارباح السفير بالكرز ليتمكن من سحبهم من وكيل شحن», and
-- «نعم» for the monthly rewards), CONVENTIONS §10.179.6. Its own migration: a value added by ALTER TYPE … ADD VALUE
-- cannot be used in the transaction that adds it.
--  - `AMBASSADOR_REWARD_CHERRIES` (credit): an ambassador's monthly target reward in withdrawable cherries (reference
--    `AMB:<user>@<YYYY-MM>`, once per person and month by `cherry_ledger_reference_once`). Its sign rule is added by
--    `20270520090000_ambassador_level_names`.
ALTER TYPE "cherry_ledger_reason" ADD VALUE 'AMBASSADOR_REWARD_CHERRIES';
