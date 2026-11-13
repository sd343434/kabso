-- v1.98-social (D307, owner 2026-11-08: «وضع بايو بالعربي والانجليزي مناسب»; CONVENTIONS §10.112.11).
-- The app owner's bilingual bio on his profile: one row per owner, the Arabic and the English text (each ≤ 300 code
-- points and ≤ 4 line breaks after the bio's normalisation, checked by the API; null = none, the app then shows its
-- own default text). Shown only while the account is the owner (an ACTIVE account holding the OWNER panel role).
-- Additive; runtime grants come from the default privileges (20261016120000_runtime_role_grants).

CREATE TABLE "owner_bios" (
    "user_id" UUID NOT NULL,
    "bio_ar" TEXT,
    "bio_en" TEXT,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "owner_bios_pkey" PRIMARY KEY ("user_id"),
    CONSTRAINT "owner_bios_shape" CHECK (
        (bio_ar IS NULL OR char_length(bio_ar) BETWEEN 1 AND 300)
        AND (bio_en IS NULL OR char_length(bio_en) BETWEEN 1 AND 300)
    )
);
ALTER TABLE "owner_bios" ADD CONSTRAINT "owner_bios_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
