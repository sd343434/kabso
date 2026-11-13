-- v1.27.1-live (D133, owner 2026-10-27): the live hub's Nearby and Featured filters,
-- CONVENTIONS §10.4, §10.28. Additive: a nullable column (every account starts with no country;
-- none is guessed) and a new table managed only by the `feature-admin` CLI. No GRANT (default
-- privileges, 20261016130000_per_database_runtime_group).

-- AlterTable: the user's own country (ISO 3166-1 alpha-2, upper case).
ALTER TABLE "user_profiles" ADD COLUMN "country_code" CHAR(2);
ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_country_code_format" CHECK (country_code ~ '^[A-Z]{2}$');

-- CreateIndex: hosts of a country (nearby).
CREATE INDEX "user_profiles_country_idx" ON "user_profiles"("country_code") WHERE country_code IS NOT NULL;

-- CreateTable: featured hosts.
CREATE TABLE "live_featured_hosts" (
    "user_id" UUID NOT NULL,
    "rank" INTEGER NOT NULL DEFAULT 100,
    "until" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "live_featured_hosts_pkey" PRIMARY KEY ("user_id")
);

-- AddForeignKey
ALTER TABLE "live_featured_hosts" ADD CONSTRAINT "live_featured_hosts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "live_featured_hosts" ADD CONSTRAINT "live_featured_hosts_rank_range" CHECK (rank BETWEEN 0 AND 1000000);
