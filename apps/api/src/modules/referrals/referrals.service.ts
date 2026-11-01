import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { ReferralRewardKind, ReferralStatus } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import {
  attachReferralIn,
  ensureReferralCodeIn,
  referralSettingsIn,
  sweepReferrals,
  type ReferralSweep,
} from './referral-core.js';
import {
  heroUpTo,
  maskName,
  milestonesTotal,
  milestoneState,
  type MilestoneState,
} from './referral-rules.js';

const DAY_MS = 86_400_000;
/** The ticker: credited rewards of the last 30 days, at most 20. */
const TICKER_DAYS = 30;
const TICKER_LIMIT = 20;
/** The invitees listed on the page (the newest). */
const INVITEES_LIMIT = 20;

/** `ReferralInvitee`: one person the caller invited (masked name, no id). */
export interface ReferralInviteeDto {
  name: string;
  status: ReferralStatus;
  joinedAt: string;
  firstRecharge: boolean;
}

/** `MyReferral` (`getMyReferral`). Cherry amounts are integers (int64 as JSON numbers, like the cherry wallet). */
export interface MyReferralDto {
  enabled: boolean;
  code: string;
  link: string;
  rules: {
    inviterSignupCherries: number;
    inviteeSignupCherries: number;
    firstRechargeBps: number;
    holdHours: number;
    applyWindowDays: number;
    dailySignupCap: number;
  };
  upTo: { total: number; milestones: number };
  payout: { currency: string; rateCherries: number; rateMinor: number };
  counts: { invited: number; qualified: number; pending: number };
  rewards: { pendingCherries: number; creditedCherries: number };
  milestones: { friends: number; cherries: number; state: MilestoneState }[];
  invitees: ReferralInviteeDto[];
  invitedBy: { status: ReferralStatus; source: 'SIGNUP' | 'LATER'; at: string } | null;
  canApply: boolean;
  applyUntil: string | null;
}

/** `ReferralTickerItem` (`listRecentReferralRewards`). */
export interface ReferralTickerItemDto {
  name: string;
  cherries: number;
  kind: ReferralRewardKind;
  at: string;
}

/**
 * «دعوة الأصدقاء» for the person (v1.74-social, D217, CONVENTIONS §10.71): their code and link, the configured
 * amounts, their invitees and rewards, a later code, and the public ticker. The rules are `referral-core.ts`.
 */
@Injectable()
export class ReferralsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  link(code: string): string {
    return `${this.config.appPublicUrl}/i/${code}`;
  }

  async mine(userId: string): Promise<MyReferralDto> {
    const now = this.clock.now();
    const [settings, code] = await Promise.all([
      referralSettingsIn(this.prisma),
      ensureReferralCodeIn(this.prisma, userId),
    ]);
    const [statusCounts, rewardSums, milestoneRows, invitees, invitedBy, me] = await Promise.all([
      this.prisma.referral.groupBy({
        by: ['status'],
        where: { inviterUserId: userId },
        _count: { _all: true },
      }),
      this.prisma.referralReward.groupBy({
        by: ['status'],
        where: { userId, status: { in: ['PENDING', 'CREDITED'] } },
        _sum: { cherries: true },
      }),
      this.prisma.referralReward.findMany({
        where: { userId, kind: 'MILESTONE', status: 'CREDITED' },
        select: { milestoneFriends: true },
      }),
      this.prisma.referral.findMany({
        where: { inviterUserId: userId },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: INVITEES_LIMIT,
        select: {
          status: true,
          createdAt: true,
          firstRechargeAt: true,
          invitee: { select: { profile: { select: { displayName: true } } } },
        },
      }),
      this.prisma.referral.findUnique({
        where: { inviteeUserId: userId },
        select: { status: true, source: true, createdAt: true },
      }),
      this.prisma.user.findUniqueOrThrow({ where: { id: userId }, select: { createdAt: true } }),
    ]);
    const count = (s: ReferralStatus) => statusCounts.find((c) => c.status === s)?._count._all ?? 0;
    const sum = (s: 'PENDING' | 'CREDITED') =>
      Number(rewardSums.find((r) => r.status === s)?._sum.cherries ?? 0n);
    const counts = {
      invited: statusCounts.reduce((n, c) => n + c._count._all, 0),
      qualified: count('QUALIFIED'),
      pending: count('PENDING'),
    };
    const credited = new Set(milestoneRows.map((r) => r.milestoneFriends!));
    const applyUntil = new Date(me.createdAt.getTime() + settings.applyWindowDays * DAY_MS);
    return {
      enabled: settings.enabled,
      code,
      link: this.link(code),
      rules: {
        inviterSignupCherries: Number(settings.inviterSignupCherries),
        inviteeSignupCherries: Number(settings.inviteeSignupCherries),
        firstRechargeBps: settings.firstRechargeBps,
        holdHours: settings.holdHours,
        applyWindowDays: settings.applyWindowDays,
        dailySignupCap: settings.dailySignupCap,
      },
      upTo: { total: Number(heroUpTo(settings)), milestones: Number(milestonesTotal(settings.milestones)) },
      payout: {
        currency: this.config.economy.currency,
        rateCherries: this.config.economy.rateCherries,
        rateMinor: this.config.economy.rateMinor,
      },
      counts,
      rewards: { pendingCherries: sum('PENDING'), creditedCherries: sum('CREDITED') },
      milestones: settings.milestones.map((m) => ({
        friends: m.friends,
        cherries: Number(m.cherries),
        state: milestoneState(m, counts, credited),
      })),
      invitees: invitees.map((r) => ({
        name: maskName(r.invitee.profile?.displayName ?? ''),
        status: r.status,
        joinedAt: r.createdAt.toISOString(),
        firstRecharge: r.firstRechargeAt !== null,
      })),
      invitedBy: invitedBy
        ? {
            status: invitedBy.status,
            source: invitedBy.source as 'SIGNUP' | 'LATER',
            at: invitedBy.createdAt.toISOString(),
          }
        : null,
      canApply: settings.enabled && invitedBy === null && now.getTime() < applyUntil.getTime(),
      applyUntil: invitedBy === null ? applyUntil.toISOString() : null,
    };
  }

  /**
   * A code entered later (in settings): once, within `applyWindowDays` of the account's creation. Order: 503
   * REFERRAL_UNAVAILABLE → 409 REFERRAL_NOT_ALLOWED (ALREADY_REFERRED, WINDOW_CLOSED) → 422 REFERRAL_CODE_INVALID
   * (unknown, own, or its owner cannot invite) → 200 with the page (`invitedBy.status` PENDING, or REJECTED when a
   * fraud rule matched: no reward).
   */
  async apply(
    userId: string,
    code: string,
    installId: string | null,
    meta: { ip: string | null; requestId: string | null },
  ): Promise<MyReferralDto> {
    const now = this.clock.now();
    const settings = await referralSettingsIn(this.prisma);
    if (!settings.enabled) throw new AppException(ErrorCode.REFERRAL_UNAVAILABLE);
    const me = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { email: true, createdAt: true },
    });
    const notAllowed = (issue: 'ALREADY_REFERRED' | 'WINDOW_CLOSED') =>
      new AppException(ErrorCode.REFERRAL_NOT_ALLOWED, undefined, [{ field: 'referral', issue }]);
    if ((await this.prisma.referral.count({ where: { inviteeUserId: userId } })) > 0)
      throw notAllowed('ALREADY_REFERRED');
    if (now.getTime() >= me.createdAt.getTime() + settings.applyWindowDays * DAY_MS)
      throw notAllowed('WINDOW_CLOSED');
    // The install id of the caller's session when the body has none (the app sends it in the body too).
    const session =
      installId ??
      (
        await this.prisma.session.findFirst({
          where: { userId, revokedAt: null, installId: { not: null } },
          orderBy: { lastUsedAt: 'desc' },
          select: { installId: true },
        })
      )?.installId ??
      null;
    let result;
    try {
      result = await this.prisma.$transaction((tx) =>
        attachReferralIn(tx, {
          inviteeUserId: userId,
          code,
          source: 'LATER',
          installId: session,
          ip: meta.ip,
          email: me.email,
          now,
          requestId: meta.requestId,
        }),
      );
    } catch (err) {
      // Two concurrent applies: the second one breaks the one-inviter rule.
      if ((err as { code?: string }).code === 'P2002') throw notAllowed('ALREADY_REFERRED');
      throw err;
    }
    switch (result.kind) {
      case 'DISABLED':
        throw new AppException(ErrorCode.REFERRAL_UNAVAILABLE);
      case 'ALREADY':
        throw notAllowed('ALREADY_REFERRED');
      case 'UNKNOWN_CODE':
      case 'OWN_CODE':
        throw new AppException(ErrorCode.REFERRAL_CODE_INVALID);
      default:
        return this.mine(userId);
    }
  }

  /** The public ticker: real credited rewards only (masked names); empty when there are none or it is off. */
  async ticker(): Promise<{ data: ReferralTickerItemDto[] }> {
    const settings = await referralSettingsIn(this.prisma);
    if (!settings.enabled) return { data: [] };
    const since = new Date(this.clock.now().getTime() - TICKER_DAYS * DAY_MS);
    const rows = await this.prisma.referralReward.findMany({
      where: { status: 'CREDITED', creditedAt: { gte: since }, user: { status: 'ACTIVE' } },
      orderBy: [{ creditedAt: 'desc' }, { id: 'desc' }],
      take: TICKER_LIMIT,
      select: {
        cherries: true,
        kind: true,
        creditedAt: true,
        user: { select: { profile: { select: { displayName: true } } } },
      },
    });
    return {
      data: rows.map((r) => ({
        name: maskName(r.user.profile?.displayName ?? ''),
        cherries: Number(r.cherries),
        kind: r.kind,
        at: r.creditedAt!.toISOString(),
      })),
    };
  }
}

/**
 * The referral sweeper (v1.74-social, D217): every `REFERRAL_SWEEP_INTERVAL_SECONDS` (0: off — tests; refused in
 * production) it qualifies or voids the referrals whose hold ended and credits or voids the due rewards
 * (`sweepReferrals`).
 */
@Injectable()
export class ReferralSweeper implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(ReferralSweeper.name);
  private timer: NodeJS.Timeout | null = null;
  private inFlight: Promise<unknown> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  onModuleInit(): void {
    if (this.config.referrals.sweepIntervalSeconds > 0) this.schedule();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    await this.inFlight?.catch(() => undefined);
  }

  /** One step (also the tests' entry, with a later time). */
  sweep(now: Date = this.clock.now()): Promise<ReferralSweep> {
    return sweepReferrals(this.prisma, now);
  }

  private schedule(): void {
    this.timer = setTimeout(() => {
      this.inFlight = this.sweep()
        .then((r) => {
          if (r.qualified + r.voided + r.credited + r.rewardsVoided > 0) {
            this.logger.log({ ...r, milestoneCherries: Number(r.milestoneCherries) }, 'Referrals swept');
          }
        })
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Referral sweep failed');
        })
        .finally(() => {
          this.inFlight = null;
          this.schedule();
        });
    }, this.config.referrals.sweepIntervalSeconds * 1000);
    this.timer.unref();
  }
}
