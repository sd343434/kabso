import { randomBytes } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { loadConfig, type AppConfig } from '../../config/app-config.js';
import { RegistrationService } from './registration.service.js';

const base = {
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  JWT_ACCESS_SECRET: 'x'.repeat(32),
  APP_PUBLIC_URL: 'http://localhost:3000',
};

/** Only the constructor's key derivation and `codeHash` are exercised; other deps are unused. */
function service(config: AppConfig): RegistrationService {
  const unused = {} as never;
  return new RegistrationService(
    unused,
    unused,
    unused,
    unused,
    unused,
    unused,
    unused,
    unused,
    unused,
    config,
  );
}

describe('registration code key (SEC-029)', () => {
  const rateKey = randomBytes(32).toString('base64url');
  const codeKey = randomBytes(32).toString('base64url');

  it('derives from RATE_LIMIT_KEY_SECRET when REGISTRATION_CODE_KEY is unset', () => {
    const a = service(loadConfig({ ...base, RATE_LIMIT_KEY_SECRET: rateKey }));
    const b = service(loadConfig({ ...base, RATE_LIMIT_KEY_SECRET: rateKey }));
    expect(a.codeHash('a@b.co', '12345678')).toBe(b.codeHash('a@b.co', '12345678'));
  });

  it('derives from REGISTRATION_CODE_KEY when set (independent of the rate-limit key)', () => {
    const withCodeKey = (rate: string) =>
      service(loadConfig({ ...base, RATE_LIMIT_KEY_SECRET: rate, REGISTRATION_CODE_KEY: codeKey }));
    const rotatedRateKey = randomBytes(32).toString('base64url');
    expect(withCodeKey(rateKey).codeHash('a@b.co', '12345678')).toBe(
      withCodeKey(rotatedRateKey).codeHash('a@b.co', '12345678'),
    );
    const legacy = service(loadConfig({ ...base, RATE_LIMIT_KEY_SECRET: rateKey }));
    expect(withCodeKey(rateKey).codeHash('a@b.co', '12345678')).not.toBe(
      legacy.codeHash('a@b.co', '12345678'),
    );
  });
});
