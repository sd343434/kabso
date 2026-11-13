import { Injectable } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import type { CategoryRequestStatus, Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { isPanelStaff } from '../live/live-staff.js';
import { normalizeContentText } from '../posts/content-text.js';
import type { AccountCategory } from './profile-fields.js';
import { violatedUniqueIndex } from './users.service.js';

/**
 * v1.138-social (D386, owner 2026-11-12: «الموثقة»), CONVENTIONS §10.175.4: the account category's verification by the
 * Kabso Team, the person's «طلب توثيق الفئة», and the rules shared by `PATCH /me` and the panel. Only a verified
 * category gives the profile page its own look and featured section.
 */

type Db = Prisma.TransactionClient | PrismaService;

/** `CategoryVerificationRequest` on the wire. */
export interface CategoryRequestDto {
  id: string;
  category: AccountCategory;
  status: CategoryRequestStatus;
  createdAt: string;
  decidedAt: string | null;
  rejectReason: string | null;
}

/** `CategoryVerificationStatus`. */
export interface CategoryVerificationStatusDto {
  category: AccountCategory | null;
  verified: boolean;
  locked: boolean;
  request: CategoryRequestDto | null;
}

export const CATEGORY_REQUEST_SELECT = {
  id: true,
  category: true,
  status: true,
  createdAt: true,
  decidedAt: true,
  rejectReason: true,
} as const;

export function categoryRequestDto(r: {
  id: string;
  category: string;
  status: CategoryRequestStatus;
  createdAt: Date;
  decidedAt: Date | null;
  rejectReason: string | null;
}): CategoryRequestDto {
  return {
    id: r.id,
    category: r.category as AccountCategory,
    status: r.status,
    createdAt: r.createdAt.toISOString(),
    decidedAt: r.decidedAt?.toISOString() ?? null,
    rejectReason: r.status === 'REJECTED' ? r.rejectReason : null,
  };
}

/** The person's open request, else the latest one (null when none was ever made). */
export async function latestCategoryRequestIn(db: Db, userId: string) {
  const open = await db.categoryRequest.findFirst({
    where: { userId, status: 'PENDING' },
    select: CATEGORY_REQUEST_SELECT,
  });
  if (open) return open;
  return db.categoryRequest.findFirst({
    where: { userId },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    select: CATEGORY_REQUEST_SELECT,
  });
}

/**
 * A change of the person's category (`PATCH /me` or the team's CLEAR): the verification goes and an open request is
 * cancelled with `reason`.
 */
export async function categoryChangedIn(
  tx: Prisma.TransactionClient,
  userId: string,
  now: Date,
  reason: 'category_changed' | 'cleared_by_team' = 'category_changed',
): Promise<void> {
  await tx.userProfile.update({
    where: { userId },
    data: { categoryVerifiedAt: null, categoryVerifiedById: null },
  });
  await tx.categoryRequest.updateMany({
    where: { userId, status: 'PENDING' },
    data: { status: 'CANCELLED', decidedAt: now, cancelReason: reason },
  });
}

/** `getMyCategoryVerification`: a Kabso Team account shows no category (D367), so nothing is verified. */
export async function categoryStatusIn(db: Db, userId: string): Promise<CategoryVerificationStatusDto> {
  const profile = await db.userProfile.findUnique({
    where: { userId },
    select: { category: true, categoryVerifiedAt: true, categoryLockedAt: true },
  });
  if (!profile) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
  const staff = profile.category !== null && (await isPanelStaff(db, userId));
  const request = await latestCategoryRequestIn(db, userId);
  return {
    category: staff ? null : profile.category,
    verified: !staff && profile.category !== null && profile.categoryVerifiedAt !== null,
    locked: profile.categoryLockedAt !== null,
    request: request ? categoryRequestDto(request) : null,
  };
}

const requestBody = z
  .strictObject({ note: z.string().max(4000).optional() })
  .optional()
  .transform((b) => b ?? {});

/** The app's «طلب توثيق الفئة» (every route needs a token). */
@Injectable()
export class CategoryVerificationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
  ) {}

  status(userId: string): Promise<CategoryVerificationStatusDto> {
    return categoryStatusIn(this.prisma, userId);
  }

  /** `requestCategoryVerification` — the order of §10.175.4. */
  async request(
    userId: string,
    raw: unknown,
    meta: { ip: string | null; requestId: string },
  ): Promise<CategoryVerificationStatusDto> {
    const parsed = requestBody.safeParse(raw === null || raw === '' ? undefined : raw);
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    let note: string | null = null;
    if (parsed.data.note !== undefined) {
      const n = normalizeContentText(parsed.data.note, {
        maxCodePoints: 300,
        maxLineBreaks: 10,
        allowEmpty: true,
      });
      if ('issue' in n) throw AppException.validation([{ field: 'note', issue: n.issue }]);
      note = n.value === '' ? null : n.value;
    }
    const now = this.clock.now();
    try {
      await this.prisma.$transaction(async (tx) => {
        const [profile] = await tx.$queryRaw<{ category: string | null; verified: boolean }[]>`
          SELECT account_category::text AS category, category_verified_at IS NOT NULL AS verified
            FROM user_profiles WHERE user_id = ${userId}::uuid FOR UPDATE`;
        if (!profile) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
        if (profile.category === null || (await isPanelStaff(tx, userId)))
          throw AppException.validation([{ field: 'category', issue: 'required' }]);
        if (profile.verified)
          throw AppException.validation([{ field: 'category', issue: 'already_verified' }]);
        const open = await tx.categoryRequest.count({ where: { userId, status: 'PENDING' } });
        if (open > 0) throw new AppException(ErrorCode.CATEGORY_VERIFICATION_PENDING);
        const row = await tx.categoryRequest.create({
          data: { userId, category: profile.category as AccountCategory, note, createdAt: now },
          select: { id: true },
        });
        await this.audit.recordIn(tx, {
          action: AuditAction.CATEGORY_VERIFICATION_REQUEST,
          actorUserId: userId,
          targetType: 'category_request',
          targetId: row.id,
          metadata: { category: profile.category },
          ip: meta.ip,
          requestId: meta.requestId,
        });
      });
    } catch (err) {
      // Two devices at once: the partial unique index keeps one PENDING request.
      if (violatedUniqueIndex(err) !== null) throw new AppException(ErrorCode.CATEGORY_VERIFICATION_PENDING);
      throw err;
    }
    return this.status(userId);
  }

  /** `cancelCategoryVerification` (idempotent). */
  async cancel(
    userId: string,
    meta: { ip: string | null; requestId: string },
  ): Promise<CategoryVerificationStatusDto> {
    await this.prisma.$transaction(async (tx) => {
      const open = await tx.categoryRequest.findFirst({
        where: { userId, status: 'PENDING' },
        select: { id: true, category: true },
      });
      if (!open) return;
      const done = await tx.categoryRequest.updateMany({
        where: { id: open.id, status: 'PENDING' },
        data: { status: 'CANCELLED', decidedAt: this.clock.now(), cancelReason: 'user' },
      });
      if (done.count === 0) return;
      await this.audit.recordIn(tx, {
        action: AuditAction.CATEGORY_VERIFICATION_CANCEL,
        actorUserId: userId,
        targetType: 'category_request',
        targetId: open.id,
        metadata: { category: open.category },
        ip: meta.ip,
        requestId: meta.requestId,
      });
    });
    return this.status(userId);
  }
}
