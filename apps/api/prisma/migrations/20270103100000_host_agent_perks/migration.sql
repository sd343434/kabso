-- v1.58-social (D189, owner 2026-10-30): host-agent perks (CONVENTIONS §10.52, CP-032). An agency's owner — the host
-- agent «وكيل مضيفين» — gets at activation (`economy-admin agency-create`) the code `host` + a sequential number
-- (at least two digits: host01 … host99, host100), which becomes their special username (§10.48.1, source
-- HOST_AGENT), plus a frame, a badge and an entrance derived from the agency (not bag items). `suspended_at`: the
-- team's suspension of the host agent (`economy-admin agency-suspend`) removes every perk at once; the code stays the
-- person's. Additive: existing agencies get their code from the agency sweeper (oldest first); no username changes
-- here. The runtime role gets DML through the default privileges: no GRANT here.

ALTER TABLE "agencies"
  ADD COLUMN "host_code" VARCHAR(30),
  ADD COLUMN "host_code_number" INTEGER,
  ADD COLUMN "host_code_at" TIMESTAMPTZ(3),
  ADD COLUMN "suspended_at" TIMESTAMPTZ(3),
  ADD COLUMN "suspend_reason" VARCHAR(500);

CREATE UNIQUE INDEX "agencies_host_code_key" ON "agencies"("host_code");
CREATE UNIQUE INDEX "agencies_host_code_number_key" ON "agencies"("host_code_number");
ALTER TABLE "agencies" ADD CONSTRAINT "agencies_host_code_shape" CHECK (
  (host_code IS NULL) = (host_code_number IS NULL)
  AND (host_code IS NULL) = (host_code_at IS NULL)
  AND (host_code IS NULL OR (host_code ~ '^host[0-9]{2,}$' AND host_code_number >= 1))
  AND ((suspended_at IS NULL) = (suspend_reason IS NULL)));

-- The next host-agent number (one row; updated in the activation transaction: in order, never twice).
CREATE TABLE "host_agent_counter" (
    "id" SMALLINT NOT NULL,
    "last_number" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "host_agent_counter_pkey" PRIMARY KEY ("id")
);
INSERT INTO "host_agent_counter" ("id", "last_number") VALUES (1, 0);
ALTER TABLE "host_agent_counter" ADD CONSTRAINT "host_agent_counter_one" CHECK (id = 1 AND last_number >= 0);

-- A `host` + digits special username is never given to another row (like `coin`).
CREATE UNIQUE INDEX "special_usernames_host_once" ON "special_usernames"("username") WHERE username ~ '^host[0-9]+$';
