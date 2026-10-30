import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { AgencyComplaint, AgencyRank } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { USER_SUMMARY_SELECT, userSummary, type PageDto } from '../posts/post-views.js';
import type { PageQuery } from '../posts/posts.schemas.js';
import { SocialCursorCodec } from '../posts/social-cursor.js';
import { agencyStandings, evaluateAgencyRanks, hostActivity, type RankChange } from './agency-ranks.js';
import { addMonths, agencyRateBps, dateValue, monthKey, normalizeInviteCode } from './economy-math.js';
import { assignMissingHostCodes, hostAgentPerksActive } from './host-agents.js';
import { syncHostFrames, type HostFrameChange } from './host-frames.js';

const DAY_MS = 86_400_000;

/** `AgencyPreview` (openapi v1.52-social, D179). */
export interface AgencyPreviewDto {
  inviteCode: string;
  owner: UserSummaryDto;
  rank: AgencyRank;
  hostCount: number;
}

/** `AgencyComplaint`. */
export interface AgencyComplaintDto {
  id: string;
  status: 'OPEN' | 'RESOLVED' | 'REJECTED';
  text: string;
  resolution: string | null;
  createdAt: string;
  resolvedAt: string | null;
}

/** `AgencyMembership`: the caller as a host. */
export interface AgencyMembershipDto {
  agency: AgencyPreviewDto;
  joinedAt: string;
  leaveUntil: string;
  canLeave: boolean;
  complaint: AgencyComplaintDto | null;
}

interface CommissionTotalsDto {
  thisMonth: number;
  lastMonth: number;
  total: number;
}

/** `AgencySubAgency`. */
export interface AgencySubAgencyDto {
  inviteCode: string;
  owner: UserSummaryDto;
  rank: AgencyRank;
  activeHosts: number;
  monthHostCherries: number;
  qualifies: boolean;
}

/** `OwnAgency`: the caller's own agency (the host agent's dashboard). */
export interface OwnAgencyDto {
  inviteCode: string;
  rank: AgencyRank;
  rankMonth: string | null;
  createdAt: string;
  timeZone: string;
  month: string;
  commissionRateBps: number;
  parent: AgencyPreviewDto | null;
  progress: {
    hostCount: number;
    activeHosts: number;
    requiredActiveHosts: number;
    monthHostCherries: number;
    lastMonthHostCherries: number;
    exceptionCherries: number;
    tierCherries: number;
    qualifiesNow: boolean;
    qualifiedSubAgencies: number;
    requiredSubAgencies: number;
  };
  commission: CommissionTotalsDto;
  parentCommission: CommissionTotalsDto;
  subAgencies: AgencySubAgencyDto[];
  /** v1.58-social (D189, §10.52): the owner as a host agent «وكيل مضيفين». */
  hostAgent: OwnHostAgentDto;
}

/** v1.58-social (D189, §10.52). */
export interface OwnHostAgentDto {
  /** `hostNN`; null until the sweeper gives an agency made before D189 its code. */
  code: string | null;
  /** The perks are on (not suspended by the team). */
  active: boolean;
  /** The code is the username shown now (false: suspended, or another special username activated first). */
  usernameShown: boolean;
}

/** `MyAgency`. */
export interface MyAgencyDto {
  membership: AgencyMembershipDto | null;
  ownAgency: OwnAgencyDto | null;
  activeHostRule: { minDays: number; minHours: number; windowDays: number };
  leaveDays: number;
}

/** `AgencyHost`: one host in the agent's list. */
export interface AgencyHostDto {
  user: UserSummaryDto;
  joinedAt: string;
  liveDays: number;
  liveSeconds: number;
  active: boolean;
  monthCherries: number;
  commissionEligible: boolean;
}

export const joinBodySchema = z.strictObject({ inviteCode: z.string().min(1).max(32) });
export const complaintBodySchema = z.strictObject({ text: z.string().trim().min(1).max(1000) });

function complaintDto(c: AgencyComplaint): AgencyComplaintDto {
  return {
    id: c.id,
    status: c.status,
    text: c.text,
    resolution: c.resolution,
    createdAt: c.createdAt.toISOString(),
    resolvedAt: c.resolvedAt?.toISOString() ?? null,
  };
}

/**
 * Host agencies «وكالة المضيفين» (v1.52-social, D179, CONVENTIONS §10.46, owner 2026-10-30): a host joins
 * with the agent's invite code and accepts; may leave within AGENCY_LEAVE_DAYS of joining, later only
 * through a complaint the admin resolves (`economy-admin`). The agent sees the rank and its progress, the
 * hosts with their activity and month cherries, the commissions and the sub-agencies. Ranks are
 * evaluated by the sweeper (month start: up or down; otherwise only up).
 */
@Injectable()
export class AgencyService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger('AgencyService');
  private readonly cursors: SocialCursorCodec;
  private timer: NodeJS.Timeout | undefined;
  private inFlight: Promise<void> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  onModuleInit(): void {
    if (this.config.economy.sweepIntervalSeconds > 0) this.schedule();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    await this.inFlight?.catch(() => undefined);
  }

  private schedule(): void {
    this.timer = setTimeout(() => {
      this.inFlight = this.evaluate()
        .then(async ({ ranks, frames }) => {
          if (ranks.length > 0) this.logger.log({ changes: ranks.length }, 'Agency ranks evaluated');
          if (frames.length > 0) this.logger.log({ changes: frames.length }, 'Host frames synced');
          // v1.58-social (D189, §10.52): agencies made before D189 get their host code (oldest first).
          const coded = await this.assignHostCodes();
          if (coded > 0) this.logger.log({ coded }, 'Host-agent codes given');
        })
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Agency rank evaluation failed');
        })
        .finally(() => {
          this.inFlight = null;
          this.schedule();
        });
    }, this.config.economy.sweepIntervalSeconds * 1000);
    this.timer.unref();
  }

  private get zone(): string {
    return this.config.live.rankingsTimeZone;
  }

  /** v1.58-social (D189): the sweeper's backfill of host codes. */
  assignHostCodes(): Promise<number> {
    return assignMissingHostCodes(this.prisma, this.clock.now(), this.config.specialUsernames.graceDays);
  }

  /** The rank evaluation (also `economy-admin agency-evaluate`). */
  evaluateRanks(): Promise<RankChange[]> {
    return evaluateAgencyRanks(this.prisma, this.clock.now(), this.config.economy, this.zone);
  }

  /**
   * The sweeper's work: the ranks, then (v1.55-social, D186) the active-host frames by the same
   * active-host test — given to hosts who became active, taken back from those who are not any more.
   */
  async evaluate(): Promise<{ ranks: RankChange[]; frames: HostFrameChange[] }> {
    const ranks = await this.evaluateRanks();
    const frames = await this.syncHostFrames();
    return { ranks, frames };
  }

  /** D186: the active-host frames of every host now, or of `userIds`. */
  syncHostFrames(userIds: readonly string[] | null = null): Promise<HostFrameChange[]> {
    return syncHostFrames(this.prisma, this.clock.now(), this.config.economy, this.zone, userIds);
  }

  private async preview(agencyId: string): Promise<AgencyPreviewDto | null> {
    const a = await this.prisma.agency.findUnique({
      where: { id: agencyId },
      select: {
        inviteCode: true,
        rank: true,
        owner: { select: { ...USER_SUMMARY_SELECT, status: true } },
        _count: { select: { hosts: { where: { status: 'ACTIVE' } } } },
      },
    });
    if (!a || a.owner.status !== 'ACTIVE') return null;
    return { inviteCode: a.inviteCode, owner: userSummary(a.owner), rank: a.rank, hostCount: a._count.hosts };
  }

  /** `GET /agencies/{inviteCode}`: 404 for an unknown code or an owner who is not ACTIVE. */
  async byCode(raw: string): Promise<AgencyPreviewDto> {
    const code = normalizeInviteCode(raw);
    const agency =
      code === null ? null : await this.prisma.agency.findUnique({ where: { inviteCode: code } });
    const preview = agency ? await this.preview(agency.id) : null;
    if (!preview) throw new AppException(ErrorCode.NOT_FOUND);
    return preview;
  }

  /** `GET /me/agency`. */
  async mine(me: string): Promise<MyAgencyDto> {
    const e = this.config.economy;
    const [membership, ownAgency] = await Promise.all([this.membership(me), this.ownAgency(me)]);
    return {
      membership,
      ownAgency,
      activeHostRule: {
        minDays: e.activeHostMinDays,
        minHours: e.activeHostMinHours,
        windowDays: e.activeHostWindowDays,
      },
      leaveDays: e.leaveDays,
    };
  }

  private async membership(me: string): Promise<AgencyMembershipDto | null> {
    const link = await this.prisma.agencyHost.findFirst({ where: { hostUserId: me, status: 'ACTIVE' } });
    if (!link) return null;
    const agency = await this.preview(link.agencyId);
    if (!agency) return null;
    const complaint = await this.prisma.agencyComplaint.findFirst({
      where: { agencyHostId: link.id },
      orderBy: { createdAt: 'desc' },
    });
    const leaveUntil = new Date(link.activatedAt.getTime() + this.config.economy.leaveDays * DAY_MS);
    return {
      agency,
      joinedAt: link.activatedAt.toISOString(),
      leaveUntil: leaveUntil.toISOString(),
      canLeave: this.clock.now() < leaveUntil,
      complaint: complaint ? complaintDto(complaint) : null,
    };
  }

  private async ownAgency(me: string): Promise<OwnAgencyDto | null> {
    const agency = await this.prisma.agency.findUnique({ where: { ownerUserId: me } });
    if (!agency) return null;
    const e = this.config.economy;
    const now = this.clock.now();
    const month = monthKey(now, this.zone);
    const previous = addMonths(month, -1);
    const standings = await agencyStandings(this.prisma, now, e, this.zone, [agency.id]);
    const self = standings.get(agency.id)!;
    const [months, totals, hostCount, subs, parent, profile] = await Promise.all([
      this.prisma.agencyMonth.findMany({
        where: { agencyId: agency.id, month: { in: [dateValue(month), dateValue(previous)] } },
      }),
      this.prisma.agencyMonth.aggregate({
        where: { agencyId: agency.id },
        _sum: { commission: true, parentCommission: true },
      }),
      this.prisma.agencyHost.count({ where: { agencyId: agency.id, status: 'ACTIVE' } }),
      this.prisma.agency.findMany({
        where: { parentAgencyId: agency.id },
        orderBy: { createdAt: 'asc' },
        select: { id: true, inviteCode: true, rank: true, owner: { select: USER_SUMMARY_SELECT } },
      }),
      agency.parentAgencyId ? this.preview(agency.parentAgencyId) : Promise.resolve(null),
      this.prisma.userProfile.findUnique({ where: { userId: me }, select: { username: true } }),
    ]);
    const cur = months.find((m) => m.month.toISOString().startsWith(month));
    const prev = months.find((m) => m.month.toISOString().startsWith(previous));
    return {
      inviteCode: agency.inviteCode,
      rank: agency.rank,
      rankMonth: agency.rankMonth?.toISOString().slice(0, 10) ?? null,
      createdAt: agency.createdAt.toISOString(),
      timeZone: this.zone,
      month: month.slice(0, 7),
      commissionRateBps: agencyRateBps(prev?.hostCherries ?? 0n, e),
      parent,
      progress: {
        hostCount,
        activeHosts: self.activeHosts,
        requiredActiveHosts: e.rankMinActiveHosts,
        monthHostCherries: Number(cur?.hostCherries ?? 0n),
        lastMonthHostCherries: Number(prev?.hostCherries ?? 0n),
        exceptionCherries: e.rankExceptionCherries,
        tierCherries: e.agencyTierMonthlyCherries,
        qualifiesNow: self.selfQualifies,
        qualifiedSubAgencies: self.qualifiedSubAgencies,
        requiredSubAgencies: e.adminMinSubAgencies,
      },
      commission: {
        thisMonth: Number(cur?.commission ?? 0n),
        lastMonth: Number(prev?.commission ?? 0n),
        total: Number(totals._sum.commission ?? 0n),
      },
      parentCommission: {
        thisMonth: Number(cur?.parentCommission ?? 0n),
        lastMonth: Number(prev?.parentCommission ?? 0n),
        total: Number(totals._sum.parentCommission ?? 0n),
      },
      subAgencies: subs.map((s) => {
        const st = standings.get(s.id);
        return {
          inviteCode: s.inviteCode,
          owner: userSummary(s.owner),
          rank: s.rank,
          activeHosts: st?.activeHosts ?? 0,
          monthHostCherries: Number(st?.monthHostCherries ?? 0n),
          qualifies: st?.selfQualifies ?? false,
        };
      }),
      hostAgent: {
        code: agency.hostCode,
        active: hostAgentPerksActive(agency),
        usernameShown: agency.hostCode !== null && profile?.username === agency.hostCode,
      },
    };
  }

  /**
   * `POST /me/agency/join {inviteCode}` — the host accepts the agency of the code. Order: 400 → 404 (unknown
   * code, owner not ACTIVE) → 409 AGENCY_JOIN_NOT_ALLOWED (the caller owns an agency) → already a host of
   * this agency → 200 → 409 AGENCY_ALREADY_MEMBER (another agency) → 201.
   */
  async join(me: string, body: unknown): Promise<{ created: boolean; result: MyAgencyDto }> {
    const parsed = joinBodySchema.safeParse(body);
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const code = normalizeInviteCode(parsed.data.inviteCode);
    if (code === null) throw new AppException(ErrorCode.NOT_FOUND);
    const agency = await this.prisma.agency.findUnique({
      where: { inviteCode: code },
      select: { id: true, rank: true, owner: { select: { status: true } } },
    });
    if (!agency || agency.owner.status !== 'ACTIVE') throw new AppException(ErrorCode.NOT_FOUND);
    if ((await this.prisma.agency.count({ where: { ownerUserId: me } })) > 0) {
      throw new AppException(ErrorCode.AGENCY_JOIN_NOT_ALLOWED);
    }
    const existing = async () => {
      const link = await this.prisma.agencyHost.findFirst({
        where: { hostUserId: me, status: 'ACTIVE' },
        select: { agencyId: true },
      });
      if (!link) return null;
      if (link.agencyId !== agency.id) throw new AppException(ErrorCode.AGENCY_ALREADY_MEMBER);
      return { created: false, result: await this.mine(me) };
    };
    const before = await existing();
    if (before) return before;
    try {
      await this.prisma.$transaction(async (tx) => {
        const id = uuidv7();
        await tx.agencyHost.create({
          data: {
            id,
            agencyId: agency.id,
            hostUserId: me,
            commissionEligible: agency.rank !== 'LAPSED',
            activatedAt: this.clock.now(),
          },
        });
        await tx.auditLog.create({
          data: {
            actorUserId: me,
            action: AuditAction.AGENCY_JOIN,
            targetType: 'agency',
            targetId: agency.id,
            metadata: { link: id, rank: agency.rank },
          },
        });
      });
    } catch (err) {
      // A concurrent join (the partial unique index `agency_hosts_one_active`).
      const raced = await existing();
      if (raced) return raced;
      throw err;
    }
    // D186: past live time counts, so a new host may be active (and get the frame) at once.
    await this.syncHostFrames([me]);
    return { created: true, result: await this.mine(me) };
  }

  /** `POST /me/agency/leave`: 404 not a host → 409 AGENCY_LEAVE_WINDOW_CLOSED → 200. */
  async leave(me: string): Promise<MyAgencyDto> {
    const now = this.clock.now();
    const link = await this.prisma.agencyHost.findFirst({ where: { hostUserId: me, status: 'ACTIVE' } });
    if (!link) throw new AppException(ErrorCode.NOT_FOUND);
    if (now.getTime() >= link.activatedAt.getTime() + this.config.economy.leaveDays * DAY_MS) {
      throw new AppException(ErrorCode.AGENCY_LEAVE_WINDOW_CLOSED);
    }
    await this.prisma.$transaction(async (tx) => {
      const ended = await tx.agencyHost.updateMany({
        where: { id: link.id, status: 'ACTIVE' },
        data: { status: 'LEFT', endedAt: now },
      });
      if (ended.count === 0) return;
      // An open complaint has no object any more.
      await tx.agencyComplaint.updateMany({
        where: { agencyHostId: link.id, status: 'OPEN' },
        data: {
          status: 'RESOLVED',
          resolution: 'RELEASED',
          note: 'left in the leave window',
          resolvedAt: now,
        },
      });
      await tx.auditLog.create({
        data: {
          actorUserId: me,
          action: AuditAction.AGENCY_LEAVE,
          targetType: 'agency',
          targetId: link.agencyId,
          metadata: { link: link.id },
        },
      });
    });
    // D186: no agency, no active-host frame.
    await this.syncHostFrames([me]);
    return this.mine(me);
  }

  /** `POST /me/agency/complaints {text}`: 404 not a host → 400 → an open complaint → 200 → 201. */
  async complain(me: string, body: unknown): Promise<{ created: boolean; result: AgencyComplaintDto }> {
    const link = await this.prisma.agencyHost.findFirst({ where: { hostUserId: me, status: 'ACTIVE' } });
    if (!link) throw new AppException(ErrorCode.NOT_FOUND);
    const parsed = complaintBodySchema.safeParse(body);
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const open = () =>
      this.prisma.agencyComplaint.findFirst({ where: { agencyHostId: link.id, status: 'OPEN' } });
    const before = await open();
    if (before) return { created: false, result: complaintDto(before) };
    try {
      const created = await this.prisma.$transaction(async (tx) => {
        const row = await tx.agencyComplaint.create({
          data: {
            id: uuidv7(),
            agencyHostId: link.id,
            hostUserId: me,
            agencyId: link.agencyId,
            text: parsed.data.text,
            createdAt: this.clock.now(),
          },
        });
        await tx.auditLog.create({
          data: {
            actorUserId: me,
            action: AuditAction.AGENCY_COMPLAINT,
            targetType: 'agency_complaint',
            targetId: row.id,
            metadata: { agency: link.agencyId },
          },
        });
        return row;
      });
      return { created: true, result: complaintDto(created) };
    } catch (err) {
      const raced = await open();
      if (raced) return { created: false, result: complaintDto(raced) };
      throw err;
    }
  }

  /** `GET /me/agency/hosts`: the caller's agency's ACTIVE hosts, newest first (404 without an agency). */
  async hosts(me: string, query: PageQuery): Promise<PageDto<AgencyHostDto>> {
    const agency = await this.prisma.agency.findUnique({ where: { ownerUserId: me }, select: { id: true } });
    if (!agency) throw new AppException(ErrorCode.NOT_FOUND);
    const scope = `agency-hosts:${agency.id}`;
    let after = null;
    if (query.cursor !== undefined) {
      after = this.cursors.decode(query.cursor, scope);
      if (!after) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    }
    const links = await this.prisma.agencyHost.findMany({
      where: {
        agencyId: agency.id,
        status: 'ACTIVE',
        ...(after
          ? { OR: [{ activatedAt: { lt: after.at } }, { activatedAt: after.at, id: { lt: after.id } }] }
          : {}),
      },
      orderBy: [{ activatedAt: 'desc' }, { id: 'desc' }],
      take: query.limit + 1,
      select: {
        id: true,
        activatedAt: true,
        commissionEligible: true,
        hostUserId: true,
        host: { select: USER_SUMMARY_SELECT },
      },
    });
    const hasMore = links.length > query.limit;
    const page = links.slice(0, query.limit);
    const now = this.clock.now();
    const ids = page.map((l) => l.hostUserId);
    const [activity, cherries] = await Promise.all([
      ids.length === 0
        ? []
        : hostActivity(this.prisma, [agency.id], now, this.config.economy, this.zone, ids),
      ids.length === 0
        ? []
        : this.prisma.agencyEarning.groupBy({
            by: ['hostUserId'],
            where: {
              agencyId: agency.id,
              month: dateValue(monthKey(now, this.zone)),
              hostUserId: { in: ids },
              reversedAt: null,
            },
            _sum: { hostCherries: true },
          }),
    ]);
    const act = new Map(activity.map((a) => [a.hostUserId, a]));
    const month = new Map(cherries.map((c) => [c.hostUserId, c._sum.hostCherries ?? 0n]));
    const last = page[page.length - 1];
    return {
      data: page.map((l) => {
        const a = act.get(l.hostUserId);
        return {
          user: userSummary(l.host),
          joinedAt: l.activatedAt.toISOString(),
          liveDays: a?.liveDays ?? 0,
          liveSeconds: a?.liveSeconds ?? 0,
          active: a?.active ?? false,
          monthCherries: Number(month.get(l.hostUserId) ?? 0n),
          commissionEligible: l.commissionEligible,
        };
      }),
      page: {
        hasMore,
        nextCursor:
          hasMore && last ? this.cursors.encode(scope, { at: last.activatedAt, id: last.id }) : null,
      },
    };
  }
}
