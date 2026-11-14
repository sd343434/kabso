import { Inject, Injectable } from '@nestjs/common';
import { Prisma } from '../../generated/prisma/client.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { normalizeInviteCode } from '../economy/economy-math.js';
import { dayStart } from '../recharge/recharge-rules.js';
import type { AdminContext } from './admin-auth.service.js';
import { can } from './admin-permissions.js';
import { AdminUsersService } from './admin-users.service.js';

const DAY_MS = 86_400_000;
/** The KPI cards' sparkline: the last 14 days, today included. */
export const SPARK_DAYS = 14;

/** YYYY-MM-DD of `at` in `zone`. */
export function dayKey(at: Date, zone: string): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: zone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(at);
}

/** The `days` day keys ending today (oldest first) and the instant the first one starts. */
export function dayWindow(now: Date, days: number, zone: string): { keys: string[]; from: Date } {
  const today = dayStart(now, zone);
  const keys: string[] = [];
  // Noon of each day avoids a DST edge putting two keys on one day.
  for (let i = days - 1; i >= 0; i--)
    keys.push(dayKey(new Date(today.getTime() - i * DAY_MS + DAY_MS / 2), zone));
  const from = dayStart(new Date(today.getTime() - (days - 1) * DAY_MS + DAY_MS / 2), zone);
  return { keys, from };
}

type DayRow = { day: string; n: bigint | number | null };

function byDay(rows: DayRow[]): Map<string, number> {
  return new Map(rows.map((r) => [r.day, Number(r.n ?? 0)]));
}

export interface StatsDay {
  day: string;
  newUsers: number;
  agentCoins: number;
  websiteCoins: number;
  coinsSold: number;
  giftCoins: number;
  giftsSent: number;
  livesStarted: number;
  newPending: number;
}

/**
 * The panel's read-only statistics (v1.65-social, D197, CONVENTIONS §10.60.1): real aggregates per **Asia/Riyadh
 * day** (`ADMIN_DASHBOARD_TIME_ZONE`, the D191 owner answer), each one a range scan of one indexed time column
 * (migration 20270112100000_admin_v2) grouped by the local day — the KPI cards (today, yesterday, a 14-day
 * sparkline), the 7/30/90-day chart, «يحتاج انتباهك» (the pending queues the admin's roles can act on), the recent
 * panel activity and the top bar's quick search. Nothing here changes anything.
 */
@Injectable()
export class AdminStatsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly users: AdminUsersService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  private get zone(): string {
    return this.config.adminPanel.dashboardTimeZone;
  }

  /** Every per-day aggregate of the window [from, now]. */
  async days(now: Date, count: number): Promise<StatsDay[]> {
    const zone = this.zone;
    const { keys, from } = dayWindow(now, count, zone);
    const local = (col: 'created_at' | 'credited_at' | 'started_at') =>
      Prisma.sql`to_char(timezone(${zone}::text, ${Prisma.raw(col)}), 'YYYY-MM-DD')`;
    const [users, sales, web, gifts, lives, apps, wds, reports, complaints, cases] = await Promise.all([
      this.prisma.$queryRaw<DayRow[]>`
        SELECT ${local('created_at')} AS day, count(*) AS n FROM users WHERE created_at >= ${from} GROUP BY 1`,
      this.prisma.$queryRaw<DayRow[]>`
        SELECT ${local('created_at')} AS day, sum(coins) AS n FROM recharge_sales WHERE created_at >= ${from} GROUP BY 1`,
      this.prisma.$queryRaw<DayRow[]>`
        SELECT ${local('credited_at')} AS day, sum(coins) AS n FROM topup_orders
         WHERE credited_at IS NOT NULL AND credited_at >= ${from} GROUP BY 1`,
      this.prisma.$queryRaw<(DayRow & { c: bigint })[]>`
        SELECT ${local('created_at')} AS day, sum(total_coins) AS n, count(*) AS c FROM live_gifts
         WHERE created_at >= ${from} GROUP BY 1`,
      this.prisma.$queryRaw<DayRow[]>`
        SELECT ${local('started_at')} AS day, count(*) AS n FROM live_rooms WHERE started_at >= ${from} GROUP BY 1`,
      this.prisma.$queryRaw<DayRow[]>`
        SELECT ${local('created_at')} AS day, count(*) AS n FROM recharge_agent_applications
         WHERE created_at >= ${from} GROUP BY 1`,
      this.prisma.$queryRaw<DayRow[]>`
        SELECT ${local('created_at')} AS day, count(*) AS n FROM cherry_withdrawals WHERE created_at >= ${from} GROUP BY 1`,
      this.prisma.$queryRaw<DayRow[]>`
        SELECT ${local('created_at')} AS day, count(*) AS n FROM reports WHERE created_at >= ${from} GROUP BY 1`,
      this.prisma.$queryRaw<DayRow[]>`
        SELECT ${local('created_at')} AS day, count(*) AS n FROM agency_complaints WHERE created_at >= ${from} GROUP BY 1`,
      this.prisma.$queryRaw<DayRow[]>`
        SELECT ${local('created_at')} AS day, count(*) AS n FROM topup_cases WHERE created_at >= ${from} GROUP BY 1`,
    ]);
    const m = {
      users: byDay(users),
      sales: byDay(sales),
      web: byDay(web),
      gifts: byDay(gifts),
      giftCount: new Map(gifts.map((r) => [r.day, Number(r.c)])),
      lives: byDay(lives),
      pending: [apps, wds, reports, complaints, cases].map(byDay),
    };
    return keys.map((day) => {
      const agentCoins = m.sales.get(day) ?? 0;
      const websiteCoins = m.web.get(day) ?? 0;
      return {
        day,
        newUsers: m.users.get(day) ?? 0,
        agentCoins,
        websiteCoins,
        coinsSold: agentCoins + websiteCoins,
        giftCoins: m.gifts.get(day) ?? 0,
        giftsSent: m.giftCount.get(day) ?? 0,
        livesStarted: m.lives.get(day) ?? 0,
        newPending: m.pending.reduce((n, map) => n + (map.get(day) ?? 0), 0),
      };
    });
  }

  /** The KPI cards: today, yesterday and the 14-day sparkline of each; lives and pending also as of now. */
  async overview(now = new Date()) {
    const [days, livesNow, pending] = await Promise.all([
      this.days(now, SPARK_DAYS),
      this.prisma.liveRoom.count({ where: { status: 'LIVE' } }),
      this.pendingCounts(),
    ]);
    const today = days[days.length - 1]!;
    const yesterday = days[days.length - 2]!;
    const kpi = (pick: (d: StatsDay) => number, value?: number) => ({
      value: value ?? pick(today),
      today: pick(today),
      yesterday: pick(yesterday),
      spark: days.map(pick),
    });
    return {
      since: dayStart(now, this.zone).toISOString(),
      timeZone: this.zone,
      kpis: {
        newUsers: kpi((d) => d.newUsers),
        coinsSold: {
          ...kpi((d) => d.coinsSold),
          agentsToday: today.agentCoins,
          websiteToday: today.websiteCoins,
        },
        giftCoins: { ...kpi((d) => d.giftCoins), giftsToday: today.giftsSent },
        lives: kpi((d) => d.livesStarted, livesNow),
        pending: kpi(
          (d) => d.newPending,
          Object.values(pending).reduce((a, b) => a + b, 0),
        ),
      },
    };
  }

  /** The chart: one row per day of the last 7, 30 or 90 days. */
  async series(days: 7 | 30 | 90, now = new Date()) {
    return { timeZone: this.zone, days: await this.days(now, days) };
  }

  private async pendingCounts() {
    const [rechargeApplications, withdrawals, reports, agencyComplaints, topupCases] = await Promise.all([
      this.prisma.rechargeAgentApplication.count({ where: { status: 'PENDING' } }),
      this.prisma.cherryWithdrawal.count({ where: { status: 'PENDING' } }),
      this.prisma.report.count({ where: { status: 'OPEN' } }),
      this.prisma.agencyComplaint.count({ where: { status: 'OPEN' } }),
      this.prisma.topupCase.count({ where: { status: 'OPEN' } }),
    ]);
    return { rechargeApplications, withdrawals, reports, agencyComplaints, topupCases };
  }

  /**
   * «يحتاج انتباهك» and the bell: the pending queues this admin's roles can open, with the count and the oldest
   * waiting item. Account deletion requests are not in this base (D193 not merged): not listed.
   */
  async attention(ctx: AdminContext) {
    const oldest = async (
      kind: string,
      count: Promise<number>,
      first: Promise<{ createdAt: Date } | null>,
    ) => {
      const [n, row] = await Promise.all([count, first]);
      return { kind, count: n, oldestAt: row?.createdAt.toISOString() ?? null };
    };
    const asc = { orderBy: { createdAt: 'asc' as const }, select: { createdAt: true } };
    const jobs: Promise<{ kind: string; count: number; oldestAt: string | null }>[] = [];
    if (can(ctx.roles, 'recharge.applications')) {
      const where = { status: 'PENDING' as const };
      jobs.push(
        oldest(
          'RECHARGE_APPLICATIONS',
          this.prisma.rechargeAgentApplication.count({ where }),
          this.prisma.rechargeAgentApplication.findFirst({ where, ...asc }),
        ),
      );
    }
    if (can(ctx.roles, 'withdrawals.view')) {
      const where = { status: 'PENDING' as const };
      jobs.push(
        oldest(
          'WITHDRAWALS',
          this.prisma.cherryWithdrawal.count({ where }),
          this.prisma.cherryWithdrawal.findFirst({ where, ...asc }),
        ),
      );
    }
    if (can(ctx.roles, 'reports.view')) {
      const where = { status: 'OPEN' as const };
      jobs.push(
        oldest(
          'REPORTS',
          this.prisma.report.count({ where }),
          this.prisma.report.findFirst({ where, ...asc }),
        ),
      );
    }
    if (can(ctx.roles, 'agencies.view')) {
      const where = { status: 'OPEN' as const };
      jobs.push(
        oldest(
          'AGENCY_COMPLAINTS',
          this.prisma.agencyComplaint.count({ where }),
          this.prisma.agencyComplaint.findFirst({ where, ...asc }),
        ),
      );
    }
    if (can(ctx.roles, 'finance.view')) {
      const where = { status: 'OPEN' as const };
      jobs.push(
        oldest(
          'TOPUP_CASES',
          this.prisma.topupCase.count({ where }),
          this.prisma.topupCase.findFirst({ where, ...asc }),
        ),
      );
    }
    const items = await Promise.all(jobs);
    return { total: items.reduce((n, i) => n + i.count, 0), items };
  }

  /**
   * The latest panel changes (audit rows with `via: panel`, sign-ins excluded). An OWNER sees the whole team's; any
   * other role sees only its own (an audit row can carry a reason about a user).
   */
  async activity(ctx: AdminContext, limit = 12) {
    const rows = await this.prisma.auditLog.findMany({
      where: {
        metadata: { path: ['via'], equals: 'panel' },
        // Changes only: no sign-ins and no views of private data (those stay in the audit log).
        NOT: [{ action: { startsWith: 'admin.login' } }, { action: { endsWith: 'view' } }],
        ...(ctx.roles.includes('OWNER') ? { actorUserId: { not: null } } : { actorUserId: ctx.userId }),
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit,
      select: {
        id: true,
        action: true,
        targetType: true,
        targetId: true,
        createdAt: true,
        actor: { select: { id: true, profile: { select: { username: true, displayName: true } } } },
      },
    });
    return {
      data: rows.map((r) => ({
        id: r.id,
        action: r.action,
        targetType: r.targetType,
        targetId: r.targetId,
        createdAt: r.createdAt.toISOString(),
        actor: r.actor
          ? {
              id: r.actor.id,
              username: r.actor.profile?.username ?? '',
              displayName: r.actor.profile?.displayName ?? '',
            }
          : null,
      })),
    };
  }

  /**
   * The top bar's quick search: users (as `searchAdminUsers`: id, email prefix, shown/base/special username),
   * recharge agents by code (`coin…`) and agencies by invite or host code (`host…`), by the admin's capabilities.
   */
  async search(q: string, ctx: AdminContext) {
    const value = q.trim();
    const lower = value.toLowerCase().replace(/^@/, '');
    const [users, agents, agencies] = await Promise.all([
      this.users.search(value, 6).then((r) => r.data),
      can(ctx.roles, 'recharge.agents')
        ? this.prisma.rechargeAgent.findMany({
            where: { code: { startsWith: lower } },
            orderBy: { code: 'asc' },
            take: 5,
            select: {
              userId: true,
              code: true,
              status: true,
              user: { select: { profile: { select: { username: true, displayName: true } } } },
            },
          })
        : Promise.resolve([]),
      can(ctx.roles, 'agencies.view')
        ? this.prisma.agency.findMany({
            where: {
              OR: [
                ...(normalizeInviteCode(value) ? [{ inviteCode: normalizeInviteCode(value)! }] : []),
                { hostCode: { startsWith: lower } },
              ],
            },
            orderBy: { createdAt: 'asc' },
            take: 5,
            select: {
              id: true,
              inviteCode: true,
              hostCode: true,
              rank: true,
              suspendedAt: true,
              owner: { select: { profile: { select: { username: true, displayName: true } } } },
            },
          })
        : Promise.resolve([]),
    ]);
    return {
      users,
      agents: agents.map((a) => ({
        userId: a.userId,
        code: a.code,
        status: a.status,
        username: a.user.profile?.username ?? '',
        displayName: a.user.profile?.displayName ?? '',
      })),
      agencies: agencies.map((a) => ({
        id: a.id,
        inviteCode: a.inviteCode,
        hostCode: a.hostCode,
        rank: a.rank,
        suspended: a.suspendedAt !== null,
        ownerUsername: a.owner.profile?.username ?? '',
        ownerDisplayName: a.owner.profile?.displayName ?? '',
      })),
    };
  }
}
