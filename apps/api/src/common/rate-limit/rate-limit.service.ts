import { createHmac } from 'node:crypto';
import { safeErrorLog } from '../../logging/redact-text.js';
import { Inject, Injectable, Logger } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
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

/**
 * Amount budget (e.g. declared upload bytes per day): adds ARGV[2] and, if that exceeds ARGV[3],
 * takes it back in the same atomic step, so a rejected request never consumes budget and
 * concurrent requests can never exceed it. Returns [allowed (1|0), ttlMilliseconds].
 */
const AMOUNT_SCRIPT = `
local amount = tonumber(ARGV[2])
local total = redis.call('INCRBY', KEYS[1], amount)
if total == amount then
  redis.call('PEXPIRE', KEYS[1], ARGV[1])
end
local ttl = redis.call('PTTL', KEYS[1])
if ttl < 0 then
  redis.call('PEXPIRE', KEYS[1], ARGV[1])
  ttl = tonumber(ARGV[1])
end
if total > tonumber(ARGV[3]) then
  redis.call('DECRBY', KEYS[1], amount)
  return { 0, ttl }
end
return { 1, ttl }
`;

const REFUND_AMOUNT_SCRIPT = `
local count = tonumber(redis.call('GET', KEYS[1]) or '0')
local amount = math.min(count, tonumber(ARGV[1]))
if amount > 0 then
  redis.call('DECRBY', KEYS[1], amount)
end
return amount
`;

const REFUND_SCRIPT = `
local count = tonumber(redis.call('GET', KEYS[1]) or '0')
if count > 0 then
  redis.call('DECR', KEYS[1])
end
return count
`;

export interface RateLimitResult {
  readonly allowed: boolean;
  readonly count: number;
  readonly retryAfterSeconds: number;
}

@Injectable()
export class RateLimitService {
  private readonly logger = new Logger(RateLimitService.name);

  constructor(
    @Inject(REDIS) private readonly redis: Redis,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /**
   * Redis key for a subject (email, identifier, IP bucket, user id). Subjects are never stored
   * raw or as a plain hash: HMAC-SHA-256 under RATE_LIMIT_KEY_SECRET (SEC-010).
   */
  keyFor(bucket: string, subject: string): string {
    const mac = createHmac('sha256', this.config.rateLimitKeySecret)
      .update(`${bucket}\u0000${subject}`)
      .digest('base64url')
      .slice(0, 32);
    return `rl:${bucket}:${mac}`;
  }

  /** Records one hit for `subject` in `bucket` and reports whether it is within `rule`. */
  async hit(bucket: string, subject: string, rule: RateLimitRule): Promise<RateLimitResult> {
    const redisKey = this.keyFor(bucket, subject);
    let reply: unknown;
    try {
      reply = await this.redis.eval(HIT_SCRIPT, 1, redisKey, String(rule.windowSeconds * 1000));
    } catch (err) {
      // Fail closed: abuse protection on auth endpoints must not silently disappear.
      this.logger.error({ error: safeErrorLog(err), bucket }, 'Rate limiter unavailable');
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
  async consume(bucket: string, subject: string, rule: RateLimitRule): Promise<void> {
    const result = await this.hit(bucket, subject, rule);
    if (!result.allowed) {
      throw new AppException(ErrorCode.RATE_LIMITED, undefined, undefined, {
        'Retry-After': String(result.retryAfterSeconds),
      });
    }
  }

  /**
   * Consumes `amount` units of a per-window budget (`rule.max` units per `rule.windowSeconds`)
   * or throws RATE_LIMITED (with `Retry-After`) without consuming anything (v1.4: daily declared
   * upload bytes, CONVENTIONS §7).
   */
  async consumeAmount(bucket: string, subject: string, amount: number, rule: RateLimitRule): Promise<void> {
    let reply: unknown;
    try {
      reply = await this.redis.eval(
        AMOUNT_SCRIPT,
        1,
        this.keyFor(bucket, subject),
        String(rule.windowSeconds * 1000),
        String(amount),
        String(rule.max),
      );
    } catch (err) {
      this.logger.error({ error: safeErrorLog(err), bucket }, 'Rate limiter unavailable');
      throw new AppException(ErrorCode.SERVICE_UNAVAILABLE);
    }
    const [allowed, ttlMs] = reply as [number, number];
    if (allowed !== 1) {
      throw new AppException(ErrorCode.RATE_LIMITED, undefined, undefined, {
        'Retry-After': String(Math.max(1, Math.ceil(ttlMs / 1000))),
      });
    }
  }

  /** Gives back `amount` units consumed by {@link consumeAmount} (never below zero). */
  async refundAmount(bucket: string, subject: string, amount: number): Promise<void> {
    try {
      await this.redis.eval(REFUND_AMOUNT_SCRIPT, 1, this.keyFor(bucket, subject), String(amount));
    } catch (err) {
      this.logger.error({ error: safeErrorLog(err), bucket }, 'Rate limiter unavailable');
      throw new AppException(ErrorCode.SERVICE_UNAVAILABLE);
    }
  }

  /**
   * Gives back one hit of a counter reserved by {@link consume}/{@link hit} (increment-before-check
   * pattern, contract v1.2.3 §7). Never goes below zero and keeps the window's TTL.
   */
  async refund(bucket: string, subject: string): Promise<void> {
    try {
      await this.redis.eval(REFUND_SCRIPT, 1, this.keyFor(bucket, subject));
    } catch (err) {
      this.logger.error({ error: safeErrorLog(err), bucket }, 'Rate limiter unavailable');
      throw new AppException(ErrorCode.SERVICE_UNAVAILABLE);
    }
  }

  /** Sets a keyed flag with a TTL; returns false if it was already set (SET NX EX). */
  async setFlagOnce(bucket: string, subject: string, ttlSeconds: number): Promise<boolean> {
    try {
      return (await this.redis.set(this.keyFor(bucket, subject), '1', 'EX', ttlSeconds, 'NX')) === 'OK';
    } catch (err) {
      this.logger.error({ error: safeErrorLog(err), bucket }, 'Rate limiter unavailable');
      throw new AppException(ErrorCode.SERVICE_UNAVAILABLE);
    }
  }

  /** Sets (or refreshes) a keyed flag with a TTL. */
  async setFlag(bucket: string, subject: string, ttlSeconds: number): Promise<void> {
    try {
      await this.redis.set(this.keyFor(bucket, subject), '1', 'EX', ttlSeconds);
    } catch (err) {
      this.logger.error({ error: safeErrorLog(err), bucket }, 'Rate limiter unavailable');
      throw new AppException(ErrorCode.SERVICE_UNAVAILABLE);
    }
  }

  async hasFlag(bucket: string, subject: string): Promise<boolean> {
    try {
      return (await this.redis.exists(this.keyFor(bucket, subject))) === 1;
    } catch (err) {
      this.logger.error({ error: safeErrorLog(err), bucket }, 'Rate limiter unavailable');
      throw new AppException(ErrorCode.SERVICE_UNAVAILABLE);
    }
  }
}
