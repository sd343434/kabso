import { Inject, Injectable } from '@nestjs/common';
import { adminKycSummaryIn } from '../kyc/kyc-core.js';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { HostApplicationStatus, Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import {
  ageOn,
  approveHostApplicationIn,
  HostApplicationError,
  rejectHostApplicationIn,
} from '../host-applications/host-applications.core.js';
import { OBJECT_STORAGE, type ObjectStorage } from '../media/object-storage.js';
import type { AdminContext } from './admin-auth.service.js';
import { tableResult, window, type TableQuery } from './admin-tables.js';
import { refused, viaOf } from './admin-users.service.js';

export interface HostApplicationsQuery extends TableQuery {
  readonly status?: HostApplicationStatus | undefined;
}

const DAY_MS = 86_400_000;

async function rule<T>(step: () => Promise<T>): Promise<T> {
  try {
    return await step();
  } catch (err) {
    if (err instanceof HostApplicationError) throw refused(err.message, err.issue);
    throw err;
  }
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

/**
 * «طلبات المضيفين» in the panel (v1.73-social, D209, CONVENTIONS §10.68): the applications «كن مضيفاً مع الإدارة» —
 * the list (no private field), one application with its fields and the applicant's account summary (audited
 * `host.application.view`), its two pictures streamed through the API (audited `host.application.photo.view`), and
 * the decision (`host-applications.core.ts`, the same code as `host-admin`, `via: panel`). The decision needs no
 * authenticator code again: it moves no money (owner D209).
 */
@Injectable()
export class AdminHostApplicationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  async table(q: HostApplicationsQuery, ctx: AdminContext) {
    const text = q.q?.trim().toLowerCase().replace(/^@/, '');
    const where: Prisma.HostApplicationWhereInput = {
      ...(q.status ? { status: q.status } : {}),
      ...(text
        ? {
            OR: [
              { user: { profile: { username: { startsWith: text } } } },
              { user: { email: { startsWith: text } } },
              { displayName: { contains: text, mode: 'insensitive' as const } },
            ],
          }
        : {}),
    };
    const orderBy: Prisma.HostApplicationOrderByWithRelationInput[] =
      q.sort === 'decidedAt'
        ? [{ decidedAt: { sort: q.order, nulls: 'last' } }, { id: q.order }]
        : [{ createdAt: q.order }, { id: q.order }];
    const [rows, total] = await Promise.all([
      this.prisma.hostApplication.findMany({
        where,
        orderBy,
        ...window(q),
        select: {
          id: true,
          status: true,
          displayName: true,
          country: true,
          createdAt: true,
          decidedAt: true,
          purgedAt: true,
          user: person,
          decidedBy: person,
        },
      }),
      this.prisma.hostApplication.count({ where }),
    ]);
    // A list shows no private field (only the audited detail does).
    const data = rows.map((r) => ({
      id: r.id,
      status: r.status,
      displayName: r.displayName,
      country: r.country,
      user: personDto(r.user),
      decidedBy: r.decidedBy ? personDto(r.decidedBy) : null,
      createdAt: r.createdAt.toISOString(),
      decidedAt: r.decidedAt?.toISOString() ?? null,
      purged: r.purgedAt !== null,
    }));
    return tableResult(
      this.audit,
      ctx,
      'host-applications',
      q,
      data,
      total,
      [
        ['id', (r) => r.id],
        ['status', (r) => r.status],
        ['username', (r) => r.user.username],
        ['display_name', (r) => r.displayName],
        ['country', (r) => r.country],
        ['created_at', (r) => r.createdAt],
        ['decided_at', (r) => r.decidedAt],
        ['decided_by', (r) => r.decidedBy?.username ?? null],
      ],
      { status: q.status ?? null },
    );
  }

  /** The application's fields with the applicant's account summary (audited `host.application.view`, via panel). */
  async detail(id: string, ctx: AdminContext, now = new Date()) {
    const app = await this.prisma.hostApplication.findUnique({
      where: { id },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            status: true,
            createdAt: true,
            profile: { select: { username: true, displayName: true, avatarUrl: true, countryCode: true } },
          },
        },
        decidedBy: person,
      },
    });
    if (!app) throw new AppException(ErrorCode.NOT_FOUND);
    const userId = app.user.id;
    const [openReports, totalReports, bans, warnings, host, agencyLink, ownedAgency, history] =
      await Promise.all([
        this.prisma.report.count({ where: { targetUserId: userId, status: 'OPEN' } }),
        this.prisma.report.count({ where: { targetUserId: userId } }),
        this.prisma.auditLog.count({
          where: { action: AuditAction.ADMIN_USER_BAN, targetType: 'user', targetId: userId },
        }),
        this.prisma.auditLog.count({
          where: { action: AuditAction.ADMIN_USER_WARN, targetType: 'user', targetId: userId },
        }),
        this.prisma.liveHost.findUnique({
          where: { userId },
          select: { source: true, grantedAt: true },
        }),
        this.prisma.agencyHost.findFirst({
          where: { hostUserId: userId, status: 'ACTIVE' },
          select: { agency: { select: { inviteCode: true } } },
        }),
        this.prisma.agency.findUnique({
          where: { ownerUserId: userId },
          select: { inviteCode: true, status: true },
        }),
        this.prisma.hostApplication.findMany({
          where: { userId, id: { not: app.id } },
          orderBy: { createdAt: 'desc' },
          take: 10,
          select: { id: true, status: true, createdAt: true, decidedAt: true, rejectReason: true },
        }),
      ]);
    await this.audit.record({
      action: AuditAction.HOST_APPLICATION_VIEW,
      actorUserId: ctx.userId,
      targetType: 'host_application',
      targetId: app.id,
      metadata: { via: 'panel' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    const purged = app.purgedAt !== null;
    return {
      id: app.id,
      status: app.status,
      createdAt: app.createdAt.toISOString(),
      decidedAt: app.decidedAt?.toISOString() ?? null,
      decidedBy: app.decidedBy ? personDto(app.decidedBy) : null,
      rejectReason: app.rejectReason,
      cancelReason: app.cancelReason,
      purgedAt: app.purgedAt?.toISOString() ?? null,
      reapplyAt:
        app.status === 'REJECTED' && app.decidedAt
          ? new Date(
              app.decidedAt.getTime() + this.config.economy.hostApplyReapplyDays * DAY_MS,
            ).toISOString()
          : null,
      displayName: app.displayName,
      country: app.country,
      dateOfBirth: purged || !app.dateOfBirth ? null : app.dateOfBirth.toISOString().slice(0, 10),
      age: purged || !app.dateOfBirth ? null : ageOn(app.dateOfBirth, now),
      contact: { type: app.contactType, value: purged ? null : app.contactValue },
      bio: purged ? null : app.bio,
      links: purged ? [] : app.links,
      rulesAcceptedAt: app.rulesAcceptedAt.toISOString(),
      photos: { photo: !purged && app.photoKey !== null, selfie: !purged && app.selfieKey !== null },
      account: {
        id: userId,
        username: app.user.profile?.username ?? '',
        displayName: app.user.profile?.displayName ?? '',
        avatarUrl: app.user.profile?.avatarUrl ?? null,
        email: app.user.email,
        status: app.user.status,
        createdAt: app.user.createdAt.toISOString(),
        accountAgeDays: Math.max(0, Math.floor((now.getTime() - app.user.createdAt.getTime()) / DAY_MS)),
        profileCountry: app.user.profile?.countryCode ?? null,
        openReports,
        totalReports,
        bans,
        warnings,
        host: host ? { source: host.source, grantedAt: host.grantedAt.toISOString() } : null,
        agency: agencyLink
          ? { role: 'HOST' as const, inviteCode: agencyLink.agency.inviteCode }
          : ownedAgency?.status === 'OPEN'
            ? { role: 'OWNER' as const, inviteCode: ownedAgency.inviteCode }
            : null,
      },
      // v1.80-kyc (D227): the person's identity check — approved is required before «موافقة» while Didit is on.
      kyc: await adminKycSummaryIn(
        this.prisma,
        userId,
        'HOST_APPLICATION',
        now,
        ctx.capabilities.includes('kyc.view'),
      ),
      history: history.map((h) => ({
        id: h.id,
        status: h.status,
        createdAt: h.createdAt.toISOString(),
        decidedAt: h.decidedAt?.toISOString() ?? null,
        rejectReason: h.rejectReason,
      })),
    };
  }

  /** One of the application's pictures (the ID card or the selfie), audited per view; 404 when purged or missing. */
  async photo(id: string, which: 'photo' | 'selfie', ctx: AdminContext): Promise<Buffer> {
    const app = await this.prisma.hostApplication.findUnique({
      where: { id },
      select: { photoKey: true, selfieKey: true, purgedAt: true },
    });
    const key = app && app.purgedAt === null ? (which === 'photo' ? app.photoKey : app.selfieKey) : null;
    if (!key) throw new AppException(ErrorCode.NOT_FOUND);
    await this.audit.record({
      action: AuditAction.HOST_APPLICATION_PHOTO_VIEW,
      actorUserId: ctx.userId,
      targetType: 'host_application',
      targetId: id,
      metadata: { which, via: 'panel' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    const bytes = await this.storage.get(key, 16 * 1024 * 1024);
    if (!bytes) throw new AppException(ErrorCode.NOT_FOUND);
    return bytes;
  }

  /** `host-admin approve` from the panel: the `live_hosts` row with source IDENTITY, the applicant notified. */
  async approve(id: string, ctx: AdminContext) {
    const r = await rule(() =>
      this.prisma.$transaction((tx) => approveHostApplicationIn(tx, id, new Date(), viaOf(ctx))),
    );
    return { status: 'APPROVED' as const, source: r.source };
  }

  /** `host-admin reject` from the panel: the reason is shown to the applicant. */
  async reject(id: string, reason: string, ctx: AdminContext) {
    await rule(() =>
      this.prisma.$transaction((tx) => rejectHostApplicationIn(tx, id, reason, new Date(), viaOf(ctx))),
    );
    return { status: 'REJECTED' as const };
  }
}
