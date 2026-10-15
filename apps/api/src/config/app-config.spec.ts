import { describe, expect, it } from 'vitest';
import { ConfigValidationError, loadConfig } from './app-config.js';

const base = {
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  JWT_ACCESS_SECRET: 'k9Qz2vX7pL4mN8rT1wY6bC3dF5gH0jK2sA7eR9uI',
  APP_PUBLIC_URL: 'https://kabso.example/',
};

describe('loadConfig', () => {
  it('applies CONVENTIONS defaults', () => {
    const config = loadConfig(base);
    expect(config.jwt).toMatchObject({
      accessTtlSeconds: 900,
      issuer: 'kabso-api',
      audience: 'kabso-mobile',
    });
    expect(config.refresh).toEqual({ ttlSeconds: 2_592_000, absoluteTtlSeconds: 15_552_000 });
    expect(config.rateLimits.loginIpIdentifier).toEqual({ max: 10, windowSeconds: 900 });
    expect(config.rateLimits.loginIp).toEqual({ max: 50, windowSeconds: 900 });
    expect(config.rateLimits.registerIp).toEqual({ max: 5, windowSeconds: 3600 });
    expect(config.rateLimits.forgotEmail).toEqual({ max: 3, windowSeconds: 3600 });
    expect(config.rateLimits.forgotIp).toEqual({ max: 10, windowSeconds: 3600 });
    expect(config.rateLimits.refreshSession).toEqual({ max: 60, windowSeconds: 900 });
    expect(config.rateLimits.authenticatedUser).toEqual({ max: 600, windowSeconds: 900 });
    expect(config.appPublicUrl).toBe('https://kabso.example');
    expect(config.http.trustProxy).toBe(false);
  });

  it('parses overrides', () => {
    const config = loadConfig({
      ...base,
      RATE_LIMIT_LOGIN_IP: '5/60',
      CORS_ORIGINS: 'https://a.example, https://b.example',
      TRUST_PROXY: '1',
    });
    expect(config.rateLimits.loginIp).toEqual({ max: 5, windowSeconds: 60 });
    expect(config.http.corsOrigins).toEqual(['https://a.example', 'https://b.example']);
    expect(config.http.trustProxy).toBe(1);
  });

  it('fails fast listing every problem without echoing secret values', () => {
    let error: unknown;
    try {
      loadConfig({ JWT_ACCESS_SECRET: 'tooshort', RATE_LIMIT_LOGIN_IP: 'ten' });
    } catch (err) {
      error = err;
    }
    expect(error).toBeInstanceOf(ConfigValidationError);
    const message = (error as Error).message;
    expect(message).toContain('DATABASE_URL');
    expect(message).toContain('REDIS_URL');
    expect(message).toContain('JWT_ACCESS_SECRET: must be at least 32 bytes');
    expect(message).toContain('RATE_LIMIT_LOGIN_IP');
    expect(message).toContain('APP_PUBLIC_URL');
    expect(message).not.toContain('tooshort');
  });

  it('rejects placeholder secrets and the log mail transport in production', () => {
    expect(() =>
      loadConfig({
        ...base,
        NODE_ENV: 'production',
        JWT_ACCESS_SECRET: 'replace-me-with-a-long-random-string-of-at-least-32-bytes',
      }),
    ).toThrow(/JWT_ACCESS_SECRET: looks like a placeholder[\s\S]*MAIL_TRANSPORT/);
  });

  it('rejects an absolute refresh TTL shorter than the sliding TTL', () => {
    expect(() =>
      loadConfig({ ...base, REFRESH_TTL_SECONDS: '100', REFRESH_ABSOLUTE_TTL_SECONDS: '50' }),
    ).toThrow(/REFRESH_ABSOLUTE_TTL_SECONDS/);
  });
});
