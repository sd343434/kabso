import { randomUUID } from 'node:crypto';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Prisma } from '../../generated/prisma/client.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { VIP_BUILT_PERKS } from './vip-rules.js';

/**
 * v1.133-social (D380, owner 2026-11-11, CONVENTIONS §10.170): the VIP privacy perks — who holds them now and whether
 * the holder's switch is on. A perk works only for a member whose effective perks include it (D258 inheritance: their
 * tier's or a lower tier's enabled row) while the membership is active, and only while the catalogue says it is built.
 *
 * Each perk with a switch keeps its holder's choice in `privacy_settings` (kept when the membership ends, so a renewal
 * finds it again); the defaults (no row, or a row from before D380) are below. ANONYMOUS_GIFT has no switch: it is
 * chosen per send.
 */
export const VIP_PRIVACY_SWITCHES = {
  /** «زيارة خفية»: on by default — a visit is a private act; the perk works as soon as it is bought. */
  HIDDEN_VISIT: { column: 'vip_hidden_visit', field: 'hiddenVisit', default: true },
  /** «اسم مخفي في التصنيفات»: off by default — VIP is bought to be seen; the member chooses to hide. */
  RANKING_ANONYMOUS: { column: 'vip_ranking_anonymous', field: 'rankingAnonymous', default: false },
  /** «حماية من طرد وكتم المشرف العادي»: on by default — protection takes nothing visible from the member. */
  KICK_MUTE_SHIELD: { column: 'vip_kick_mute_shield', field: 'kickMuteShield', default: true },
} as const;
export type VipPrivacySwitch = keyof typeof VIP_PRIVACY_SWITCHES;
export type VipPrivacyPerk = VipPrivacySwitch | 'ANONYMOUS_GIFT';

/** The `PrivacySettings` field of each switch. */
export type VipPrivacyField = (typeof VIP_PRIVACY_SWITCHES)[VipPrivacySwitch]['field'];

export const VIP_PRIVACY_SWITCH_CODES = Object.keys(VIP_PRIVACY_SWITCHES) as VipPrivacySwitch[];

type Db = Pick<Prisma.TransactionClient, '$queryRaw'>;

/**
 * The ids among [userIds] whose VIP holds [code] at [now] (active membership; the perk enabled on their tier or a lower
 * one; built) and — for a perk with a switch — whose switch is on. One query whatever the number of ids.
 */
export async function vipPrivacyOnIn(
  db: Db,
  userIds: readonly string[],
  code: VipPrivacyPerk,
  now: Date,
): Promise<Set<string>> {
  const ids = [...new Set(userIds)];
  if (ids.length === 0 || !VIP_BUILT_PERKS.has(code)) return new Set();
  const sw = code === 'ANONYMOUS_GIFT' ? null : VIP_PRIVACY_SWITCHES[code];
  const switchSql = sw
    ? Prisma.sql`AND COALESCE((SELECT ps.${Prisma.raw(sw.column)} FROM privacy_settings ps
                                  WHERE ps.user_id = m.user_id), ${sw.default})`
    : Prisma.empty;
  const rows = await db.$queryRaw<{ user_id: string }[]>`
    SELECT m.user_id::text AS user_id
      FROM vip_memberships m
      JOIN vip_tiers t ON t.id = m.tier_id
     WHERE m.user_id = ANY(${ids}::uuid[])
       AND m.expires_at > ${now}::timestamptz
       AND EXISTS (SELECT 1 FROM vip_tier_perks p JOIN vip_tiers pt ON pt.id = p.tier_id
                    WHERE p.code = ${code} AND p.enabled AND pt.sort_order <= t.sort_order)
       ${switchSql}`;
  return new Set(rows.map((r) => r.user_id));
}

/** {@link vipPrivacyOnIn} for one person. */
export async function vipPrivacyOn(
  db: Db,
  userId: string,
  code: VipPrivacyPerk,
  now: Date,
): Promise<boolean> {
  return (await vipPrivacyOnIn(db, [userId], code, now)).has(userId);
}

/**
 * The anonymous person «مجهول» shown instead of a member (RANKING_ANONYMOUS on a board, the sender of an ANONYMOUS_GIFT).
 * It carries nothing of the member: a fresh random id on every answer (never linkable across lists or reads), a
 * username no account can take (regular and premium usernames have no dot), the Arabic name (the apps localize it from
 * `anonymous`; an older app shows the name as it is), no picture (the generic avatar) and none of the badges.
 */
export const ANONYMOUS_USERNAME = 'kabso.anonymous';
export const ANONYMOUS_DISPLAY_NAME = 'مجهول';

export function anonymousUserSummary(): UserSummaryDto {
  return {
    id: randomUUID(),
    username: ANONYMOUS_USERNAME,
    displayName: ANONYMOUS_DISPLAY_NAME,
    avatarUrl: null,
    anonymous: true,
  };
}

/**
 * [user] as [viewerId] sees it on a public board: «مجهول» when the person is in [anonymous] (RANKING_ANONYMOUS on) and the
 * viewer is neither the person nor one of [alsoReal] (e.g. the host of their own room's list); else as it is.
 */
export function rankedUser(
  user: UserSummaryDto,
  anonymous: ReadonlySet<string>,
  viewerId: string | null,
  alsoReal: readonly string[] = [],
): UserSummaryDto {
  if (!anonymous.has(user.id)) return user;
  if (viewerId !== null && (viewerId === user.id || alsoReal.includes(viewerId))) return user;
  return anonymousUserSummary();
}

/** D380 (§10.170.4): what a room moderator tried on a KICK_MUTE_SHIELD holder. */
export type VipShieldAction = 'KICK' | 'CHAT_MUTE' | 'SEAT_MUTE' | 'SEAT_REMOVE';

/**
 * v1.133-social (D380, §10.170.4) «حماية من طرد وكتم المشرف العادي»: a room MODERATOR (appointed by the host) may not
 * kick, chat-mute, seat-mute or take off a seat a member holding KICK_MUTE_SHIELD with the switch on — 403
 * `VIP_PROTECTED`, audited `vip.shield.refused` (written on its own connection, so it stays when the caller's
 * transaction rolls back). The host and the Kabso Team (their own staff tools) are never refused; reports and automated
 * safety are untouched. Call only for a moderator's action.
 */
export async function refuseVipShielded(
  db: Pick<Prisma.TransactionClient, '$queryRaw' | 'auditLog'>,
  input: { actorId: string; targetId: string; roomId: string; action: VipShieldAction },
  now: Date,
): Promise<void> {
  if (!(await vipPrivacyOn(db, input.targetId, 'KICK_MUTE_SHIELD', now))) return;
  try {
    await db.auditLog.create({
      data: {
        action: AuditAction.VIP_SHIELD_REFUSED,
        actorUserId: input.actorId,
        targetType: 'user',
        targetId: input.targetId,
        metadata: { roomId: input.roomId, action: input.action },
      },
    });
  } catch {
    // The refusal stands even when its audit row cannot be written.
  }
  throw new AppException(ErrorCode.VIP_PROTECTED, undefined, [{ field: 'username', issue: 'vip_shield' }]);
}

/**
 * D380 (§10.170.5): the anonymous gifts a person may send — at most this many anonymous sends an hour (a burst limit on
 * top of the gifts' own limits; anti-harassment).
 */
export const ANONYMOUS_GIFT_RATE = { max: 60, windowSeconds: 3600 } as const;
