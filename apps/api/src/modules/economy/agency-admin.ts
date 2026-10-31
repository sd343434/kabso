import { auditBy, CLI_VIA, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import type { Prisma, PrismaClient } from '../../generated/prisma/client.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { addMonths, dateValue, monthKey, newInviteCode, normalizeInviteCode } from './economy-math.js';
import { createAgencyIn, HostAgentError } from './host-agents.js';

type Tx = Prisma.TransactionClient;

/**
 * The agency rules of `economy-admin agency-create` and `complaint-resolve` (v1.52/v1.58-social, D179/D189), moved
 * out of the CLI so the admin panel runs them unchanged (v1.65-social, D197, CONVENTIONS §10.60.2; the D191 rule
 * «one rule for the CLI and the panel», §10.54.4). A refusal is an {@link HostAgentError} with the rule's sentence
 * (the CLI prints it and exits 1; the panel answers 409 ADMIN_ACTION_REFUSED). Every change writes its audit row in
 * the same transaction; only `via` and the actor differ between the CLI and the panel.
 */

/** The agency with this invite code, or a refusal. */
export async function agencyByInviteCodeIn(
  db: Pick<Tx, 'agency'>,
  raw: string,
): Promise<{ id: string; ownerUserId: string; inviteCode: string }> {
  const code = normalizeInviteCode(raw);
  const agency = code === null ? null : await db.agency.findUnique({ where: { inviteCode: code } });
  if (!agency) throw new HostAgentError(`No agency with invite code ${raw}.`);
  return agency;
}

/**
 * `agency-create`: an ACTIVE account without an agency and not a host of one gets a NEW agency (its grace: evaluated
 * from the month start two months after its creation month) and, in the same transaction, its host-agent code.
 */
export async function createAgencyByAdmin(
  prisma: PrismaClient,
  input: { ownerUserId: string; parentInviteCode: string | null; reason?: string | null },
  rules: { timeZone: string; specialGraceDays: number },
  by: AdminVia = CLI_VIA,
  now: Date = new Date(),
): Promise<{ agencyId: string; inviteCode: string; hostCode: string; evaluateFrom: string }> {
  const owner = await prisma.user.findUnique({
    where: { id: input.ownerUserId },
    select: { id: true, status: true, deletedAt: true },
  });
  if (!owner || owner.deletedAt !== null) throw new HostAgentError('No such account.');
  if (owner.status !== 'ACTIVE') throw new HostAgentError('The account is not ACTIVE.');
  const existing = await prisma.agency.findUnique({
    where: { ownerUserId: owner.id },
    select: { status: true },
  });
  if (existing?.status === 'CLOSED') {
    // v1.70-social (D206): the owner's closed agency opens again (`agency-reopen`), never a second row.
    throw new HostAgentError('The account has a closed agency; reopen it (agency-reopen) instead.');
  }
  if (existing) throw new HostAgentError('The account already has an agency.');
  if ((await prisma.agencyHost.count({ where: { hostUserId: owner.id, status: 'ACTIVE' } })) > 0) {
    throw new HostAgentError(
      'The account is a host of an agency; the host must leave it (or an admin release it) first.',
    );
  }
  const parent =
    input.parentInviteCode === null ? null : await agencyByInviteCodeIn(prisma, input.parentInviteCode);
  const evaluateFrom = addMonths(monthKey(now, rules.timeZone), 2);
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = newInviteCode();
    if ((await prisma.agency.count({ where: { inviteCode: code } })) > 0) continue;
    const created = await prisma.$transaction(async (tx) => {
      const row = await createAgencyIn(
        tx,
        {
          ownerUserId: owner.id,
          inviteCode: code,
          parentAgencyId: parent?.id ?? null,
          evaluateFrom: dateValue(evaluateFrom),
        },
        now,
        rules.specialGraceDays,
      );
      await tx.auditLog.create({
        data: {
          ...auditBy(by),
          action: AuditAction.AGENCY_CREATE,
          targetType: 'agency',
          targetId: row.agencyId,
          metadata: {
            owner: owner.id,
            inviteCode: code,
            parent: parent?.id ?? null,
            evaluateFrom,
            hostCode: row.hostCode,
            ...(input.reason ? { reason: input.reason } : {}),
            via: by.via,
          },
        },
      });
      return row;
    });
    return { agencyId: created.agencyId, inviteCode: code, hostCode: created.hostCode, evaluateFrom };
  }
  throw new HostAgentError('Could not find a free invite code; try again.');
}

export type ComplaintDecision = 'release' | 'keep' | 'move';

/**
 * `complaint-resolve`: an OPEN complaint of a host about their agency — `release` (the host leaves the agency),
 * `keep` (rejected: the host stays) or `move` (to the agency `toInviteCode`). Returns the host (the caller syncs
 * the host's active-host frame after the commit, D186).
 */
export async function resolveComplaintIn(
  tx: Tx,
  complaintId: string,
  decision: ComplaintDecision,
  toInviteCode: string | null,
  note: string | null,
  now: Date,
  by: AdminVia = CLI_VIA,
): Promise<{ hostUserId: string; newLink: string | null }> {
  if (decision === 'move' && toInviteCode === null) throw new HostAgentError('move needs the target agency.');
  const target = decision === 'move' ? await agencyByInviteCodeIn(tx, toInviteCode!) : null;
  const [c] = await tx.$queryRaw<
    { id: string; status: string; agency_host_id: string; host_user_id: string }[]
  >`
    SELECT id::text AS id, status::text AS status, agency_host_id::text AS agency_host_id,
           host_user_id::text AS host_user_id
      FROM agency_complaints WHERE id = ${complaintId}::uuid FOR UPDATE`;
  if (!c) throw new HostAgentError(`No complaint ${complaintId}.`);
  if (c.status !== 'OPEN') throw new HostAgentError(`The complaint is ${c.status}; nothing changed.`);
  const link = await tx.agencyHost.findUnique({ where: { id: c.agency_host_id } });
  if (target && target.ownerUserId === c.host_user_id) {
    throw new HostAgentError('A host cannot be moved to their own agency.');
  }
  if (target && link && target.id === link.agencyId)
    throw new HostAgentError('The host is already in that agency.');
  if (decision !== 'keep' && link?.status === 'ACTIVE') {
    await tx.agencyHost.update({
      where: { id: link.id },
      data: { status: decision === 'move' ? 'MOVED' : 'RELEASED', endedAt: now },
    });
  }
  let newLink: string | null = null;
  if (target) {
    const rank = await tx.agency.findUnique({ where: { id: target.id }, select: { rank: true } });
    newLink = uuidv7();
    await tx.agencyHost.create({
      data: {
        id: newLink,
        agencyId: target.id,
        hostUserId: c.host_user_id,
        commissionEligible: rank?.rank !== 'LAPSED',
        activatedAt: now,
      },
    });
  }
  await tx.agencyComplaint.update({
    where: { id: complaintId },
    data: {
      status: decision === 'keep' ? 'REJECTED' : 'RESOLVED',
      resolution: decision === 'release' ? 'RELEASED' : decision === 'move' ? 'MOVED' : 'KEPT',
      note,
      resolvedAt: now,
    },
  });
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.AGENCY_COMPLAINT_RESOLVE,
      targetType: 'agency_complaint',
      targetId: complaintId,
      metadata: {
        action: decision,
        link: link?.id ?? null,
        to: target?.id ?? null,
        newLink,
        note,
        before: 'OPEN',
        after: decision === 'keep' ? 'REJECTED' : 'RESOLVED',
        via: by.via,
      },
    },
  });
  return { hostUserId: c.host_user_id, newLink };
}
