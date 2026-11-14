import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { auditBy, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import {
  recomputeAllBadges,
  recomputeBadgesIn,
  thresholdsIn,
  type RecomputeResult,
} from './verification-badges.js';
import {
  DEFAULT_THRESHOLDS,
  MAX_HOSTS_THRESHOLD,
  MAX_THRESHOLD,
  thresholdsDto,
  VERIFICATION_BADGES,
  VERIFICATION_WINDOW_DAYS,
  type VerificationBadgeValue,
  type VerificationThresholdsDto,
} from './verification-rules.js';

const amount = z.number().int().min(0).max(Number(MAX_THRESHOLD));

/** `updateAdminVerificationSettings`: any of the four thresholds, a reason and the authenticator code again. */
export const verificationSettingsBody = z
  .strictObject({
    rechargeMinSalesCoins: amount.optional(),
    rechargeMinCherries: amount.optional(),
    hostAgentMinHosts: z.number().int().min(0).max(MAX_HOSTS_THRESHOLD).optional(),
    hostAgentMinCherries: amount.optional(),
    reason: z.string().trim().min(1).max(500),
    totpCode: z.string().regex(/^[0-9]{6}$/),
  })
  .refine(
    (b) =>
      b.rechargeMinSalesCoins !== undefined ||
      b.rechargeMinCherries !== undefined ||
      b.hostAgentMinHosts !== undefined ||
      b.hostAgentMinCherries !== undefined,
    { message: 'nothing to change', path: ['rechargeMinSalesCoins'], params: { issue: 'required' } },
  );
export type VerificationSettingsBody = z.output<typeof verificationSettingsBody>;

/** `AdminVerificationSettings`. */
export interface AdminVerificationSettingsDto {
  settings: VerificationThresholdsDto;
  defaults: VerificationThresholdsDto;
  windowDays: number;
  /** How many people hold each badge now. */
  holders: Record<VerificationBadgeValue, number>;
  lastRunAt: string | null;
  updatedAt: string;
}

/**
 * v1.90-social (D293, CONVENTIONS §10.105): the panel's «شارات التوثيق» (`verification.view` reads,
 * `verification.settings` — OWNER, the code again, a reason — changes the thresholds and recomputes everyone at once),
 * and the sweeper's full recompute.
 */
@Injectable()
export class VerificationService {
  private readonly logger = new Logger(VerificationService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
  ) {}

  async settingsView(): Promise<AdminVerificationSettingsDto> {
    const [row, thresholds, counts] = await Promise.all([
      this.prisma.verificationBadgeSettings.findUnique({ where: { id: 1 } }),
      thresholdsIn(this.prisma),
      this.prisma.userVerificationBadge.groupBy({ by: ['badge'], _count: { _all: true } }),
    ]);
    const holders = Object.fromEntries(VERIFICATION_BADGES.map((b) => [b, 0])) as Record<
      VerificationBadgeValue,
      number
    >;
    for (const c of counts) holders[c.badge] = c._count._all;
    return {
      settings: thresholdsDto(thresholds),
      defaults: thresholdsDto(DEFAULT_THRESHOLDS),
      windowDays: VERIFICATION_WINDOW_DAYS,
      holders,
      lastRunAt: row?.lastRunAt?.toISOString() ?? null,
      updatedAt: (row?.updatedAt ?? new Date(0)).toISOString(),
    };
  }

  /** Changes the thresholds (audited before / after) and recomputes everyone in the same transaction. */
  async updateSettings(body: VerificationSettingsBody, by: AdminVia): Promise<AdminVerificationSettingsDto> {
    const now = this.clock.now();
    await this.prisma.$transaction(
      async (tx) => {
        // The row is made by the migration; put back (the owner's defaults) if it was ever removed.
        await tx.verificationBadgeSettings.upsert({ where: { id: 1 }, create: { id: 1 }, update: {} });
        await tx.$queryRaw`SELECT 1 FROM verification_badge_settings WHERE id = 1 FOR UPDATE`;
        const before = thresholdsDto(await thresholdsIn(tx));
        await tx.verificationBadgeSettings.update({
          where: { id: 1 },
          data: {
            ...(body.rechargeMinSalesCoins !== undefined
              ? { rechargeMinSalesCoins: BigInt(body.rechargeMinSalesCoins) }
              : {}),
            ...(body.rechargeMinCherries !== undefined
              ? { rechargeMinCherries: BigInt(body.rechargeMinCherries) }
              : {}),
            ...(body.hostAgentMinHosts !== undefined ? { hostAgentMinHosts: body.hostAgentMinHosts } : {}),
            ...(body.hostAgentMinCherries !== undefined
              ? { hostAgentMinCherries: BigInt(body.hostAgentMinCherries) }
              : {}),
            updatedAt: now,
            updatedById: by.actorUserId,
          },
        });
        const after = thresholdsDto(await thresholdsIn(tx));
        await tx.auditLog.create({
          data: {
            ...auditBy(by),
            action: AuditAction.VERIFICATION_SETTINGS_UPDATE,
            targetType: 'verification_badge_settings',
            targetId: '1',
            metadata: {
              before: before as unknown as Prisma.InputJsonValue,
              after: after as unknown as Prisma.InputJsonValue,
              reason: body.reason,
              via: by.via,
            },
          },
        });
        await recomputeBadgesIn(tx, null, 'settings', now);
      },
      { timeout: 120_000 },
    );
    return this.settingsView();
  }

  /** The sweeper's run: everyone, over the window ending now. */
  sweep(): Promise<RecomputeResult> {
    return recomputeAllBadges(this.prisma, 'sweep', this.clock.now());
  }

  logSweep(r: RecomputeResult): void {
    if (r.granted + r.changed + r.removed > 0) this.logger.log({ ...r }, 'Verification badges recomputed');
  }

  logFailure(err: unknown): void {
    this.logger.error({ error: safeErrorLog(err) }, 'Verification badge recompute failed');
  }
}

/**
 * v1.90-social (D293): every `VERIFICATION_BADGE_SWEEP_INTERVAL_SECONDS` (default 3600; 0: off — tests; refused in
 * production) the badges are recomputed over the rolling 30-day window, so they appear and go as the activity does.
 */
@Injectable()
export class VerificationBadgeSweeper implements OnModuleInit, OnModuleDestroy {
  private timer: NodeJS.Timeout | null = null;
  private inFlight: Promise<unknown> | null = null;

  constructor(
    private readonly verification: VerificationService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  onModuleInit(): void {
    if (this.config.verificationBadges.sweepIntervalSeconds > 0) this.schedule();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    await this.inFlight?.catch(() => undefined);
  }

  private schedule(): void {
    this.timer = setTimeout(() => {
      this.inFlight = this.verification
        .sweep()
        .then((r) => this.verification.logSweep(r))
        .catch((err: unknown) => this.verification.logFailure(err))
        .finally(() => {
          this.inFlight = null;
          this.schedule();
        });
    }, this.config.verificationBadges.sweepIntervalSeconds * 1000);
    this.timer.unref();
  }
}
