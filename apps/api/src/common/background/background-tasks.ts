import { Global, Injectable, Logger, Module, type OnModuleDestroy } from '@nestjs/common';
import { safeErrorLog } from '../../logging/redact-text.js';

/**
 * Runs work after the HTTP response has been written (equal latency for responses that must not
 * reveal which branch ran — contract v1.2 §6, forgot-password). Failures are logged, never
 * surfaced. Outstanding tasks are awaited on shutdown (before Prisma/Redis disconnect, which
 * happen in `onApplicationShutdown`).
 */
@Injectable()
export class BackgroundTasks implements OnModuleDestroy {
  private readonly logger = new Logger(BackgroundTasks.name);
  private readonly running = new Set<Promise<void>>();

  /** Schedules `task` on the next macrotask (after the current response is flushed). */
  run(name: string, task: () => Promise<void>): void {
    const promise = new Promise<void>((resolve) => setImmediate(resolve))
      .then(task)
      .catch((err: unknown) => {
        this.logger.error({ error: safeErrorLog(err), task: name }, 'Background task failed');
      })
      .finally(() => {
        this.running.delete(promise);
      });
    this.running.add(promise);
  }

  /** Resolves when every task scheduled so far (and any they schedule) has settled. */
  async idle(): Promise<void> {
    while (this.running.size > 0) await Promise.allSettled([...this.running]);
  }

  async onModuleDestroy(): Promise<void> {
    await this.idle();
  }
}

@Global()
@Module({ providers: [BackgroundTasks], exports: [BackgroundTasks] })
export class BackgroundTasksModule {}
