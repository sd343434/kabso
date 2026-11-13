import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma, type Ambassador, type AmbassadorApplication } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { ensureReferralCodeIn } from '../referrals/referral-core.js';
import { maskName } from '../referrals/referral-rules.js';
import {
  ambassadorSettingsIn,
  eligibilityIn,
  setAmbassadorTimeZone,
  sweepAmbassadors,
  type AmbassadorRefusal,
  type AmbassadorSettingsValue,
  type AmbassadorSweep,
} from './ambassador-core.js';
import { ambassadorMonth, levelIndex, progressToNext, type AmbassadorLevel } from './ambassador-rules.js';

/**
 * «برنامج سفراء Kabso» (v1.140-social, D390, CONVENTIONS §10.179): the app's programme page and application, the
 * ambassador's dashboard, the panel's reads, and the sweeper.
 */

export const ambassadorApplicationBody = z.strictObject({
  country: z.string().regex(/^[A-Z]{2}$/),
  /** Plain https links to the person's social accounts (1–5). */
  links: z
    .array(
      z
        .string()
        .trim()
        .max(200)
        .regex(/^https:\/\/[^\s/$.?#][^\s]*$/i),
    )
    .min(1)
    .max(5),
  audienceSize: z.number().int().min(0).max(1_000_000_000),
  motivation: z.string().trim().min(1).max(1000),
});

function isUniqueViolation(err: unknown): boolean {
  return err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002';
}

export function applicationDto(a: AmbassadorApplication) {
  return {
    id: a.id,
    status: a.status,
    country: a.country,
    links: a.links,
    audienceSize: a.audienceSize,
    motivation: a.motivation,
    createdAt: a.createdAt.toISOString(),
    decidedAt: a.decidedAt?.toISOString() ?? null,
    rejectReason: a.rejectReason,
  };
}

/** The levels as the app and the panel show them (the reward as stored). */
export function levelsDto(levels: readonly AmbassadorLevel[]) {
  return levels.map((l) => ({
    code: l.code,
    minActiveReferrals: l.minActiveReferrals,
    minTopupCoins: l.minTopupCoins,
    commissionBps: l.commissionBps,
    reward: l.reward,
  }));
}

export function settingsDto(s: AmbassadorSettingsValue) {
  return {
    enabled: s.enabled,
    attributionWindowDays: s.attributionWindowDays,
    holdDays: s.holdDays,
    minActiveDays: s.minActiveDays,
    minActiveTopupCoins: Number(s.minActiveTopupCoins),
    monthlyCapCherries: Number(s.monthlyCapCherries),
    velocityMaxPerDay: s.velocityMaxPerDay,
    ipClusterMax: s.ipClusterMax,
    ipClusterWindowDays: s.ipClusterWindowDays,
    levels: levelsDto(s.levels),
    updatedAt: s.updatedAt.toISOString(),
  };
}

interface CommissionSums {
  pending: bigint;
  held: bigint;
  paid: bigint;
  reversed: bigint;
}

@Injectable()
export class AmbassadorsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  get zone(): string {
    return this.config.live.rankingsTimeZone;
  }

  private latest(me: string): Promise<AmbassadorApplication | null> {
    return this.prisma.ambassadorApplication.findFirst({
      where: { userId: me },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    });
  }

  /** `GET /ambassadors/programme`: the explanation page's numbers, the caller's status and application. */
  async programme(me: string) {
    const settings = await ambassadorSettingsIn(this.prisma);
    const now = this.clock.now();
    const [amb, latest] = await Promise.all([
      this.prisma.ambassador.findUnique({ where: { userId: me }, select: { userId: true } }),
      this.latest(me),
    ]);
    const refusal: AmbassadorRefusal | 'DISABLED' | null = !settings.enabled
      ? 'DISABLED'
      : await eligibilityIn(this.prisma, me, now);
    return {
      enabled: settings.enabled,
      status: amb
        ? ('AMBASSADOR' as const)
        : latest?.status === 'PENDING'
          ? ('PENDING' as const)
          : latest?.status === 'REJECTED'
            ? ('REJECTED' as const)
            : ('NONE' as const),
      canApply: refusal === null,
      refusal: amb ? ('AMBASSADOR' as const) : refusal,
      application: latest ? applicationDto(latest) : null,
      levels: settings.enabled ? levelsDto(settings.levels) : [],
      rules: {
        attributionWindowDays: settings.attributionWindowDays,
        holdDays: settings.holdDays,
        minActiveDays: settings.minActiveDays,
        minActiveTopupCoins: Number(settings.minActiveTopupCoins),
      },
    };
  }

  /**
   * `POST /ambassadors/applications`. Order: 503 switched off → 400 body → 409 AMBASSADOR_APPLICATION_NOT_ALLOWED
   * (`details[0] = {field: application, issue}`) → 201.
   */
  async apply(me: string, body: unknown) {
    const settings = await ambassadorSettingsIn(this.prisma);
    if (!settings.enabled) throw new AppException(ErrorCode.SERVICE_UNAVAILABLE);
    const parsed = ambassadorApplicationBody.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;
    const now = this.clock.now();
    const refused = (issue: string) =>
      new AppException(ErrorCode.AMBASSADOR_APPLICATION_NOT_ALLOWED, undefined, [{ field: 'application', issue }]);
    const refusal = await eligibilityIn(this.prisma, me, now);
    if (refusal) throw refused(refusal);
    const id = uuidv7(now.getTime());
    try {
      await this.prisma.$transaction(async (tx) => {
        await tx.ambassadorApplication.create({
          data: {
            id,
            userId: me,
            country: input.country,
            links: input.links,
            audienceSize: input.audienceSize,
            motivation: input.motivation,
            createdAt: now,
          },
        });
        await tx.auditLog.create({
          data: {
            actorUserId: me,
            action: AuditAction.AMBASSADOR_APPLICATION_SUBMIT,
            targetType: 'ambassador_application',
            targetId: id,
            metadata: { country: input.country, links: input.links.length, audienceSize: input.audienceSize },
          },
        });
      });
    } catch (err) {
      if (isUniqueViolation(err)) throw refused('PENDING');
      throw err;
    }
    return this.programme(me);
  }

  /** Commission totals of one ambassador (pending in hold, held after the hold, paid, reversed). */
  async commissionSums(userId: string, amb: Ambassador): Promise<CommissionSums> {
    const now = this.clock.now();
    const [row] = await this.prisma.$queryRaw<{ pending: bigint; held: bigint; paid: bigint; reversed: bigint }[]>`
      SELECT COALESCE(sum(cherries) FILTER (WHERE status = 'PENDING' AND hold_until > ${now}), 0)::bigint AS pending,
             COALESCE(sum(cherries) FILTER (WHERE status = 'PENDING' AND hold_until <= ${now}), 0)::bigint AS held,
             COALESCE(sum(cherries) FILTER (WHERE status = 'CREDITED'), 0)::bigint AS paid,
             COALESCE(sum(cherries) FILTER (WHERE status = 'REVERSED'), 0)::bigint AS reversed
        FROM ambassador_commissions WHERE ambassador_user_id = ${userId}::uuid`;
    // A frozen ambassador's whole pending amount is held.
    const frozen = amb.status === 'FROZEN' || amb.underReview;
    const pending = row?.pending ?? 0n;
    const heldAmount = row?.held ?? 0n;
    return {
      pending: frozen ? 0n : pending,
      held: frozen ? pending + heldAmount : heldAmount,
      paid: row?.paid ?? 0n,
      reversed: row?.reversed ?? 0n,
    };
  }

  /** The month's stats (referrals that became active, qualifying top-up coins). */
  async monthStats(userId: string, month: string): Promise<{ activeReferrals: number; topupCoins: bigint }> {
    const activeReferrals = await this.prisma.ambassadorReferral.count({
      where: { ambassadorUserId: userId, status: 'ACTIVE', activeMonth: month },
    });
    const [row] = await this.prisma.$queryRaw<{ c: bigint }[]>`
      SELECT COALESCE(sum(coins), 0)::bigint AS c FROM ambassador_commissions
       WHERE ambassador_user_id = ${userId}::uuid AND month = ${month}
         AND (status IN ('PENDING', 'CREDITED') OR void_reason IN ('MONTHLY_CAP', 'ZERO'))`;
    return { activeReferrals, topupCoins: row?.c ?? 0n };
  }

  async referralCounts(userId: string) {
    const groups = await this.prisma.ambassadorReferral.groupBy({
      by: ['status'],
      where: { ambassadorUserId: userId },
      _count: { _all: true },
    });
    const of = (s: string) => groups.find((g) => g.status === s)?._count._all ?? 0;
    return { total: of('PENDING') + of('ACTIVE'), active: of('ACTIVE'), pending: of('PENDING'), void: of('VOID') };
  }

  /** `GET /ambassadors/me`: the ambassador's dashboard (404 for anyone else). */
  async dashboard(me: string) {
    const amb = await this.prisma.ambassador.findUnique({ where: { userId: me } });
    if (!amb) throw new AppException(ErrorCode.NOT_FOUND);
    const settings = await ambassadorSettingsIn(this.prisma);
    const now = this.clock.now();
    const month = ambassadorMonth(now, this.zone);
    const levels = settings.levels;
    const current = levelIndex(levels, amb.level);
    const [code, stats, counts, sums, history, recent] = await Promise.all([
      ensureReferralCodeIn(this.prisma, me),
      this.monthStats(me, month),
      this.referralCounts(me),
      this.commissionSums(me, amb),
      this.prisma.ambassadorMonth.findMany({
        where: { ambassadorUserId: me },
        orderBy: { month: 'desc' },
        take: 12,
      }),
      this.prisma.ambassadorCommission.findMany({
        where: { ambassadorUserId: me },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: 20,
      }),
    ]);
    const names = new Map(
      (
        await this.prisma.userProfile.findMany({
          where: { userId: { in: [...new Set(recent.map((c) => c.inviteeUserId))] } },
          select: { userId: true, displayName: true },
        })
      ).map((p) => [p.userId, p.displayName]),
    );
    const level = levels[current];
    const targetLevel = levels[Math.min(current + 1, levels.length - 1)];
    return {
      enabled: settings.enabled,
      payoutsHeld: amb.status === 'FROZEN' || amb.underReview,
      since: amb.activatedAt.toISOString(),
      code,
      link: `${this.config.appPublicUrl}/i/${code}`,
      level: level ? { code: level.code, commissionBps: level.commissionBps } : null,
      nextLevel: progressToNext(levels, current, stats),
      month: {
        month,
        activeReferrals: stats.activeReferrals,
        topupCoins: Number(stats.topupCoins),
        target: targetLevel
          ? {
              code: targetLevel.code,
              minActiveReferrals: targetLevel.minActiveReferrals,
              minTopupCoins: targetLevel.minTopupCoins,
              reward: targetLevel.reward,
            }
          : null,
      },
      referrals: counts,
      commissions: {
        pendingCherries: Number(sums.pending),
        heldCherries: Number(sums.held),
        paidCherries: Number(sums.paid),
        reversedCherries: Number(sums.reversed),
      },
      history: history.map((h) => ({
        month: h.month,
        activeReferrals: h.activeReferrals,
        topupCoins: Number(h.topupCoins),
        commissionCherries: Number(h.commissionCherries),
        levelAfter: h.levelAfter,
        rewardStatus: h.rewardStatus as 'NONE' | 'GRANTED' | 'HELD',
      })),
      recent: recent.map((c) => ({
        id: c.id,
        at: c.createdAt.toISOString(),
        friend: maskName(names.get(c.inviteeUserId) ?? ''),
        coins: Number(c.coins),
        cherries: Number(c.cherries),
        status: c.status,
      })),
    };
  }
}

/**
 * The ambassadors' sweeper (v1.140-social, D390): every `AMBASSADOR_SWEEP_INTERVAL_SECONDS` (0: off — tests; refused
 * in production) it activates referrals, credits or voids due commissions and evaluates the finished month.
 */
@Injectable()
export class AmbassadorSweeper implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(AmbassadorSweeper.name);
  private timer: NodeJS.Timeout | null = null;
  private inFlight: Promise<unknown> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    setAmbassadorTimeZone(config.live.rankingsTimeZone);
  }

  onModuleInit(): void {
    if (this.config.ambassadors.sweepIntervalSeconds > 0) this.schedule();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    await this.inFlight?.catch(() => undefined);
  }

  /** One step (also the tests' entry, with a later time). */
  sweep(now: Date = this.clock.now()): Promise<AmbassadorSweep> {
    return sweepAmbassadors(this.prisma, now, this.config.live.rankingsTimeZone);
  }

  private schedule(): void {
    this.timer = setTimeout(() => {
      this.inFlight = this.sweep()
        .then((r) => {
          if (Object.values(r).some((n) => n > 0)) this.logger.log(r, 'Ambassadors swept');
        })
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Ambassador sweep failed');
        })
        .finally(() => {
          this.inFlight = null;
          this.schedule();
        });
    }, this.config.ambassadors.sweepIntervalSeconds * 1000);
    this.timer.unref();
  }
}
