import type { Prisma } from '../../generated/prisma/client.js';
import { programWindowsIn } from '../programs/programs-time.js';
import { VIP_BUILT_PERKS } from './vip-rules.js';

/**
 * v1.134-social (D381, CONVENTIONS §10.171): the reads the gift / CP / support / rocket / voice perks share — a member's
 * effective value of a perk (inheritance: the highest-ranked tier at or below the member's that lists the perk enabled,
 * D258) and the exclusive gifts (EXCLUSIVE_GIFTS: every tier's list, a code open from the lowest tier listing it up).
 * Kept apart from `vip-perks.ts` so the sibling perk branches merge cleanly.
 */

type Db = Pick<Prisma.TransactionClient, 'vipMembership' | 'vipTierPerk'>;

/** The rank (`sortOrder`) of the member's tier while the membership is active, else null. */
export async function vipRankIn(
  db: Pick<Prisma.TransactionClient, 'vipMembership'>,
  userId: string,
  now: Date,
): Promise<number | null> {
  const m = await db.vipMembership.findUnique({
    where: { userId },
    select: { expiresAt: true, tier: { select: { sortOrder: true } } },
  });
  if (!m || m.expiresAt.getTime() <= now.getTime()) return null;
  return m.tier.sortOrder;
}

/** What a member holds of a perk: `null` (not held), else its effective value (`null` when the tier set none). */
export type VipHeld = { readonly value: unknown } | null;

/**
 * D381: the member's effective [code] now — the enabled perk of the highest-ranked tier at or below theirs (a tier
 * holds every lower tier's perks), with that row's `value`. Null: no active membership, not held, or not built.
 */
export async function vipPerkHeldIn(db: Db, userId: string, code: string, now: Date): Promise<VipHeld> {
  if (!VIP_BUILT_PERKS.has(code)) return null;
  const rank = await vipRankIn(db, userId, now);
  if (rank === null) return null;
  const row = await db.vipTierPerk.findFirst({
    where: { code, enabled: true, tier: { sortOrder: { lte: rank } } },
    orderBy: { tier: { sortOrder: 'desc' } },
    select: { value: true },
  });
  return row ? { value: row.value } : null;
}

/** The effective whole-number value of [code] (an `int` perk), or null when not held or not set. */
export async function vipPerkIntIn(db: Db, userId: string, code: string, now: Date): Promise<number | null> {
  const held = await vipPerkHeldIn(db, userId, code, now);
  return held && typeof held.value === 'number' && Number.isInteger(held.value) ? held.value : null;
}

/**
 * D381: the exclusive gifts — gift code → the lowest rank whose members may send it (the lowest-ranked tier listing it
 * in an enabled EXCLUSIVE_GIFTS; a higher tier inherits the lower tier's list: «lower tier's list carries up»). A code
 * on no list is not exclusive. Read for every send, so cached for {@link EXCLUSIVE_CACHE_MS} in this process and
 * forgotten whenever this process saves a tier ({@link forgetVipExclusiveGifts}).
 */
export async function vipExclusiveGiftsIn(
  db: Pick<Prisma.TransactionClient, 'vipTierPerk'>,
  now = Date.now(),
): Promise<ReadonlyMap<string, number>> {
  if (!VIP_BUILT_PERKS.has('EXCLUSIVE_GIFTS')) return new Map();
  if (exclusiveCache && now - exclusiveCache.at < EXCLUSIVE_CACHE_MS) return exclusiveCache.map;
  const rows = await db.vipTierPerk.findMany({
    where: { code: 'EXCLUSIVE_GIFTS', enabled: true },
    select: { value: true, tier: { select: { sortOrder: true } } },
  });
  const map = new Map<string, number>();
  for (const r of rows) {
    if (!Array.isArray(r.value)) continue;
    for (const code of r.value) {
      if (typeof code !== 'string') continue;
      const before = map.get(code);
      if (before === undefined || r.tier.sortOrder < before) map.set(code, r.tier.sortOrder);
    }
  }
  exclusiveCache = { at: now, map };
  return map;
}

/** How long {@link vipExclusiveGiftsIn} keeps its answer (another API instance's panel save shows within this). */
export const EXCLUSIVE_CACHE_MS = 30_000;
let exclusiveCache: { readonly at: number; readonly map: ReadonlyMap<string, number> } | null = null;

/** Forgets the cached exclusive gifts (a tier was saved here; tests). */
export function forgetVipExclusiveGifts(): void {
  exclusiveCache = null;
}

/** Whether a member of [rank] (null: no active VIP) may send [giftCode] given the exclusive map. */
export function vipMaySendGift(
  exclusive: ReadonlyMap<string, number>,
  giftCode: string,
  rank: number | null,
): boolean {
  const min = exclusive.get(giftCode);
  return min === undefined || (rank !== null && rank >= min);
}

/** The exclusive codes a member of [rank] may send (their «VIP» tab), in code order. */
export function vipGiftCodesFor(exclusive: ReadonlyMap<string, number>, rank: number | null): string[] {
  if (rank === null) return [];
  return [...exclusive.entries()]
    .filter(([, min]) => rank >= min)
    .map(([code]) => code)
    .sort();
}

/**
 * D381 (HIGHER_GIFT_QUANTITY, owner «حد إرسال أعلى، مثل 9999 دفعة واحدة»): the larger quantities a holder may pick,
 * beside `LIVE_GIFT_QUANTITIES`: these steps up to the perk's maximum, and the maximum itself.
 */
export const VIP_GIFT_QUANTITY_STEPS: readonly number[] = [3344, 5200, 9999, 13140, 52000, 99999];

/**
 * The extra quantities of a holder whose perk maximum is [max] (null: not held): every step and the maximum above the
 * largest configured quantity, ascending, distinct. Empty when the maximum is not above the configured ones.
 */
export function vipExtraQuantities(base: readonly number[], max: number | null): number[] {
  if (max === null) return [];
  const top = Math.max(...base);
  const out = new Set<number>();
  for (const q of VIP_GIFT_QUANTITY_STEPS) if (q > top && q <= max) out.add(q);
  if (max > top) out.add(max);
  return [...out].sort((a, b) => a - b);
}

/**
 * v1.134-social (D381, §10.171.2) FREE_CP_REQUEST: [userId]'s free CP requests this calendar month (the programs'
 * clock [timeZone] = `LIVE_RANKINGS_TIME_ZONE`, D99) — the perk's number, the free requests sent this month (any
 * outcome: a declined, cancelled or expired free request still used its slot; nothing was charged, so nothing comes
 * back) and what is left; `resetsAt` the next month's start. Null without the perk (or with no number set).
 */
export async function vipFreeCpRequestsIn(
  db: Db & Pick<Prisma.TransactionClient, 'cpRequest' | '$queryRaw'>,
  userId: string,
  now: Date,
  timeZone: string,
): Promise<{ perMonth: number; used: number; left: number; resetsAt: Date } | null> {
  const perMonth = await vipPerkIntIn(db, userId, 'FREE_CP_REQUEST', now);
  if (perMonth === null) return null;
  const { month } = await programWindowsIn(db, now, timeZone);
  const used = await db.cpRequest.count({
    where: { senderId: userId, cost: 0, createdAt: { gte: month.start, lt: month.end } },
  });
  return { perMonth, used, left: Math.max(0, perMonth - used), resetsAt: month.end };
}

/** v1.134-social (D381, §10.171.5): at most this many scheduled gifts of one sender wait at a time. */
export const VIP_SCHEDULED_GIFT_MAX_PENDING = 10;
