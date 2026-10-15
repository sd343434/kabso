import type { ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { describe, expect, it, vi } from 'vitest';
import { RateLimitGuard } from '../../common/rate-limit/rate-limit.guard.js';
import type { RateLimitService } from '../../common/rate-limit/rate-limit.service.js';
import { loadConfig } from '../../config/app-config.js';
import { AccessTokenGuard } from './access-token.guard.js';
import type { AccessTokenService } from './access-token.service.js';
import type { SessionsService } from './sessions.service.js';

const config = loadConfig({
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  JWT_ACCESS_SECRET: 'x'.repeat(32),
  APP_PUBLIC_URL: 'http://localhost:3000',
});

function contextOf(type: string): ExecutionContext {
  return {
    getType: () => type,
    getHandler: () => () => undefined,
    getClass: () => class {},
    switchToHttp: () => {
      throw new Error('must not be reached for non-HTTP contexts');
    },
  } as unknown as ExecutionContext;
}

describe('guards deny non-HTTP execution contexts (SEC-013)', () => {
  const verify = vi.fn();
  const access = new AccessTokenGuard(
    new Reflector(),
    { verify } as unknown as AccessTokenService,
    {} as SessionsService,
  );
  const consume = vi.fn();
  const rate = new RateLimitGuard(new Reflector(), { consume } as unknown as RateLimitService, config);

  it.each(['ws', 'rpc', 'graphql'])('AccessTokenGuard and RateLimitGuard refuse %s', async (type) => {
    expect(await access.canActivate(contextOf(type))).toBe(false);
    expect(await rate.canActivate(contextOf(type))).toBe(false);
    expect(verify).not.toHaveBeenCalled();
    expect(consume).not.toHaveBeenCalled();
  });
});
