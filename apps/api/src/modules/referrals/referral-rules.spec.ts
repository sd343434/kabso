import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../config/app-config.js';
import { envSchema } from '../../config/env.schema.js';
import {
  adminReferralSettingsBody,
  canonicalEmail,
  CODE_ALPHABET,
  CODE_LENGTH,
  firstRechargeCherries,
  heroUpTo,
  maskName,
  milestoneState,
  milestonesTotal,
  newReferralCode,
  normalizeReferralCode,
  parseMilestones,
  patchOf,
  referralCodeInput,
  referralSettingsPatch,
} from './referral-rules.js';

describe('D217 invite codes', () => {
  it('are 8 characters without look-alikes, and differ', () => {
    const codes = new Set(Array.from({ length: 500 }, () => newReferralCode()));
    expect(codes.size).toBe(500);
    for (const c of codes) {
      expect(c).toHaveLength(CODE_LENGTH);
      expect([...c].every((ch) => CODE_ALPHABET.includes(ch))).toBe(true);
      expect(c).not.toMatch(/[01ILOU]/);
    }
  });

  it('a typed code or an invite link reads as the stored code', () => {
    expect(normalizeReferralCode(' k7qm-4p2x ')).toBe('K7QM4P2X');
    expect(normalizeReferralCode('https://kabsolive.com/i/K7QM4P2X')).toBe('K7QM4P2X');
    expect(normalizeReferralCode('https://kabsolive.com/i/k7qm4p2x/')).toBe('K7QM4P2X');
    expect(normalizeReferralCode('ab')).toBeNull();
    expect(normalizeReferralCode('كود')).toBeNull();
    expect(normalizeReferralCode('A'.repeat(17))).toBeNull();
    expect(referralCodeInput.safeParse('K7QM 4P2X').data).toBe('K7QM4P2X');
    expect(referralCodeInput.safeParse('<script>').success).toBe(false);
  });
});

describe('D217 canonical mailbox (alias tricks)', () => {
  it('folds Gmail dots, googlemail and +tags; keeps other providers as typed (lower case)', () => {
    expect(canonicalEmail('A.Li.Ce+promo@GMAIL.com')).toBe('alice@gmail.com');
    expect(canonicalEmail('alice@googlemail.com')).toBe('alice@gmail.com');
    expect(canonicalEmail('bob+x@outlook.com')).toBe('bob@outlook.com');
    expect(canonicalEmail('b.o.b+x@example.com')).toBe('b.o.b+x@example.com');
    expect(canonicalEmail('Sara@Example.COM')).toBe('sara@example.com');
  });
});

describe('D217 masked names', () => {
  it('keeps the first and last grapheme', () => {
    expect(maskName('سارة')).toBe('س***ة');
    expect(maskName('Ahmad')).toBe('A***d');
    expect(maskName('Al')).toBe('A***');
    expect(maskName('')).toBe('***');
    expect(maskName('👩‍👩‍👧 Lina')).toBe('👩‍👩‍👧***a');
  });
});

describe('D217 amounts and milestones', () => {
  const ms = parseMilestones([
    { friends: 1, cherries: 50000 },
    { friends: 5, cherries: 300000 },
    { friends: 15, cherries: 1000000 },
  ]);

  it('first recharge: floor(coins × cherries per coin × bps / 10 000)', () => {
    expect(firstRechargeCherries(1000n, 10, 500)).toBe(500n);
    expect(firstRechargeCherries(7n, 10, 500)).toBe(3n);
    expect(firstRechargeCherries(1000n, 10, 0)).toBe(0n);
    expect(firstRechargeCherries(0n, 10, 500)).toBe(0n);
  });

  it('the totals the page shows come from the settings', () => {
    expect(milestonesTotal(ms)).toBe(1_350_000n);
    expect(heroUpTo({ inviterSignupCherries: 20_000n, milestones: ms })).toBe(20_000n * 15n + 1_350_000n);
    expect(heroUpTo({ inviterSignupCherries: 20_000n, milestones: [] })).toBe(20_000n);
  });

  it('locked / unlocked (counting friends in their hold) / claimed', () => {
    const credited = new Set([1]);
    expect(milestoneState(ms[0]!, { qualified: 1, pending: 0 }, credited)).toBe('CLAIMED');
    expect(milestoneState(ms[1]!, { qualified: 2, pending: 3 }, credited)).toBe('UNLOCKED');
    expect(milestoneState(ms[1]!, { qualified: 2, pending: 2 }, credited)).toBe('LOCKED');
  });

  it('a bad stored list reads as no milestones; a change must increase', () => {
    expect(parseMilestones('nope')).toEqual([]);
    expect(
      parseMilestones([
        { friends: 5, cherries: 1 },
        { friends: 1, cherries: 1 },
      ]),
    ).toEqual([]);
    expect(
      referralSettingsPatch.safeParse({
        milestones: [
          { friends: 3, cherries: 10 },
          { friends: 2, cherries: 10 },
        ],
      }).success,
    ).toBe(false);
    expect(referralSettingsPatch.safeParse({}).success).toBe(false);
    expect(referralSettingsPatch.safeParse({ firstRechargeBps: 5001 }).success).toBe(false);
    expect(referralSettingsPatch.safeParse({ inviterSignupCherries: -1 }).success).toBe(false);
    expect(referralSettingsPatch.parse({ inviterSignupCherries: '25000' }).inviterSignupCherries).toBe(
      25_000n,
    );
  });

  it('the panel body needs a change, a reason and the code; the patch keeps only the settings', () => {
    expect(adminReferralSettingsBody.safeParse({ reason: 'x', totpCode: '123456' }).success).toBe(false);
    expect(adminReferralSettingsBody.safeParse({ enabled: false, reason: 'x' }).success).toBe(false);
    const body = adminReferralSettingsBody.parse({
      enabled: false,
      holdHours: 48,
      reason: 'x',
      totpCode: '123456',
    });
    expect(patchOf(body)).toEqual({ enabled: false, holdHours: 48 });
  });
});

describe('D217 config', () => {
  const base = {
    NODE_ENV: 'development',
    DATABASE_URL: 'postgresql://u:p@localhost:5432/kabso_dev',
    REDIS_URL: 'redis://localhost:6379/0',
    JWT_ACCESS_SECRET: 'x'.repeat(48),
    APP_PUBLIC_URL: 'https://kabsolive.com',
  };
  it('the sweeper interval defaults to 5 minutes; off is refused in production', () => {
    expect(loadConfig(base).referrals.sweepIntervalSeconds).toBe(300);
    expect(loadConfig(base).rateLimits.referralApplyUser).toEqual({ max: 10, windowSeconds: 86_400 });
    const prod = envSchema.safeParse({
      ...base,
      NODE_ENV: 'production',
      REFERRAL_SWEEP_INTERVAL_SECONDS: '0',
    });
    expect(prod.success).toBe(false);
    expect(prod.error!.issues.some((i) => i.path[0] === 'REFERRAL_SWEEP_INTERVAL_SECONDS')).toBe(true);
  });
});
