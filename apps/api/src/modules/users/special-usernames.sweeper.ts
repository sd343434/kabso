import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { sweepSpecialUsernames } from './special-usernames.js';

/**
 * v1.54-social (D185, §10.48.1): ends special usernames past `expires_at` (the person's own username is shown
 * again) and releases names whose grace ended. Every `SPECIAL_USERNAME_SWEEP_INTERVAL_SECONDS` (0: off).
 */
@Injectable()
export class SpecialUsernamesSweeper implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(SpecialUsernamesSweeper.name);
  private timer: NodeJS.Timeout | null = null;
  private inFlight: Promise<unknown> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  onModuleInit(): void {
    if (this.config.specialUsernames.sweepIntervalSeconds > 0) this.schedule();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    await this.inFlight?.catch(() => undefined);
  }

  /** One step (also the tests' entry). */
  sweep(): Promise<number> {
    return sweepSpecialUsernames(this.prisma, this.clock.now(), this.config.specialUsernames.graceDays);
  }

  private schedule(): void {
    this.timer = setTimeout(() => {
      this.inFlight = this.sweep()
        .then((n) => {
          if (n > 0) this.logger.log({ changed: n }, 'Special usernames swept');
        })
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Special-username sweep failed');
        })
        .finally(() => {
          this.inFlight = null;
          this.schedule();
        });
    }, this.config.specialUsernames.sweepIntervalSeconds * 1000);
    this.timer.unref();
  }
}
