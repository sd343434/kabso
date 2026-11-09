import { randomBytes } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { ConfigValidationError, loadConfig } from '../../config/app-config.js';
import { updatePaymentSettingsSchema } from '../payment-settings/payment-settings.rules.js';
import { estimatedFeeMinor, grossUpMinor, topupPriceOf } from './topup-rules.js';

const base = {
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  JWT_ACCESS_SECRET: randomBytes(48).toString('base64url'),
  APP_PUBLIC_URL: 'https://kabso.example/',
};

/** What Kabso keeps of `charged` after Stripe's `percent × charged + fixed` (Stripe rounds the fee half up). */
const net = (charged: number, bps: number, fixed: number) => charged - estimatedFeeMinor(charged, bps, fixed);

describe('D344 Stripe fee in the website price (gross-up)', () => {
  it('charged = ceil((base + fixed) / (1 − percent)), in minor units', () => {
    // $12.50 at 2.9 % + 30 ¢: (1250 + 30) / 0.971 = 1318.23… → 1319.
    expect(grossUpMinor(1250, 290, 30)).toBe(1319);
    expect(grossUpMinor(125, 290, 30)).toBe(160); // 155 / 0.971 = 159.6… → 160
    expect(grossUpMinor(1, 0, 0)).toBe(1);
    expect(grossUpMinor(1000, 0, 30)).toBe(1030);
    expect(grossUpMinor(1000, 1000, 0)).toBe(1112); // 1000 / 0.9 = 1111.1… → 1112
    expect(grossUpMinor(970, 300, 0)).toBe(1000); // exact: no extra cent
  });

  it('Kabso always nets at least the base price (every owner package, several rate sets)', () => {
    const packages = [125, 625, 1250, 6250, 12_500, 62_500];
    for (const [bps, fixed] of [
      [290, 30],
      [340, 30],
      [150, 25],
      [440, 30],
      [0, 0],
      [2000, 10_000],
    ] as const) {
      for (const b of packages) {
        const charged = grossUpMinor(b, bps, fixed);
        expect(net(charged, bps, fixed), `${b} @ ${bps}+${fixed}`).toBeGreaterThanOrEqual(b);
        // …and never more than one minor unit over what is needed (rounded up once).
        expect((charged - 1) * (10_000 - bps) < (b + fixed) * 10_000, `${b} @ ${bps}+${fixed}`).toBe(true);
      }
    }
  });

  it('works for any minor unit: zero-decimal (JPY) and three-decimal (KWD) amounts', () => {
    // ¥1 000 at 3.6 % + ¥0: 1000 / 0.964 = 1037.3… → ¥1 038.
    expect(grossUpMinor(1000, 360, 0)).toBe(1038);
    // 4.000 KWD (4000 fils) at 2.9 % + 0.100 KWD (100 fils): 4100 / 0.971 = 4222.4… → 4223 fils.
    expect(grossUpMinor(4000, 290, 100)).toBe(4223);
    // Very large packages stay exact (BigInt).
    expect(grossUpMinor(9_000_000_000_000, 290, 30)).toBe(9_268_795_056_674);
  });

  it('off → the base price, parts recorded as 0; bounds are enforced', () => {
    expect(topupPriceOf(1250, { grossUp: false, percentBps: 290, fixedMinor: 30 })).toEqual({
      priceMinor: 1250,
      baseMinor: 1250,
      percentBps: 0,
      fixedMinor: 0,
    });
    expect(topupPriceOf(1250, { grossUp: true, percentBps: 290, fixedMinor: 30 })).toEqual({
      priceMinor: 1319,
      baseMinor: 1250,
      percentBps: 290,
      fixedMinor: 30,
    });
    expect(() => grossUpMinor(0, 290, 30)).toThrow(RangeError);
    expect(() => grossUpMinor(100, 2001, 30)).toThrow(RangeError);
    expect(() => grossUpMinor(100, 290, 10_001)).toThrow(RangeError);
    expect(() => grossUpMinor(100, 2.5, 30)).toThrow(RangeError);
  });

  it('server settings: on by default with the placeholder 2.9 % + 30 ¢; bounded', () => {
    expect(loadConfig(base).topup.fee).toEqual({ grossUp: true, percentBps: 290, fixedMinor: 30 });
    expect(
      loadConfig({
        ...base,
        TOPUP_STRIPE_FEE_GROSS_UP: 'false',
        TOPUP_STRIPE_FEE_PERCENT: '3.25',
        TOPUP_STRIPE_FEE_FIXED_MINOR: '0',
      }).topup.fee,
    ).toEqual({ grossUp: false, percentBps: 325, fixedMinor: 0 });
    for (const [k, v] of [
      ['TOPUP_STRIPE_FEE_PERCENT', '21'],
      ['TOPUP_STRIPE_FEE_PERCENT', '2.905'],
      ['TOPUP_STRIPE_FEE_PERCENT', '-1'],
      ['TOPUP_STRIPE_FEE_FIXED_MINOR', '10001'],
      ['TOPUP_STRIPE_FEE_FIXED_MINOR', '0.3'],
      ['TOPUP_STRIPE_FEE_GROSS_UP', 'yes'],
    ] as const) {
      expect(() => loadConfig({ ...base, [k]: v }), `${k}=${v}`).toThrow(ConfigValidationError);
    }
  });

  it('the panel takes the three settings (null = the server value) within bounds', () => {
    const auth = { totpCode: '123456', reason: 'my Stripe rates' };
    expect(
      updatePaymentSettingsSchema.safeParse({ ...auth, stripeFeePercentBps: 340, stripeFeeFixedMinor: 30 })
        .success,
    ).toBe(true);
    expect(updatePaymentSettingsSchema.safeParse({ ...auth, stripeFeeGrossUp: false }).success).toBe(true);
    expect(updatePaymentSettingsSchema.safeParse({ ...auth, stripeFeePercentBps: null }).success).toBe(true);
    for (const bad of [
      { stripeFeePercentBps: 2001 },
      { stripeFeePercentBps: 2.5 },
      { stripeFeeFixedMinor: -1 },
      { stripeFeeFixedMinor: 10_001 },
      { stripeFeeGrossUp: 'true' },
    ]) {
      expect(updatePaymentSettingsSchema.safeParse({ ...auth, ...bad }).success, JSON.stringify(bad)).toBe(
        false,
      );
    }
  });
});
