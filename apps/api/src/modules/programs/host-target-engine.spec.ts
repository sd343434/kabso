import { describe, expect, it } from 'vitest';
import {
  ALL_DAY,
  CHERRY_LADDER,
  DEFAULT_TARGET_TUNING,
  NEW_HOST_DEFAULTS,
  assignHostTargets,
  cappedTargetReward,
  catalogueStats,
  catalogueVersion,
  catalogueWindows,
  completionAdjustment,
  enumerateTargets,
  expectedProfitUnits,
  parseTargetCode,
  percentile,
  platformProfitUnits,
  rewardCherriesFor,
  targetCode,
  targetSeed,
  targetTitle,
  unitsUsd,
  type CatalogueGift,
  type HostDay,
  type HostProfile,
  type ProfitEconomy,
} from './host-target-engine.js';

/** The owner's economy: 1 000 000 coins = $12.50, 1 000 000 cherries = $1.10, 10 cherries a coin, 65 % / 50 % / 10 %, RTP 75 %. */
const ECONOMY: ProfitEconomy = {
  cherriesPerCoin: 10,
  coinCentsPerMillion: 1_250,
  rateCherries: 1_000_000,
  rateMinor: 110,
  luckyRtpBps: 7_500,
  luckyHostShareBps: 1_000,
  hostShareBps: { POPULAR: 6_500, EVENT: 6_500, FUN: 6_500, QUIPS: 5_000 },
};

/** A realistic enabled catalogue: 20 paid gifts in 4 categories (+ a free quip, never a count target). */
const GIFTS: CatalogueGift[] = [
  ...Array.from({ length: 8 }, (_, i) => ({
    code: `rose_${String(i)}`,
    category: 'POPULAR',
    priceCoins: 10 * (i + 1),
    nameAr: `وردة ${String(i)}`,
    nameEn: `Rose ${String(i)}`,
    lucky: false,
  })),
  ...Array.from({ length: 5 }, (_, i) => ({
    code: `car_${String(i)}`,
    category: 'EVENT',
    priceCoins: 5_000 * (i + 1),
    nameAr: `سيارة ${String(i)}`,
    nameEn: `Car ${String(i)}`,
    lucky: false,
  })),
  ...Array.from({ length: 4 }, (_, i) => ({
    code: `luck_${String(i)}`,
    category: 'LUCKY',
    priceCoins: 10 * (i + 1),
    nameAr: `حظ ${String(i)}`,
    nameEn: `Luck ${String(i)}`,
    lucky: true,
  })),
  { code: 'warrior', category: 'FUN', priceCoins: 1_000, nameAr: 'المحارب', nameEn: 'Warrior', lucky: false },
  { code: 'quip_a', category: 'QUIPS', priceCoins: 1, nameAr: 'قفشة', nameEn: 'Quip', lucky: false },
  { code: 'quip_free', category: 'QUIPS', priceCoins: 0, nameAr: 'مجانية', nameEn: 'Free', lucky: false },
];

const day = (i: number, over: Partial<HostDay> = {}): HostDay => ({
  day: `2027-01-${String(30 - i).padStart(2, '0')}`,
  giftCherries: 0,
  luckyCherries: 0,
  giftCoins: 0,
  luckyCoins: 0,
  sends: 0,
  supporters: 0,
  maxCombo: 0,
  liveMinutes: 120,
  hourCherries: new Array<number>(24).fill(0),
  giftQty: {},
  ...over,
});

const profile = (days: HostDay[], over: Partial<HostProfile> = {}): HostProfile => ({
  band: 2,
  days,
  liveHourMinutes: new Array<number>(24).fill(0),
  avgViewers: 20,
  recentAssigned: 0,
  recentCompleted: 0,
  recentCodes: [],
  ...over,
});

/** Twenty active days with known values: gift cherries 100k … 2M in steps of 100k (shuffled). */
function richHost(): HostDay[] {
  const order = [7, 2, 15, 11, 0, 19, 4, 9, 13, 1, 17, 6, 10, 3, 18, 8, 14, 5, 16, 12];
  return order.map((k, i) => {
    const cherries = (k + 1) * 100_000;
    const hour = new Array<number>(24).fill(0);
    hour[21] = cherries * 0.5;
    hour[22] = cherries * 0.5;
    return day(i, {
      giftCherries: cherries,
      luckyCherries: (k + 1) * 1_000,
      giftCoins: Math.round(cherries / 6.5),
      sends: 50 + k * 5,
      supporters: 5 + k,
      maxCombo: 10 + k,
      hourCherries: hour,
      giftQty: { warrior: 10 + k, rose_0: 30 },
    });
  });
}

describe('D281 the target catalogue', () => {
  it('holds more than 100 000 distinct targets for a 19-gift catalogue (enumerated, not hand-written)', () => {
    const codes = new Set<string>();
    let n = 0;
    for (const t of enumerateTargets(GIFTS)) {
      codes.add(t.code);
      n += 1;
    }
    expect(codes.size).toBe(n);
    expect(n).toBeGreaterThan(100_000);
    const stats = catalogueStats(GIFTS);
    expect(stats.total).toBe(n);
    // 19 paid gifts (the free quip never), 5 categories, 147 windows.
    expect(stats).toMatchObject({ gifts: 19, categories: 5, windows: 147 });
    expect(stats.byKind.GIFT_CHERRIES).toBe(90 * 147);
    expect(stats.byKind.GIFT_COUNT).toBe(19 * 40 * 147);
    // The gift side alone and the kinds without a gift each make many thousands.
    expect(catalogueStats([]).total).toBe((90 + 90 + 20 + 40 + 20) * 147);
  });

  it('follows the gift catalogue: a gift added or switched off adds or removes its targets', () => {
    const base = catalogueStats(GIFTS);
    const more = catalogueStats([
      ...GIFTS,
      { code: 'lion', category: 'FUN', priceCoins: 30_000, nameAr: 'أسد', nameEn: 'Lion', lucky: false },
    ]);
    expect(more.total - base.total).toBe((40 + 20) * 147);
    expect(catalogueVersion(GIFTS)).not.toBe(catalogueVersion(GIFTS.slice(1)));
    expect(catalogueVersion(GIFTS)).toBe(catalogueVersion([...GIFTS].reverse()));
  });

  it('codes round-trip; windows cover the day', () => {
    const t = {
      kind: 'GIFT_COUNT' as const,
      subject: 'warrior',
      amount: 100,
      window: { from: 1200, to: 1440 },
    };
    expect(targetCode(t)).toBe('T.GIFT_COUNT.warrior.100.1200-1440');
    expect(parseTargetCode(targetCode(t))).toEqual(t);
    expect(parseTargetCode('T.NOPE.*.1.0-1440')).toBeNull();
    const w = catalogueWindows();
    expect(w[0]).toEqual(ALL_DAY);
    expect(w.every((x) => x.from >= 0 && x.to <= 1440 && x.from < x.to)).toBe(true);
    expect(targetTitle(t, { giftAr: 'المحارب', giftEn: 'Warrior' })).toEqual({
      ar: 'استقبل 100 هدية من المحارب من 20:00 إلى 24:00',
      en: 'Receive 100 × Warrior between 20:00–24:00',
    });
  });
});

describe('D281 platform profit and the reward', () => {
  it('a normal gift: the coins paid less the host cherries at their dollar value', () => {
    // 1 000 000 coins: $12.50 in, 6 500 000 cherries ($7.15) out → $5.35.
    const units = platformProfitUnits(
      [{ lucky: false, coins: 1_000_000n, chargedCoins: 1_000_000n, hostCherries: 6_500_000n }],
      ECONOMY,
    );
    expect(unitsUsd(units, ECONOMY)).toBeCloseTo(5.35, 6);
  });

  it('a lucky gift: also less the expected payout (RTP)', () => {
    // 1 000 000 coins: $12.50 − 75 % ($9.375) − 1 000 000 cherries ($1.10) → $2.025.
    const units = platformProfitUnits(
      [{ lucky: true, coins: 1_000_000n, chargedCoins: 1_000_000n, hostCherries: 1_000_000n }],
      ECONOMY,
    );
    expect(unitsUsd(units, ECONOMY)).toBeCloseTo(2.025, 6);
    // A bag gift earned nothing now: a loss.
    expect(
      platformProfitUnits([{ lucky: false, coins: 100n, chargedCoins: 0n, hostCherries: 650n }], ECONOMY),
    ).toBeLessThan(0n);
  });

  it('the worked example: a hard target of 3 000 000 cherries from normal gifts → 4 % → 89 790 cherries', () => {
    const profit = expectedProfitUnits('GIFT_CHERRIES', 3_000_000, 0, ECONOMY);
    // 461 538.46 coins = $5.769 in, 3 000 000 cherries = $3.30 out → $2.469 profit.
    expect(unitsUsd(profit, ECONOMY)).toBeCloseTo(2.4692, 4);
    expect(rewardCherriesFor(profit, 400, ECONOMY)).toBe(89_790);
    // Easy 1.5 % and medium 2.5 % of the same profit.
    expect(rewardCherriesFor(profit, 150, ECONOMY)).toBe(33_671);
    expect(rewardCherriesFor(profit, 250, ECONOMY)).toBe(56_118);
  });

  it('lucky targets: profit after the RTP; a higher RTP leaves less', () => {
    const at75 = expectedProfitUnits('LUCKY_CHERRIES', 200_000, 0, ECONOMY);
    expect(unitsUsd(at75, ECONOMY)).toBeCloseTo(0.405, 6);
    const at85 = expectedProfitUnits('LUCKY_CHERRIES', 200_000, 0, { ...ECONOMY, luckyRtpBps: 8_500 });
    expect(unitsUsd(at85, ECONOMY)).toBeCloseTo(0.155, 6);
    // An RTP that leaves nothing: no reward at all.
    expect(expectedProfitUnits('LUCKY_CHERRIES', 200_000, 0, { ...ECONOMY, luckyRtpBps: 9_500 })).toBe(0n);
  });

  it('a gift count target: its coin value as that gift', () => {
    // 100 × the warrior (1 000 coins) = 100 000 coins at 65 %: $1.25 − $0.715 = $0.535.
    const profit = expectedProfitUnits('GIFT_COUNT', 100, 100_000, ECONOMY, { shareBps: 6_500 });
    expect(unitsUsd(profit, ECONOMY)).toBeCloseTo(0.535, 6);
  });

  it('the guard: never more than the share of the ACTUAL profit counted', () => {
    const shown = rewardCherriesFor(
      expectedProfitUnits('GIFT_CHERRIES', 3_000_000, 0, ECONOMY),
      400,
      ECONOMY,
    );
    const halfProfit = expectedProfitUnits('GIFT_CHERRIES', 1_500_000, 0, ECONOMY);
    expect(cappedTargetReward(shown, halfProfit, 400, ECONOMY)).toBe(
      rewardCherriesFor(halfProfit, 400, ECONOMY),
    );
    expect(cappedTargetReward(shown, halfProfit, 400, ECONOMY)).toBeLessThan(shown);
    // More profit than the nominal: still the reward shown.
    const more = expectedProfitUnits('GIFT_CHERRIES', 9_000_000, 0, ECONOMY);
    expect(cappedTargetReward(shown, more, 400, ECONOMY)).toBe(shown);
    // A loss: nothing.
    expect(cappedTargetReward(shown, -5n, 400, ECONOMY)).toBe(0);
  });
});

describe('D281 the smart assignment', () => {
  it('percentiles and the completion adjustment', () => {
    expect(percentile([1, 2, 3, 4, 5], 50)).toBe(3);
    expect(percentile([10, 20], 75)).toBe(17.5);
    expect(percentile([], 90)).toBe(0);
    expect(completionAdjustment(9, 9, 10)).toBe(10);
    expect(completionAdjustment(0, 9, 10)).toBe(-10);
    expect(completionAdjustment(3, 6, 10)).toBe(0);
    expect(completionAdjustment(2, 2, 10)).toBe(0);
  });

  it('three targets, three levels, three kinds; HARD a cherries target; deterministic per host and day', () => {
    const p = profile(richHost());
    const seed = targetSeed('host-1', '2027-01-31');
    const a = assignHostTargets(p, GIFTS, ECONOMY, DEFAULT_TARGET_TUNING, seed);
    expect(a.map((x) => x.level)).toEqual(['EASY', 'MEDIUM', 'HARD']);
    expect(new Set(a.map((x) => x.target.kind)).size).toBe(3);
    expect(['GIFT_CHERRIES', 'LUCKY_CHERRIES']).toContain(a[2]!.target.kind);
    expect(assignHostTargets(p, GIFTS, ECONOMY, DEFAULT_TARGET_TUNING, seed)).toEqual(a);
    // Another day may differ but is equally stable.
    const b = assignHostTargets(p, GIFTS, ECONOMY, DEFAULT_TARGET_TUNING, targetSeed('host-1', '2027-02-01'));
    expect(
      assignHostTargets(p, GIFTS, ECONOMY, DEFAULT_TARGET_TUNING, targetSeed('host-1', '2027-02-01')),
    ).toEqual(b);
    // The reward is the level's share of the nominal profit; 1.5 % < 2.5 % < 4 %.
    expect(a.map((x) => x.rewardBps)).toEqual([150, 250, 400]);
    for (const x of a) expect(x.rewardCherries).toBeGreaterThanOrEqual(0);
  });

  it('the amounts sit on the percentiles of the host’s own days (easy ≈ p50, hard ≈ p90)', () => {
    const days = richHost().map((d) => ({
      ...d,
      luckyCherries: 0,
      sends: 0,
      supporters: 0,
      maxCombo: 0,
      giftQty: {},
      hourCherries: new Array<number>(24).fill(1),
    }));
    // Only all-day gift cherries is supported → every level is that kind, growing.
    const a = assignHostTargets(profile(days), GIFTS, ECONOMY, DEFAULT_TARGET_TUNING, 7);
    expect(a.every((x) => x.target.kind === 'GIFT_CHERRIES')).toBe(true);
    // Days are 100k … 2M: p50 = 1 050 000 → 1 200 000; p75 = 1 525 000 → 1 800 000; p90 = 1 810 000 → 2 000 000.
    expect(a.map((x) => x.reason.basis)).toEqual([1_050_000, 1_525_000, 1_810_000]);
    expect(a.map((x) => x.target.amount)).toEqual([1_200_000, 1_800_000, 2_000_000]);
    expect(a[0]!.reason.percentile).toBe(50);
    expect(a[2]!.reason.avg30).toBe(1_050_000);
  });

  it('raises the levels for a host who always finishes and lowers them for one who never does', () => {
    const days = richHost().map((d) => ({
      ...d,
      luckyCherries: 0,
      sends: 0,
      supporters: 0,
      maxCombo: 0,
      giftQty: {},
      hourCherries: new Array<number>(24).fill(1),
    }));
    const always = assignHostTargets(
      profile(days, { recentAssigned: 21, recentCompleted: 21 }),
      GIFTS,
      ECONOMY,
      DEFAULT_TARGET_TUNING,
      7,
    );
    const never = assignHostTargets(
      profile(days, { recentAssigned: 21, recentCompleted: 0 }),
      GIFTS,
      ECONOMY,
      DEFAULT_TARGET_TUNING,
      7,
    );
    const plain = assignHostTargets(profile(days), GIFTS, ECONOMY, DEFAULT_TARGET_TUNING, 7);
    expect(always[0]!.reason.percentile).toBe(60);
    expect(never[0]!.reason.percentile).toBe(40);
    for (const i of [0, 1, 2]) {
      expect(always[i]!.target.amount).toBeGreaterThanOrEqual(plain[i]!.target.amount);
      expect(never[i]!.target.amount).toBeLessThanOrEqual(plain[i]!.target.amount);
    }
    expect(always[0]!.target.amount).toBeGreaterThan(never[0]!.target.amount);
  });

  it('never repeats a target given in the last N days', () => {
    const days = richHost().map((d) => ({
      ...d,
      luckyCherries: 0,
      sends: 0,
      supporters: 0,
      maxCombo: 0,
      giftQty: {},
      hourCherries: new Array<number>(24).fill(1),
    }));
    const first = assignHostTargets(profile(days), GIFTS, ECONOMY, DEFAULT_TARGET_TUNING, 7);
    const again = assignHostTargets(
      profile(days, { recentCodes: first.map((x) => x.target.code) }),
      GIFTS,
      ECONOMY,
      DEFAULT_TARGET_TUNING,
      7,
    );
    for (const x of again) expect(first.map((f) => f.target.code)).not.toContain(x.target.code);
    expect(new Set(again.map((x) => x.target.code)).size).toBe(3);
  });

  it('new hosts get the band defaults', () => {
    for (const band of [1, 2, 3, 4]) {
      const a = assignHostTargets(
        profile([day(0, { giftCherries: 5 })], { band }),
        GIFTS,
        ECONOMY,
        DEFAULT_TARGET_TUNING,
        1,
      );
      expect(a.map((x) => x.target.kind)).toEqual(['GIFT_SENDS', 'SUPPORTERS', 'GIFT_CHERRIES']);
      expect(a.every((x) => x.reason.newHost)).toBe(true);
      expect(a[2]!.target.amount).toBe(NEW_HOST_DEFAULTS.GIFT_CHERRIES[band - 1]![2]);
      expect(CHERRY_LADDER).toContain(a[2]!.target.amount);
      expect(a[2]!.rewardCherries).toBeGreaterThan(0);
    }
  });

  it('gift count targets name a gift the host usually receives; the usual hours make a windowed target', () => {
    const seen = new Set<string>();
    for (let s = 0; s < 60; s++) {
      for (const x of assignHostTargets(profile(richHost()), GIFTS, ECONOMY, DEFAULT_TARGET_TUNING, s)) {
        seen.add(x.target.kind);
        if (x.target.kind === 'GIFT_COUNT') expect(['warrior', 'rose_0']).toContain(x.target.subject);
        if (x.target.kind === 'GIFT_CHERRIES' && x.target.window.from !== 0)
          expect(x.target.window).toEqual({ from: 1260, to: 1380 });
      }
    }
    expect(seen).toEqual(
      new Set([
        'GIFT_CHERRIES',
        'LUCKY_CHERRIES',
        'GIFT_COUNT',
        'CATEGORY_COUNT',
        'SUPPORTERS',
        'GIFT_SENDS',
        'COMBO',
      ]),
    );
  });
});
