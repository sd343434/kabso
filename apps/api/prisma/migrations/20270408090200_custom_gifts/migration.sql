-- v1.100-social (D312, CONVENTIONS §10.118): custom gifts «مُخصَّص». A CUSTOM gift names its owner (an account; never
-- deleted from under a gift: RESTRICT, accounts are tombstoned, not removed); every other gift has none. The special
-- category CUSTOM is seeded like LUCKY and QUIPS (code = kind; renamed / reordered / given an icon in the panel, never
-- disabled or deleted). No GRANT: the runtime role gets DML through the default privileges
-- (20261016120000_runtime_role_grants).

ALTER TABLE "gifts" ADD COLUMN "owner_user_id" UUID;
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_owner_user_id_fkey" FOREIGN KEY ("owner_user_id")
    REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE;
CREATE INDEX "gifts_owner_idx" ON "gifts" ("owner_user_id");
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_custom_owner" CHECK (
    ("category" = 'CUSTOM') = ("owner_user_id" IS NOT NULL)
    AND ("category" <> 'CUSTOM' OR "pk_booster" IS NULL));

INSERT INTO "gift_categories" ("code", "kind", "name_ar", "name_en", "sort_order")
VALUES ('CUSTOM', 'CUSTOM', 'مُخصَّص', 'Custom', 60)
ON CONFLICT ("code") DO NOTHING;

-- «الربح» (D301) reads the gift owners' coin shares per day as a cost (COIN_REWARDS); a small partial index like the
-- free coins' one (wallet_ledger_free_coins_idx).
CREATE INDEX "wallet_ledger_gift_owner_idx" ON "wallet_ledger" ("created_at")
    WHERE reason IN ('GIFT_OWNER_ROYALTY'::wallet_ledger_reason, 'GIFT_OWNER_ROYALTY_REVERSAL'::wallet_ledger_reason);

-- The ledger's sign rule: GIFT_OWNER_ROYALTY is a credit, GIFT_OWNER_ROYALTY_REVERSAL a debit. Extended in place (read
-- from the catalogue, not restated), as 20270310090100_store did.
DO $$
DECLARE
  def text;
BEGIN
  SELECT pg_get_constraintdef(c.oid) INTO STRICT def
    FROM pg_constraint c
   WHERE c.conrelid = 'wallet_ledger'::regclass AND c.conname = 'wallet_ledger_reason_sign';
  ALTER TABLE "wallet_ledger" DROP CONSTRAINT "wallet_ledger_reason_sign";
  EXECUTE format('ALTER TABLE wallet_ledger ADD CONSTRAINT wallet_ledger_reason_sign CHECK ((%s) OR (reason::text = %L AND delta > 0) OR (reason::text = %L AND delta < 0))',
                 substring(def FROM '^CHECK \((.*)\)$'), 'GIFT_OWNER_ROYALTY', 'GIFT_OWNER_ROYALTY_REVERSAL');
END
$$;
