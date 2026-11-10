import { describe, expect, it } from 'vitest';
import { ApiError } from '../src/api';
import { CAPACITY_FALLBACK_SECONDS, capacityRetryAt, errorKey, secondsLeft } from '../src/errors';
import { STRINGS } from '../src/i18n';

/** D351 (v1.113-live, CONVENTIONS §10.148): the studio's «البث مزدحم» after LIVE_CAPACITY_FULL. */
describe('LIVE_CAPACITY_FULL in the studio (D351)', () => {
  const full = (retryAfter: number | null) =>
    new ApiError(503, 'LIVE_CAPACITY_FULL', 'Live is busy right now, please try again shortly.', retryAfter);

  it('says the same words as the app, in Arabic and English', () => {
    expect(errorKey(full(60))).toEqual({ key: 'errCapacityFull' });
    expect(STRINGS.ar.errCapacityFull).toBe('البث مزدحم الآن، حاول بعد قليل');
    expect(STRINGS.en.errCapacityFull).toBe('Live is busy right now, please try again shortly.');
    expect(STRINGS.ar.capacityRetryIn).toContain('{wait}');
    expect(STRINGS.en.capacityRetryIn).toContain('{wait}');
  });

  it('waits out Retry-After (60 s without it) before «حاول مجددًا»', () => {
    const now = 1_000_000;
    expect(capacityRetryAt(full(45), now)).toBe(now + 45_000);
    expect(capacityRetryAt(full(null), now)).toBe(now + CAPACITY_FALLBACK_SECONDS * 1000);
    expect(capacityRetryAt(full(Number.NaN), now)).toBe(now + 60_000);
    expect(capacityRetryAt(full(0), now)).toBe(now + 60_000);
    expect(capacityRetryAt(new ApiError(503, 'SERVICE_UNAVAILABLE', 'x', 30), now)).toBeNull();
    expect(capacityRetryAt(new Error('x'), now)).toBeNull();
    expect(secondsLeft(now + 45_000, now)).toBe(45);
    expect(secondsLeft(now + 44_001, now)).toBe(45);
    expect(secondsLeft(now, now + 5)).toBe(0);
  });

  it('the hosting-off error is still its own message', () => {
    expect(errorKey(new ApiError(503, 'LIVE_HOSTING_UNAVAILABLE', 'x'))).toEqual({ key: 'gateHostingOff' });
  });
});
