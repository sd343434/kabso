import { Inject, Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { z } from 'zod';
import {
  drawWinners,
  expectedReturnBps,
  LUCKY_CHANCE_SCALE,
  type LuckyRng,
  type LuckyTable,
} from './lucky-odds.js';
import { LUCKY_RNG } from './lucky-rng.js';

/** Why the caller may not send lucky gifts now (`LuckyGiftEligibility.reason`). */
export type LuckyIneligibility = 'DISABLED' | 'REGION_UNAVAILABLE' | 'AGE_UNCONFIRMED';

/** `LuckyGiftEligibility`. */
export interface LuckyGiftEligibilityDto {
  eligible: boolean;
  reason: LuckyIneligibility | null;
  ageConfirmed: boolean;
}

/** `LuckyGiftOdds` (openapi v1.27-live). */
export interface LuckyGiftOddsDto {
  enabled: boolean;
  drawsPerGift: 1;
  returnPercent: number;
  hostSharePercent: number;
  outcomes: { multiplier: number; chancePerMillion: number; probability: number }[];
  noWinChancePerMillion: number;
  noWinProbability: number;
  bigWinMultiplier: number;
  dailyProtection: true;
  dayTimeZone: string;
  minimumAge: 18;
  caller: LuckyGiftEligibilityDto | null;
}

/** The request facts the region check needs: the edge's country header and the caller's own. */
export interface LuckyRegionInput {
  /** The value of LUCKY_GIFTS_COUNTRY_HEADER on the request (undefined: absent). */
  readonly edgeCountry: string | undefined;
}

/** `LuckyGiftAgeConfirmationRequest`: `{"adult": true}` only. */
export const luckyAgeConfirmationSchema = z.strictObject({
  // Missing → `required`; anything but `true` → `invalid_value` (a bare literal reports both alike).
  adult: z.unknown().superRefine((value, ctx) => {
    if (value === true) return;
    ctx.addIssue({
      code: 'custom',
      params: { issue: value === undefined ? 'required' : 'invalid_value' },
      message: 'must be true',
    });
  }),
});

/** `YYYY-MM-DD` of `at` in `timeZone` (the daily protection's day). */
export function dayIn(at: Date, timeZone: string): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(at);
}

/**
 * Lucky gifts (v1.27-live, D132, CONVENTIONS §10.27): the published odds, the 18+ statement, the
 * region and age gates and the draws. The send itself (charge, daily protection, crediting) is in
 * `LiveGiftsService`, in one transaction.
 */
@Injectable()
export class LuckyGiftsService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(LUCKY_RNG) private readonly rng: LuckyRng,
    private readonly audit: AuditService,
    private readonly clock: Clock,
  ) {}

  get enabled(): boolean {
    return this.config.lucky.enabled;
  }

  get table(): LuckyTable {
    return this.config.lucky.table;
  }

  get bigWinMultiplier(): number {
    return this.config.lucky.bigWinMultiplier;
  }

  /** The daily protection's day for `at` (`YYYY-MM-DD`). */
  dayOf(at: Date): string {
    return dayIn(at, this.config.lucky.dayTimeZone);
  }

  /** The request header the edge sets to the client's country, or null (none configured). */
  get countryHeader(): string | null {
    return this.config.lucky.countryHeader;
  }

  /** The region facts of a request: the edge's country header (when one is configured). */
  regionOf(headers: Readonly<Record<string, string | string[] | undefined>>): LuckyRegionInput {
    const header = this.countryHeader;
    if (header === null) return { edgeCountry: undefined };
    const value = headers[header];
    return { edgeCountry: Array.isArray(value) ? value[0] : value };
  }

  /** The winning draws of `draws` gifts (`[index, multiplier]`), from the CSPRNG. */
  draw(draws: number): [number, number][] {
    return drawWinners(this.table, draws, this.rng);
  }

  /**
   * Whether lucky gifts are off for this caller's country: the edge's country and the caller's own
   * (`Me.country`) are both checked; with a list configured, an unknown edge country is refused
   * too (fail closed). No list → never.
   */
  async regionBlocked(userId: string, region: LuckyRegionInput): Promise<boolean> {
    const list = this.config.lucky.disabledCountries;
    if (list.length === 0) return false;
    const edge = region.edgeCountry?.trim().toUpperCase();
    if (edge === undefined || !/^[A-Z]{2}$/.test(edge) || edge === 'XX' || edge === 'T1') return true;
    if (list.includes(edge)) return true;
    const profile = await this.prisma.userProfile.findUnique({
      where: { userId },
      select: { countryCode: true },
    });
    return (
      profile?.countryCode !== null &&
      profile?.countryCode !== undefined &&
      list.includes(profile.countryCode)
    );
  }

  async ageConfirmed(userId: string): Promise<boolean> {
    return (await this.prisma.luckyGiftAgeConfirmation.count({ where: { userId } })) > 0;
  }

  /** The checks of a lucky send after the gift is known (§10.27 order): region, then age. */
  async assertMaySend(userId: string, region: LuckyRegionInput): Promise<void> {
    if (await this.regionBlocked(userId, region))
      throw new AppException(ErrorCode.LUCKY_GIFT_REGION_UNAVAILABLE);
    if (!(await this.ageConfirmed(userId))) throw new AppException(ErrorCode.LUCKY_GIFT_AGE_UNCONFIRMED);
  }

  async eligibility(userId: string, region: LuckyRegionInput): Promise<LuckyGiftEligibilityDto> {
    const ageConfirmed = await this.ageConfirmed(userId);
    const reason: LuckyIneligibility | null = !this.enabled
      ? 'DISABLED'
      : (await this.regionBlocked(userId, region))
        ? 'REGION_UNAVAILABLE'
        : ageConfirmed
          ? null
          : 'AGE_UNCONFIRMED';
    return { eligible: reason === null, reason, ageConfirmed };
  }

  /** `GET /live/gifts/lucky/odds`: the table drawn from now; `caller` null for a guest. */
  async odds(userId: string | null, region: LuckyRegionInput): Promise<LuckyGiftOddsDto> {
    const t = this.table;
    return {
      enabled: this.enabled,
      drawsPerGift: 1,
      returnPercent: expectedReturnBps(t) / 100,
      hostSharePercent: t.hostShareBps / 100,
      outcomes: t.outcomes.map((o) => ({
        multiplier: o.multiplier,
        chancePerMillion: o.chancePerMillion,
        probability: o.chancePerMillion / LUCKY_CHANCE_SCALE,
      })),
      noWinChancePerMillion: t.noWinChancePerMillion,
      noWinProbability: t.noWinChancePerMillion / LUCKY_CHANCE_SCALE,
      bigWinMultiplier: this.bigWinMultiplier,
      dailyProtection: true,
      dayTimeZone: this.config.lucky.dayTimeZone,
      minimumAge: 18,
      caller: userId === null ? null : await this.eligibility(userId, region),
    };
  }

  /**
   * `PUT /me/lucky-gifts/age-confirmation`: stores the caller's "I am 18 or older" once (the first
   * time is kept) and audits the first statement.
   */
  async confirmAge(
    userId: string,
    meta: { ip: string | null; requestId: string | null },
  ): Promise<{ ageConfirmedAt: string }> {
    const confirmedAt = await this.prisma.$transaction(async (tx: Prisma.TransactionClient) => {
      const inserted = await tx.luckyGiftAgeConfirmation.createMany({
        data: [{ userId, confirmedAt: this.clock.now() }],
        skipDuplicates: true,
      });
      if (inserted.count === 1) {
        await this.audit.recordIn(tx, {
          action: AuditAction.LUCKY_AGE_CONFIRM,
          actorUserId: userId,
          targetType: 'user',
          targetId: userId,
          ip: meta.ip,
          requestId: meta.requestId,
        });
      }
      return (await tx.luckyGiftAgeConfirmation.findUniqueOrThrow({ where: { userId } })).confirmedAt;
    });
    return { ageConfirmedAt: confirmedAt.toISOString() };
  }
}
