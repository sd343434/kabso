-- Integration of D176 (v1.50-social) and D177 (v1.51-social): each branch replaced the banner
-- placement CHECK with its own new value — 20261220090000_wallet_banners allowed WALLET and
-- 20261230090000_daily_task_pool, which runs after it, allowed TASKS but dropped WALLET. Both
-- placements exist (CONVENTIONS §10.26), so the CHECK allows all four. Only the CHECK changes.
ALTER TABLE "home_banners" DROP CONSTRAINT "home_banners_placement_values";
ALTER TABLE "home_banners" ADD CONSTRAINT "home_banners_placement_values" CHECK (placement IN ('HOME', 'ROOM', 'TASKS', 'WALLET'));
