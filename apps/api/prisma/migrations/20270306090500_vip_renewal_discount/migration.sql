-- D258 (CONVENTIONS §10.94.12): a tier's renewal discount (owner: 15 % by default), and what each purchase was charged.
ALTER TABLE "vip_tiers" ADD COLUMN "renewal_discount_percent" INTEGER NOT NULL DEFAULT 15;
ALTER TABLE "vip_tiers" ADD CONSTRAINT "vip_tiers_renewal_discount_check"
  CHECK ("renewal_discount_percent" BETWEEN 0 AND 90);
ALTER TABLE "vip_purchases" ADD COLUMN "list_price_coins" BIGINT;
ALTER TABLE "vip_purchases" ADD COLUMN "discount_percent" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "vip_purchases" ADD CONSTRAINT "vip_purchases_discount_check"
  CHECK ("discount_percent" BETWEEN 0 AND 90);
