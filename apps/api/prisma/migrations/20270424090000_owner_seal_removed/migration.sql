-- v1.118-social (D357, CONVENTIONS §10.105 / §10.153): the OWNER verification seal is retired.
--
-- Owner (2026-11-10): «ازيلها» — no black-and-gold seal beside the founder's name anywhere. The app owner now shows no
-- verification badge at all (`pickBadge` returns null while OWNER is held, D357), so the recompute would remove these
-- rows at its next run; this deletes them at deploy so no payload (and no older installed app) sees `OWNER` in the
-- meantime. The enum value `OWNER` stays (reserved: older apps still parse it; nothing writes it any more). No audit
-- rows: the next recompute finds nothing to change for these users. Data only; no schema change, no GRANT.

DELETE FROM "user_verification_badges" WHERE "badge" = 'OWNER';
