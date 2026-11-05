import { Injectable } from '@nestjs/common';
import { z } from 'zod';
import { auditBy, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { Prisma, type CreatorApplication } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { isLimitedStaff } from '../live/live-staff.js';
import { formatStaffId } from '../users/staff-ids.js';
import { attributeRecruitIn, recruiterOfForm } from '../recruits/recruit-core.js';

/**
 * v1.75-live (D285, owner, CONVENTIONS §10.96.13): the creator programme «صانع المحتوى» — there was no creator
 * application before, so D285 adds one: «انضم كصانع محتوى» (country, a content category, 1–5 links to the person's
 * work, an optional bio and the optional recruiter field). The team approves or rejects it in the panel «طلبات صناع
 * المحتوى» (OWNER, SUPPORT); an approval makes the person a member (`creator_members`) and, when the form named a
 * recruiter, attributes them (`staff_recruitments` CREATOR). One PENDING application at a time; a rejected person may
 * apply again at once; a member cannot apply again. Kabso Team accounts cannot apply.
 */

type Tx = Prisma.TransactionClient;

export const CREATOR_CATEGORIES = [
  'VIDEO',
  'PHOTO',
  'MUSIC',
  'GAMING',
  'COMEDY',
  'EDUCATION',
  'LIFESTYLE',
  'OTHER',
] as const;

export const creatorApplicationBody = z.strictObject({
  country: z.string().regex(/^[A-Z]{2}$/),
  category: z.enum(CREATOR_CATEGORIES),
  links: z
    .array(
      z
        .string()
        .trim()
        .max(200)
        .regex(/^https?:\/\/[^\s]+$/i),
    )
    .min(1)
    .max(5),
  bio: z.string().trim().max(300).optional(),
  /** «إن كنت تابعاً لمشرف، ضع معرّفه هنا» — a staff ID or username (optional). */
  recruiter: z.string().trim().max(64).optional(),
});

export type CreatorApplyRefusal = 'MEMBER' | 'PENDING' | 'ACCOUNT_NOT_ACTIVE' | 'STAFF';

export interface CreatorApplicationDto {
  id: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED' | 'CANCELLED';
  country: string;
  category: string;
  links: string[];
  bio: string | null;
  recruiter: { staffId: string | null; displayName: string } | null;
  createdAt: string;
  decidedAt: string | null;
  rejectReason: string | null;
}

export interface MyCreatorApplicationDto {
  member: { activatedAt: string } | null;
  application: CreatorApplicationDto | null;
  rule: { canApply: boolean; refusal: CreatorApplyRefusal | null };
}

export class CreatorApplicationError extends Error {}

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
      targetType: 'creator_application',
      targetId,
      metadata: { ...metadata, via: by.via },
    },
  });
}

async function lockPending(tx: Tx, id: string): Promise<{ id: string; user_id: string; recruiter: string | null }> {
  const [app] = await tx.$queryRaw<{ id: string; user_id: string; status: string; recruiter: string | null }[]>`
    SELECT id::text AS id, user_id::text AS user_id, status::text AS status, recruiter_user_id::text AS recruiter
      FROM creator_applications WHERE id = ${id}::uuid FOR UPDATE`;
  if (!app) throw new CreatorApplicationError(`No application ${id}.`);
  if (app.status !== 'PENDING') throw new CreatorApplicationError(`The application is ${app.status}, not PENDING.`);
  return app;
}

/** Approve: the person becomes a creator; a named recruiter is attributed (D285). Audited. */
export async function approveCreatorApplicationIn(
  tx: Tx,
  applicationId: string,
  now: Date,
  by: AdminVia,
): Promise<{ userId: string; recruitmentId: string | null }> {
  const app = await lockPending(tx, applicationId);
  const user = await tx.user.findUnique({ where: { id: app.user_id }, select: { status: true } });
  if (user?.status !== 'ACTIVE') throw new CreatorApplicationError('The applicant account is not ACTIVE.');
  await tx.creatorApplication.update({
    where: { id: app.id },
    data: { status: 'APPROVED', decidedAt: now, decidedById: by.actorUserId },
  });
  await tx.creatorMember.createMany({
    data: [{ userId: app.user_id, applicationId: app.id, activatedAt: now }],
    skipDuplicates: true,
  });
  await audit(
    tx,
    AuditAction.CREATOR_APPLICATION_APPROVE,
    app.id,
    { user: app.user_id, before: 'PENDING', after: 'APPROVED' },
    by,
  );
  const attributed = await attributeRecruitIn(tx, {
    type: 'CREATOR',
    recruitUserId: app.user_id,
    recruiterUserId: app.recruiter,
    applicationId: app.id,
    now,
    by,
  });
  return { userId: app.user_id, recruitmentId: attributed?.recruitmentId ?? null };
}

export async function rejectCreatorApplicationIn(
  tx: Tx,
  applicationId: string,
  reason: string,
  now: Date,
  by: AdminVia,
): Promise<{ userId: string }> {
  const app = await lockPending(tx, applicationId);
  await tx.creatorApplication.update({
    where: { id: app.id },
    data: { status: 'REJECTED', decidedAt: now, decidedById: by.actorUserId, rejectReason: reason },
  });
  await audit(
    tx,
    AuditAction.CREATOR_APPLICATION_REJECT,
    app.id,
    { user: app.user_id, reason, before: 'PENDING', after: 'REJECTED' },
    by,
  );
  return { userId: app.user_id };
}

function isUniqueViolation(err: unknown): boolean {
  return err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002';
}

@Injectable()
export class CreatorApplicationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
  ) {}

  async dto(a: CreatorApplication): Promise<CreatorApplicationDto> {
    let recruiter: CreatorApplicationDto['recruiter'] = null;
    if (a.recruiterUserId) {
      const r = await this.prisma.user.findUnique({
        where: { id: a.recruiterUserId },
        select: { profile: { select: { displayName: true } }, staffNumber: { select: { number: true } } },
      });
      recruiter = {
        staffId: r?.staffNumber ? formatStaffId(r.staffNumber.number) : null,
        displayName: r?.profile?.displayName ?? '',
      };
    }
    return {
      id: a.id,
      status: a.status,
      country: a.country,
      category: a.category,
      links: a.links,
      bio: a.bio,
      recruiter,
      createdAt: a.createdAt.toISOString(),
      decidedAt: a.decidedAt?.toISOString() ?? null,
      rejectReason: a.rejectReason,
    };
  }

  private async refusal(me: string, latest: CreatorApplication | null): Promise<CreatorApplyRefusal | null> {
    const [user, member] = await Promise.all([
      this.prisma.user.findUnique({ where: { id: me }, select: { status: true, deletedAt: true } }),
      this.prisma.creatorMember.count({ where: { userId: me } }),
    ]);
    if (!user || user.deletedAt !== null || user.status !== 'ACTIVE') return 'ACCOUNT_NOT_ACTIVE';
    if (member > 0) return 'MEMBER';
    if (await isLimitedStaff(this.prisma, me)) return 'STAFF';
    if (latest?.status === 'PENDING') return 'PENDING';
    return null;
  }

  private latest(me: string): Promise<CreatorApplication | null> {
    return this.prisma.creatorApplication.findFirst({
      where: { userId: me },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    });
  }

  /** `GET /me/creator-application`. */
  async mine(me: string): Promise<MyCreatorApplicationDto> {
    const [member, latest] = await Promise.all([
      this.prisma.creatorMember.findUnique({ where: { userId: me }, select: { activatedAt: true } }),
      this.latest(me),
    ]);
    const refusal = await this.refusal(me, latest);
    return {
      member: member ? { activatedAt: member.activatedAt.toISOString() } : null,
      application: latest ? await this.dto(latest) : null,
      rule: { canApply: refusal === null, refusal },
    };
  }

  /**
   * `POST /me/creator-application`. Order: 400 body → 400 `recruiter` (`not_found` / `self`) → 409
   * CREATOR_APPLICATION_NOT_ALLOWED (`details[0].issue` = the refusal) → 201.
   */
  async apply(me: string, body: unknown): Promise<MyCreatorApplicationDto> {
    const parsed = creatorApplicationBody.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;
    const recruiter = await recruiterOfForm(this.prisma, input.recruiter, me);
    const refused = (issue: CreatorApplyRefusal) =>
      new AppException(ErrorCode.CREATOR_APPLICATION_NOT_ALLOWED, undefined, [{ field: 'application', issue }]);
    const refusal = await this.refusal(me, await this.latest(me));
    if (refusal) throw refused(refusal);
    const id = uuidv7();
    const now = this.clock.now();
    try {
      await this.prisma.$transaction(async (tx) => {
        await tx.creatorApplication.create({
          data: {
            id,
            userId: me,
            country: input.country,
            category: input.category,
            links: input.links,
            bio: input.bio && input.bio !== '' ? input.bio : null,
            recruiterUserId: recruiter,
            createdAt: now,
          },
        });
        await tx.auditLog.create({
          data: {
            actorUserId: me,
            action: AuditAction.CREATOR_APPLICATION_SUBMIT,
            targetType: 'creator_application',
            targetId: id,
            metadata: {
              country: input.country,
              category: input.category,
              links: input.links.length,
              recruiter: recruiter !== null,
              after: 'PENDING',
            },
          },
        });
      });
    } catch (err) {
      if (isUniqueViolation(err)) throw refused('PENDING');
      throw err;
    }
    return this.mine(me);
  }

  /** `POST /me/creator-application/cancel`: the caller's PENDING application → CANCELLED (404: none pending). */
  async cancel(me: string): Promise<MyCreatorApplicationDto> {
    const now = this.clock.now();
    const done = await this.prisma.$transaction(async (tx) => {
      const pending = await tx.creatorApplication.findFirst({ where: { userId: me, status: 'PENDING' } });
      if (!pending) return false;
      await tx.creatorApplication.update({
        where: { id: pending.id },
        data: { status: 'CANCELLED', decidedAt: now },
      });
      await tx.auditLog.create({
        data: {
          actorUserId: me,
          action: AuditAction.CREATOR_APPLICATION_CANCEL,
          targetType: 'creator_application',
          targetId: pending.id,
          metadata: { before: 'PENDING', after: 'CANCELLED' },
        },
      });
      return true;
    });
    if (!done) throw new AppException(ErrorCode.NOT_FOUND);
    return this.mine(me);
  }

  /** The panel's list (newest first, at most 200), with the applicant. */
  async panelList(status: CreatorApplication['status'] | undefined) {
    const rows = await this.prisma.creatorApplication.findMany({
      where: status ? { status } : {},
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: 200,
      include: { user: { select: { id: true, profile: { select: { username: true, displayName: true } } } } },
    });
    return {
      data: await Promise.all(
        rows.map(async (r) => ({
          ...(await this.dto(r)),
          user: {
            id: r.user.id,
            username: r.user.profile?.username ?? '',
            displayName: r.user.profile?.displayName ?? '',
          },
        })),
      ),
    };
  }
}
