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

/** What {@link addItemTimeIn} did. */
export type AddItemOutcome =
  /** The user did not own it (or theirs had expired): a new item, not worn. */
  | { readonly kind: 'added'; readonly expiresAt: Date | null }
  /** Time was added to the item they own (or it became permanent). */
  | { readonly kind: 'extended'; readonly expiresAt: Date | null }
  /** They own it permanently already: nothing changed. */
  | { readonly kind: 'permanent' };

/**
 * Serializes every change to the holders of `code` among `userIds` for the rest of `tx`
 * (v1.48-social, D171): advisory locks taken in a fixed order (sorted ids), so a send between two
 * users and a grant never deadlock and never interleave.
 */
export async function lockItemHoldersIn(
  tx: Prisma.TransactionClient,
  code: string,
  userIds: readonly string[],
): Promise<void> {
  for (const id of [...new Set(userIds)].sort()) {
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:bag-item'), hashtext(${`${id}:${code}`}::text))`;
  }
}

/**
 * Gives `userId` the item, or adds time to the one they own (v1.48-social, D171, §10.43). The
 * caller holds {@link lockItemHoldersIn} for `(userId, code)`. `durationMs` null = permanent.
 *
 * - Not owned, or owned but expired: a new item counting from `now` (not worn; an expired row is
 *   replaced, worn or not).
 * - Owned with an expiry: the time is added from max(`expiresAt`, `now`); permanent → permanent.
 * - Owned permanently: nothing changes (`permanent`).
 *
 * Granting never changes what the user wears (owner D107). When time is added the row's `source`
 * and `gifted_by_user_id` become the latest giver's; `acquired_at` stays.
 */
export async function addItemTimeIn(
  tx: Prisma.TransactionClient,
  input: {
    readonly userId: string;
    readonly item: CatalogueItemRef;
    readonly source: BagItemSource;
    readonly giftedById: string | null;
    readonly durationMs: number | null;
    readonly now: Date;
  },
): Promise<AddItemOutcome> {
  const { userId, item, source, giftedById, durationMs, now } = input;
  const rows = await tx.$queryRaw<{ expires_at: Date | null }[]>`
    SELECT expires_at FROM user_bag_items
     WHERE user_id = ${userId}::uuid AND item_code = ${item.code}
       FOR UPDATE`;
  const owned = rows[0];
  const fresh = durationMs === null ? null : new Date(now.getTime() + durationMs);
  if (!owned || (owned.expires_at !== null && owned.expires_at <= now)) {
    if (owned) {
      await tx.$executeRaw`DELETE FROM user_bag_items WHERE user_id = ${userId}::uuid AND item_code = ${item.code}`;
    }
    await tx.$executeRaw`
      INSERT INTO user_bag_items (user_id, item_code, category, source, equipped, expires_at, gifted_by_user_id, acquired_at)
      VALUES (${userId}::uuid, ${item.code}, ${item.category}::bag_category, ${source}::bag_item_source, false,
              ${fresh}, ${giftedById}::uuid, ${now})`;
    return { kind: 'added', expiresAt: fresh };
  }
  if (owned.expires_at === null) return { kind: 'permanent' };
  const expiresAt = durationMs === null ? null : new Date(owned.expires_at.getTime() + durationMs);
  await tx.$executeRaw`
    UPDATE user_bag_items
       SET expires_at = ${expiresAt}, source = ${source}::bag_item_source, gifted_by_user_id = ${giftedById}::uuid
     WHERE user_id = ${userId}::uuid AND item_code = ${item.code}`;
  return { kind: 'extended', expiresAt };
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
