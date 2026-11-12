-- v1.127-social (D372, CONVENTIONS §10.164): «هدية الدعم» — a catalogue gift sent on a post or reel of a host or content
-- creator. The send is a `live_gifts` row (the live pipeline without a room, like a conversation gift, D155) that names
-- the post; its gift line is a `comments` row of kind GIFT; the post keeps the cherries its author earned from them.
-- No GRANT: the runtime role gets DML through the default privileges (20261016120000_runtime_role_grants).

CREATE TYPE "comment_kind" AS ENUM ('TEXT', 'GIFT');

-- The post a send was made on (SET NULL: the money rows outlive a post removed for good).
ALTER TABLE "live_gifts" ADD COLUMN "post_id" UUID;
ALTER TABLE "live_gifts" ADD CONSTRAINT "live_gifts_post_id_fkey" FOREIGN KEY ("post_id")
    REFERENCES "posts" ("id") ON DELETE SET NULL ON UPDATE CASCADE;
CREATE INDEX "live_gifts_post_idx" ON "live_gifts" ("post_id") WHERE post_id IS NOT NULL;
-- A content send has no room and no conversation.
ALTER TABLE "live_gifts" ADD CONSTRAINT "live_gifts_post_place" CHECK (
    "post_id" IS NULL OR ("room_id" IS NULL AND "dm_conversation_id" IS NULL));

-- The gift line: a top-level comment of kind GIFT names its send (one line per send), with no text of its own.
ALTER TABLE "comments" ADD COLUMN "kind" "comment_kind" NOT NULL DEFAULT 'TEXT';
ALTER TABLE "comments" ADD COLUMN "gift_id" UUID;
ALTER TABLE "comments" ADD CONSTRAINT "comments_gift_id_fkey" FOREIGN KEY ("gift_id")
    REFERENCES "live_gifts" ("id") ON DELETE CASCADE ON UPDATE CASCADE;
CREATE UNIQUE INDEX "comments_gift_id_key" ON "comments" ("gift_id");
ALTER TABLE "comments" ADD CONSTRAINT "comments_gift_shape" CHECK (
    ("kind" = 'GIFT') = ("gift_id" IS NOT NULL)
    AND ("kind" = 'TEXT' OR ("parent_id" IS NULL AND "text" = '')));

-- The cherries the author earned from the gifts on this post (the counter «هدية الدعم» shows).
ALTER TABLE "posts" ADD COLUMN "gift_cherries" BIGINT NOT NULL DEFAULT 0;
ALTER TABLE "posts" ADD CONSTRAINT "posts_gift_cherries_range" CHECK ("gift_cherries" >= 0);

-- The ledger's sign rule: CONTENT_GIFT is a debit. Extended in place (read from the catalogue, not restated), as
-- 20270417090100_store_iap did.
DO $$
DECLARE
  def text;
BEGIN
  SELECT pg_get_constraintdef(c.oid) INTO STRICT def
    FROM pg_constraint c
   WHERE c.conrelid = 'wallet_ledger'::regclass AND c.conname = 'wallet_ledger_reason_sign';
  ALTER TABLE "wallet_ledger" DROP CONSTRAINT "wallet_ledger_reason_sign";
  EXECUTE format('ALTER TABLE wallet_ledger ADD CONSTRAINT wallet_ledger_reason_sign CHECK ((%s) OR (reason::text = %L AND delta < 0))',
                 substring(def FROM '^CHECK \((.*)\)$'), 'CONTENT_GIFT');
END
$$;
