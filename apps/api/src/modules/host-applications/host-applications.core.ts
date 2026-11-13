import { assertKycForDecisionIn, KycRequiredError } from '../kyc/kyc-core.js';
import { auditBy, CLI_VIA, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import type { LiveHostSource, Prisma } from '../../generated/prisma/client.js';
import { Notifier } from '../notifications/notifier.js';
import { attributeRecruitIn } from '../recruits/recruit-core.js';
import { recomputeBadgesIn } from '../verification/verification-badges.js';

/**
 * «كن مضيفاً مع الإدارة» (v1.73-social, D209, CONVENTIONS §10.68): the team's decisions on an application to host
 * directly with Kabso, shared by the API (the panel), the `host-admin` CLI and the tests (no Nest dependencies). Every
 * change writes its audit row in the caller's transaction.
 */

type Tx = Prisma.TransactionClient;

/** A refused admin action (the CLI prints the message and exits 1; the panel answers 409; nothing changed). */
export class HostApplicationError extends Error {
  /** v1.80-kyc (D227): `kyc_required` when the identity check is missing (the panel's `details[0].issue`). */
  constructor(
    message: string,
    readonly issue?: string,
  ) {
    super(message);
  }
}

/** Why a pending application was cancelled. */
export type HostApplicationCancelReason = 'USER' | 'AGENCY' | 'ACCOUNT';

/** The private keys of an application's two pictures (never public, `private, no-store`, §11.1). */
export function hostApplicationPictureKey(applicationId: string, which: 'photo' | 'selfie'): string {
  return `private/host-applications/${applicationId}/${which}.webp`;
}

/** Whole years between a date of birth (a calendar day) and `now` in UTC. */
export function ageOn(dateOfBirth: Date, now: Date): number {
  const y = now.getUTCFullYear() - dateOfBirth.getUTCFullYear();
  const beforeBirthday =
    now.getUTCMonth() < dateOfBirth.getUTCMonth() ||
    (now.getUTCMonth() === dateOfBirth.getUTCMonth() && now.getUTCDate() < dateOfBirth.getUTCDate());
  return beforeBirthday ? y - 1 : y;
}

/** v1.80-kyc (D227): the identity-check gate of an approval, as this module's error (CLI and panel). */
async function kycGateOrThrow(tx: Tx, userId: string, hasPictures: boolean): Promise<void> {
  try {
    await assertKycForDecisionIn(tx, userId, 'HOST_APPLICATION', hasPictures);
  } catch (err) {
    if (err instanceof KycRequiredError) throw new HostApplicationError(err.message, err.issue);
    throw err;
  }
}

async function audit(
  tx: Tx,
  action: AuditAction,
  targetId: string,
  metadata: Prisma.InputJsonObject,
  by: AdminVia,
): Promise<void> {
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action,
      targetType: 'host_application',
      targetId,
      metadata: { ...metadata, via: by.via },
    },
  });
}

interface LockedApplication {
  id: string;
  user_id: string;
  status: string;
}

async function lockApplication(tx: Tx, id: string): Promise<LockedApplication> {
  const [app] = await tx.$queryRaw<LockedApplication[]>`
    SELECT id::text AS id, user_id::text AS user_id, status::text AS status
      FROM host_applications WHERE id = ${id}::uuid FOR UPDATE`;
  if (!app) throw new HostApplicationError(`No application ${id}.`);
  if (app.status !== 'PENDING')
    throw new HostApplicationError(`The application is ${app.status}, not PENDING.`);
  return app;
}

/**
 * `host-admin approve`: a PENDING application gives the hosting permission — a `live_hosts` row with source
 * `IDENTITY` and `granted_by_id` the admin (none from the CLI). The applicant must still be ACTIVE and in no agency (a
 * join or an opening cancels the application, so this is a guard). A person who got the permission another way
 * meanwhile keeps their row and its source (`existingSource` in the audit). The applicant is notified
 * (`HOST_APPLICATION_APPROVED`, pushed by the outbox). Audited `host.application.approve` and `live.host.grant`.
 */
export async function approveHostApplicationIn(
  tx: Tx,
  applicationId: string,
  now: Date,
  by: AdminVia = CLI_VIA,
): Promise<{ userId: string; source: LiveHostSource }> {
  const app = await lockApplication(tx, applicationId);
  const user = await tx.user.findUnique({ where: { id: app.user_id }, select: { status: true } });
  if (user?.status !== 'ACTIVE') throw new HostApplicationError('The applicant account is not ACTIVE.');
  const [links, owned] = await Promise.all([
    tx.agencyHost.count({ where: { hostUserId: app.user_id, status: 'ACTIVE' } }),
    tx.agency.count({ where: { ownerUserId: app.user_id, status: 'OPEN' } }),
  ]);
  if (links > 0 || owned > 0) throw new HostApplicationError('The applicant is now in an agency.');
  // v1.82-live (D295, §10.108): a content creator cannot also be a host.
  if ((await tx.creatorMember.count({ where: { userId: app.user_id } })) > 0) {
    throw new HostApplicationError(
      'The applicant is a content creator; a creator cannot also be a host.',
      'CREATOR',
    );
  }
  // v1.80-kyc (D227): Didit on → an approved identity check first; off → the manual ID pictures (or a check).
  const pictures = await tx.hostApplication.findUniqueOrThrow({
    where: { id: app.id },
    select: { photoKey: true, selfieKey: true, recruiterUserId: true },
  });
  await kycGateOrThrow(tx, app.user_id, !!pictures.photoKey && !!pictures.selfieKey);

  const existing = await tx.liveHost.findUnique({ where: { userId: app.user_id }, select: { source: true } });
  let source: LiveHostSource = existing?.source ?? 'IDENTITY';
  if (!existing) {
    // CP-016 G: the room number is drawn by the column default; `skipDuplicates` would also skip a (rare) clash on
    // it, so draw again while the host is still missing (as `grantHost`).
    let created = 0;
    let raced: LiveHostSource | null = null;
    for (let attempt = 0; attempt < 5 && created === 0 && raced === null; attempt += 1) {
      created = (
        await tx.liveHost.createMany({
          data: [{ userId: app.user_id, source: 'IDENTITY', grantedById: by.actorUserId, grantedAt: now }],
          skipDuplicates: true,
        })
      ).count;
      if (created === 0) {
        const row = await tx.liveHost.findUnique({
          where: { userId: app.user_id },
          select: { source: true },
        });
        raced = row?.source ?? null;
      }
    }
    if (created === 0 && raced === null) {
      throw new HostApplicationError('Could not give the hosting permission; try again.');
    }
    if (raced !== null) source = raced;
    if (created > 0) {
      await tx.auditLog.create({
        data: {
          ...auditBy(by),
          action: AuditAction.LIVE_HOST_GRANT,
          targetType: 'user',
          targetId: app.user_id,
          metadata: { source: 'IDENTITY', application: app.id, via: by.via },
        },
      });
    }
  }
  await tx.hostApplication.update({
    where: { id: app.id },
    data: { status: 'APPROVED', decidedAt: now, decidedById: by.actorUserId },
  });
  // v1.90-social (D293, §10.105; owner «نعم»): the team's approval of the ID card and selfie gives the blue badge at once.
  await recomputeBadgesIn(tx, [app.user_id], 'host', now);
  await new Notifier().system(tx, { type: 'HOST_APPLICATION_APPROVED', recipientId: app.user_id });
  await audit(
    tx,
    AuditAction.HOST_APPLICATION_APPROVE,
    app.id,
    {
      user: app.user_id,
      before: 'PENDING',
      after: 'APPROVED',
      source,
      ...(existing ? { existingSource: existing.source } : {}),
    },
    by,
  );
  // v1.75-live (D285, §10.96.13): the recruiter the form named is attributed for good at this activation.
  await attributeRecruitIn(tx, {
    type: 'HOST',
    recruitUserId: app.user_id,
    recruiterUserId: pictures.recruiterUserId,
    applicationId: app.id,
    now,
    by,
  });
  return { userId: app.user_id, source };
}

/**
 * `host-admin reject`: a PENDING application is refused with a reason the person sees; they may apply again
 * `HOST_APPLICATION_REAPPLY_DAYS` after `decidedAt`. Notified (`HOST_APPLICATION_REJECTED`) when ACTIVE.
 */
export async function rejectHostApplicationIn(
  tx: Tx,
  applicationId: string,
  reason: string,
  now: Date,
  by: AdminVia = CLI_VIA,
): Promise<{ userId: string }> {
  const app = await lockApplication(tx, applicationId);
  await tx.hostApplication.update({
    where: { id: app.id },
    data: { status: 'REJECTED', decidedAt: now, decidedById: by.actorUserId, rejectReason: reason },
  });
  const active = await tx.user.count({ where: { id: app.user_id, status: 'ACTIVE' } });
  if (active > 0) {
    await new Notifier().system(tx, { type: 'HOST_APPLICATION_REJECTED', recipientId: app.user_id });
  }
  await audit(
    tx,
    AuditAction.HOST_APPLICATION_REJECT,
    app.id,
    { user: app.user_id, reason, before: 'PENDING', after: 'REJECTED' },
    by,
  );
  return { userId: app.user_id };
}

/**
 * The person's PENDING application (if any) becomes CANCELLED in the caller's transaction: they cancelled it
 * (`USER`), joined or opened an agency (`AGENCY`: an agency host is not a direct host), or their account is being
 * deleted (`ACCOUNT`). Audited `host.application.cancel` (the person as the actor, none for ACCOUNT). Returns the
 * cancelled application's id, or null when none was pending.
 */
export async function cancelPendingHostApplicationIn(
  tx: Tx,
  userId: string,
  reason: HostApplicationCancelReason,
  now: Date,
): Promise<string | null> {
  const rows = await tx.$queryRaw<{ id: string }[]>`
    UPDATE host_applications
       SET status = 'CANCELLED'::host_application_status, decided_at = ${now}, cancel_reason = ${reason}
     WHERE user_id = ${userId}::uuid AND status = 'PENDING'::host_application_status
     RETURNING id::text AS id`;
  const row = rows[0];
  if (!row) return null;
  await tx.auditLog.create({
    data: {
      actorUserId: reason === 'ACCOUNT' ? null : userId,
      action: AuditAction.HOST_APPLICATION_CANCEL,
      targetType: 'host_application',
      targetId: row.id,
      metadata: { reason, before: 'PENDING', after: 'CANCELLED' },
    },
  });
  return row.id;
}
