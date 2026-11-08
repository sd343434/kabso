-- v1.95-social (D301 follow-up, owner 2026-11-07: «اريد عند حساب الارباح على صفحتي كمؤسس ان تزيل نسب الجميع لكون ربح
-- نهائي وضعها قبل وبعد. بالاضافة هناك تكاليف ثابتة … هذه التكاليف الشهرية يتم تقسيمها على الشهر»; CONVENTIONS §10.112.10).
--
-- 1. `owner_fixed_costs`: the owner's fixed monthly costs (Claude, LiveKit, filters, servers …), in US dollars, active
--    from one day to another (or open-ended); a day's share = the monthly amount ÷ the days of that month.
-- 2. `wallet_ledger_free_coins_idx`: a small partial index so «الربح» can sum the free coins given in a period (event
--    prizes, task and check-in coins) without scanning the whole coin ledger. On a large `wallet_ledger` it is built
--    while the migration holds its lock (only the matching rows are indexed).
-- Runtime grants come from the default privileges (20261016120000_runtime_role_grants).

CREATE TABLE "owner_fixed_costs" (
    "id" UUID NOT NULL,
    "name" VARCHAR(60) NOT NULL,
    "monthly_minor" BIGINT NOT NULL,
    "currency" CHAR(3) NOT NULL DEFAULT 'USD',
    "active_from" DATE NOT NULL,
    "active_to" DATE,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "owner_fixed_costs_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "owner_fixed_costs_shape" CHECK (
        char_length(btrim(name)) BETWEEN 1 AND 60
        AND monthly_minor BETWEEN 1 AND 100000000000
        AND currency = 'USD'
        AND (active_to IS NULL OR active_to >= active_from)
    )
);
CREATE INDEX "owner_fixed_costs_active_idx" ON "owner_fixed_costs"("active_from", "active_to");

CREATE INDEX "wallet_ledger_free_coins_idx" ON "wallet_ledger"("created_at") WHERE (reason IN ('EVENT_PRIZE'::wallet_ledger_reason, 'TASK_REWARD'::wallet_ledger_reason, 'CHECK_IN_REWARD'::wallet_ledger_reason));
