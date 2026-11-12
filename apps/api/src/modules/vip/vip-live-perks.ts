import { Prisma } from '../../generated/prisma/client.js';
import { VIP_BUILT_PERKS } from './vip-rules.js';

/**
 * v1.132-social (D379, CONVENTIONS §10.169): reading the VIP perks the live rooms use — a member's effective perk row
 * (D258's inheritance: the perk of the highest-ranked tier at or below the member's, enabled; D374's typed `value` and
 * art), and an SQL expression for lists that rank holders. A perk that is not built (`vip-catalogue.ts`), not held, or
 * held by a membership that ended gives nothing.
 */

/** The live-room perks D379 builds. */
export const VIP_LIVE_PERKS = [
  'SEAT_EMOJI',
  'PINNED_MESSAGE',
  'HOST_GREETING',
  'SEAT_CROWN',
  'BIG_GIFT_RAIN',
  'TICKER_HOLD',
  'VIEWER_LIST_PRIORITY',
  'SEAT_REQUEST_PRIORITY',
  'VIP_ROOM',
  'SEAT_RESERVE',
] as const;
export type VipLivePerkCode = (typeof VIP_LIVE_PERKS)[number];

/** A member's effective perk row. */
export interface VipLivePerk {
  readonly code: string;
  /** The tier row's typed value (`vip_tier_perks.value`), null when not set. */
  readonly value: Prisma.JsonValue | null;
  readonly animation: string | null;
  readonly still: string | null;
  readonly video: string | null;
  readonly artWidth: number | null;
  readonly artHeight: number | null;
  /** The member's own tier: its rank (`sort_order`) and code. */
  readonly rank: number;
  readonly tierCode: string;
}

type Db = Pick<Prisma.TransactionClient, 'vipMembership' | 'vipTierPerk'>;

/**
 * The member's effective row of the built perk [code] at [now], or null (not built, no active membership, not held by
 * their tier nor a lower one).
 */
export async function vipLivePerkIn(
  db: Db,
  userId: string,
  code: VipLivePerkCode,
  now: Date,
): Promise<VipLivePerk | null> {
  if (!VIP_BUILT_PERKS.has(code)) return null;
  const membership = await db.vipMembership.findUnique({
    where: { userId },
    select: { expiresAt: true, tier: { select: { sortOrder: true, code: true } } },
  });
  if (!membership || membership.expiresAt.getTime() <= now.getTime()) return null;
  const row = await db.vipTierPerk.findFirst({
    where: { code, enabled: true, tier: { sortOrder: { lte: membership.tier.sortOrder } } },
    orderBy: [{ tier: { sortOrder: 'desc' } }],
    select: {
      code: true,
      value: true,
      animation: true,
      still: true,
      video: true,
      artWidth: true,
      artHeight: true,
    },
  });
  if (!row) return null;
  return { ...row, rank: membership.tier.sortOrder, tierCode: membership.tier.code };
}

/** A whole number of [value] (the perk's `int` value), or null. */
export function vipIntValue(value: Prisma.JsonValue | null): number | null {
  return typeof value === 'number' && Number.isSafeInteger(value) && value > 0 ? value : null;
}

/** PINNED_MESSAGE's `{count, seconds}`, or null when not set. */
export function vipPinValue(value: Prisma.JsonValue | null): { count: number; seconds: number } | null {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return null;
  const count = vipIntValue((value as Record<string, Prisma.JsonValue>).count ?? null);
  const seconds = vipIntValue((value as Record<string, Prisma.JsonValue>).seconds ?? null);
  return count === null || seconds === null ? null : { count, seconds };
}

/** SEAT_EMOJI's art pack (https URLs), empty when not set. */
export function vipArtPackValue(value: Prisma.JsonValue | null): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((x): x is string => typeof x === 'string' && x.startsWith('https://'));
}

/**
 * SQL: the tier rank (`vip_tiers.sort_order`) of [user]'s active membership when it holds the built perk [code] (its
 * tier or a lower one lists it, enabled), else NULL. [user] is a uuid expression of the surrounding statement.
 */
export function vipPerkRankSql(code: VipLivePerkCode, user: Prisma.Sql): Prisma.Sql {
  if (!VIP_BUILT_PERKS.has(code)) return Prisma.sql`NULL::int`;
  return Prisma.sql`(
    SELECT vt.sort_order FROM vip_memberships vm JOIN vip_tiers vt ON vt.id = vm.tier_id
     WHERE vm.user_id = ${user} AND vm.expires_at > now()
       AND EXISTS (SELECT 1 FROM vip_tier_perks vp JOIN vip_tiers vpt ON vpt.id = vp.tier_id
                    WHERE vp.code = ${code} AND vp.enabled AND vpt.sort_order <= vt.sort_order))`;
}
