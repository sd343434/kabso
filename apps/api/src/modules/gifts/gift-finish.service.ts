import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { OBJECT_STORAGE, type ObjectStorage } from '../media/object-storage.js';
import { emptiedArchivedGiftsIn, finishArchivedGiftIn, type GiftFinish } from './gift-admin-rules.js';
import { unusedGiftFileKeysIn } from './gift-catalogue.js';

/**
 * v1.102-social (D338, CONVENTIONS §10.131; owner: «مخفية الا ان تنتهي من حقيبة المستخدمين ثم تحذف»): an archived gift
 * is finished once nobody holds a piece — deleted for real (and its unused files) when it has no history, else kept
 * archived for history. Checked right after a bag send of an archived gift ({@link finish}) and by a sweep on the
 * events sweeper's interval (`EVENTS_SWEEP_INTERVAL_SECONDS`; 0 = off), so pieces that left without a send (deleted
 * accounts) are not missed. `gift-admin finish` runs the same rule.
 */
@Injectable()
export class GiftFinishService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(GiftFinishService.name);
  private timer: NodeJS.Timeout | null = null;
  private inFlight: Promise<unknown> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  onModuleInit(): void {
    if (this.config.programs.eventsSweepIntervalSeconds > 0) this.schedule();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    await this.inFlight?.catch(() => undefined);
  }

  /** Finishes archived gift `code` if nobody holds a piece; a failure is logged (the send that called it is done). */
  async finish(code: string): Promise<GiftFinish | null> {
    try {
      const done = await this.prisma.$transaction((tx) => finishArchivedGiftIn(tx, code, 'system'));
      if (done?.result === 'DELETED') {
        await this.removeFiles([
          done.before.imageObjectKey,
          done.before.animationObjectKey,
          done.before.audioObjectKey,
        ]);
      }
      return done;
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err), gift: code }, 'Archived gift could not be finished');
      return null;
    }
  }

  /** Every archived gift nobody holds a piece of: how many were deleted and kept. */
  async sweep(): Promise<{ deleted: number; kept: number }> {
    let deleted = 0;
    let kept = 0;
    for (const code of await emptiedArchivedGiftsIn(this.prisma)) {
      const done = await this.finish(code);
      if (done?.result === 'DELETED') deleted += 1;
      else if (done?.result === 'KEPT') kept += 1;
    }
    return { deleted, kept };
  }

  private async removeFiles(keys: readonly (string | null)[]): Promise<void> {
    const gone = await unusedGiftFileKeysIn(this.prisma, keys);
    if (gone.length === 0) return;
    try {
      await this.storage.delete(gone);
    } catch (err) {
      // The gift is gone; the files only cost storage.
      this.logger.warn(
        { error: safeErrorLog(err), keys: gone.length },
        'Deleted gift files could not be removed',
      );
    }
  }

  private schedule(): void {
    this.timer = setTimeout(() => {
      this.inFlight = this.sweep()
        .then((r) => {
          if (r.deleted > 0) this.logger.log(r, 'Archived gifts finished');
        })
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Archived gift sweep failed');
        })
        .finally(() => {
          this.inFlight = null;
          this.schedule();
        });
    }, this.config.programs.eventsSweepIntervalSeconds * 1000);
    this.timer.unref();
  }
}
