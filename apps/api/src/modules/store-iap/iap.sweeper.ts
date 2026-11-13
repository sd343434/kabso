import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { IapService } from './iap.service.js';

/**
 * v1.110-social (D345, §10.144): every `STORE_IAP_SWEEP_INTERVAL_SECONDS` (0: off) — Google's voided purchases when the
 * daily poll is due, Apple consumption requests still to send, Google purchases still to consume.
 */
@Injectable()
export class IapSweeper implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(IapSweeper.name);
  private timer: NodeJS.Timeout | null = null;
  private inFlight: Promise<unknown> | null = null;

  constructor(
    private readonly iap: IapService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  onModuleInit(): void {
    const on = this.config.storeIap.google !== null || this.config.storeIap.apple !== null;
    if (on && this.config.storeIap.sweepIntervalSeconds > 0) this.schedule();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    await this.inFlight?.catch(() => undefined);
  }

  private schedule(): void {
    this.timer = setTimeout(() => {
      this.inFlight = this.iap
        .sweep()
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Store purchases sweep failed');
        })
        .finally(() => {
          this.inFlight = null;
          this.schedule();
        });
    }, this.config.storeIap.sweepIntervalSeconds * 1000);
    this.timer.unref();
  }
}
