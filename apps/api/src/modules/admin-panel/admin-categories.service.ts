import { Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { CategoryRequestStatus, Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { isPanelStaff } from '../live/live-staff.js';
import { Notifier } from '../notifications/notifier.js';
import {
  categoryChangedIn,
  categoryRequestDto,
  latestCategoryRequestIn,
} from '../users/category-verification.js';
import type { AdminContext } from './admin-auth.service.js';
import { isPanelRole } from './admin-permissions.js';
import { tableResult, window, type TableQuery } from './admin-tables.js';
import { refused } from './admin-users.service.js';

type Tx = Prisma.TransactionClient;

export type CategoryAction = 'VERIFY' | 'UNVERIFY' | 'CLEAR' | 'LOCK' | 'UNLOCK';

export interface CategoryRequestsQuery extends TableQuery {
  readonly status?: CategoryRequestStatus | undefined;
}

const person = {
  select: { id: true, profile: { select: { username: true, displayName: true, avatarUrl: true } } },
};
type Person = {
  id: string;
  profile: { username: string; displayName: string; avatarUrl: string | null } | null;
};
const personDto = (u: Person) => ({
  id: u.id,
  username: u.profile?.username ?? '',
  displayName: u.profile?.displayName ?? '',
  avatarUrl: u.profile?.avatarUrl ?? null,
});

/** The state the audit row keeps before and after. */
interface CategoryState {
  category: string | null;
  verified: boolean;
  locked: boolean;
}

const ROW_SELECT = {
  id: true,
  status: true,
  category: true,
  note: true,
  createdAt: true,
  decidedAt: true,
  rejectReason: true,
  user: {
    select: { ...person.select, profile: { select: { ...person.select.profile.select, category: true } } },
  },
  decidedBy: person,
} as const;

type RowIn = {
  id: string;
  status: CategoryRequestStatus;
  category: string;
  note: string | null;
  createdAt: Date;
  decidedAt: Date | null;
  rejectReason: string | null;
  user: Person & { profile: { category: string | null } | null };
  decidedBy: Person | null;
};

function rowDto(r: RowIn) {
  return {
    id: r.id,
    status: r.status,
    category: r.category,
    currentCategory: r.user.profile?.category ?? null,
    note: r.note,
    user: personDto(r.user),
    createdAt: r.createdAt.toISOString(),
    decidedAt: r.decidedAt?.toISOString() ?? null,
    decidedBy: r.decidedBy ? personDto(r.decidedBy) : null,
    rejectReason: r.rejectReason,
  };
}

/**
 * v1.138-social (D386, owner 2026-11-12: «الموثقة»), CONVENTIONS §10.175.5: the account category in the panel — read
 * it (`users.control_view`), VERIFY / UNVERIFY / CLEAR / LOCK / UNLOCK it (`users.profile_edit`), and the queue
 * «طلبات توثيق الفئة» with approve / reject. The D208 patterns: a reason on every change, never on one's own account,
 * a panel admin's account only by an OWNER, one audit row with before / after, the person notified.
 */
@Injectable()
export class AdminCategoriesService {
  private readonly notifier = new Notifier();

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  /** The account an action targets: not one's own; a panel admin only by an OWNER. */
  private async target(db: Tx | PrismaService, id: string, ctx: AdminContext) {
    const user = await db.user.findUnique({
      where: { id },
      select: { id: true, status: true, role: true, adminPermissions: { select: { permission: true } } },
    });
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    if (user.id === ctx.userId) throw refused('You cannot do this to your own account.');
    const isAdmin = user.role === 'ADMIN' && user.adminPermissions.some((p) => isPanelRole(p.permission));
    if (isAdmin && !ctx.roles.includes('OWNER')) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    return user;
  }

  /** `AdminUserCategory`. */
  async state(id: string, db: Tx | PrismaService = this.prisma) {
    const profile = await db.userProfile.findUnique({
      where: { userId: id },
      select: {
        category: true,
        categoryVerifiedAt: true,
        categoryLockedAt: true,
        categoryVerifiedBy: person,
      },
    });
    if (!profile) throw new AppException(ErrorCode.NOT_FOUND);
    const request = await latestCategoryRequestIn(db, id);
    const verified = profile.category !== null && profile.categoryVerifiedAt !== null;
    return {
      category: profile.category,
      verified,
      verifiedAt: verified ? profile.categoryVerifiedAt!.toISOString() : null,
      verifiedBy: verified && profile.categoryVerifiedBy ? personDto(profile.categoryVerifiedBy) : null,
      locked: profile.categoryLockedAt !== null,
      lockedAt: profile.categoryLockedAt?.toISOString() ?? null,
      kabsoTeam: await isPanelStaff(db, id),
      request: request ? categoryRequestDto(request) : null,
    };
  }

  private async stateRowIn(tx: Tx, id: string): Promise<CategoryState> {
    const [row] = await tx.$queryRaw<CategoryState[]>`
      SELECT account_category::text AS category,
             (account_category IS NOT NULL AND category_verified_at IS NOT NULL) AS verified,
             category_locked_at IS NOT NULL AS locked
        FROM user_profiles WHERE user_id = ${id}::uuid FOR UPDATE`;
    if (!row) throw new AppException(ErrorCode.NOT_FOUND);
    return row;
  }

  /** Verifies the current category; an open request for it is approved by `ctx`. */
  private async verifyIn(tx: Tx, id: string, category: string, ctx: AdminContext, now: Date): Promise<void> {
    await tx.userProfile.update({
      where: { userId: id },
      data: { categoryVerifiedAt: now, categoryVerifiedById: ctx.userId },
    });
    await tx.categoryRequest.updateMany({
      where: { userId: id, status: 'PENDING', category: category as never },
      data: { status: 'APPROVED', decidedAt: now, decidedById: ctx.userId },
    });
  }

  /** `controlAdminUserCategory`. */
  async control(id: string, action: CategoryAction, reason: string, ctx: AdminContext, now = new Date()) {
    await this.target(this.prisma, id, ctx);
    await this.prisma.$transaction(async (tx) => {
      const before = await this.stateRowIn(tx, id);
      let after: CategoryState = before;
      switch (action) {
        case 'VERIFY':
          if (before.category === null)
            throw refused('The account has no category.', 'no_category', 'category');
          if (!before.verified) {
            await this.verifyIn(tx, id, before.category, ctx, now);
            after = { ...before, verified: true };
          }
          break;
        case 'UNVERIFY':
          if (before.verified) {
            await tx.userProfile.update({
              where: { userId: id },
              data: { categoryVerifiedAt: null, categoryVerifiedById: null },
            });
            after = { ...before, verified: false };
          }
          break;
        case 'CLEAR':
          if (before.category !== null) {
            await categoryChangedIn(tx, id, now, 'cleared_by_team');
            await tx.userProfile.update({ where: { userId: id }, data: { category: null } });
            after = { ...before, category: null, verified: false };
          }
          break;
        case 'LOCK':
          if (!before.locked) {
            await tx.userProfile.update({
              where: { userId: id },
              data: { categoryLockedAt: now, categoryLockedById: ctx.userId },
            });
            after = { ...before, locked: true };
          }
          break;
        case 'UNLOCK':
          if (before.locked) {
            await tx.userProfile.update({
              where: { userId: id },
              data: { categoryLockedAt: null, categoryLockedById: null },
            });
            after = { ...before, locked: false };
          }
          break;
      }
      if (
        after.category === before.category &&
        after.verified === before.verified &&
        after.locked === before.locked
      )
        return;
      await this.notifier.system(tx, {
        type: action === 'VERIFY' ? 'CATEGORY_VERIFIED' : 'CATEGORY_REVIEWED',
        recipientId: id,
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.ADMIN_USER_CATEGORY,
        actorUserId: ctx.userId,
        targetType: 'user',
        targetId: id,
        metadata: { action, reason, before: { ...before }, after: { ...after }, via: ctx.via ?? 'panel' },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    });
    return this.state(id);
  }

  /** «طلبات توثيق الفئة» (the panel v2 table). */
  async table(q: CategoryRequestsQuery, ctx: AdminContext) {
    const text = q.q?.trim().toLowerCase().replace(/^@/, '');
    const where: Prisma.CategoryRequestWhereInput = {
      ...(q.status ? { status: q.status } : {}),
      ...(text
        ? {
            OR: [
              { user: { profile: { username: { startsWith: text } } } },
              { user: { email: { startsWith: text } } },
            ],
          }
        : {}),
    };
    const orderBy: Prisma.CategoryRequestOrderByWithRelationInput[] =
      q.sort === 'decidedAt'
        ? [{ decidedAt: { sort: q.order, nulls: 'last' } }, { id: q.order }]
        : [{ createdAt: q.order }, { id: q.order }];
    const [rows, total] = await Promise.all([
      this.prisma.categoryRequest.findMany({ where, orderBy, ...window(q), select: ROW_SELECT }),
      this.prisma.categoryRequest.count({ where }),
    ]);
    const data = rows.map((r) => rowDto(r as RowIn));
    return tableResult(
      this.audit,
      ctx,
      'category-requests',
      q,
      data,
      total,
      [
        ['id', (r) => r.id],
        ['status', (r) => r.status],
        ['username', (r) => r.user.username],
        ['category', (r) => r.category],
        ['current_category', (r) => r.currentCategory],
        ['created_at', (r) => r.createdAt],
        ['decided_at', (r) => r.decidedAt],
        ['decided_by', (r) => r.decidedBy?.username ?? null],
      ],
      { status: q.status ?? null },
    );
  }

  private async pendingIn(tx: Tx, requestId: string, ctx: AdminContext) {
    const [row] = await tx.$queryRaw<{ user_id: string; status: string; category: string }[]>`
      SELECT user_id, status::text AS status, category::text AS category
        FROM category_verification_requests WHERE id = ${requestId}::uuid FOR UPDATE`;
    if (!row) throw new AppException(ErrorCode.NOT_FOUND);
    await this.target(tx, row.user_id, ctx);
    if (row.status !== 'PENDING') throw refused('The request is not pending.', 'not_pending', 'status');
    return row;
  }

  private async row(requestId: string) {
    const r = await this.prisma.categoryRequest.findUniqueOrThrow({
      where: { id: requestId },
      select: ROW_SELECT,
    });
    return rowDto(r);
  }

  /** `approveAdminCategoryRequest`: the request's category (still the account's — a change cancels it) is verified. */
  async approve(requestId: string, ctx: AdminContext, now = new Date()) {
    await this.prisma.$transaction(async (tx) => {
      const req = await this.pendingIn(tx, requestId, ctx);
      const user = await tx.user.findUnique({ where: { id: req.user_id }, select: { status: true } });
      if (user?.status !== 'ACTIVE') throw refused('The account is not active.', 'not_active', 'status');
      const before = await this.stateRowIn(tx, req.user_id);
      if (before.category !== req.category)
        throw refused('The category changed since the request.', 'category_changed', 'category');
      await this.verifyIn(tx, req.user_id, req.category, ctx, now);
      await this.notifier.system(tx, { type: 'CATEGORY_VERIFIED', recipientId: req.user_id });
      await this.audit.recordIn(tx, {
        action: AuditAction.CATEGORY_REQUEST_APPROVE,
        actorUserId: ctx.userId,
        targetType: 'category_request',
        targetId: requestId,
        metadata: { userId: req.user_id, category: req.category, via: ctx.via ?? 'panel' },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    });
    return this.row(requestId);
  }

  /** `rejectAdminCategoryRequest`: the reason is shown to the person; they may ask again. */
  async reject(requestId: string, reason: string, ctx: AdminContext, now = new Date()) {
    await this.prisma.$transaction(async (tx) => {
      const req = await this.pendingIn(tx, requestId, ctx);
      await tx.categoryRequest.update({
        where: { id: requestId },
        data: { status: 'REJECTED', decidedAt: now, decidedById: ctx.userId, rejectReason: reason },
      });
      await this.notifier.system(tx, { type: 'CATEGORY_REVIEWED', recipientId: req.user_id });
      await this.audit.recordIn(tx, {
        action: AuditAction.CATEGORY_REQUEST_REJECT,
        actorUserId: ctx.userId,
        targetType: 'category_request',
        targetId: requestId,
        metadata: { userId: req.user_id, category: req.category, reason, via: ctx.via ?? 'panel' },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    });
    return this.row(requestId);
  }
}
