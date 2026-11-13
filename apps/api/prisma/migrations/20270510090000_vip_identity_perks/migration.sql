-- v1.131-social (D378, owner 2026-11-11: the VIP identity perks), CONVENTIONS §10.168.
--
-- 1. `vip_memberships.signature`: the member's ANIMATED_SIGNATURE text (1–24 characters; the API refuses blocked
--    words), shown under their posts and public bullet messages only while the perk is held.
-- 2. `premium_username_source` gains `VIP`: a premium username claimed free with the PREMIUM_USERNAME perk; the lease
--    ends with the membership (then D146's grace period, as a rented one).
-- 3. `vip_golden_ids`: the owner's stock of golden IDs «آيدي ذهبي» (GOLDEN_ID), each with its class; a holder picks a
--    FREE number of their perk's class; at the end of the membership it is kept for them in GRACE, then returns FREE.
--    An ordinary table: the runtime group's DML comes from the default privileges (no GRANT, KL-013).
--
-- Nothing existing is changed or deleted.
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

ALTER TABLE "vip_memberships" ADD COLUMN "signature" VARCHAR(96);
ALTER TABLE "vip_memberships" ADD CONSTRAINT "vip_memberships_signature_length" CHECK (
    "signature" IS NULL OR char_length("signature") BETWEEN 1 AND 24);

ALTER TYPE "premium_username_source" ADD VALUE 'VIP';

CREATE TYPE "vip_golden_id_class" AS ENUM ('REPEATED', 'THREE_DIGIT', 'FOUR_DIGIT', 'FIVE_DIGIT');
CREATE TYPE "vip_golden_id_state" AS ENUM ('FREE', 'HELD', 'GRACE');

CREATE TABLE "vip_golden_ids" (
    "number" VARCHAR(8) NOT NULL,
    "class" "vip_golden_id_class" NOT NULL,
    "state" "vip_golden_id_state" NOT NULL DEFAULT 'FREE',
    "holder_id" UUID,
    "held_until" TIMESTAMPTZ(3),
    "grace_until" TIMESTAMPTZ(3),
    "claimed_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "vip_golden_ids_pkey" PRIMARY KEY ("number"),
    CONSTRAINT "vip_golden_ids_number_format" CHECK ("number" ~ '^[1-9][0-9]{1,7}$'),
    -- A FREE number has no holder or dates; HELD has its end; GRACE its grace end. A deleted holder leaves a
    -- HELD / GRACE row without a holder: the API treats it as free and the sweeper returns it to the stock.
    CONSTRAINT "vip_golden_ids_state_fields" CHECK (
        ("state" = 'FREE' AND "holder_id" IS NULL AND "held_until" IS NULL AND "grace_until" IS NULL)
        OR ("state" = 'HELD' AND "held_until" IS NOT NULL AND "grace_until" IS NULL)
        OR ("state" = 'GRACE' AND "grace_until" IS NOT NULL))
);

CREATE UNIQUE INDEX "vip_golden_ids_holder_key" ON "vip_golden_ids"("holder_id");
CREATE INDEX "vip_golden_ids_class_idx" ON "vip_golden_ids"("class", "state", "number");

ALTER TABLE "vip_golden_ids" ADD CONSTRAINT "vip_golden_ids_holder_id_fkey" FOREIGN KEY ("holder_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
