import { Inject, Injectable, Logger } from '@nestjs/common';
import type { Redis } from 'ioredis';
import type { RateLimitRule } from '../../config/env.schema.js';
import { REDIS } from '../../redis/redis.module.js';
import { AppException } from '../errors/app-exception.js';
import { ErrorCode } from '../errors/error-codes.js';

/**
 * Fixed-window counter: INCR the key and set its expiry on first hit, atomically.
 * Returns [count, ttlMilliseconds].
 */
const HIT_SCRIPT = `
local count = redis.call('INCR', KEYS[1])
if count == 1 then
  redis.call('PEXPIRE', KEYS[1], ARGV[1])
end
local ttl = redis.call('PTTL', KEYS[1])
if ttl < 0 then
  redis.call('PEXPIRE', KEYS[1], ARGV[1])
  ttl = tonumber(ARGV[1])
end
return { count, ttl }
`;

export interface RateLimitResult {
  readonly allowed: boolean;
  readonly count: number;
  readonly retryAfterSeconds: number;
}

@Injectable()
export class RateLimitService {
  private readonly logger = new Logger(RateLimitService.name);

  constructor(@Inject(REDIS) private readonly redis: Redis) {}

  /** Records one hit for `bucket:key` and reports whether it is within `rule`. */
  async hit(bucket: string, key: string, rule: RateLimitRule): Promise<RateLimitResult> {
    const redisKey = `rl:${bucket}:${key}`;
    let reply: unknown;
    try {
      reply = await this.redis.eval(HIT_SCRIPT, 1, redisKey, String(rule.windowSeconds * 1000));
    } catch (err) {
      // Fail closed: abuse protection on auth endpoints must not silently disappear.
      this.logger.error({ err: { message: (err as Error).message }, bucket }, 'Rate limiter unavailable');
      throw new AppException(ErrorCode.SERVICE_UNAVAILABLE);
    }
    const [count, ttlMs] = reply as [number, number];
    return {
      allowed: count <= rule.max,
      count,
      retryAfterSeconds: Math.max(1, Math.ceil(ttlMs / 1000)),
    };
  }

  /** Like {@link hit} but throws RATE_LIMITED (with `Retry-After`) when over the limit. */
  async consume(bucket: string, key: string, rule: RateLimitRule): Promise<void> {
    const result = await this.hit(bucket, key, rule);
    if (!result.allowed) {
      throw new AppException(ErrorCode.RATE_LIMITED, undefined, undefined, {
        'Retry-After': String(result.retryAfterSeconds),
      });
    }
  }
}
