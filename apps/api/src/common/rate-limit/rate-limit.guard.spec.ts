import 'reflect-metadata';
import { randomBytes } from 'node:crypto';
import type { ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../config/app-config.js';
import type { RateLimitRule } from '../../config/env.schema.js';
import { LiveController } from '../../modules/live/live.controller.js';
import { FollowsController } from '../../modules/social/follows.controller.js';
import { PublicProfileController } from '../../modules/users/profiles/public-profile.controller.js';
import { AppException } from '../errors/app-exception.js';
import { ErrorCode } from '../errors/error-codes.js';
import type { AppRequest } from '../http/request-context.js';
import { RateLimitGuard } from './rate-limit.guard.js';
import { RateLimitService } from './rate-limit.service.js';

const USER_ID = '0192f1c2-7a10-7c3e-9d2a-3b4c5d6e7f80';
const config = loadConfig({
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  JWT_ACCESS_SECRET: randomBytes(48).toString('base64url'),
  RATE_LIMIT_KEY_SECRET: randomBytes(48).toString('base64url'),
  APP_PUBLIC_URL: 'https://kabso.example',
});

interface Hit {
  bucket: string;
  subject: string;
  rule: RateLimitRule;
}

class RecordingLimiter {
  readonly hits: Hit[] = [];
  reject: string | null = null;
  consume(bucket: string, subject: string, rule: RateLimitRule): Promise<void> {
    this.hits.push({ bucket, subject, rule });
    if (bucket === this.reject) return Promise.reject(new AppException(ErrorCode.RATE_LIMITED));
    return Promise.resolve();
  }
}

function contextFor(
  handler: (...args: never[]) => unknown,
  cls: object,
  req: Partial<AppRequest>,
): ExecutionContext {
  return {
    getType: () => 'http',
    getHandler: () => handler,
    getClass: () => cls,
    switchToHttp: () => ({ getRequest: () => req }),
  } as unknown as ExecutionContext;
}

async function bucketsFor(handler: (...args: never[]) => unknown, cls: object): Promise<Hit[]> {
  const limiter = new RecordingLimiter();
  const guard = new RateLimitGuard(new Reflector(), limiter as unknown as RateLimitService, config);
  await guard.canActivate(contextFor(handler, cls, { auth: { userId: USER_ID, sessionId: 's' } }));
  return limiter.hits;
}

const live = LiveController.prototype;
const follows = FollowsController.prototype;
const profiles = PublicProfileController.prototype;

describe('v1.3 rate limits (CONVENTIONS §7)', () => {
  it.each([
    ['GET /live/rooms', live.listRooms, LiveController, [['live:list', config.rateLimits.liveListUser]]],
    [
      'POST /live/rooms',
      live.startRoom,
      LiveController,
      [
        ['live:start:h', config.rateLimits.liveStartHourUser],
        ['live:start:d', config.rateLimits.liveStartDayUser],
      ],
    ],
    ['heartbeat', live.heartbeat, LiveController, [['live:heartbeat', config.rateLimits.liveHeartbeatUser]]],
    ['end', live.endRoom, LiveController, [['live:end', config.rateLimits.liveEndUser]]],
    [
      'GET /users/{username}',
      profiles.get,
      PublicProfileController,
      [['users:profile', config.rateLimits.profileUser]],
    ],
    [
      'PUT follow',
      follows.follow,
      FollowsController,
      [
        ['follow:h', config.rateLimits.followHourUser],
        ['follow:d', config.rateLimits.followDayUser],
      ],
    ],
    [
      'DELETE follow',
      follows.unfollow,
      FollowsController,
      [
        ['follow:h', config.rateLimits.followHourUser],
        ['follow:d', config.rateLimits.followDayUser],
      ],
    ],
  ] as const)(
    '%s uses its own per-user buckets instead of the default',
    async (_name, handler, cls, expected) => {
      const hits = await bucketsFor(handler as (...args: never[]) => unknown, cls);
      expect(hits.map((h) => [h.bucket, h.rule])).toEqual(expected);
      expect(hits.every((h) => h.subject === USER_ID)).toBe(true);
    },
  );

  it.each([
    ['GET /live/config', live.config],
    ['GET /live/categories', live.listCategories],
    ['GET /live/rooms/{roomId}', live.getRoom],
  ] as const)('%s counts against the default authenticated bucket', async (_name, handler) => {
    const hits = await bucketsFor(handler as (...args: never[]) => unknown, LiveController);
    expect(hits.map((h) => [h.bucket, h.subject, h.rule])).toEqual([
      ['user', USER_ID, config.rateLimits.authenticatedUser],
    ]);
  });

  it('follow and unfollow share the same bucket names (one budget)', async () => {
    const put = await bucketsFor(follows.follow, FollowsController);
    const del = await bucketsFor(follows.unfollow, FollowsController);
    expect(put.map((h) => h.bucket)).toEqual(del.map((h) => h.bucket));
  });

  it('rethrows RATE_LIMITED and stops at the first exhausted bucket', async () => {
    const limiter = new RecordingLimiter();
    limiter.reject = 'live:start:h';
    const guard = new RateLimitGuard(new Reflector(), limiter as unknown as RateLimitService, config);
    await expect(
      guard.canActivate(
        contextFor(live.startRoom as (...args: never[]) => unknown, LiveController, {
          auth: { userId: USER_ID, sessionId: 's' },
        }),
      ),
    ).rejects.toMatchObject({ code: ErrorCode.RATE_LIMITED });
    expect(limiter.hits.map((h) => h.bucket)).toEqual(['live:start:h']);
  });

  it('bucket keys are HMACs: no raw user id in the Redis key', () => {
    const service = new RateLimitService({} as never, config);
    for (const bucket of [
      'live:list',
      'users:profile',
      'live:start:h',
      'live:start:d',
      'live:heartbeat',
      'live:end',
      'follow:h',
      'follow:d',
    ]) {
      const key = service.keyFor(bucket, USER_ID);
      expect(key).toMatch(new RegExp(`^rl:${bucket}:[A-Za-z0-9_-]{32}$`));
      expect(key).not.toContain(USER_ID);
      expect(key).not.toContain(USER_ID.replace(/-/g, ''));
    }
    expect(service.keyFor('follow:h', USER_ID)).not.toBe(service.keyFor('follow:d', USER_ID));
  });
});
