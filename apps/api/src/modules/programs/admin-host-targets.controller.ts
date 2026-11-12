import { Body, Controller, Get, Inject, Module, Param, Put, Query, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { Clock } from '../../common/time/clock.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import {
  DEFAULT_KINDS,
  validNewHostDefaults,
  type DefaultKind,
  type NewHostDefaults,
} from './host-target-engine.js';
import type { AdminContext } from '../admin-panel/admin-auth.service.js';
import { AdminPanelModule } from '../admin-panel/admin-panel.module.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from '../admin-panel/admin-session.guard.js';
import { Public } from '../auth/public.decorator.js';
import { HostTargetsService, settingsDto, type HostTargetSettingsDto } from './host-targets.service.js';
import { ProgramsModule } from './programs.module.js';
import { programWindowsIn } from './programs-time.js';
import { TasksService } from './tasks.service.js';

const knobs = {
  easyPercentile: z.number().int().min(1).max(97),
  mediumPercentile: z.number().int().min(2).max(98),
  hardPercentile: z.number().int().min(3).max(99),
  easyRewardBps: z.number().int().min(0).max(2000),
  mediumRewardBps: z.number().int().min(0).max(2000),
  hardRewardBps: z.number().int().min(0).max(2000),
  noRepeatDays: z.number().int().min(0).max(60),
  taskNoRepeatDays: z.number().int().min(0).max(60),
  historyDays: z.number().int().min(7).max(90),
  completionShift: z.number().int().min(0).max(30),
};
type Knob = keyof typeof knobs;
const KNOBS = Object.keys(knobs) as Knob[];

/** D281b: the OWNER's new-host defaults (every kind, 4 bands of [easy, medium, hard]); null = back to the code's. */
const band = z.tuple([
  z.number().int().min(1).max(1_000_000_000),
  z.number().int().min(1).max(1_000_000_000),
  z.number().int().min(1).max(1_000_000_000),
]);
const newHostDefaults = z
  .strictObject(
    Object.fromEntries(DEFAULT_KINDS.map((k) => [k, z.array(band).length(4)])) as Record<
      DefaultKind,
      z.ZodArray<typeof band>
    >,
  )
  .refine((v) => validNewHostDefaults(v), { message: 'easy ≤ medium ≤ hard' })
  .nullable();

export const settingsBody = z
  .strictObject({
    ...Object.fromEntries(KNOBS.map((k) => [k, knobs[k].optional()])),
    newHostDefaults: newHostDefaults.optional(),
    reason: z.string().trim().min(1).max(500),
  } as { [K in Knob]: z.ZodOptional<(typeof knobs)[K]> } & {
    newHostDefaults: z.ZodOptional<typeof newHostDefaults>;
    reason: z.ZodString;
  })
  .refine((v) => Object.keys(v).length > 1, { message: 'at least one change' });

const dayQuery = z.strictObject({
  day: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .optional(),
});

/**
 * «الأهداف الذكية» in the admin panel (v1.71-live, D281, CONVENTIONS §10.62.2) — OWNER only: the tuning knobs (the
 * level percentiles, the reward shares 1.5 / 2.5 / 4 %, the no-repeat days, …; every change with a reason, audited
 * with before and after), the catalogues' size, and a host's targets of a day with «لماذا هذا الهدف» (audited read).
 */
@Public()
@Controller('admin/host-targets')
@RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true })
@UseGuards(AdminSessionGuard)
export class AdminHostTargetsController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly targets: HostTargetsService,
    private readonly tasks: TasksService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  @Get('settings')
  @RequireCapability('host_targets.view')
  async settings(): Promise<HostTargetSettingsDto> {
    return settingsDto(await this.targets.settings());
  }

  @Put('settings')
  @RequireCapability('host_targets.edit')
  async update(
    @Body(new ZodValidationPipe(settingsBody)) body: z.infer<typeof settingsBody>,
    @CurrentAdmin() admin: AdminContext,
  ): Promise<HostTargetSettingsDto> {
    const {
      reason,
      newHostDefaults: defaults,
      ...patch
    } = body as { reason: string } & Partial<Record<Knob, number>> & {
        newHostDefaults?: NewHostDefaults | null;
      };
    const now = this.clock.now();
    const row = await this.prisma.$transaction(async (tx) => {
      const before = settingsDto(await this.targets.settings(tx));
      const merged = { ...before, ...patch };
      if (
        !(
          merged.easyPercentile < merged.mediumPercentile && merged.mediumPercentile < merged.hardPercentile
        ) ||
        !(merged.easyRewardBps <= merged.mediumRewardBps && merged.mediumRewardBps <= merged.hardRewardBps)
      ) {
        // The order must hold: easy < medium < hard percentiles, easy ≤ medium ≤ hard shares.
        throw AppException.validation([{ field: 'body', issue: 'invalid' }]);
      }
      const after = await tx.hostTargetSettings.update({
        where: { id: 1 },
        data: {
          ...patch,
          ...(defaults === undefined
            ? {}
            : {
                newHostDefaults:
                  defaults === null ? Prisma.DbNull : (defaults as unknown as Prisma.InputJsonValue),
              }),
          updatedAt: now,
          updatedById: admin.userId,
        },
      });
      const pick = (s: HostTargetSettingsDto) => ({
        ...Object.fromEntries(KNOBS.map((k) => [k, s[k]])),
        newHostDefaults: s.newHostDefaults,
      });
      await tx.auditLog.create({
        data: {
          action: AuditAction.HOST_TARGET_SETTINGS_UPDATE,
          actorUserId: admin.userId,
          targetType: 'host_target_settings',
          targetId: '1',
          metadata: { before: pick(before), after: pick(settingsDto(after)), reason, via: 'panel' },
          ip: admin.ip?.slice(0, 64) ?? null,
          requestId: admin.requestId ?? null,
        },
      });
      return after;
    });
    return settingsDto(row);
  }

  @Get('catalogue')
  @RequireCapability('host_targets.view')
  async catalogue() {
    const [targets, tasks] = await Promise.all([this.targets.targetCatalogue(), this.tasks.taskCatalogue()]);
    return { targets, tasks };
  }

  @Get('hosts/:username')
  @RequireCapability('host_targets.view')
  async host(
    @Param('username') username: string,
    @Query(new ZodValidationPipe(dayQuery)) q: z.infer<typeof dayQuery>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    const user = await this.prisma.user.findFirst({
      where: { profile: { username: username.trim().toLowerCase().slice(0, 40) } },
      select: { id: true, profile: { select: { username: true, displayName: true } } },
    });
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    const day =
      q.day ??
      (await programWindowsIn(this.prisma, this.clock.now(), this.config.live.rankingsTimeZone)).day.date;
    const targets = await this.targets.forPanel(user.id, day);
    await this.prisma.auditLog.create({
      data: {
        action: AuditAction.HOST_TARGET_VIEW,
        actorUserId: admin.userId,
        targetType: 'user',
        targetId: user.id,
        metadata: { day, via: 'panel' },
        ip: admin.ip?.slice(0, 64) ?? null,
        requestId: admin.requestId ?? null,
      },
    });
    return {
      host: {
        id: user.id,
        username: user.profile?.username ?? '',
        displayName: user.profile?.displayName ?? '',
      },
      day,
      // v1.139-social (D387, §10.176.2): the platform profit counted is the OWNER's (`revenue.view`).
      targets: admin.capabilities.includes('revenue.view') ? targets : targets.map((t) => ({ ...t, profitUsd: null })),
    };
  }
}

/** The panel's «الأهداف الذكية» (needs the admin session guard of AdminPanelModule). */
@Module({
  imports: [AdminPanelModule, ProgramsModule],
  controllers: [AdminHostTargetsController],
})
export class ProgramsAdminModule {}
