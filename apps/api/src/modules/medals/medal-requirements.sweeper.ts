import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { sweepRequirementMedals, type RequirementSweepResult } from './medal-requirements.js';

/**
 * D300 (CONVENTIONS §10.111): every `MEDAL_CREATOR_SWEEP_INTERVAL_SECONDS` (default 600; 0: off — tests; refused in
 * production) the content creators' multi-requirement medals («مدرسة المحتوى») are raised to the level their followers,
 * likes and views reach together (`sweepRequirementMedals` with its upper-bound pre-filter). Levels never go down; a
 * repeat or two replicas at once change nothing twice (the D291 raise is idempotent per row).
 */
@Injectable()
export class MedalRequirementsSweeper implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(MedalRequirementsSweeper.name);
  private timer: NodeJS.Timeout | null = null;
  private inFlight: Promise<unknown> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  onModuleInit(): void {
    if (this.config.medalCreators.sweepIntervalSeconds > 0) this.schedule();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    await this.inFlight?.catch(() => undefined);
  }

  /** One run (the timer's; tests call it directly). Notifies every change. */
  sweep(): Promise<RequirementSweepResult> {
    return sweepRequirementMedals(this.prisma, { via: 'sweep', prefilter: true, at: this.clock.now() });
  }

  private schedule(): void {
    this.timer = setTimeout(() => {
      this.inFlight = this.sweep()
        .then((r) => {
          if (r.raised.length > 0) {
            this.logger.log(
              { candidates: r.candidates, counted: r.counted, raised: r.raised.length },
              'Content-creator medals raised',
            );
          }
        })
        .catch((err: unknown) =>
          this.logger.error({ error: safeErrorLog(err) }, 'Content-creator medal sweep failed'),
        )
        .finally(() => {
          this.inFlight = null;
          this.schedule();
        });
    }, this.config.medalCreators.sweepIntervalSeconds * 1000);
    this.timer.unref();
  }
}
