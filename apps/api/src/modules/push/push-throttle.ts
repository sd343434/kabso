import { Inject, Injectable } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { REDIS } from '../../redis/redis.module.js';

/**
 * D152 burst collapse (CONVENTIONS §11.12): "at most one push per key per N seconds", one Redis
 * `SET NX EX` per key. Redis down → the push goes out (a missed collapse is better than a lost
 * message; FCM's own `tag` still replaces the shown notification).
 */
@Injectable()
export class PushThrottle {
  constructor(@Inject(REDIS) private readonly redis: Redis) {}

  /** True when nothing with `key` went out in the last `seconds` (0 = always true). */
  async allow(key: string, seconds: number): Promise<boolean> {
    if (seconds <= 0) return true;
    try {
      return (await this.redis.set(`push:${key}`, '1', 'EX', seconds, 'NX')) === 'OK';
    } catch {
      return true;
    }
  }

  /** {@link allow} for many keys in one round trip; answers the keys that may go out. */
  async allowMany(keys: readonly string[], seconds: number): Promise<Set<string>> {
    if (seconds <= 0 || keys.length === 0) return new Set(keys);
    try {
      const pipeline = this.redis.pipeline();
      for (const key of keys) pipeline.set(`push:${key}`, '1', 'EX', seconds, 'NX');
      const answers = (await pipeline.exec()) ?? [];
      return new Set(keys.filter((_, i) => answers[i]?.[1] === 'OK'));
    } catch {
      return new Set(keys);
    }
  }
}
