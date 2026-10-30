import type { Prisma } from '../../generated/prisma/client.js';
import type { BagCategory, BagItemSource } from './bag.catalogue.js';

/**
 * Writes to the bag shared by the API (signup) and the `bag-admin` CLI (no Nest dependencies),
 * always inside the caller's transaction (CP-019, D107, CONVENTIONS §10.22).
 */

/**
 * Gives `userId` every free catalogue item it does not own yet and wears the first one of each
 * category where it wears nothing. Called when the account is created (FREE_SIGNUP), in the same
 * transaction. Only an account that wears nothing is ever dressed here, and this runs once per
 * account, so an item the user took off is never put back on. A catalogue without free items (an
 * empty test database) gives nothing. Returns the number of items given.
 */
export async function grantFreeItemsIn(
  tx: Prisma.TransactionClient,
  userId: string,
  source: Extract<BagItemSource, 'FREE_SIGNUP' | 'BACKFILL'>,
): Promise<number> {
  return tx.$executeRaw`
    INSERT INTO user_bag_items (user_id, item_code, category, source, equipped)
    SELECT ${userId}::uuid, i.code, i.category, ${source}::bag_item_source,
           ROW_NUMBER() OVER (PARTITION BY i.category ORDER BY i.sort_order, i.code) = 1
           AND NOT EXISTS (
             SELECT 1 FROM user_bag_items e
              WHERE e.user_id = ${userId}::uuid AND e.category = i.category AND e.equipped)
      FROM bag_items i
     WHERE i.free
       AND NOT EXISTS (
         SELECT 1 FROM user_bag_items o WHERE o.user_id = ${userId}::uuid AND o.item_code = i.code)`;
}

export interface CatalogueItemRef {
  readonly code: string;
  readonly category: BagCategory;
}

/** The catalogue item with this code, or null. */
export async function catalogueItemIn(
  tx: Prisma.TransactionClient,
  code: string,
): Promise<CatalogueItemRef | null> {
  return tx.bagItem.findUnique({ where: { code }, select: { code: true, category: true } });
}

/**
 * Gives `userId` the item `code` (source ADMIN), not worn: granting never changes what the user
 * wears (owner D107). Returns false when the user already owns it (nothing changes).
 */
export async function grantItemIn(
  tx: Prisma.TransactionClient,
  userId: string,
  item: CatalogueItemRef,
  source: BagItemSource,
): Promise<boolean> {
  const inserted = await tx.$executeRaw`
    INSERT INTO user_bag_items (user_id, item_code, category, source, equipped)
    VALUES (${userId}::uuid, ${item.code}, ${item.category}::bag_category, ${source}::bag_item_source, false)
    ON CONFLICT (user_id, item_code) DO NOTHING`;
  return inserted === 1;
}

/**
 * Takes the item `code` back from `userId`. When it was worn the user wears nothing in that
 * category afterwards (nothing else is put on). Returns whether it was owned and whether it was
 * worn.
 */
export async function revokeItemIn(
  tx: Prisma.TransactionClient,
  userId: string,
  code: string,
): Promise<{ owned: boolean; wasEquipped: boolean }> {
  const rows = await tx.$queryRaw<{ equipped: boolean }[]>`
    DELETE FROM user_bag_items WHERE user_id = ${userId}::uuid AND item_code = ${code}
    RETURNING equipped`;
  return { owned: rows.length === 1, wasEquipped: rows[0]?.equipped ?? false };
}

/**
 * Gives `userId` the catalogue items `codes` it does not own yet (source LEVEL_REWARD, not worn:
 * a reward never changes what the user wears), inside the caller's transaction. Codes missing
 * from the catalogue give nothing. Returns the codes given now (v1.46-levels, D169: the support
 * tier frames).
 */
export async function grantLevelRewardsIn(
  tx: Prisma.TransactionClient,
  userId: string,
  codes: readonly string[],
): Promise<string[]> {
  if (codes.length === 0) return [];
  const rows = await tx.$queryRaw<{ item_code: string }[]>`
    INSERT INTO user_bag_items (user_id, item_code, category, source, equipped)
    SELECT ${userId}::uuid, i.code, i.category, 'LEVEL_REWARD'::bag_item_source, false
      FROM bag_items i WHERE i.code = ANY(${[...new Set(codes)]}::text[])
    ON CONFLICT (user_id, item_code) DO NOTHING
    RETURNING item_code`;
  return rows.map((r) => r.item_code);
}

/**
 * Takes back level rewards (owner D169: only a fraud demotion does this): deletes the user's
 * LEVEL_REWARD rows for `codes`; a worn one leaves the category worn by nothing. Returns the codes
 * removed.
 */
export async function revokeLevelRewardsIn(
  tx: Prisma.TransactionClient,
  userId: string,
  codes: readonly string[],
): Promise<string[]> {
  if (codes.length === 0) return [];
  const rows = await tx.$queryRaw<{ item_code: string }[]>`
    DELETE FROM user_bag_items
     WHERE user_id = ${userId}::uuid AND source = 'LEVEL_REWARD'::bag_item_source
       AND item_code = ANY(${[...new Set(codes)]}::text[])
    RETURNING item_code`;
  return rows.map((r) => r.item_code);
}
