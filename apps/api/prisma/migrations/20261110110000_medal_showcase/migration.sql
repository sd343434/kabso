-- v1.21-live (CP-018, owner D106 amendment, 2026-10-26): a user shows up to 6 of their unlocked
-- medals on their profile, in the order they chose (CONVENTIONS §10.21). `showcase_position` is
-- 1 … 6 for a shown medal, NULL otherwise; never chosen = nothing shown (no auto-fill).

ALTER TABLE "user_medals" ADD COLUMN "showcase_position" SMALLINT;

-- CreateIndex
CREATE UNIQUE INDEX "user_medals_showcase_position_key" ON "user_medals"("user_id", "showcase_position") WHERE (showcase_position IS NOT NULL);

ALTER TABLE "user_medals" ADD CONSTRAINT "user_medals_showcase_range" CHECK (showcase_position IS NULL OR showcase_position BETWEEN 1 AND 6);
