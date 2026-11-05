import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { topupMinorPerMillion } from '../../config/env.schema.js';
import { Prisma, type StaffRecruitment } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { CherriesService, type CherryWalletDto } from '../economy/cherries.service.js';
import { creditRecruitCommissionIn } from '../economy/cherry-ledger.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import type { ProfitEconomy } from '../programs/host-target-engine.js';
import { dateValue, programWindowsIn } from '../programs/programs-time.js';
import {
  bpsOf,
  findRecruiter,
  recruiterRoleOf,
  recruitProfitIn,
  recruitSettingsIn,
  type StaffRecruiterDto,
} from './recruit-core.js';
import {
  RECRUIT_TYPES,
  commissionCherries,
  recruitCommissionReference,
  unitsToUsd,
  withinGuard,
  type RecruitType,
} from './recruit-math.js';

type Db = Prisma.TransactionClient | PrismaService;

/** `StaffRecruiterLookup`: the forms' live check of the recruiter field. */
export interface StaffRecruiterLookupDto {
  found: boolean;
  recruiter: {
    staffId: string | null;
    username: string;
    displayName: string;
    avatarUrl: string | null;
    role: 'MODERATION' | 'BD';
  } | null;
}

/** Where a recruit stands now (per type): ACTIVE, or INACTIVE (suspended, closed, no longer a host, account off). */
export type RecruitStatus = 'ACTIVE' | 'INACTIVE';

/** `StaffRecruit`: one recruit of a recruiter, as the app's «استقطاباتي» and the panel show it. */
export interface StaffRecruitDto {
  id: string;
  type: RecruitType;
  recruit: UserSummaryDto;
  status: RecruitStatus;
  activatedAt: string;
  /** The platform profit counted for this recruit so far (paid days), US dollars. */
  profitUsd: number;
  /** The same over the last 30 paid days. */
  profitUsd30d: number;
  /** The commissions credited for this recruit (to whoever was the recruiter that day). */
  commissionCherries: number;
  /** The last day paid (`YYYY-MM-DD`), null before the first. */
  lastDay: string | null;
}

/** `StaffEarnings`: «أرباحي». */
export interface StaffEarningsDto {
  /** The cherry wallet (the same as `getMyCherryWallet`): balance, withdrawable, payout rules, pending withdrawal. */
  wallet: CherryWalletDto;
  /** Every STAFF_RECRUIT_COMMISSION credited to the caller. */
  totalCherries: number;
  last30DaysCherries: number;
  /** The shares in effect (bps). */
  bps: Record<RecruitType, number>;
  /** Per recruit: what the caller earned from each (newest recruit first). */
  byRecruit: { recruitmentId: string; type: RecruitType; recruit: UserSummaryDto; cherries: number }[];
  /** The last 60 days credited to the caller (newest first; days without a commission are left out). */
  history: {
    day: string;
    recruitmentId: string;
    type: RecruitType;
    recruit: UserSummaryDto;
    profitUsd: number;
    bps: number;
    cherries: number;
  }[];
}

/** What one run of the daily job did. */
export interface RecruitSweep {
  days: number;
  paid: number;
  cherries: bigint;
  skipped: number;
}

const typeQuery = z.strictObject({ type: z.enum(RECRUIT_TYPES).optional() });

@Injectable()
export class RecruitsService {
  private readonly logger = new Logger(RecruitsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly cherries: CherriesService,
  ) {}

  /** D281's economy constants (configuration). */
  economy(): ProfitEconomy {
    const e = this.config.economy;
    return {
      cherriesPerCoin: e.cherriesPerCoin,
      coinCentsPerMillion:
        topupMinorPerMillion(e.coinRetailUsdPerMillion) ?? Math.round(e.coinRetailUsdPerMillion * 100),
      rateCherries: e.rateCherries,
      rateMinor: e.rateMinor,
      luckyRtpBps: this.config.lucky.table.rtpBps,
      luckyHostShareBps: this.config.lucky.table.hostShareBps,
      hostShareBps: this.config.gifts.hostShareBps,
    };
  }

  private get zone(): string {
    return this.config.live.rankingsTimeZone;
  }

  // ---- The forms' live check ---------------------------------------------------------------------------------------

  /** `GET /staff-recruiters/lookup?q=`: who the recruiter field names (only a recruiter is ever found). */
  async lookup(raw: unknown): Promise<StaffRecruiterLookupDto> {
    const q = z.strictObject({ q: z.string().trim().min(1).max(64) }).safeParse(raw);
    if (!q.success) throw AppException.validation([{ field: 'q', issue: 'required' }]);
    const found = await findRecruiter(this.prisma, q.data.q);
    return { found: found !== null, recruiter: found ? publicRecruiter(found) : null };
  }

  // ---- The recruiter's own views (app and panel) --------------------------------------------------------------------

  /** 403 AUTH_FORBIDDEN unless the caller can recruit now (MODERATION or BD). */
  async requireRecruiter(userId: string): Promise<void> {
    if ((await recruiterRoleOf(this.prisma, userId)) === null)
      throw new AppException(ErrorCode.AUTH_FORBIDDEN);
  }

  /** The recruits of `recruiterId` (or everyone's when null: the OWNER's view), newest first. */
  async recruits(
    recruiterId: string | null,
    type: RecruitType | undefined,
  ): Promise<(StaffRecruitDto & { recruiter: UserSummaryDto; reassignedAt: string | null })[]> {
    const rows = await this.prisma.staffRecruitment.findMany({
      where: { ...(recruiterId ? { recruiterUserId: recruiterId } : {}), ...(type ? { type } : {}) },
      orderBy: [{ activatedAt: 'desc' }, { id: 'desc' }],
      take: 500,
      include: { recruit: { select: USER_SUMMARY_SELECT }, recruiter: { select: USER_SUMMARY_SELECT } },
    });
    if (rows.length === 0) return [];
    const now = this.clock.now();
    const e = this.economy();
    const ids = rows.map((r) => r.id);
    const since = new Date(now.getTime() - 30 * 86_400_000).toISOString().slice(0, 10);
    const sums = await this.prisma.$queryRaw<
      { id: string; profit: Prisma.Decimal; profit30: Prisma.Decimal; cherries: bigint; last: Date | null }[]
    >`
      SELECT recruitment_id::text AS id, COALESCE(sum(profit_units), 0) AS profit,
             COALESCE(sum(profit_units) FILTER (WHERE day >= ${since}::date), 0) AS profit30,
             COALESCE(sum(cherries), 0)::bigint AS cherries, max(day) AS last
        FROM staff_recruit_commissions
       WHERE recruitment_id IN (${Prisma.join(ids.map((id) => Prisma.sql`${id}::uuid`))})
       GROUP BY recruitment_id`;
    const byId = new Map(sums.map((s) => [s.id, s]));
    const status = await this.statusesOf(rows);
    return rows.map((r) => {
      const s = byId.get(r.id);
      return {
        id: r.id,
        type: r.type,
        recruit: userSummary(r.recruit, now),
        recruiter: userSummary(r.recruiter, now),
        status: status.get(r.id) ?? 'INACTIVE',
        activatedAt: r.activatedAt.toISOString(),
        reassignedAt: r.reassignedAt?.toISOString() ?? null,
        profitUsd: unitsToUsd(BigInt(s ? s.profit.toFixed(0) : '0'), e),
        profitUsd30d: unitsToUsd(BigInt(s ? s.profit30.toFixed(0) : '0'), e),
        commissionCherries: Number(s?.cherries ?? 0n),
        lastDay: s?.last ? s.last.toISOString().slice(0, 10) : null,
      };
    });
  }

  /** Each recruit's standing now (see {@link RecruitStatus}). */
  private async statusesOf(rows: readonly StaffRecruitment[]): Promise<Map<string, RecruitStatus>> {
    const out = new Map<string, RecruitStatus>();
    const users = [...new Set(rows.map((r) => r.recruitUserId))];
    const [accounts, hosts, agencies, agents, creators] = await Promise.all([
      this.prisma.user.findMany({ where: { id: { in: users } }, select: { id: true, status: true } }),
      this.prisma.liveHost.findMany({ where: { userId: { in: users } }, select: { userId: true } }),
      this.prisma.agency.findMany({
        where: { id: { in: rows.flatMap((r) => (r.agencyId ? [r.agencyId] : [])) } },
        select: { id: true, status: true, suspendedAt: true },
      }),
      this.prisma.rechargeAgent.findMany({
        where: { userId: { in: users } },
        select: { userId: true, status: true },
      }),
      this.prisma.creatorMember.findMany({ where: { userId: { in: users } }, select: { userId: true } }),
    ]);
    const active = new Set(accounts.filter((a) => a.status === 'ACTIVE').map((a) => a.id));
    const hostSet = new Set(hosts.map((h) => h.userId));
    const agencyBy = new Map(agencies.map((a) => [a.id, a]));
    const agentBy = new Map(agents.map((a) => [a.userId, a.status]));
    const creatorSet = new Set(creators.map((c) => c.userId));
    for (const r of rows) {
      let ok = active.has(r.recruitUserId);
      if (ok) {
        switch (r.type) {
          case 'HOST':
            ok = hostSet.has(r.recruitUserId);
            break;
          case 'AGENCY': {
            const a = r.agencyId ? agencyBy.get(r.agencyId) : undefined;
            ok = a !== undefined && a.status === 'OPEN' && a.suspendedAt === null;
            break;
          }
          case 'RECHARGE_AGENT':
            ok = agentBy.has(r.recruitUserId) && agentBy.get(r.recruitUserId) !== 'SUSPENDED';
            break;
          case 'CREATOR':
            ok = creatorSet.has(r.recruitUserId);
            break;
        }
      }
      out.set(r.id, ok ? 'ACTIVE' : 'INACTIVE');
    }
    return out;
  }

  /** `GET /me/staff/recruits`: the caller's recruits (MODERATION / BD), by type, with their counts. */
  async myRecruits(me: string, raw: unknown) {
    await this.requireRecruiter(me);
    const q = typeQuery.safeParse(raw ?? {});
    if (!q.success) throw AppException.validation([{ field: 'type', issue: 'invalid_value' }]);
    const all = await this.recruits(me, undefined);
    const counts = { HOST: 0, AGENCY: 0, RECHARGE_AGENT: 0, CREATOR: 0, total: all.length };
    for (const r of all) counts[r.type] += 1;
    return {
      counts,
      data: all
        .filter((r) => q.data.type === undefined || r.type === q.data.type)
        .map(({ recruiter: _recruiter, reassignedAt: _reassigned, ...r }) => r),
    };
  }

  /** `GET /me/staff/earnings`: «أرباحي» (MODERATION / BD). */
  async myEarnings(me: string): Promise<StaffEarningsDto> {
    await this.requireRecruiter(me);
    const now = this.clock.now();
    const e = this.economy();
    const since30 = new Date(now.getTime() - 30 * 86_400_000).toISOString().slice(0, 10);
    const since60 = new Date(now.getTime() - 60 * 86_400_000).toISOString().slice(0, 10);
    const [wallet, settings, totals, per, history] = await Promise.all([
      this.cherries.wallet(me),
      recruitSettingsIn(this.prisma),
      this.prisma.$queryRaw<{ total: bigint; d30: bigint }[]>`
        SELECT COALESCE(sum(cherries), 0)::bigint AS total,
               COALESCE(sum(cherries) FILTER (WHERE day >= ${since30}::date), 0)::bigint AS d30
          FROM staff_recruit_commissions WHERE recruiter_user_id = ${me}::uuid`,
      this.prisma.$queryRaw<{ id: string; cherries: bigint }[]>`
        SELECT recruitment_id::text AS id, COALESCE(sum(cherries), 0)::bigint AS cherries
          FROM staff_recruit_commissions WHERE recruiter_user_id = ${me}::uuid GROUP BY recruitment_id`,
      this.prisma.staffRecruitCommission.findMany({
        where: { recruiterUserId: me, cherries: { gt: 0 }, day: { gte: dateValue(since60) } },
        orderBy: [{ day: 'desc' }, { recruitmentId: 'asc' }],
        take: 200,
      }),
    ]);
    const perBy = new Map(per.map((p) => [p.id, p.cherries]));
    const ids = [...new Set([...per.map((p) => p.id), ...history.map((h) => h.recruitmentId)])];
    const recruitments = ids.length
      ? await this.prisma.staffRecruitment.findMany({
          where: { id: { in: ids } },
          include: { recruit: { select: USER_SUMMARY_SELECT } },
        })
      : [];
    const rBy = new Map(recruitments.map((r) => [r.id, r]));
    const byRecruit = [...recruitments]
      .sort((a, b) => b.activatedAt.getTime() - a.activatedAt.getTime() || (a.id < b.id ? 1 : -1))
      .map((r) => ({
        recruitmentId: r.id,
        type: r.type,
        recruit: userSummary(r.recruit, now),
        cherries: Number(perBy.get(r.id) ?? 0n),
      }));
    return {
      wallet,
      totalCherries: Number(totals[0]?.total ?? 0n),
      last30DaysCherries: Number(totals[0]?.d30 ?? 0n),
      bps: bpsOf(settings),
      byRecruit,
      history: history.flatMap((h) => {
        const r = rBy.get(h.recruitmentId);
        if (!r) return [];
        return [
          {
            day: h.day.toISOString().slice(0, 10),
            recruitmentId: h.recruitmentId,
            type: h.type,
            recruit: userSummary(r.recruit, now),
            profitUsd: unitsToUsd(BigInt(h.profitUnits.toFixed(0)), e),
            bps: h.bps,
            cherries: Number(h.cherries),
          },
        ];
      }),
    };
  }

  // ---- The daily commission job ------------------------------------------------------------------------------------

  /**
   * Pays every finished programs' day not paid yet — from each recruitment's activation day (or `catchUpDays` back,
   * whichever is later) to yesterday — one transaction per (recruitment, day). Idempotent: the row's primary key and
   * the ledger reference allow each day once, so two runs at once or a rerun pay nothing twice.
   */
  async sweep(now: Date = this.clock.now()): Promise<RecruitSweep> {
    const today = (await programWindowsIn(this.prisma, now, this.zone)).day.date;
    const back = this.config.recruits.catchUpDays;
    const due = await this.prisma.$queryRaw<{ id: string; day: string }[]>`
      SELECT r.id::text AS id, to_char(d, 'YYYY-MM-DD') AS day
        FROM staff_recruitments r
        CROSS JOIN LATERAL generate_series(
               GREATEST((r.activated_at AT TIME ZONE ${this.zone}::text)::date, ${today}::date - ${back}::int),
               ${today}::date - 1, interval '1 day') AS d
       WHERE NOT EXISTS (SELECT 1 FROM staff_recruit_commissions c WHERE c.recruitment_id = r.id AND c.day = d::date)
       ORDER BY d, r.id
       LIMIT 2000`;
    const out: RecruitSweep = { days: 0, paid: 0, cherries: 0n, skipped: 0 };
    if (due.length === 0) return out;
    const settings = bpsOf(await recruitSettingsIn(this.prisma));
    for (const d of due) {
      const r = await this.payDay(d.id, d.day, settings);
      if (r === null) continue;
      out.days += 1;
      if (r.skipped) out.skipped += 1;
      else if (r.cherries > 0n) {
        out.paid += 1;
        out.cherries += r.cherries;
      }
    }
    return out;
  }

  /**
   * One recruitment's day: the profit counted (from the activation on, in the programs' day), the share in effect, the
   * cherries credited to the recruiter of the moment — never more than the share of that profit. Null when the day was
   * written already (another run).
   */
  async payDay(
    recruitmentId: string,
    day: string,
    bps: Record<RecruitType, number>,
  ): Promise<{ cherries: bigint; skipped: boolean } | null> {
    const e = this.economy();
    const [w] = await this.prisma.$queryRaw<{ start: Date; end: Date }[]>`
      SELECT (${day}::date::timestamp AT TIME ZONE ${this.zone}::text) AS start,
             ((${day}::date + 1)::timestamp AT TIME ZONE ${this.zone}::text) AS end`;
    const r = await this.prisma.staffRecruitment.findUnique({ where: { id: recruitmentId } });
    if (!r || !w) return null;
    const from = r.activatedAt > w.start ? r.activatedAt : w.start;
    const profit = await recruitProfitIn(
      this.prisma,
      { type: r.type, recruitUserId: r.recruitUserId, agencyId: r.agencyId },
      from,
      w.end,
      e,
      this.config.economy.currency,
    );
    const share = bps[r.type];
    try {
      return await this.prisma.$transaction(async (tx) => {
        // The recruiter of the moment (a reassignment waits for this day, or this day waits for it).
        const [locked] = await tx.$queryRaw<{ recruiter: string }[]>`
          SELECT recruiter_user_id::text AS recruiter FROM staff_recruitments WHERE id = ${r.id}::uuid FOR SHARE`;
        if (!locked) return null;
        const active = (await recruiterRoleOf(tx, locked.recruiter)) !== null;
        const cherries = active ? commissionCherries(profit.units, share, e) : 0n;
        if (!withinGuard(cherries, profit.units, share, e))
          throw new Error('recruit commission above its share');
        const inserted = await tx.$executeRaw`
          INSERT INTO staff_recruit_commissions (recruitment_id, day, type, recruiter_user_id, recruit_user_id,
                                                 profit_units, rate_cherries, rate_minor, bps, cherries, skipped,
                                                 created_at)
          VALUES (${r.id}::uuid, ${day}::date, ${r.type}::staff_recruit_type, ${locked.recruiter}::uuid,
                  ${r.recruitUserId}::uuid, ${profit.units.toString()}::numeric, ${e.rateCherries}, ${e.rateMinor},
                  ${share}, ${cherries}, ${active ? null : 'RECRUITER_INACTIVE'}, ${this.clock.now()})
          ON CONFLICT DO NOTHING`;
        if (inserted === 0) return null;
        if (cherries > 0n) {
          await creditRecruitCommissionIn(
            tx,
            locked.recruiter,
            cherries,
            recruitCommissionReference(r.id, day),
            this.clock.now(),
          );
        }
        return { cherries, skipped: !active };
      });
    } catch (err) {
      // A concurrent run wrote the day (its ledger row first): nothing to do.
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') return null;
      if (String(err).includes('cherry_ledger_reference_once')) return null;
      throw err;
    }
  }

  /** The days paid for a recruitment (the panel's drill-down), newest first. */
  async commissionsOf(recruitmentId: string, db: Db = this.prisma) {
    const e = this.economy();
    const rows = await db.staffRecruitCommission.findMany({
      where: { recruitmentId },
      orderBy: { day: 'desc' },
      take: 120,
      include: { recruiter: { select: USER_SUMMARY_SELECT } },
    });
    const now = this.clock.now();
    return rows.map((c) => ({
      day: c.day.toISOString().slice(0, 10),
      recruiter: userSummary(c.recruiter, now),
      profitUsd: unitsToUsd(BigInt(c.profitUnits.toFixed(0)), e),
      bps: c.bps,
      cherries: Number(c.cherries),
      skipped: c.skipped,
    }));
  }

  logSweep(r: RecruitSweep): void {
    if (r.days > 0) this.logger.log({ ...r, cherries: Number(r.cherries) }, 'Recruit commissions paid');
  }
}

function publicRecruiter(r: StaffRecruiterDto): NonNullable<StaffRecruiterLookupDto['recruiter']> {
  return {
    staffId: r.staffId,
    username: r.username,
    displayName: r.displayName,
    avatarUrl: r.avatarUrl,
    role: r.role,
  };
}

/**
 * The daily commission job (v1.75-live, D285): every `RECRUIT_COMMISSION_SWEEP_INTERVAL_SECONDS` (0: off — tests;
 * refused in production) it pays the finished days ({@link RecruitsService.sweep}).
 */
@Injectable()
export class RecruitCommissionSweeper implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RecruitCommissionSweeper.name);
  private timer: NodeJS.Timeout | null = null;
  private inFlight: Promise<unknown> | null = null;

  constructor(
    private readonly recruits: RecruitsService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  onModuleInit(): void {
    if (this.config.recruits.sweepIntervalSeconds > 0) this.schedule();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    await this.inFlight?.catch(() => undefined);
  }

  private schedule(): void {
    this.timer = setTimeout(() => {
      this.inFlight = this.recruits
        .sweep()
        .then((r) => this.recruits.logSweep(r))
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Recruit commission run failed');
        })
        .finally(() => {
          this.inFlight = null;
          this.schedule();
        });
    }, this.config.recruits.sweepIntervalSeconds * 1000);
    this.timer.unref();
  }
}
