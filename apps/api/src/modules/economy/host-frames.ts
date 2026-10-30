import type { Prisma, PrismaClient } from '../../generated/prisma/client.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import { HOST_FRAME_CODES, type HostFrameStyle } from '../bag/bag.catalogue.js';
import { hostActivity, type ActivityRules } from './agency-ranks.js';

/**
 * The active-host frame «إطار المضيف» (v1.55-social, D186, CONVENTIONS §10.49, owner 2026-10-30). An ACTIVE
 * agency host who passes D179's active-host test ({@link hostActivity}: ≥ 7 live days and ≥ 10 live hours
 * in the last 30 days, the account ACTIVE) owns one bag frame, source `HOST_ACTIVE`, not transferable, no
 * expiry: blue for a male host, pink for a female one, the style the host chose otherwise (no gender, or
 * «أفضّل عدم الذكر»; nothing until they choose). The host wears or removes it in the bag like any frame.
 * When the host is no longer active the frame is taken back (a worn one leaves nothing worn); when they
 * are active again it is given again (not worn). A change of gender or choice swaps it, keeping it worn.
 *
 * No Nest dependencies: the agency sweeper and `economy-admin agency-evaluate` sync every host, the gender
 * edit and the choice sync one user inside their own transaction.
 */

type Tx = Prisma.TransactionClient;

/** Where the style comes from: the gender (male / female) or the host's choice. */
export type HostFrameStyleFrom = 'GENDER' | 'CHOICE';

/** The style that applies for `gender` and the stored `choice` (null: none yet). */
export function hostFrameStyle(
  gender: string | null,
  choice: string | null,
): { style: HostFrameStyle | null; from: HostFrameStyleFrom | null } {
  if (gender === 'MALE') return { style: 'BLUE', from: 'GENDER' };
  if (gender === 'FEMALE') return { style: 'PINK', from: 'GENDER' };
  if (choice === 'BLUE' || choice === 'PINK') return { style: choice, from: 'CHOICE' };
  return { style: null, from: null };
}

/** Whether the host picks the style (no gender, or UNDISCLOSED). */
export function canChooseHostFrame(gender: string | null): boolean {
  return gender !== 'MALE' && gender !== 'FEMALE';
}

/** The frame the user should own: their style's while active, else none. */
export function desiredHostFrame(
  active: boolean,
  gender: string | null,
  choice: string | null,
): string | null {
  const { style } = hostFrameStyle(gender, choice);
  return active && style !== null ? HOST_FRAME_CODES[style] : null;
}

/** What {@link applyHostFrameIn} changed. */
export type HostFrameChange =
  | { readonly kind: 'granted'; readonly userId: string; readonly code: string }
  | { readonly kind: 'revoked'; readonly userId: string; readonly code: string; readonly wasWorn: boolean }
  | {
      readonly kind: 'swapped';
      readonly userId: string;
      readonly from: string;
      readonly to: string;
      readonly worn: boolean;
    };

/**
 * Makes `userId`'s HOST_ACTIVE frame match `active` and their style, inside `tx` (serialized per user):
 * gives it (not worn), takes it back (unworn with it) or swaps it for the other style (worn if the old one
 * was). Audited (`host_frame.grant` / `revoke` / `swap`, actor null: the server). Returns the change, or
 * null when nothing changed.
 */
export async function applyHostFrameIn(
  tx: Tx,
  userId: string,
  active: boolean,
): Promise<HostFrameChange | null> {
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:host-frame'), hashtext(${userId}::text))`;
  const [profile] = await tx.$queryRaw<{ gender: string | null; style: string | null }[]>`
    SELECT p.gender::text AS gender, c.style::text AS style
      FROM users u
      LEFT JOIN user_profiles p ON p.user_id = u.id
      LEFT JOIN host_frame_choices c ON c.user_id = u.id
     WHERE u.id = ${userId}::uuid`;
  if (!profile) return null;
  const desired = desiredHostFrame(active, profile.gender, profile.style);
  const owned = await tx.$queryRaw<{ item_code: string; equipped: boolean }[]>`
    SELECT item_code, equipped FROM user_bag_items
     WHERE user_id = ${userId}::uuid AND source = 'HOST_ACTIVE'::bag_item_source
     ORDER BY item_code
       FOR UPDATE`;
  const stale = owned.filter((o) => o.item_code !== desired);
  const keeps = owned.some((o) => o.item_code === desired);
  if (stale.length === 0 && (desired === null || keeps)) return null;
  const wasWorn = stale.some((o) => o.equipped);
  if (stale.length > 0) {
    await tx.$executeRaw`
      DELETE FROM user_bag_items
       WHERE user_id = ${userId}::uuid AND source = 'HOST_ACTIVE'::bag_item_source
         AND item_code = ANY(${stale.map((o) => o.item_code)}::text[])`;
  }
  let given = false;
  if (desired !== null && !keeps) {
    // A user never owns a host frame from another source (bag-admin refuses them); DO NOTHING is a guard.
    const rows = await tx.$queryRaw<{ item_code: string }[]>`
      INSERT INTO user_bag_items (user_id, item_code, category, source, equipped)
      SELECT ${userId}::uuid, i.code, i.category, 'HOST_ACTIVE'::bag_item_source, ${wasWorn}
        FROM bag_items i WHERE i.code = ${desired}
      ON CONFLICT (user_id, item_code) DO NOTHING
      RETURNING item_code`;
    given = rows.length === 1;
  }
  const old = stale[0]?.item_code ?? null;
  let change: HostFrameChange | null;
  if (old !== null && given) change = { kind: 'swapped', userId, from: old, to: desired!, worn: wasWorn };
  else if (old !== null) change = { kind: 'revoked', userId, code: old, wasWorn };
  else if (given) change = { kind: 'granted', userId, code: desired! };
  else change = null;
  if (change === null) return null;
  await tx.auditLog.create({
    data: {
      action:
        change.kind === 'granted'
          ? AuditAction.HOST_FRAME_GRANT
          : change.kind === 'revoked'
            ? AuditAction.HOST_FRAME_REVOKE
            : AuditAction.HOST_FRAME_SWAP,
      actorUserId: null,
      targetType: 'user',
      targetId: userId,
      metadata:
        change.kind === 'granted'
          ? { item: change.code }
          : change.kind === 'revoked'
            ? { item: change.code, wasWorn: change.wasWorn, active }
            : { from: change.from, to: change.to, worn: change.worn },
    },
  });
  return change;
}

/** One user's frame now, inside the caller's transaction (the gender edit, the host's choice). */
export async function syncHostFrameIn(
  tx: Tx,
  userId: string,
  now: Date,
  rules: ActivityRules,
  timeZone: string,
): Promise<HostFrameChange | null> {
  const [activity] = await hostActivity(tx, null, now, rules, timeZone, [userId]);
  return applyHostFrameIn(tx, userId, activity?.active ?? false);
}

/**
 * Every host's frame now (the agency sweeper, after the rank evaluation; `economy-admin agency-evaluate`),
 * or only `userIds`. Active hosts are D179's ({@link hostActivity}, the same live-time arithmetic as the
 * ranks); holders of a HOST_ACTIVE frame who are no longer active lose it. Users whose frame already
 * matches are not touched; each change is its own transaction.
 */
export async function syncHostFrames(
  db: PrismaClient,
  now: Date,
  rules: ActivityRules,
  timeZone: string,
  userIds: readonly string[] | null = null,
): Promise<HostFrameChange[]> {
  const activity = await hostActivity(db, null, now, rules, timeZone, userIds);
  const active = new Set(activity.filter((a) => a.active).map((a) => a.hostUserId));
  const candidates =
    userIds !== null
      ? [...new Set(userIds)]
      : [
          ...new Set([
            ...active,
            ...(
              await db.$queryRaw<{ user_id: string }[]>`
                SELECT DISTINCT user_id::text AS user_id FROM user_bag_items
                 WHERE source = 'HOST_ACTIVE'::bag_item_source`
            ).map((r) => r.user_id),
          ]),
        ];
  if (candidates.length === 0) return [];
  const rows = await db.$queryRaw<
    { id: string; gender: string | null; style: string | null; owned: string[] }[]
  >`
    SELECT u.id::text AS id, p.gender::text AS gender, c.style::text AS style,
           COALESCE((SELECT array_agg(b.item_code ORDER BY b.item_code) FROM user_bag_items b
                      WHERE b.user_id = u.id AND b.source = 'HOST_ACTIVE'::bag_item_source), '{}') AS owned
      FROM users u
      LEFT JOIN user_profiles p ON p.user_id = u.id
      LEFT JOIN host_frame_choices c ON c.user_id = u.id
     WHERE u.id = ANY(${candidates}::uuid[])
     ORDER BY u.id`;
  const changes: HostFrameChange[] = [];
  for (const r of rows) {
    const isActive = active.has(r.id);
    const desired = desiredHostFrame(isActive, r.gender, r.style);
    const matches = desired === null ? r.owned.length === 0 : r.owned.length === 1 && r.owned[0] === desired;
    if (matches) continue;
    const change = await db.$transaction((tx) => applyHostFrameIn(tx, r.id, isActive));
    if (change) changes.push(change);
  }
  return changes;
}
