-- D258 (CONVENTIONS §10.94.9): «من زار ملفي» — who opened whose profile (one row per pair; a VIP holding
-- PROFILE_VISITORS lists theirs).
CREATE TABLE "profile_visits" (
    "owner_id" UUID NOT NULL,
    "visitor_id" UUID NOT NULL,
    "first_visited_at" TIMESTAMPTZ(3) NOT NULL,
    "last_visited_at" TIMESTAMPTZ(3) NOT NULL,
    "visits" INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT "profile_visits_pkey" PRIMARY KEY ("owner_id", "visitor_id"),
    CONSTRAINT "profile_visits_not_self" CHECK ("owner_id" <> "visitor_id"),
    CONSTRAINT "profile_visits_visits_check" CHECK ("visits" >= 1)
);

CREATE INDEX "profile_visits_owner_last_idx" ON "profile_visits"("owner_id", "last_visited_at" DESC);

ALTER TABLE "profile_visits" ADD CONSTRAINT "profile_visits_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "profile_visits" ADD CONSTRAINT "profile_visits_visitor_id_fkey" FOREIGN KEY ("visitor_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- The runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group).
