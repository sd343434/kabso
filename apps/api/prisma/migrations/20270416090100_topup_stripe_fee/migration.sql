-- v1.109-social (D344, CONVENTIONS §10.143.2; owner 2026-11-09: «اسعار الشحن من الموقع يجب اضافة عليها عمولة stripe»):
-- the website price includes Stripe's processing fee (gross-up: charged = ceil((base + fixed) / (1 - percent))), so
-- Kabso nets the package's base price. One all-inclusive price per package — never a separate fee line (surcharging
-- consumer cards is forbidden in the EU/UK; PP-79). The coins of a package are unchanged.
-- The OWNER's rates from the panel «الدفع (Stripe)» (NULL = the server's TOPUP_STRIPE_FEE_* values).
ALTER TABLE "payment_settings" ADD COLUMN "stripe_fee_gross_up" BOOLEAN;
ALTER TABLE "payment_settings" ADD COLUMN "stripe_fee_percent_bps" INTEGER;
ALTER TABLE "payment_settings" ADD COLUMN "stripe_fee_fixed_minor" INTEGER;
ALTER TABLE "payment_settings" ADD CONSTRAINT "payment_settings_stripe_fee_check" CHECK (
  ("stripe_fee_percent_bps" IS NULL OR "stripe_fee_percent_bps" BETWEEN 0 AND 2000)
  AND ("stripe_fee_fixed_minor" IS NULL OR "stripe_fee_fixed_minor" BETWEEN 0 AND 10000)
);

-- Each order keeps how its price was made (the audit trail) and, once Stripe says it, the fee Stripe really took.
-- NULL on the orders made before this migration.
ALTER TABLE "topup_orders" ADD COLUMN "base_price_minor" INTEGER;
ALTER TABLE "topup_orders" ADD COLUMN "fee_percent_bps" INTEGER;
ALTER TABLE "topup_orders" ADD COLUMN "fee_fixed_minor" INTEGER;
ALTER TABLE "topup_orders" ADD COLUMN "stripe_fee_minor" INTEGER;
ALTER TABLE "topup_orders" ADD CONSTRAINT "topup_orders_price_parts_check" CHECK (
  ("base_price_minor" IS NULL OR ("base_price_minor" > 0 AND "base_price_minor" <= "amount_minor"))
  AND ("fee_percent_bps" IS NULL OR "fee_percent_bps" BETWEEN 0 AND 2000)
  AND ("fee_fixed_minor" IS NULL OR "fee_fixed_minor" BETWEEN 0 AND 10000)
  AND ("stripe_fee_minor" IS NULL OR "stripe_fee_minor" >= 0)
);
