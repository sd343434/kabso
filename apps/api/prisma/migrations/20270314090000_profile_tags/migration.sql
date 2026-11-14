-- v1.85-social (D278b, CONVENTIONS §10.99; owner 2026-11-05: «منشنات يضعها الشخص معاه لغاية ١٠ بسطرين فقط»): the
-- profile tags shown as chips on the profile cover. Set with `PATCH /me` (`tags`, the whole set in order); each is
-- one line of 1–24 code points after the §6 normalisation (checked by the API). At most 10 per person.
ALTER TABLE "user_profiles" ADD COLUMN "tags" VARCHAR(24)[] NOT NULL DEFAULT ARRAY[]::VARCHAR(24)[];
ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_tags_count" CHECK (cardinality("tags") <= 10);
