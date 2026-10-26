import type { ContentLanguage } from '../../common/http/content-language.js';
import type { Prisma } from '../../generated/prisma/client.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';

/**
 * CP privileges (CP-021, owner D112, CONVENTIONS §10.24): five perks a couple unlocks with its CP
 * level (one per tier, CTO default the owner may change). The server side of each: flags on the
 * couple data (`privileges`), `LiveChatMessage.cpBubble`, the `cp` field of the live `join` data
 * message and the public gift wall. Pure helpers: the live code and the seats code call them with
 * their own Prisma client (no module import cycle).
 */

export type CpPrivilegeCode =
  'SPECIAL_FRAME' | 'CHAT_BUBBLE' | 'MIC_EFFECT' | 'ENTRANCE_EFFECT' | 'GIFT_WALL';

export interface CpPrivilegeDef {
  readonly code: CpPrivilegeCode;
  /** The CP level that unlocks it. */
  readonly unlockLevel: number;
  readonly nameAr: string;
  readonly nameEn: string;
  /** The app's icon for the privilege card. */
  readonly iconKey: string;
}

/** The catalogue, by unlock level (D112 CTO default: one privilege per CP tier). */
export const CP_PRIVILEGES: readonly CpPrivilegeDef[] = [
  {
    code: 'SPECIAL_FRAME',
    unlockLevel: 1,
    nameAr: 'إطار خاص',
    nameEn: 'Special Frame',
    iconKey: 'cp_priv_frame',
  },
  {
    code: 'CHAT_BUBBLE',
    unlockLevel: 2,
    nameAr: 'فقاعة دردشة حصرية',
    nameEn: 'Exclusive Chat Bubble',
    iconKey: 'cp_priv_bubble',
  },
  {
    code: 'MIC_EFFECT',
    unlockLevel: 3,
    nameAr: 'تأثير مايك الثنائي',
    nameEn: 'Couple Mic Effect',
    iconKey: 'cp_priv_mic',
  },
  {
    code: 'ENTRANCE_EFFECT',
    unlockLevel: 4,
    nameAr: 'تأثير الدخول',
    nameEn: 'Entrance Effect',
    iconKey: 'cp_priv_entrance',
  },
  {
    code: 'GIFT_WALL',
    unlockLevel: 5,
    nameAr: 'جدار هدايا CP',
    nameEn: 'CP Gift Wall',
    iconKey: 'cp_priv_gift_wall',
  },
];

/** The privilege codes a couple of CP `level` has unlocked, in catalogue order. */
export function cpPrivilegesFor(level: number): CpPrivilegeCode[] {
  return CP_PRIVILEGES.filter((p) => level >= p.unlockLevel).map((p) => p.code);
}

/** Whether CP `level` has unlocked `code`. */
export function cpHasPrivilege(level: number, code: CpPrivilegeCode): boolean {
  const def = CP_PRIVILEGES.find((p) => p.code === code);
  return def !== undefined && level >= def.unlockLevel;
}

/** A privilege's name in `lang`. */
export function cpPrivilegeName(def: CpPrivilegeDef, lang: ContentLanguage): string {
  return lang === 'ar' ? def.nameAr : def.nameEn;
}

type Db = Pick<Prisma.TransactionClient, '$queryRaw' | 'user'>;

/**
 * The couple `userId` shows in a live (D111 rule): an ongoing couple whose partner is ACTIVE and
 * with no block either way between the partners. Null otherwise.
 */
export async function liveCoupleOf(
  db: Db,
  userId: string,
): Promise<{ coupleId: string; partnerId: string; level: number } | null> {
  const [row] = await db.$queryRaw<{ couple_id: string; partner_id: string; level: number }[]>`
    SELECT p.couple_id::text AS couple_id, p.partner_id::text AS partner_id, c.level
      FROM cp_partners p
      JOIN cp_couples c ON c.id = p.couple_id AND c.ended_at IS NULL
      JOIN users u ON u.id = p.partner_id AND u.status = 'ACTIVE'
     WHERE p.user_id = ${userId}::uuid
       AND NOT EXISTS (
             SELECT 1 FROM user_blocks b
              WHERE (b.blocker_id = p.user_id AND b.blocked_id = p.partner_id)
                 OR (b.blocker_id = p.partner_id AND b.blocked_id = p.user_id))`;
  return row ? { coupleId: row.couple_id, partnerId: row.partner_id, level: row.level } : null;
}

/** `LiveChatMessage.cpBubble`: the sender's couple shows in lives and has CHAT_BUBBLE. */
export async function cpChatBubbleOf(db: Db, userId: string): Promise<boolean> {
  const couple = await liveCoupleOf(db, userId);
  return couple !== null && cpHasPrivilege(couple.level, 'CHAT_BUBBLE');
}

/** The `cp` field of the live `join` data message (§10.11, §10.24). */
export interface LiveJoinCpDto {
  coupleId: string;
  partner: UserSummaryDto;
  level: number;
}

/**
 * The couple a joining user brings into a live room: set when the couple shows in lives and has
 * ENTRANCE_EFFECT, so the room shows "X ❤ Y entered"; null otherwise.
 */
export async function cpEntranceOf(db: Db, userId: string): Promise<LiveJoinCpDto | null> {
  const couple = await liveCoupleOf(db, userId);
  if (!couple || !cpHasPrivilege(couple.level, 'ENTRANCE_EFFECT')) return null;
  const partner = await db.user.findUnique({ where: { id: couple.partnerId }, select: USER_SUMMARY_SELECT });
  if (!partner) return null;
  return { coupleId: couple.coupleId, partner: userSummary(partner), level: couple.level };
}
