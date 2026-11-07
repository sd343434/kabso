import { auditBy, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import type { LiveHostSource, Prisma } from '../../generated/prisma/client.js';

/**
 * v1.82-live (D295, owner, CONVENTIONS §10.108): content creators go live «صانع محتوى».
 *
 * - A creator-programme membership (`creator_members`) GRANTS the hosting permission: a `live_hosts` row with source
 *   `CREATOR`, written with the membership and removed when it ends — so `Me.canHost` is true while a member, with no
 *   host application and no agency.
 * - Host and creator are mutually exclusive: a person never holds both a membership and a hosting permission of
 *   another source (`ADMIN`, `AGENCY`, `IDENTITY`). Every path refuses it (the creator application, the host
 *   application, the admin grant, the agency activation) and the trigger `kabso_creator_host_exclusive` backs it in the
 *   database.
 *
 * Shared by the API, the CLI and the tests (no Nest dependencies). Every change writes its audit rows in the caller's
 * transaction.
 */

type Tx = Prisma.TransactionClient;
type Db = Pick<Tx, 'creatorMember' | 'liveHost'>;

/** Why a creator activation or a host grant was refused (`details[0].issue` in the API). */
export type CreatorHostConflict = 'HOST' | 'CREATOR';

/** A refused creator / host change (the caller maps it to its own error code). */
export class CreatorHostConflictError extends Error {
  constructor(readonly issue: CreatorHostConflict) {
    super(
      issue === 'HOST'
        ? 'This person is a host; a host cannot also be a content creator.'
        : 'This person is a content creator; a creator cannot also be a host.',
    );
  }
}

/** Whether `userId` is a creator-programme member now. */
export async function isCreatorIn(db: Pick<Tx, 'creatorMember'>, userId: string): Promise<boolean> {
  return (await db.creatorMember.count({ where: { userId } })) > 0;
}

/** The person's hosting permission that makes them a HOST (any source but `CREATOR`), else null. */
export async function hostSourceIn(db: Pick<Tx, 'liveHost'>, userId: string): Promise<LiveHostSource | null> {
  const row = await db.liveHost.findUnique({ where: { userId }, select: { source: true } });
  return row && row.source !== 'CREATOR' ? row.source : null;
}

/** What the person is for the D295 exclusivity: a host, a creator or neither. */
export async function hostKindIn(db: Db, userId: string): Promise<'HOST' | 'CREATOR' | null> {
  if (await isCreatorIn(db, userId)) return 'CREATOR';
  return (await hostSourceIn(db, userId)) !== null ? 'HOST' : null;
}

/**
 * Makes `userId` a creator member from `applicationId` and gives the hosting permission `CREATOR` (when they have
 * none yet). Refuses a host ({@link CreatorHostConflictError} `HOST`). Idempotent: an existing membership is kept.
 * Audited `live.host.grant` (source CREATOR) when the permission is written.
 */
export async function activateCreatorIn(
  tx: Tx,
  input: { userId: string; applicationId: string; now: Date; by: AdminVia; via?: string; agencyId?: string },
): Promise<{ created: boolean }> {
  // The person's rows in a fixed order (live_hosts then creator_members), so two activations queue.
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`creator-host:${input.userId}`}, 0))`;
  if ((await hostSourceIn(tx, input.userId)) !== null) throw new CreatorHostConflictError('HOST');
  const member = await tx.creatorMember.createMany({
    data: [{ userId: input.userId, applicationId: input.applicationId, activatedAt: input.now }],
    skipDuplicates: true,
  });
  // CP-016 G: the room number is drawn by the column default; `skipDuplicates` would also skip a (rare) clash on it, so
  // draw again while the permission is still missing (as `grantHost`).
  let granted = 0;
  for (let attempt = 0; attempt < 5 && granted === 0; attempt += 1) {
    granted = (
      await tx.liveHost.createMany({
        data: [
          {
            userId: input.userId,
            source: 'CREATOR',
            grantedById: input.by.actorUserId,
            grantedAt: input.now,
          },
        ],
        skipDuplicates: true,
      })
    ).count;
    if (granted === 0 && (await tx.liveHost.count({ where: { userId: input.userId } })) > 0) break;
  }
  if (granted > 0) {
    await tx.auditLog.create({
      data: {
        ...auditBy(input.by),
        action: AuditAction.LIVE_HOST_GRANT,
        targetType: 'user',
        targetId: input.userId,
        metadata: {
          source: 'CREATOR',
          application: input.applicationId,
          ...(input.agencyId ? { agency: input.agencyId } : {}),
          via: input.via ?? input.by.via,
        },
      },
    });
  }
  return { created: member.count > 0 };
}

/**
 * Ends `userId`'s creator membership (the team in the panel, or an agency ban): the membership goes, its application
 * becomes REVOKED (kept, with the reason), and the hosting permission it gave (`live_hosts` CREATOR) is removed. The
 * caller ends the person's running live after the commit. Null when the person is not a member (nothing changed).
 * Audited `creator.member.revoke` (and `live.host.revoke` when the permission went).
 */
export async function revokeCreatorIn(
  tx: Tx,
  userId: string,
  reason: string,
  now: Date,
  by: AdminVia,
  extra: { agencyBan?: string } = {},
): Promise<{ applicationId: string; hostingRemoved: boolean; agencyId: string | null } | null> {
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`creator-host:${userId}`}, 0))`;
  const member = await tx.creatorMember.findUnique({
    where: { userId },
    select: { applicationId: true, application: { select: { agencyId: true, source: true } } },
  });
  if (!member) return null;
  await tx.creatorMember.delete({ where: { userId } });
  await tx.creatorApplication.update({
    where: { id: member.applicationId },
    data: { status: 'REVOKED', revokedAt: now, revokedById: by.actorUserId, revokeReason: reason },
  });
  const removed = await tx.liveHost.deleteMany({ where: { userId, source: 'CREATOR' } });
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.CREATOR_MEMBER_REVOKE,
      targetType: 'user',
      targetId: userId,
      metadata: {
        application: member.applicationId,
        source: member.application.source,
        agency: member.application.agencyId,
        reason,
        hostingRemoved: removed.count > 0,
        ...(extra.agencyBan ? { agencyBan: extra.agencyBan } : {}),
        before: 'MEMBER',
        after: 'REVOKED',
        via: by.via,
      },
    },
  });
  if (removed.count > 0) {
    await tx.auditLog.create({
      data: {
        ...auditBy(by),
        action: AuditAction.LIVE_HOST_REVOKE,
        targetType: 'user',
        targetId: userId,
        metadata: { source: 'CREATOR', reason, via: by.via },
      },
    });
  }
  return {
    applicationId: member.applicationId,
    hostingRemoved: removed.count > 0,
    agencyId: member.application.agencyId,
  };
}
