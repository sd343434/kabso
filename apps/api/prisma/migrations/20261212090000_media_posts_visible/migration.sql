-- v1.42-social (D162a, owner 2026-10-29: «جميعها تظهر فوراً»): posts with media are visible at once,
-- like stories (D91); CONVENTIONS §11.2. Data only. Until now the only writer of PENDING was
-- createPost's CP-006 Q2 hold (no admin hold, provider or CLI sets it), so every PENDING post is
-- such a hold and becomes VISIBLE. REMOVED posts are untouched. `updated_at` is left as it was (a
-- visibility change is not an edit). No GRANT, no schema change.
UPDATE "posts" SET "moderation" = 'VISIBLE'::post_moderation WHERE "moderation" = 'PENDING'::post_moderation;
