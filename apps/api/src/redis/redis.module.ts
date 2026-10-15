import {
  Global,
  Inject,
  Injectable,
  Logger,
  Module,
  type OnApplicationShutdown,
  type OnModuleInit,
} from '@nestjs/common';
import { Redis } from 'ioredis';
import { APP_CONFIG, type AppConfig } from '../config/app-config.js';

export const REDIS = Symbol('REDIS');

const READY_TIMEOUT_MS = 3000;

/** Waits for the initial connection on boot and closes it on shutdown. */
@Injectable()
class RedisLifecycle implements OnModuleInit, OnApplicationShutdown {
  private readonly logger = new Logger('Redis');

  constructor(@Inject(REDIS) private readonly redis: Redis) {}

  async onModuleInit(): Promise<void> {
    if (this.redis.status === 'ready') return;
    const ready = await new Promise<boolean>((resolve) => {
      const timer = setTimeout(() => resolve(false), READY_TIMEOUT_MS);
      this.redis.once('ready', () => {
        clearTimeout(timer);
        resolve(true);
      });
    });
    if (!ready) {
      // Not fatal: /health/ready reports it and rate-limited routes answer 503 until it is back.
      this.logger.warn('Redis not ready at startup; continuing (will keep retrying)');
    }
  }

  async onApplicationShutdown(): Promise<void> {
    if (this.redis.status === 'end') return;
    try {
      await this.redis.quit();
    } catch {
      this.redis.disconnect();
    }
  }
}

@Global()
@Module({
  providers: [
    {
      provide: REDIS,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig): Redis => {
        const logger = new Logger('Redis');
        const client = new Redis(config.redis.url, {
          keyPrefix: config.redis.keyPrefix,
          // Fail fast instead of queueing commands while Redis is unreachable, so rate limiting
          // and readiness checks report the outage immediately.
          enableOfflineQueue: false,
          maxRetriesPerRequest: 1,
          connectTimeout: 2000,
          retryStrategy: (attempt) => Math.min(attempt * 200, 5000),
        });
        let lastLoggedAt = 0;
        client.on('error', (err: Error) => {
          const now = Date.now();
          if (now - lastLoggedAt > 10_000) {
            lastLoggedAt = now;
            logger.error({ err: { message: err.message } }, 'Redis connection error');
          }
        });
        return client;
      },
    },
    RedisLifecycle,
  ],
  exports: [REDIS],
})
export class RedisModule {}
