-- v1.55-live (D242, owner 2026-11-02: «لا يحتوي pk زر إعادة pk أو لعب جولة أخرى»): «جولة أخرى» — a rematch with the
-- same opponent. CONVENTIONS §10.85. Additive columns on pk_matches; the runtime role has DML through the default
-- privileges (20261016130000_per_database_runtime_group): no GRANT here.
--
-- A rematch is a NEW match row (its own result, dare, records and history), linked to the one it follows:
-- `rematch_of` (the previous battle), `rematch_root_id` (the first of the chain: the PK media watchers of that chain
-- stay valid) and `rematch_count` (how many rematches came before: PK_REMATCH_MAX). While a RESULT match has an
-- offer: `rematch_by` (the side that asked) and `rematch_expires_at` (PK_REMATCH_ACCEPT_SECONDS).
ALTER TABLE "pk_matches"
    ADD COLUMN "rematch_of" UUID,
    ADD COLUMN "rematch_root_id" UUID,
    ADD COLUMN "rematch_count" INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN "rematch_by" "pk_side",
    ADD COLUMN "rematch_expires_at" TIMESTAMPTZ(3);

ALTER TABLE "pk_matches"
    ADD CONSTRAINT "pk_matches_rematch_of_fkey" FOREIGN KEY ("rematch_of") REFERENCES "pk_matches"("id")
        ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "pk_matches" ADD CONSTRAINT "pk_matches_rematch_count" CHECK (rematch_count >= 0);
ALTER TABLE "pk_matches" ADD CONSTRAINT "pk_matches_rematch_offer"
    CHECK ((rematch_by IS NULL) = (rematch_expires_at IS NULL));

CREATE INDEX "pk_matches_rematch_root_idx" ON "pk_matches"("rematch_root_id") WHERE "rematch_root_id" IS NOT NULL;
