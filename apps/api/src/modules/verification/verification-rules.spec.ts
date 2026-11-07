import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../config/app-config.js';
import { envSchema } from '../../config/env.schema.js';
import { verificationSettingsBody } from './verification.service.js';
import {
  changeOf,
  DEFAULT_THRESHOLDS,
  exceeds,
  pickBadge,
  thresholdsDto,
  VERIFICATION_BADGES,
  windowStart,
} from './verification-rules.js';

describe('D293 verification badge rules', () => {
  it('the owner priority: OWNER › STAFF › RECHARGE_AGENT › HOST_AGENT › CREATOR › VERIFIED_HOST', () => {
    expect(VERIFICATION_BADGES).toEqual([
      'OWNER',
      'STAFF',
      'RECHARGE_AGENT',
      'HOST_AGENT',
      'CREATOR',
      'VERIFIED_HOST',
    ]);
    expect(pickBadge([])).toBeNull();
    expect(pickBadge(['VERIFIED_HOST', 'CREATOR'])).toBe('CREATOR');
    expect(pickBadge(['VERIFIED_HOST', 'STAFF', 'OWNER'])).toBe('OWNER');
    expect(pickBadge(['HOST_AGENT', 'RECHARGE_AGENT'])).toBe('RECHARGE_AGENT');
    expect(pickBadge(['HOST_AGENT', 'VERIFIED_HOST'])).toBe('HOST_AGENT');
    expect(pickBadge(new Set(['STAFF', 'CREATOR'] as const))).toBe('STAFF');
  });

  it('"more than", exact in BIGINT (300 000 000 does not qualify; 300 000 001 does; far above 2^53 too)', () => {
    expect(exceeds(300_000_000n, DEFAULT_THRESHOLDS.rechargeMinSalesCoins)).toBe(false);
    expect(exceeds(300_000_001n, DEFAULT_THRESHOLDS.rechargeMinSalesCoins)).toBe(true);
    expect(exceeds(2n ** 63n - 1n, 2n ** 63n - 2n)).toBe(true);
    expect(exceeds(2n ** 63n - 2n, 2n ** 63n - 2n)).toBe(false);
  });

  it('the owner defaults and the 30-day window', () => {
    expect(thresholdsDto(DEFAULT_THRESHOLDS)).toEqual({
      rechargeMinSalesCoins: 300_000_000,
      rechargeMinCherries: 300_000_000,
      hostAgentMinHosts: 30,
      hostAgentMinCherries: 300_000_000,
    });
    const now = new Date('2026-11-06T12:00:00Z');
    expect(windowStart(now).toISOString()).toBe('2026-10-07T12:00:00.000Z');
  });

  it('a change is granted, changed or removed', () => {
    expect(changeOf(null, null)).toBeNull();
    expect(changeOf('CREATOR', 'CREATOR')).toBeNull();
    expect(changeOf(null, 'CREATOR')).toBe('granted');
    expect(changeOf('RECHARGE_AGENT', 'CREATOR')).toBe('changed');
    expect(changeOf('STAFF', null)).toBe('removed');
  });

  it('the panel body: at least one threshold, whole non-negative numbers ≤ 10^15, a reason and the code', () => {
    const ok = { reason: 'x', totpCode: '123456' };
    expect(verificationSettingsBody.safeParse({ ...ok, hostAgentMinHosts: 31 }).success).toBe(true);
    expect(verificationSettingsBody.safeParse({ ...ok, rechargeMinSalesCoins: 10 ** 15 }).success).toBe(true);
    expect(verificationSettingsBody.safeParse(ok).success).toBe(false);
    expect(verificationSettingsBody.safeParse({ ...ok, rechargeMinSalesCoins: 10 ** 15 + 1 }).success).toBe(
      false,
    );
    expect(verificationSettingsBody.safeParse({ ...ok, rechargeMinCherries: -1 }).success).toBe(false);
    expect(verificationSettingsBody.safeParse({ ...ok, hostAgentMinCherries: 1.5 }).success).toBe(false);
    expect(verificationSettingsBody.safeParse({ ...ok, hostAgentMinHosts: 100_001 }).success).toBe(false);
    expect(verificationSettingsBody.safeParse({ hostAgentMinHosts: 1, totpCode: '123456' }).success).toBe(
      false,
    );
    expect(verificationSettingsBody.safeParse({ hostAgentMinHosts: 1, reason: 'x' }).success).toBe(false);
    expect(verificationSettingsBody.safeParse({ ...ok, hostAgentMinHosts: 1, extra: 1 }).success).toBe(false);
  });
});

describe('D293 config', () => {
  const base = {
    NODE_ENV: 'development',
    DATABASE_URL: 'postgresql://u:p@localhost:5432/kabso_dev',
    REDIS_URL: 'redis://localhost:6379/0',
    JWT_ACCESS_SECRET: 'x'.repeat(48),
    APP_PUBLIC_URL: 'https://kabsolive.com',
  };
  it('the sweeper interval defaults to an hour; at most a day; off is refused in production', () => {
    expect(loadConfig(base).verificationBadges.sweepIntervalSeconds).toBe(3600);
    expect(
      loadConfig({ ...base, VERIFICATION_BADGE_SWEEP_INTERVAL_SECONDS: '86400' }).verificationBadges,
    ).toEqual({
      sweepIntervalSeconds: 86_400,
    });
    expect(envSchema.safeParse({ ...base, VERIFICATION_BADGE_SWEEP_INTERVAL_SECONDS: '86401' }).success).toBe(
      false,
    );
    expect(
      loadConfig({ ...base, VERIFICATION_BADGE_SWEEP_INTERVAL_SECONDS: '0' }).verificationBadges,
    ).toEqual({
      sweepIntervalSeconds: 0,
    });
    const prod = envSchema.safeParse({
      ...base,
      NODE_ENV: 'production',
      VERIFICATION_BADGE_SWEEP_INTERVAL_SECONDS: '0',
    });
    expect(prod.success).toBe(false);
    expect(prod.error!.issues.some((i) => i.path[0] === 'VERIFICATION_BADGE_SWEEP_INTERVAL_SECONDS')).toBe(
      true,
    );
  });
});
