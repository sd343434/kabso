import { auditBy, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { revokeCreatorIn } from '../creator/creator-membership.js';
import { closeAgencyIn } from './agency-probation.js';
import { forfeitAgencyCommissionIn, taskCherryLockIn } from './cherry-ledger.js';

/**
 * v1.82-live (D295, owner 2026-11-06, CONVENTIONS §10.108): «حظر الوكالة — تفعيل صانع محتوى وهمي». The OWNER (the
 * authenticator code again and a reason) bans an agency whose owner activated someone as a content creator who was not
 * one. In one transaction:
 *  (a) the agency is closed with the reason `BANNED` (the existing closing: its ACTIVE members are released, the owner
 *      is told and loses the host-agent perks) and can never be reopened (the owner's own «افتح وكالة» and the team's
 *      reopening refuse it);
 *  (b) the owner LOSES the agency's earnings still in the balance: the agency and parent commission this agency paid
 *      them (net of reversals), capped at what the balance holds beyond the locked task cherries, is debited as one
 *      `AGENCY_FORFEIT` row. Money already withdrawn (or held for a pending withdrawal) is NOT clawed back and the
 *      balance never goes below 0; the hosts' and creators' own earnings are NOT touched. Nothing is pending: an agency
 *      commission is credited with each gift (D179), and a closed agency earns none afterwards (`creditGiftCherriesIn`
 *      reads OPEN agencies only), so no sweeper credits it again;
 *  (c) ONLY the creators the OWNER ticked as fake (owner 2026-11-06: `fakeCreatorUserIds`, none pre-selected; an empty
 *      list is valid) are revoked with the hosting permission they gave — the agency's other creators stay creators and
 *      are released from the closed agency like its hosts. The ticked ids must be active creators this agency
 *      activated (else refused, nothing changed); the caller ends the revoked creators' running lives after the commit.
 * One `agency_bans` row per agency: a second ban changes nothing and answers with the first one's figures. Audited
 * `agency.ban` with the creators revoked as fake (`fakeCreators`, their `applications`) and those kept.
 */

type Tx = Prisma.TransactionClient;

/** A refused ban (the panel answers 409 ADMIN_ACTION_REFUSED; nothing changed). */
export class AgencyBanError extends Error {}

/** The agency's commission to its owner (agency + parent, net of reversals), cherries. */
export async function agencyCommissionOwedIn(db: Pick<Tx, '$queryRaw'>, agencyId: string): Promise<bigint> {
  const [row] = await db.$queryRaw<{ total: bigint }[]>`
    SELECT (COALESCE((SELECT sum(commission) FROM agency_earnings
                       WHERE agency_id = ${agencyId}::uuid AND reversed_at IS NULL), 0)
          + COALESCE((SELECT sum(parent_commission) FROM agency_earnings
                       WHERE parent_agency_id = ${agencyId}::uuid AND reversed_at IS NULL), 0))::bigint AS total`;
  return row?.total ?? 0n;
}

export interface AgencyBanFigures {
  /** The agency's commission to its owner (net of reversals). */
  readonly commissionCherries: bigint;
  /** The owner's balance now, the locked task cherries and a pending withdrawal's held cherries. */
  readonly balanceCherries: bigint;
  readonly lockedCherries: bigint;
  readonly heldCherries: bigint;
  /** What the ban forfeits: min(commission, max(0, balance − locked)). */
  readonly forfeitCherries: bigint;
}

/** The figures a ban would use now (the panel's confirmation shows them before the OWNER confirms). */
export async function agencyBanFiguresIn(
  db: Tx,
  agencyId: string,
  ownerUserId: string,
  rules: { taskCherriesUnlockGiftMinor: number; rateCherries: number; rateMinor: number },
): Promise<AgencyBanFigures> {
  const [commission, wallet, lock, held] = await Promise.all([
    agencyCommissionOwedIn(db, agencyId),
    db.cherryWallet.findUnique({ where: { userId: ownerUserId }, select: { cherries: true } }),
    taskCherryLockIn(db, ownerUserId, rules),
    db.cherryWithdrawal.findFirst({
      where: { userId: ownerUserId, status: 'PENDING' },
      select: { cherries: true },
    }),
  ]);
  const balance = wallet?.cherries ?? 0n;
  const free = balance - lock.lockedCherries;
  const available = free > 0n ? free : 0n;
  return {
    commissionCherries: commission,
    balanceCherries: balance,
    lockedCherries: lock.lockedCherries,
    heldCherries: held?.cherries ?? 0n,
    forfeitCherries: commission < available ? commission : available,
  };
}

/** The creator memberships an agency activated that are still active. */
export async function agencyCreatorActivationsIn(
  db: Pick<Tx, 'creatorApplication'>,
  agencyId: string,
): Promise<{ applicationId: string; userId: string; activatedAt: Date }[]> {
  const rows = await db.creatorApplication.findMany({
    where: { agencyId, source: 'AGENCY', status: 'APPROVED', member: { isNot: null } },
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    select: { id: true, userId: true, createdAt: true },
  });
  return rows.map((r) => ({ applicationId: r.id, userId: r.userId, activatedAt: r.createdAt }));
}

export interface AgencyBanResult {
  /** False: the agency was banned before (nothing changed; the first ban's figures). */
  readonly banned: boolean;
  readonly commissionCherries: bigint;
  readonly forfeitedCherries: bigint;
  readonly revokedCreators: string[];
  readonly releasedHosts: string[];
}

export async function banAgencyIn(
  tx: Tx,
  agencyId: string,
  input: { reason: string; fakeCreatorUserIds: readonly string[] },
  now: Date,
  rules: { taskCherriesUnlockGiftMinor: number; rateCherries: number; rateMinor: number },
  specialGraceDays: number,
  by: AdminVia,
): Promise<AgencyBanResult> {
  const [a] = await tx.$queryRaw<{ owner: string; status: string }[]>`
    SELECT owner_user_id::text AS owner, status::text AS status FROM agencies WHERE id = ${agencyId}::uuid FOR UPDATE`;
  if (!a) throw new AgencyBanError('No such agency.');
  const before = await tx.agencyBan.findUnique({ where: { agencyId } });
  if (before) {
    return {
      banned: false,
      commissionCherries: before.commissionCherries,
      forfeitedCherries: before.forfeitedCherries,
      revokedCreators: before.creatorUserIds,
      releasedHosts: [],
    };
  }
  // The owner's wallet row first (the ledger's lock order: wallets after agency rows), so the balance read is final.
  await tx.$queryRaw`SELECT 1 FROM cherry_wallets WHERE user_id = ${a.owner}::uuid FOR UPDATE`;
  const figures = await agencyBanFiguresIn(tx, agencyId, a.owner, rules);

  // (c) Only the creators the OWNER ticked as fake (owner 2026-11-06); the others stay creators.
  const activations = await agencyCreatorActivationsIn(tx, agencyId);
  const named = new Set(input.fakeCreatorUserIds.map((id) => id.toLowerCase()));
  const own = new Set(activations.map((x) => x.userId));
  const foreign = [...named].filter((id) => !own.has(id));
  if (foreign.length > 0)
    throw new AgencyBanError('A ticked creator is not an active creator this agency activated.');
  const concerned = activations.filter((x) => named.has(x.userId));
  const kept = activations.filter((x) => !named.has(x.userId)).map((x) => x.userId);
  const revoked: string[] = [];
  for (const c of concerned) {
    const out = await revokeCreatorIn(tx, c.userId, input.reason, now, by, { agencyBan: agencyId });
    if (out) revoked.push(c.userId);
  }

  // (a) Closed BANNED (or, closed already, marked BANNED).
  let releasedHosts: string[] = [];
  if (a.status === 'OPEN') {
    const closed = await closeAgencyIn(
      tx,
      agencyId,
      { reason: 'BANNED', note: input.reason, activated: null, required: null },
      now,
      specialGraceDays,
      by,
    );
    releasedHosts = closed?.releasedHosts ?? [];
  } else {
    await tx.agency.update({
      where: { id: agencyId },
      data: { closeReason: 'BANNED', closeNote: input.reason, updatedAt: now },
    });
  }

  // (b) The forfeit (exact; once per agency through the ledger's reference and the ban row).
  await forfeitAgencyCommissionIn(tx, a.owner, figures.forfeitCherries, agencyId, now);
  await tx.agencyBan.create({
    data: {
      agencyId,
      ownerUserId: a.owner,
      bannedById: by.actorUserId,
      reason: input.reason,
      commissionCherries: figures.commissionCherries,
      forfeitedCherries: figures.forfeitCherries,
      creatorUserIds: revoked,
      createdAt: now,
    },
  });
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.AGENCY_BAN,
      targetType: 'agency',
      targetId: agencyId,
      metadata: {
        owner: a.owner,
        reason: input.reason,
        commissionCherries: figures.commissionCherries.toString(),
        forfeitedCherries: figures.forfeitCherries.toString(),
        balanceBefore: figures.balanceCherries.toString(),
        lockedCherries: figures.lockedCherries.toString(),
        heldCherries: figures.heldCherries.toString(),
        // The creators revoked as FAKE (ticked by the OWNER) and their activations; the agency's other creators kept.
        fakeCreators: revoked,
        applications: concerned.filter((c) => revoked.includes(c.userId)).map((c) => c.applicationId),
        keptCreators: kept,
        releasedHosts: releasedHosts.length,
        before: a.status,
        after: 'BANNED',
        via: by.via,
      },
    },
  });
  return {
    banned: true,
    commissionCherries: figures.commissionCherries,
    forfeitedCherries: figures.forfeitCherries,
    revokedCreators: revoked,
    releasedHosts,
  };
}
