-- v1.88-live (D315, CONVENTIONS §10.120; owner: «مجنون اللعب» — players ranked by the game tickets they SPEND): the
-- spend ledger the first game writes (once per game and reference, in the game's transaction that debits the
-- tickets) and its hourly / monthly rollups for the five board periods. No game exists yet. No GRANT: default
-- privileges.
CREATE TABLE "game_ticket_spends" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "game_code" VARCHAR(40) NOT NULL,
    "tickets" BIGINT NOT NULL,
    "reference" VARCHAR(64) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "game_ticket_spends_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "game_ticket_spends_shape" CHECK (
        "tickets" > 0
        AND "game_code" ~ '^[a-z0-9][a-z0-9_]{0,39}$'
        AND length("reference") BETWEEN 1 AND 64)
);
CREATE UNIQUE INDEX "game_ticket_spends_reference_once" ON "game_ticket_spends" ("game_code", "reference");
CREATE INDEX "game_ticket_spends_user_idx" ON "game_ticket_spends" ("user_id", "created_at" DESC);
ALTER TABLE "game_ticket_spends" ADD CONSTRAINT "game_ticket_spends_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "game_ticket_spends_hourly" (
    "user_id" UUID NOT NULL,
    "hour_start" TIMESTAMPTZ(3) NOT NULL,
    "tickets" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "game_ticket_spends_hourly_pkey" PRIMARY KEY ("user_id", "hour_start"),
    CONSTRAINT "game_ticket_spends_hourly_tickets" CHECK ("tickets" >= 0)
);
CREATE INDEX "game_ticket_spends_hourly_hour_idx" ON "game_ticket_spends_hourly" ("hour_start");
ALTER TABLE "game_ticket_spends_hourly" ADD CONSTRAINT "game_ticket_spends_hourly_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "game_ticket_spends_monthly" (
    "user_id" UUID NOT NULL,
    "month_start" TIMESTAMPTZ(3) NOT NULL,
    "tickets" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "game_ticket_spends_monthly_pkey" PRIMARY KEY ("user_id", "month_start"),
    CONSTRAINT "game_ticket_spends_monthly_tickets" CHECK ("tickets" >= 0)
);
CREATE INDEX "game_ticket_spends_monthly_month_idx" ON "game_ticket_spends_monthly" ("month_start");
ALTER TABLE "game_ticket_spends_monthly" ADD CONSTRAINT "game_ticket_spends_monthly_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE CASCADE ON UPDATE CASCADE;
