import { Inject, Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { createAgencyByAdmin, resolveComplaintIn, type ComplaintDecision } from '../economy/agency-admin.js';
import {
  closeAgencyByAdminIn,
  extendProbationIn,
  probationHostsAt,
  probationInstant,
  reopenAgencyIn,
} from '../economy/agency-probation.js';
import { AgencyService } from '../economy/agency.service.js';
import { OBJECT_STORAGE, type ObjectStorage } from '../media/object-storage.js';
import { addMonths, dateValue, monthKey } from '../economy/economy-math.js';
import { HostAgentError, reinstateHostAgentIn, suspendHostAgentIn } from '../economy/host-agents.js';
import { normalizeEmail } from '../users/username.js';
import { AdminAuthService, type AdminContext } from './admin-auth.service.js';
import { tableResult, window, type TableQuery } from './admin-tables.js';
import { refused, viaOf } from './admin-users.service.js';

export interface AgenciesQuery extends TableQuery {
  readonly rank?: 'NEW' | 'AGENT' | 'ADMIN' | 'LAPSED' | undefined;
  readonly state?: 'active' | 'suspended' | 'probation' | 'closed' | undefined;
  /** v1.70-social (D206): who made it. */
  readonly origin?: 'ADMIN' | 'SELF' | undefined;
}

export interface ComplaintsQuery extends TableQuery {
  readonly status: 'OPEN' | 'RESOLVED' | 'REJECTED';
}

async function rule<T>(step: () => Promise<T>): Promise<T> {
  try {
    return await step();
  } catch (err) {
    if (err instanceof HostAgentError) throw refused(err.message);
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

/** v1.70-social (D206): NONE (no probation), RUNNING, PASSED, or FAILED (closed for it). */
function probationState(a: {
  status: 'OPEN' | 'CLOSED';
  probationEndsAt: Date | null;
  probationPassedAt: Date | null;
  closeReason: 'PROBATION_FAILED' | 'ADMIN' | null;
}): 'NONE' | 'RUNNING' | 'PASSED' | 'FAILED' | 'STOPPED' {
  if (a.probationEndsAt === null) return 'NONE';
  if (a.probationPassedAt !== null) return 'PASSED';
  if (a.status === 'CLOSED') return a.closeReason === 'PROBATION_FAILED' ? 'FAILED' : 'STOPPED';
  return 'RUNNING';
}

/**
 * Host agencies «الوكالات» in the panel v2 (v1.65-social, D197, CONVENTIONS §10.60.2; D179/D189): the list and an
 * agency's page (owner, `hostNN`, rank, this month's totals, hosts, sub-agencies, commissions), creation, the host
 * agent's suspension / reinstatement, the hosts' complaints and the rank evaluation — every change through the
 * `economy-admin` rules (agency-admin.ts, host-agents.ts, AgencyService), audited with `via: panel` and the reason.
 */
@Injectable()
export class AdminAgenciesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly agencies: AgencyService,
    private readonly auth: AdminAuthService,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  private get zone(): string {
    return this.config.live.rankingsTimeZone;
  }

  private month(now = new Date()): Date {
    return dateValue(monthKey(now, this.zone));
  }

  async table(q: AgenciesQuery, ctx: AdminContext) {
    const text = q.q?.trim().toLowerCase().replace(/^@/, '');
    const where: Prisma.AgencyWhereInput = {
      ...(q.rank ? { rank: q.rank } : {}),
      ...(q.state === 'suspended'
        ? { suspendedAt: { not: null } }
        : q.state === 'active'
          ? { suspendedAt: null, status: 'OPEN' as const }
          : q.state === 'probation'
            ? { status: 'OPEN' as const, probationEndsAt: { not: null }, probationPassedAt: null }
            : q.state === 'closed'
              ? { status: 'CLOSED' as const }
              : {}),
      ...(q.origin ? { origin: q.origin } : {}),
      ...(text
        ? {
            OR: [
              { inviteCode: { startsWith: text.toUpperCase() } },
              { hostCode: { startsWith: text } },
              { owner: { profile: { username: { startsWith: text } } } },
              { owner: { email: { startsWith: text } } },
            ],
          }
        : {}),
    };
    const orderBy: Prisma.AgencyOrderByWithRelationInput[] =
      q.sort === 'inviteCode'
        ? [{ inviteCode: q.order }]
        : q.sort === 'rank'
          ? [{ rank: q.order }, { createdAt: 'desc' }]
          : [{ createdAt: q.order }, { id: q.order }];
    const month = this.month();
    const [rows, total] = await Promise.all([
      this.prisma.agency.findMany({
        where,
        orderBy,
        ...window(q),
        select: {
          id: true,
          inviteCode: true,
          hostCode: true,
          rank: true,
          suspendedAt: true,
          createdAt: true,
          name: true,
          origin: true,
          status: true,
          probationEndsAt: true,
          probationPassedAt: true,
          closedAt: true,
          closeReason: true,
          owner: person,
          parent: { select: { inviteCode: true } },
          _count: { select: { hosts: { where: { status: 'ACTIVE' } }, subAgencies: true } },
          months: { where: { month }, select: { hostCherries: true, commission: true } },
        },
      }),
      this.prisma.agency.count({ where }),
    ]);
    const data = rows.map((a) => ({
      id: a.id,
      inviteCode: a.inviteCode,
      hostCode: a.hostCode,
      rank: a.rank,
      suspended: a.suspendedAt !== null,
      name: a.name,
      origin: a.origin,
      status: a.status,
      probation: probationState(a),
      probationEndsAt: a.probationEndsAt?.toISOString() ?? null,
      closedAt: a.closedAt?.toISOString() ?? null,
      closeReason: a.closeReason,
      owner: personDto(a.owner),
      parentInviteCode: a.parent?.inviteCode ?? null,
      activeHosts: a._count.hosts,
      subAgencies: a._count.subAgencies,
      monthHostCherries: Number(a.months[0]?.hostCherries ?? 0n),
      monthCommission: Number(a.months[0]?.commission ?? 0n),
      createdAt: a.createdAt.toISOString(),
    }));
    return tableResult(
      this.audit,
      ctx,
      'agencies',
      q,
      data,
      total,
      [
        ['invite_code', (r) => r.inviteCode],
        ['host_code', (r) => r.hostCode],
        ['rank', (r) => r.rank],
        ['suspended', (r) => r.suspended],
        ['name', (r) => r.name],
        ['origin', (r) => r.origin],
        ['status', (r) => r.status],
        ['probation', (r) => r.probation],
        ['owner_username', (r) => r.owner.username],
        ['parent', (r) => r.parentInviteCode],
        ['active_hosts', (r) => r.activeHosts],
        ['sub_agencies', (r) => r.subAgencies],
        ['month_host_cherries', (r) => r.monthHostCherries],
        ['month_commission', (r) => r.monthCommission],
        ['created_at', (r) => r.createdAt],
      ],
      { rank: q.rank ?? null, state: q.state ?? null, origin: q.origin ?? null },
    );
  }

  async detail(id: string, now = new Date()) {
    const month = this.month(now);
    const since = dateValue(addMonths(monthKey(now, this.zone), -5));
    const a = await this.prisma.agency.findUnique({
      where: { id },
      select: {
        id: true,
        inviteCode: true,
        hostCode: true,
        rank: true,
        rankMonth: true,
        evaluateFrom: true,
        suspendedAt: true,
        suspendReason: true,
        createdAt: true,
        name: true,
        origin: true,
        status: true,
        probationEndsAt: true,
        probationPassedAt: true,
        probationActivated: true,
        closedAt: true,
        closeReason: true,
        closeNote: true,
        applications: {
          orderBy: { createdAt: 'desc' },
          take: 10,
          select: { id: true, createdAt: true, purgedAt: true },
        },
        owner: person,
        parent: { select: { id: true, inviteCode: true } },
        subAgencies: {
          orderBy: { createdAt: 'asc' },
          take: 100,
          select: {
            id: true,
            inviteCode: true,
            hostCode: true,
            rank: true,
            suspendedAt: true,
            owner: person,
          },
        },
        hosts: {
          orderBy: [{ status: 'asc' }, { activatedAt: 'desc' }],
          take: 200,
          select: {
            id: true,
            status: true,
            commissionEligible: true,
            activatedAt: true,
            endedAt: true,
            host: person,
          },
        },
        months: {
          where: { month: { gte: since } },
          orderBy: { month: 'desc' },
          select: { month: true, hostCherries: true, commission: true, parentCommission: true },
        },
      },
    });
    if (!a) throw new AppException(ErrorCode.NOT_FOUND);
    const [perHost, lifetime, openComplaints] = await Promise.all([
      this.prisma.agencyEarning.groupBy({
        by: ['hostUserId'],
        where: { agencyId: id, month, reversedAt: null },
        _sum: { hostCherries: true, commission: true },
      }),
      this.prisma.agencyMonth.aggregate({
        where: { agencyId: id },
        _sum: { hostCherries: true, commission: true, parentCommission: true },
      }),
      this.prisma.agencyComplaint.count({ where: { agencyId: id, status: 'OPEN' } }),
    ]);
    const hostMonth = new Map(perHost.map((h) => [h.hostUserId, h]));
    const e = this.config.economy;
    const running = probationState(a) === 'RUNNING' && a.probationEndsAt !== null;
    const probationHosts = running
      ? await probationHostsAt(this.prisma, a.id, probationInstant(now, a.probationEndsAt!))
      : [];
    return {
      id: a.id,
      name: a.name,
      origin: a.origin,
      status: a.status,
      closedAt: a.closedAt?.toISOString() ?? null,
      closeReason: a.closeReason,
      closeNote: a.closeNote,
      probation:
        a.probationEndsAt === null
          ? null
          : {
              state: probationState(a),
              endsAt: a.probationEndsAt.toISOString(),
              passedAt: a.probationPassedAt?.toISOString() ?? null,
              requiredHosts: e.probationMinHosts,
              activatedHosts: running
                ? probationHosts.filter((h) => h.activated).length
                : (a.probationActivated ?? null),
              hosts: probationHosts.map((h) => ({
                userId: h.userId,
                joinedAt: h.joinedAt.toISOString(),
                wentLive: h.wentLive,
                receivedGifts: h.receivedGifts,
                activated: h.activated,
              })),
            },
      applications: a.applications.map((x) => ({
        id: x.id,
        createdAt: x.createdAt.toISOString(),
        purged: x.purgedAt !== null,
      })),
      inviteCode: a.inviteCode,
      hostCode: a.hostCode,
      rank: a.rank,
      rankMonth: a.rankMonth?.toISOString().slice(0, 7) ?? null,
      evaluateFrom: a.evaluateFrom.toISOString().slice(0, 10),
      suspended: a.suspendedAt !== null,
      suspendReason: a.suspendReason,
      createdAt: a.createdAt.toISOString(),
      owner: personDto(a.owner),
      parent: a.parent,
      subAgencies: a.subAgencies.map((s) => ({
        id: s.id,
        inviteCode: s.inviteCode,
        hostCode: s.hostCode,
        rank: s.rank,
        suspended: s.suspendedAt !== null,
        owner: personDto(s.owner),
      })),
      hosts: a.hosts.map((h) => ({
        linkId: h.id,
        status: h.status,
        commissionEligible: h.commissionEligible,
        activatedAt: h.activatedAt.toISOString(),
        endedAt: h.endedAt?.toISOString() ?? null,
        user: personDto(h.host),
        monthCherries: Number(hostMonth.get(h.host.id)?._sum.hostCherries ?? 0n),
        monthCommission: Number(hostMonth.get(h.host.id)?._sum.commission ?? 0n),
      })),
      months: a.months.map((m) => ({
        month: m.month.toISOString().slice(0, 7),
        hostCherries: Number(m.hostCherries),
        commission: Number(m.commission),
        parentCommission: Number(m.parentCommission),
      })),
      lifetime: {
        hostCherries: Number(lifetime._sum.hostCherries ?? 0n),
        commission: Number(lifetime._sum.commission ?? 0n),
        parentCommission: Number(lifetime._sum.parentCommission ?? 0n),
      },
      openComplaints,
    };
  }

  /** `economy-admin agency-create` from the panel: the owner by id or email, an optional parent, the reason. */
  async create(
    body: {
      ownerUserId?: string | undefined;
      ownerEmail?: string | undefined;
      parentInviteCode?: string | undefined;
      reason: string;
    },
    ctx: AdminContext,
  ) {
    const owner = body.ownerUserId
      ? await this.prisma.user.findUnique({ where: { id: body.ownerUserId }, select: { id: true } })
      : await this.prisma.user.findUnique({
          where: { email: normalizeEmail(body.ownerEmail ?? '') },
          select: { id: true },
        });
    if (!owner) throw refused('No such account.');
    return rule(() =>
      createAgencyByAdmin(
        this.prisma,
        { ownerUserId: owner.id, parentInviteCode: body.parentInviteCode ?? null, reason: body.reason },
        { timeZone: this.zone, specialGraceDays: this.config.specialUsernames.graceDays },
        viaOf(ctx),
      ),
    );
  }

  async suspend(id: string, reason: string, ctx: AdminContext) {
    await rule(() =>
      this.prisma.$transaction((tx) =>
        suspendHostAgentIn(tx, id, reason, new Date(), this.config.specialUsernames.graceDays, viaOf(ctx)),
      ),
    );
    return { suspended: true };
  }

  async reinstate(id: string, reason: string, ctx: AdminContext) {
    await rule(() =>
      this.prisma.$transaction((tx) =>
        reinstateHostAgentIn(tx, id, new Date(), this.config.specialUsernames.graceDays, viaOf(ctx), reason),
      ),
    );
    return { suspended: false };
  }

  // ---- v1.70-social (D206, §10.65): «افتح وكالة» — the application, the probation, closing and reopening --------

  /** A self-opened agency's application with its private fields (audited `agency.application.view`, via panel). */
  async application(agencyId: string, applicationId: string, ctx: AdminContext) {
    const app = await this.prisma.agencyApplication.findFirst({
      where: { id: applicationId, agencyId },
      include: {
        user: {
          select: { id: true, email: true, profile: { select: { username: true, displayName: true } } },
        },
      },
    });
    if (!app) throw new AppException(ErrorCode.NOT_FOUND);
    await this.audit.record({
      action: AuditAction.AGENCY_APPLICATION_VIEW,
      actorUserId: ctx.userId,
      targetType: 'agency_application',
      targetId: app.id,
      metadata: { agency: agencyId, via: 'panel' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    const purged = app.purgedAt !== null;
    return {
      id: app.id,
      agencyId,
      createdAt: app.createdAt.toISOString(),
      purgedAt: app.purgedAt?.toISOString() ?? null,
      user: {
        id: app.user.id,
        username: app.user.profile?.username ?? '',
        displayName: app.user.profile?.displayName ?? '',
        email: app.user.email,
      },
      name: app.name,
      country: app.country,
      contact: { type: app.contactType, value: purged ? null : app.contactValue },
      expectedHosts: app.expectedHosts,
      bio: purged ? null : app.bio,
      photos: { photo: !purged && app.photoKey !== null, selfie: !purged && app.selfieKey !== null },
    };
  }

  /** One of the application's pictures (the ID card or the selfie), audited per view; 404 when purged or missing. */
  async applicationPhoto(
    agencyId: string,
    applicationId: string,
    which: 'photo' | 'selfie',
    ctx: AdminContext,
  ): Promise<Buffer> {
    const app = await this.prisma.agencyApplication.findFirst({
      where: { id: applicationId, agencyId },
      select: { photoKey: true, selfieKey: true, purgedAt: true },
    });
    const key = app && app.purgedAt === null ? (which === 'photo' ? app.photoKey : app.selfieKey) : null;
    if (!key) throw new AppException(ErrorCode.NOT_FOUND);
    await this.audit.record({
      action: AuditAction.AGENCY_PHOTO_VIEW,
      actorUserId: ctx.userId,
      targetType: 'agency_application',
      targetId: applicationId,
      metadata: { which, agency: agencyId, via: 'panel' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    const bytes = await this.storage.get(key, 16 * 1024 * 1024);
    if (!bytes) throw new AppException(ErrorCode.NOT_FOUND);
    return bytes;
  }

  /** `economy-admin agency-probation-extend` from the panel (OWNER, the authenticator code again). */
  async extendProbation(
    id: string,
    body: { days: number; reason: string; totpCode: string },
    ctx: AdminContext,
  ) {
    await this.auth.reauthenticate(ctx, body.totpCode);
    return rule(() =>
      this.prisma.$transaction((tx) =>
        extendProbationIn(tx, id, body.days, body.reason, new Date(), viaOf(ctx)),
      ),
    );
  }

  /** `economy-admin agency-close` from the panel: hosts released, the owner told (OWNER, code again). */
  async close(id: string, body: { reason: string; totpCode: string }, ctx: AdminContext) {
    await this.auth.reauthenticate(ctx, body.totpCode);
    const { releasedHosts } = await rule(() =>
      this.prisma.$transaction((tx) =>
        closeAgencyByAdminIn(
          tx,
          id,
          body.reason,
          new Date(),
          this.config.specialUsernames.graceDays,
          viaOf(ctx),
        ),
      ),
    );
    if (releasedHosts.length > 0) await this.agencies.syncHostFrames(releasedHosts);
    return { status: 'CLOSED' as const, releasedHosts: releasedHosts.length };
  }

  /** `economy-admin agency-reopen` from the panel (OWNER, code again). */
  async reopen(id: string, body: { reason: string; totpCode: string }, ctx: AdminContext) {
    await this.auth.reauthenticate(ctx, body.totpCode);
    const r = await rule(() =>
      this.prisma.$transaction((tx) =>
        reopenAgencyIn(
          tx,
          id,
          body.reason,
          new Date(),
          this.agencies.probationRules,
          this.config.specialUsernames.graceDays,
          viaOf(ctx),
        ),
      ),
    );
    return { status: 'OPEN' as const, probationEndsAt: r.probationEndsAt };
  }

  async complaints(q: ComplaintsQuery, ctx: AdminContext) {
    const where: Prisma.AgencyComplaintWhereInput = { status: q.status };
    const [rows, total] = await Promise.all([
      this.prisma.agencyComplaint.findMany({
        where,
        orderBy: [{ createdAt: q.status === 'OPEN' ? 'asc' : 'desc' }, { id: 'asc' }],
        ...window(q),
        select: {
          id: true,
          status: true,
          resolution: true,
          text: true,
          note: true,
          createdAt: true,
          resolvedAt: true,
          hostUserId: true,
          agencyId: true,
        },
      }),
      this.prisma.agencyComplaint.count({ where }),
    ]);
    const [hosts, agencies] = await Promise.all([
      this.prisma.user.findMany({ where: { id: { in: rows.map((r) => r.hostUserId) } }, ...person }),
      this.prisma.agency.findMany({
        where: { id: { in: rows.map((r) => r.agencyId) } },
        select: { id: true, inviteCode: true },
      }),
    ]);
    const hostOf = new Map(hosts.map((h) => [h.id, h]));
    const agencyOf = new Map(agencies.map((x) => [x.id, x]));
    const data = rows.map((c) => ({
      id: c.id,
      status: c.status,
      resolution: c.resolution,
      text: c.text,
      note: c.note,
      createdAt: c.createdAt.toISOString(),
      resolvedAt: c.resolvedAt?.toISOString() ?? null,
      host: personDto(hostOf.get(c.hostUserId) ?? { id: c.hostUserId, profile: null }),
      agency: { id: c.agencyId, inviteCode: agencyOf.get(c.agencyId)?.inviteCode ?? '' },
    }));
    return tableResult(this.audit, ctx, 'agency-complaints', q, data, total, [
      ['id', (r) => r.id],
      ['status', (r) => r.status],
      ['resolution', (r) => r.resolution],
      ['agency', (r) => r.agency.inviteCode],
      ['host', (r) => r.host.username],
      ['text', (r) => r.text],
      ['created_at', (r) => r.createdAt],
    ]);
  }

  async resolveComplaint(
    id: string,
    body: { decision: ComplaintDecision; toInviteCode?: string | undefined; note: string },
    ctx: AdminContext,
  ) {
    const now = new Date();
    const result = await rule(() =>
      this.prisma.$transaction((tx) =>
        resolveComplaintIn(tx, id, body.decision, body.toInviteCode ?? null, body.note, now, viaOf(ctx)),
      ),
    );
    // D186: a released or moved host's active-host frame follows at once (as the CLI does).
    await this.agencies.syncHostFrames([result.hostUserId]);
    return { status: body.decision === 'keep' ? 'REJECTED' : 'RESOLVED' };
  }

  /** The rank evaluation and the active-host frames now (the sweeper's work, `economy-admin agency-evaluate`). */
  async evaluate(reason: string, ctx: AdminContext) {
    const { ranks, frames } = await this.agencies.evaluate();
    await this.audit.record({
      action: AuditAction.AGENCY_EVALUATE,
      actorUserId: ctx.userId,
      targetType: 'agency',
      targetId: '*',
      metadata: {
        rankChanges: ranks.length,
        frameChanges: frames.length,
        changes: ranks.slice(0, 50).map((c) => ({ agencyId: c.agencyId, from: c.from, to: c.to })),
        reason,
        via: 'panel',
      },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    return {
      rankChanges: ranks.map((c) => ({ agencyId: c.agencyId, from: c.from, to: c.to })),
      frameChanges: frames.length,
    };
  }
}
