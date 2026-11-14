import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../config/app-config.js';
import { envSchema } from '../../config/env.schema.js';
import { sortRequirements } from './medal-requirements.js';

// D300 (CONVENTIONS §10.111): the content-creator medals' sweeper setting and the requirements' order.
describe('D300 content-creator medals', () => {
  const base = {
    NODE_ENV: 'development',
    DATABASE_URL: 'postgresql://u:p@localhost:5432/kabso_dev',
    REDIS_URL: 'redis://localhost:6379/0',
    JWT_ACCESS_SECRET: 'x'.repeat(48),
    APP_PUBLIC_URL: 'https://kabsolive.com',
  };

  it('the sweeper interval defaults to 10 minutes; at most a day; off is refused in production', () => {
    expect(loadConfig(base).medalCreators).toEqual({ sweepIntervalSeconds: 600 });
    expect(loadConfig({ ...base, MEDAL_CREATOR_SWEEP_INTERVAL_SECONDS: '86400' }).medalCreators).toEqual({
      sweepIntervalSeconds: 86_400,
    });
    expect(envSchema.safeParse({ ...base, MEDAL_CREATOR_SWEEP_INTERVAL_SECONDS: '86401' }).success).toBe(
      false,
    );
    expect(loadConfig({ ...base, MEDAL_CREATOR_SWEEP_INTERVAL_SECONDS: '0' }).medalCreators).toEqual({
      sweepIntervalSeconds: 0,
    });
    const prod = envSchema.safeParse({
      ...base,
      NODE_ENV: 'production',
      MEDAL_CREATOR_SWEEP_INTERVAL_SECONDS: '0',
    });
    expect(prod.success).toBe(false);
    expect(prod.error!.issues.some((i) => i.path[0] === 'MEDAL_CREATOR_SWEEP_INTERVAL_SECONDS')).toBe(true);
  });

  it('requirements are shown followers, likes, views; unknown metrics last', () => {
    expect(
      sortRequirements([
        { metric: 'CREATOR_VIEWS' },
        { metric: 'SOMETHING_NEW' },
        { metric: 'CREATOR_FOLLOWERS' },
        { metric: 'CREATOR_LIKES' },
      ]).map((r) => r.metric),
    ).toEqual(['CREATOR_FOLLOWERS', 'CREATOR_LIKES', 'CREATOR_VIEWS', 'SOMETHING_NEW']);
  });
});
