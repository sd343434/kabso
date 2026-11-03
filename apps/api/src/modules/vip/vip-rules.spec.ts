import { describe, expect, it } from 'vitest';
import { createVipTierBody, reorderVipTiersBody, updateVipTierBody } from './vip.schemas.js';
import {
  planVipPurchase,
  VIP_BUILT_PERKS,
  VIP_MAX_AHEAD_DAYS,
  VIP_MAX_TIERS,
  vipActive,
  vipDaysLeft,
  vipOrderOf,
  vipPerkAvailable,
  type VipCurrent,
  type VipTarget,
} from './vip-rules.js';

/** D252 (CONVENTIONS §10.93): the purchase rules and the panel's field rules of «شراء VIP». */

const DAY = 86_400_000;
const NOW = new Date('2026-11-03T12:00:00.000Z');
const days = (n: number) => new Date(NOW.getTime() + n * DAY);

const tier = (id: string, rank: number, extra: Partial<VipTarget> = {}): VipTarget => ({
  id,
  rank,
  enabled: true,
  durationDays: 30,
  ...extra,
});
const holding = (tierId: string, rank: number, expiresInDays: number): VipCurrent => ({
  tierId,
  rank,
  startedAt: days(expiresInDays - 30),
  expiresAt: days(expiresInDays),
});

describe('planVipPurchase', () => {
  it('NEW: no membership — the tier for its length from now', () => {
    expect(planVipPurchase(null, tier('a', 1), NOW)).toEqual({
      ok: true,
      kind: 'NEW',
      startedAt: NOW,
      expiresAt: days(30),
    });
  });

  it('NEW: a membership that ended counts as none (any tier, even a lower one)', () => {
    const ended = holding('b', 2, -1);
    expect(planVipPurchase(ended, tier('a', 1, { durationDays: 7 }), NOW)).toMatchObject({
      ok: true,
      kind: 'NEW',
      expiresAt: days(7),
    });
    // Ending exactly now is ended.
    expect(planVipPurchase(holding('b', 2, 0), tier('a', 1), NOW)).toMatchObject({ ok: true, kind: 'NEW' });
  });

  it('RENEW: the same tier while active moves the end by its length and keeps the start', () => {
    const held = holding('a', 1, 10);
    expect(planVipPurchase(held, tier('a', 1), NOW)).toEqual({
      ok: true,
      kind: 'RENEW',
      startedAt: held.startedAt,
      expiresAt: days(40),
    });
  });

  it('RENEW: refused past the prepaid limit', () => {
    expect(planVipPurchase(holding('a', 1, VIP_MAX_AHEAD_DAYS - 30), tier('a', 1), NOW)).toMatchObject({
      ok: true,
      expiresAt: days(VIP_MAX_AHEAD_DAYS),
    });
    expect(planVipPurchase(holding('a', 1, VIP_MAX_AHEAD_DAYS - 29), tier('a', 1), NOW)).toEqual({
      ok: false,
      refusal: 'renewal_limit',
    });
  });

  it('UPGRADE: a higher tier while active starts now at its own length; the days left are not carried', () => {
    expect(planVipPurchase(holding('a', 1, 25), tier('b', 2, { durationDays: 30 }), NOW)).toEqual({
      ok: true,
      kind: 'UPGRADE',
      startedAt: NOW,
      expiresAt: days(30),
    });
  });

  it('a lower (or equal-rank) other tier while active is refused', () => {
    expect(planVipPurchase(holding('b', 2, 5), tier('a', 1), NOW)).toEqual({
      ok: false,
      refusal: 'downgrade',
    });
    expect(planVipPurchase(holding('b', 2, 5), tier('c', 2), NOW)).toEqual({
      ok: false,
      refusal: 'downgrade',
    });
  });

  it('a tier switched off is never sold, not even as a renewal', () => {
    expect(planVipPurchase(null, tier('a', 1, { enabled: false }), NOW)).toEqual({
      ok: false,
      refusal: 'tier_off',
    });
    expect(planVipPurchase(holding('a', 1, 5), tier('a', 1, { enabled: false }), NOW)).toEqual({
      ok: false,
      refusal: 'tier_off',
    });
  });
});

describe('VIP helpers', () => {
  it('active and days left', () => {
    expect(vipActive(days(1), NOW)).toBe(true);
    expect(vipActive(NOW, NOW)).toBe(false);
    expect(vipActive(null, NOW)).toBe(false);
    expect(vipDaysLeft(days(1.2), NOW)).toBe(2);
    expect(vipDaysLeft(days(-3), NOW)).toBe(0);
  });

  it('no perk is built yet: every perk is listed, none available', () => {
    expect(VIP_BUILT_PERKS.size).toBe(0);
    expect(vipPerkAvailable('BADGE')).toBe(false);
  });

  it('an order names every tier exactly once', () => {
    expect(vipOrderOf(['b', 'a', 'c'], ['a', 'b', 'c'])).toEqual(
      new Map([
        ['b', 1],
        ['a', 2],
        ['c', 3],
      ]),
    );
    expect(vipOrderOf(['a', 'b'], ['a', 'b', 'c'])).toBeNull();
    expect(vipOrderOf(['a', 'a', 'b'], ['a', 'b', 'c'])).toBeNull();
    expect(vipOrderOf(['a', 'b', 'x'], ['a', 'b', 'c'])).toBeNull();
  });
});

describe('VIP panel bodies', () => {
  const base = {
    code: 'VIP_1',
    nameAr: 'VIP 1',
    nameEn: 'VIP 1',
    color: '#c9a227',
    priceCoins: 3_000_000,
    durationDays: 30,
    reason: 'owner D252',
  };

  it('a tier: colour upper-cased, price and length bounded; the badge art is a hosted https URL', () => {
    const ok = createVipTierBody.safeParse(base);
    expect(ok.success && ok.data.color).toBe('#C9A227');
    expect(createVipTierBody.safeParse({ ...base, color: 'gold' }).success).toBe(false);
    expect(createVipTierBody.safeParse({ ...base, priceCoins: 0 }).success).toBe(false);
    expect(createVipTierBody.safeParse({ ...base, durationDays: 366 }).success).toBe(false);
    expect(createVipTierBody.safeParse({ ...base, code: 'vip1' }).success).toBe(false);
    expect(createVipTierBody.safeParse({ ...base, badgeStill: 'http://x.example/a.png' }).success).toBe(
      false,
    );
    expect(
      createVipTierBody.safeParse({
        ...base,
        badgeAnimation: 'https://cdn.k.test/vip1_badge.svga',
        badgeStill: 'https://cdn.k.test/vip1_badge.png',
      }).success,
    ).toBe(true);
    // Hosted only: a bundled asset path is rejected (nothing is bundled).
    expect(createVipTierBody.safeParse({ ...base, badgeStill: 'assets/vip/vip1_badge.png' }).success).toBe(
      false,
    );
  });

  it('perks: codes unique within the tier, at most 20, with optional art', () => {
    const perk = (code: string) => ({ code, titleAr: 'شارة', titleEn: 'Badge' });
    expect(
      createVipTierBody.safeParse({
        ...base,
        perks: [
          {
            ...perk('AVATAR_FRAME'),
            animation: 'https://cdn.k.test/vip1_frame.svga',
            still: 'https://cdn.k.test/vip1_frame.png',
            artWidth: 500,
            artHeight: 500,
          },
        ],
      }).success,
    ).toBe(true);
    expect(createVipTierBody.safeParse({ ...base, perks: [perk('BADGE'), perk('FRAME')] }).success).toBe(
      true,
    );
    const dup = createVipTierBody.safeParse({ ...base, perks: [perk('BADGE'), perk('BADGE')] });
    expect(dup.success).toBe(false);
    expect(dup.error?.issues[0]).toMatchObject({ code: 'custom', params: { issue: 'duplicate_code' } });
    const many = Array.from({ length: 21 }, (_, i) => perk(`P${i}`));
    expect(createVipTierBody.safeParse({ ...base, perks: many }).success).toBe(false);
  });

  it('an edit changes something besides the reason; an order needs ids', () => {
    expect(updateVipTierBody.safeParse({ reason: 'x' }).success).toBe(false);
    expect(updateVipTierBody.safeParse({ priceCoins: 5, reason: 'x' }).success).toBe(true);
    expect(reorderVipTiersBody.safeParse({ tierIds: [], reason: 'x' }).success).toBe(false);
  });
});

describe('D252c twelve tiers (owner: «لدينا ١٢ في اي بي وكل في اي بي له امتيازات»)', () => {
  it('the panel takes at least 12 tiers and reorders all 12', () => {
    expect(VIP_MAX_TIERS).toBeGreaterThanOrEqual(12);
    const ids = Array.from({ length: 12 }, (_, i) => `0192f1d0-0000-7000-8000-0000000000${String(i + 10)}`);
    expect(reorderVipTiersBody.safeParse({ tierIds: ids, reason: 'order the twelve tiers' }).success).toBe(
      true,
    );
  });
});
