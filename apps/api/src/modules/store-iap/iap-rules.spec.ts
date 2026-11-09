import { describe, expect, it } from 'vitest';
import {
  accountTokenOf,
  consumptionPercentage,
  dollarsBucket,
  refundReasonText,
  tenureBucket,
  VOIDED_MAX_WINDOW_MS,
  voidedWindow,
} from './iap-rules.js';

/** D345 (§10.144): the pure rules of store purchases. */
describe('store purchase rules', () => {
  const id = '0192f1c2-0000-7000-8000-0000000000AB';

  it('binds a purchase to the account: iOS the id itself, Android a SHA-256 hex', () => {
    expect(accountTokenOf('IOS', id)).toBe(id.toLowerCase());
    const android = accountTokenOf('ANDROID', id);
    expect(android).toMatch(/^[0-9a-f]{64}$/);
    expect(android).not.toContain(id.toLowerCase());
  });

  it('writes the refund reason the panel shows', () => {
    const at = new Date('2026-11-20T10:00:00Z');
    expect(refundReasonText('GOOGLE_PLAY', at, 'GPA.1234-5678', 'chargeback')).toBe(
      'استرداد عبر Google Play بتاريخ 2026-11-20 — طلب GPA.1234-5678 (chargeback)',
    );
    expect(refundReasonText('APP_STORE', at, '2000000123')).toBe(
      'استرداد عبر App Store بتاريخ 2026-11-20 — معاملة 2000000123',
    );
    expect(refundReasonText('GOOGLE_PLAY', at, 'x'.repeat(900)).length).toBe(500);
  });

  it('computes the consumed share in milliunits', () => {
    expect(consumptionPercentage(1000n, 1000n)).toBe(0);
    expect(consumptionPercentage(1000n, 0n)).toBe(100_000);
    expect(consumptionPercentage(3n, 2n)).toBe(33_333);
    expect(consumptionPercentage(1000n, -5n)).toBe(100_000);
    expect(consumptionPercentage(1000n, 5000n)).toBe(0);
  });

  it("buckets ConsumptionRequestV1's context", () => {
    expect([0, 3, 10, 30, 90, 180, 365].map(tenureBucket)).toEqual([1, 2, 3, 4, 5, 6, 7]);
    expect([0, 1, 5_000, 10_000, 50_000, 100_000, 200_000].map(dollarsBucket)).toEqual([1, 2, 3, 4, 5, 6, 7]);
  });

  it('keeps the voided window within 30 days, overlapping the last poll by an hour', () => {
    const now = new Date('2026-11-20T00:00:00Z');
    const [s0, e0] = voidedWindow(null, now);
    expect(e0 - s0).toBeLessThan(VOIDED_MAX_WINDOW_MS);
    const [s1] = voidedWindow(new Date('2026-11-19T00:00:00Z'), now);
    expect(s1).toBe(Date.parse('2026-11-18T23:00:00Z'));
    const [s2] = voidedWindow(new Date('2026-01-01T00:00:00Z'), now);
    expect(s2).toBe(s0);
    const [s3] = voidedWindow(new Date('2026-11-19T00:00:00Z'), now, 3 * 86_400_000);
    expect(s3).toBe(Date.parse('2026-11-17T00:00:00Z'));
  });
});
