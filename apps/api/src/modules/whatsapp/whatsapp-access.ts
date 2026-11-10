import type { Prisma } from '../../generated/prisma/client.js';
import {
  effectiveWhatsAppLevel,
  isPanelRole,
  PANEL_ROLES,
  whatsAppLevelRank,
  type PanelRole,
  type WhatsAppLevel,
} from '../admin-panel/admin-permissions.js';

/**
 * v1.120-social (D360, CONVENTIONS §10.155): the WhatsApp level of each staff member, read from `wa_staff_access` (no
 * row: the default of the roles). Plain functions over a Prisma client so the panel's guards, the team page and the
 * inbox share one rule.
 */
type Db = Pick<Prisma.TransactionClient, 'waStaffAccess' | 'user'>;

/** The level SET for one person (null: none set — the roles' default applies). */
export async function setWhatsAppLevelOf(db: Db, userId: string): Promise<WhatsAppLevel | null> {
  const row = await db.waStaffAccess.findUnique({ where: { userId }, select: { level: true } });
  return row?.level ?? null;
}

export interface WaStaffLevel {
  readonly userId: string;
  readonly roles: PanelRole[];
  readonly level: WhatsAppLevel;
}

/**
 * Every ACTIVE staff account (users.role ADMIN with a panel role — the panel's `rolesOf`) whose effective WhatsApp
 * level is at least `min`, with that level. `onlyIds` narrows to some accounts.
 */
export async function staffAtLevel(
  db: Db,
  min: WhatsAppLevel,
  onlyIds?: readonly string[],
): Promise<WaStaffLevel[]> {
  const users = await db.user.findMany({
    where: {
      role: 'ADMIN',
      status: 'ACTIVE',
      ...(onlyIds ? { id: { in: [...onlyIds] } } : {}),
      adminPermissions: { some: { permission: { in: [...PANEL_ROLES] } } },
    },
    orderBy: { createdAt: 'asc' },
    select: { id: true, adminPermissions: { select: { permission: true } } },
  });
  if (users.length === 0) return [];
  const set = new Map(
    (
      await db.waStaffAccess.findMany({
        where: { userId: { in: users.map((u) => u.id) } },
        select: { userId: true, level: true },
      })
    ).map((r) => [r.userId, r.level]),
  );
  const want = whatsAppLevelRank(min);
  const out: WaStaffLevel[] = [];
  for (const u of users) {
    const roles = u.adminPermissions.map((p) => p.permission as string).filter(isPanelRole);
    const level = effectiveWhatsAppLevel(roles, set.get(u.id) ?? null);
    if (whatsAppLevelRank(level) >= want) out.push({ userId: u.id, roles, level });
  }
  return out;
}

/** Whether `userId` is an ACTIVE staff account at `min` or above now. */
export async function isAtWhatsAppLevel(db: Db, userId: string, min: WhatsAppLevel): Promise<boolean> {
  return (await staffAtLevel(db, min, [userId])).length > 0;
}

/**
 * D360 (§10.155.4): the person can no longer answer (their level went below REPLY) — every conversation still
 * assigned to them goes back to the unassigned queue, open or closed, each with a RELEASE in its history by `actorId`
 * (the one who changed the level). Inside the caller's transaction, conversations locked in id order. Returns the ids.
 */
export async function releaseAssignedIn(
  tx: Prisma.TransactionClient,
  userId: string,
  actorId: string | null,
  now: Date,
): Promise<string[]> {
  const rows = await tx.$queryRaw<{ id: string }[]>`
    SELECT id::text AS id FROM wa_conversations
    WHERE assigned_to_id = ${userId}::uuid AND purge_after IS NULL
    ORDER BY id FOR UPDATE`;
  if (rows.length === 0) return [];
  const ids = rows.map((r) => r.id);
  await tx.waConversation.updateMany({
    where: { id: { in: ids }, assignedToId: userId },
    data: { assignedToId: null, assignedAt: null, updatedAt: now },
  });
  await tx.waAssignment.createMany({
    data: ids.map((conversationId) => ({
      conversationId,
      action: 'RELEASE' as const,
      fromUserId: userId,
      toUserId: null,
      actorId,
      createdAt: now,
    })),
  });
  return ids;
}
