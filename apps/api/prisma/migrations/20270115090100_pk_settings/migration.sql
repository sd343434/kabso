-- v1.44-live (D199, CONVENTIONS §10.62; owner «طبق تصميم 100%» — PK Setting): a host's PK settings (mode,
-- round time, auto-start, the random queue's gender and region preferences, auto match, suggestions) and
-- the match's copy of the settings used (one host's, picked at random when they differ), its rounds (best
-- of three: the first to win two rounds) and whether it was effective (counted in the records). New enum
-- types only here; the values added to existing types are in 20270115090000_pk_settings_enums.

-- CreateEnum
CREATE TYPE "pk_mode" AS ENUM ('SINGLE', 'BEST_OF_THREE');

-- CreateEnum
CREATE TYPE "pk_gender_pref" AS ENUM ('BOTH', 'MALE', 'FEMALE');

-- CreateEnum
CREATE TYPE "pk_region_pref" AS ENUM ('GLOBAL', 'SAME_COUNTRY');

-- AlterTable
ALTER TABLE "pk_host_settings"
  ADD COLUMN "mode" "pk_mode" NOT NULL DEFAULT 'SINGLE',
  ADD COLUMN "round_minutes" SMALLINT,
  ADD COLUMN "auto_start" BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN "random_gender" "pk_gender_pref" NOT NULL DEFAULT 'BOTH',
  ADD COLUMN "random_region" "pk_region_pref" NOT NULL DEFAULT 'GLOBAL',
  ADD COLUMN "auto_match" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "recommendable" BOOLEAN NOT NULL DEFAULT true;

-- AlterTable
ALTER TABLE "pk_matches"
  ADD COLUMN "mode" "pk_mode" NOT NULL DEFAULT 'SINGLE',
  ADD COLUMN "round_seconds" INTEGER NOT NULL DEFAULT 300,
  ADD COLUMN "round" SMALLINT NOT NULL DEFAULT 1,
  ADD COLUMN "rounds_a" SMALLINT NOT NULL DEFAULT 0,
  ADD COLUMN "rounds_b" SMALLINT NOT NULL DEFAULT 0,
  ADD COLUMN "total_a" BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN "total_b" BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN "settings_from" "pk_side",
  ADD COLUMN "connected_at" TIMESTAMPTZ(3),
  ADD COLUMN "effective" BOOLEAN;

-- AlterTable
ALTER TABLE "pk_boosts" ADD COLUMN "round" SMALLINT NOT NULL DEFAULT 1;

-- The round time a host may choose (minutes); null: the server's PK_BATTLE_SECONDS.
ALTER TABLE "pk_host_settings" ADD CONSTRAINT "pk_host_settings_round_minutes"
  CHECK ("round_minutes" IS NULL OR "round_minutes" IN (3, 5, 10));
ALTER TABLE "pk_matches" ADD CONSTRAINT "pk_matches_rounds" CHECK (
  "round_seconds" > 0 AND "round" BETWEEN 1 AND 3 AND "rounds_a" BETWEEN 0 AND 2 AND "rounds_b" BETWEEN 0 AND 2
  AND "total_a" >= 0 AND "total_b" >= 0 AND ("mode" = 'BEST_OF_THREE' OR "round" = 1));
ALTER TABLE "pk_boosts" ADD CONSTRAINT "pk_boosts_round" CHECK ("round" BETWEEN 1 AND 3);

-- CONNECTED behaves like BATTLE in the state check (not ended, no reason, no winner).
ALTER TABLE "pk_matches" DROP CONSTRAINT "pk_matches_state";
ALTER TABLE "pk_matches" ADD CONSTRAINT "pk_matches_state" CHECK (
  ("status" IN ('CONNECTED', 'BATTLE') AND "ended_at" IS NULL AND "end_reason" IS NULL AND "winner" IS NULL)
  OR ("status" IN ('RESULT', 'CLOSED') AND "ended_at" IS NOT NULL AND "end_reason" IS NOT NULL));

-- The boosters used in this round of a match (per-round limits).
DROP INDEX "pk_boosts_match_side_idx";
CREATE INDEX "pk_boosts_match_side_idx" ON "pk_boosts"("match_id", "side", "round", "ends_at");

-- Auto match: the tick finds the hosts who want it.
CREATE INDEX "pk_host_settings_auto_match_idx" ON "pk_host_settings"("host_id") WHERE "auto_match";
